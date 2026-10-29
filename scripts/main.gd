extends Node3D
const Rules = preload("res://scripts/rules.gd")
const Portraits = preload("res://scripts/portraits.gd")
const WeaponIcons=preload("res://scripts/weapon_icons.gd")
const MapUnit=preload("res://scripts/campaign_map_unit.gd")
const MapOverlay=preload("res://scripts/map_overlay.gd")
const MapSurface=preload("res://scripts/map_surface.gd")
const TerrainCard=preload("res://scripts/terrain_card.gd")
const BattleForecast=preload("res://scripts/battle_forecast.gd")
const FOG_FIELDS=["fog_enabled","fog_mode","fog_density","fog_depth_begin","fog_depth_end","fog_depth_curve","fog_light_color","fog_light_energy","fog_sky_affect"]
var map_catalog=preload("res://scripts/campaign_catalog.gd").new()
var map_facings: Dictionary={}
const DISPLAY_FONT = preload("res://assets/fonts/CormorantGaramond.ttf")
var portraits=Portraits.new()
var story: Dictionary
var profiles: Dictionary
var dialogue_lines: Array=[]
var dialogue_index=0
var dialogue_callback: Callable
var dialogue_label: Label
var dialogue_name: Label
var dialogue_portrait: TextureRect
var dialogue_stage: Control
var dialogue_reveal=0.0
const CombatTrail=preload("res://scripts/combat_trail.gd")
const CombatImpact=preload("res://scripts/combat_impact.gd")
const CombatProjectile=preload("res://scripts/combat_projectile.gd")
const CombatCamera=preload("res://scripts/combat_camera.gd")
const CombatHUD=preload("res://scripts/combat_hud.gd")
const CombatTransition=preload("res://scripts/combat_transition.gd")
const PhaseBanner=preload("res://scripts/phase_banner.gd")
var phase_skip=false
var phase_banner_active=false
const CriticalCutin=preload("res://scripts/critical_cutin.gd")
const Fighters = preload("res://scripts/fighters.gd")
var fighters: RefCounted
const Scenery = preload("res://scripts/scenery.gd")
var scenery: RefCounted
const CLASSES = ["Vanguard","Knight","Ranger","Arcanist","Warden","Rider","Corsair","Duelist"]
var game = Rules.new()
var preferences=preload("res://scripts/preferences.gd").new()
var settings_path="user://preferences.json"
var options_return="title"
var tactics=preload("res://scripts/tactics.gd").new()
var camera: Camera3D
var map_navigation=preload("res://scripts/tactical_camera.gd").new()
var environment: Environment
var sunlight: DirectionalLight3D
var default_lighting: Dictionary
var world: Node3D
var markers: Node3D
var pieces: Node3D
var stage: Node3D
var canvas: CanvasLayer
var ui: Control
var side: VBoxContainer
var terrain_card: Control
var forecast_panel: Control
var battle_menu: Control
var status: Label
var selected = null
var target = null
var origin = null
var busy = false
var screen = "title"
var music: AudioStreamPlayer
var score: AudioStreamSynchronized
var sfx_streams: Dictionary={}
var sfx_players: Array=[]
var music_transition: Tween
var sprites: Array = []
var unit_nodes: Dictionary={}
var moving_id=""
var route_preview: Node3D
var last_hover=Vector2i(-1,-1)
var cursor_tile=Vector2i.ZERO
var cursor_visible=false
var clock = 0.0
var skip_combat = false
var show_danger = false
var preview_actor: Node3D
var preview_unit: Dictionary
var reward_panel: PanelContainer
var reward_skip=false
var transfer_text: TextEdit
var transfer_return="title"
var browser_transfer_callback
const GOLD = Color("8d6a32")
const INK = Color("e8e0cb")
const SAVE = "user://campaign.json"
var save_path=SAVE
var save_failed=false
var save_warning_queued=false

func _ready():
	var map_catalog_loaded=map_catalog.open("res://visuals/units.json")
	assert(map_catalog_loaded,"Campaign map sprite catalog must be valid")
	story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	scenery=Scenery.new()
	fighters=Fighters.new()
	RenderingServer.set_default_clear_color(Color("b9c7ca"))
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	environment=settings
	settings.background_mode=Environment.BG_SKY
	var sky=Sky.new();var sky_material=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("648aa7");sky_material.sky_horizon_color=Color("d8dbce")
	sky_material.ground_bottom_color=Color("7a8163");sky_material.ground_horizon_color=Color("d8dbce")
	sky.sky_material=sky_material;settings.sky=sky
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("aabbd1")
	settings.ambient_light_energy=0.55
	env.environment=settings
	add_child(env)
	var sun = DirectionalLight3D.new()
	sunlight=sun
	sun.rotation_degrees=Vector3(-55,-25,0)
	sun.light_color=Color("ffe2ad")
	sun.light_energy=1.1
	sun.shadow_enabled=true
	add_child(sun)
	default_lighting=lighting_state()
	camera=Camera3D.new()
	add_child(camera)
	camera.current=true
	canvas=CanvasLayer.new()
	add_child(canvas)
	preferences.load_file(settings_path)
	setup_audio();apply_audio_preferences()
	show_title()

func setup_audio():
	music=AudioStreamPlayer.new()
	music.volume_db=-12
	music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	score=AudioStreamSynchronized.new()
	score.stream_count=2
	for i in range(2):
		var stream = load("res://assets/"+("calm" if i==0 else "ablaze")+".wav") as AudioStreamWAV
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=stream.data.size()/(4 if stream.stereo else 2)
		score.set_sync_stream(i,stream)
	score.set_sync_stream_volume(1,-60)
	music.stream=score
	add_child(music)
	for effect in ["select","swing","hit","critical","heal","magic","phase"]:
		sfx_streams[effect]=load("res://assets/audio/"+effect+".wav")
	for i in range(6):
		var player=AudioStreamPlayer.new();player.volume_db=-12;sfx_players.append(player);add_child(player)

func play_sfx(effect: String):
	for player in sfx_players:
		if not player.playing:
			player.stream=sfx_streams.get(effect);player.play();return

func music_mix(battle: bool):
	if music_transition and music_transition.is_valid():music_transition.kill()
	music_transition=create_tween().set_parallel(true)
	music_transition.tween_method(func(v):score.set_sync_stream_volume(0,linear_to_db(maxf(v,0.001))),db_to_linear(score.get_sync_stream_volume(0)),0.001 if battle else 1.0,0.45)
	music_transition.tween_method(func(v):score.set_sync_stream_volume(1,linear_to_db(maxf(v,0.001))),db_to_linear(score.get_sync_stream_volume(1)),1.0 if battle else 0.001,0.45)

func _process(dt):
	clock+=dt
	if screen=="dialogue" and is_instance_valid(dialogue_label):
		dialogue_reveal+=dt*float(preferences.values.text_speed)
		dialogue_label.visible_characters=-1 if preferences.values.text_speed==0 else int(dialogue_reveal)

func box(color: Color) -> StyleBoxFlat:
	var b=StyleBoxFlat.new()
	b.bg_color=color
	b.content_margin_left=18;b.content_margin_right=18;b.content_margin_top=12;b.content_margin_bottom=12
	b.corner_radius_top_left=2;b.corner_radius_top_right=2;b.corner_radius_bottom_left=2;b.corner_radius_bottom_right=2
	b.border_width_left=2;b.border_width_right=2;b.border_width_top=2;b.border_width_bottom=2;b.border_color=Color("ad9971")
	b.shadow_color=Color(0.15,0.12,0.08,0.22);b.shadow_size=4
	return b

func reset_ui():
	dialogue_label=null
	dialogue_stage=null
	terrain_card=null
	forecast_panel=null
	battle_menu=null
	if is_instance_valid(ui):
		canvas.remove_child(ui)
		ui.queue_free()
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme=Theme.new()
	theme.default_font_size=17
	theme.set_color("font_color","Label",Color("443e36"))
	theme.set_color("font_color","Button",Color("443e36"))
	theme.set_color("font_hover_color","Button",Color("312a21"))
	theme.set_color("font_pressed_color","Button",Color("312a21"))
	theme.set_stylebox("normal","Button",box(Color("e9dfc5")))
	theme.set_stylebox("hover","Button",box(Color("f8edce")))
	theme.set_stylebox("pressed","Button",box(Color("c9b58b")))
	theme.set_stylebox("disabled","Button",box(Color("d4cdbb")))
	theme.set_color("font_disabled_color","Button",Color("9b9587"))
	theme.set_stylebox("panel","PanelContainer",box(Color("f1ead6")))
	ui.theme=theme

func label_in(parent,text_value,size=18,color=Color("443e36")) -> Label:
	var l=Label.new();l.text=text_value;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	if size>=30:l.add_theme_font_override("font",DISPLAY_FONT)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func button_in(parent,text_value,action,disabled=false) -> Button:
	var b=Button.new();b.text=text_value;b.custom_minimum_size.y=42;b.disabled=disabled
	b.pressed.connect(action);parent.add_child(b);return b

func weapon_label(parent,kind: String,text_value: String,font_size=18) -> Label:
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",7);parent.add_child(row)
	var icon=TextureRect.new();icon.texture=WeaponIcons.get_icon(kind);icon.custom_minimum_size=Vector2(28,28)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
	var label=label_in(row,text_value,font_size,GOLD);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.tooltip_text=text_value
	return label

func show_notice(message: String,hold=2.2):
	var panel=PanelContainer.new();panel.name="Notice";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(panel)
	panel.anchor_left=.5;panel.anchor_right=.5;panel.offset_left=-300;panel.offset_right=300;panel.offset_top=110
	var text_label=label_in(panel,message,18);text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var fade=panel.create_tween();fade.tween_interval(hold);fade.tween_property(panel,"modulate:a",0.0,.3);fade.tween_callback(panel.queue_free)

func save_with_feedback(stage_name: String):
	if stage_name=="battle":cancel_selection()
	show_notice("Campaign saved on this device." if persist_campaign(stage_name,false) else "The save could not be written. Your current game is still open.")

func panel_at(parent,left,top,right,bottom) -> VBoxContainer:
	var panel=PanelContainer.new();parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=left;panel.offset_top=top;panel.offset_right=right;panel.offset_bottom=bottom
	var v=VBoxContainer.new();v.add_theme_constant_override("separation",10);panel.add_child(v);return v

func clear_world():
	for n in [world,markers,pieces,stage]:
		if is_instance_valid(n):remove_child(n);n.queue_free()
	world=Node3D.new();add_child(world)
	markers=Node3D.new();add_child(markers)
	pieces=Node3D.new();add_child(pieces)
	stage=Node3D.new();add_child(stage)
	sprites.clear();unit_nodes.clear();map_facings.clear()

func mat(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.95
	if color.a<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func cube(parent,position,scale_value,color) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=BoxMesh.new();n.position=position;n.scale=scale_value;n.material_override=mat(color);parent.add_child(n);return n

func sphere(parent,position,radius,color) -> MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=8;mesh.rings=4;n.mesh=mesh;n.position=position;n.material_override=mat(color);parent.add_child(n);return n

func map_camera():
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=maxf(16,game.board_size().x+2)
	var center=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
	camera.position=center+Vector3(2.5,22,11.5)
	camera.look_at(center)
	camera.h_offset=2.0
	map_navigation.configure(camera,game.board_size())

func make_map():
	cursor_visible=false
	clear_world()
	map_camera()
	battle_lighting(game.info().get("environment","village"),false)
	scenery.landscape(world,game)
	refresh_pieces()

func refresh_pieces():
	for n in pieces.get_children():n.queue_free()
	sprites.clear();unit_nodes.clear()
	for u in game.units:
		if u.hp<=0:continue
		var visual=MapUnit.new();visual.name=str(u.id).validate_node_name();visual.position=map_position(game.pos(u))
		pieces.add_child(visual);visual.configure(map_catalog,u,map_facings.get(u.id,"south"))
		visual.selected=selected!=null and selected.id==u.id
		unit_nodes[u.id]=visual;sprites.append(visual.sprite)

func unit_portrait(u) -> Texture2D:
	var individual=portraits.get_map_sprite(u.id)
	if individual!=null:return individual
	var texture=AtlasTexture.new();texture.atlas=load("res://assets/art/class-sprites.png")
	var index=maxi(0,CLASSES.find(u.job))
	texture.region=Rect2((index%4)*384+12,(index/4)*512+10,360,492)
	return texture

func show_title():
	screen="title";game.start_battle();make_map();reset_ui()
	var v=panel_at(ui,65,100,-760,-100)
	label_in(v,"A TACTICAL CHRONICLE",16,GOLD)
	label_in(v,"POEM",64)
	label_in(v,"A broken banner. A borrowed sun.\nTwenty-four lives caught between them.",22)
	label_in(v,"12 chapters · 24 recruits · 8 classes\nSprite battlefields / cinematic 3D combat",17,Color("766e5e"))
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(spacer)
	button_in(v,"Begin the chronicle",func():game.new_campaign();music.play();show_camp())
	button_in(v,"Continue saved campaign",load_campaign,not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".bak"))
	button_in(v,"Transfer a local save",func():show_save_transfer("title"))
	var extras=HBoxContainer.new();extras.add_theme_constant_override("separation",8);v.add_child(extras)
	button_in(extras,"Options",func():show_options("title")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(extras,"Credits",show_credits).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(v,"Visual workshop · 2D / 3D maps",show_visual_workshop)
	label_in(v,"Original playable prototype • Casual recovery\nFallen allies return next chapter. Losing everyone means retry.",14,Color("827b6c"))

func show_credits():
	screen="credits";reset_ui()
	var panel=panel_at(ui,220,100,-220,-100)
	label_in(panel,"POEM",42,GOLD)
	label_in(panel,"An original tactical chronicle",22)
	label_in(panel,"A STANDARD AT DAWN",20,GOLD)
	label_in(panel,"Original composition and paired calm / Ablaze arrangements.",20)
	label_in(panel,"Instrument recordings: VSCO 2 Community Edition\nVersilian Studios · Sam Gossner and Simon Dalzell\nSample cutting: Elan Hickler / Soundemote\nReleased under CC0 1.0 Universal.",19)
	label_in(panel,"ART & TYPE",20,GOLD)
	label_in(panel,"Original generated illustrations and sprite artwork.\nOriginal 3D environments and character figures.\nCormorant Garamond · Cormorant Project Authors\nSIL Open Font License.",19)
	label_in(panel,"Created with Godot Engine.",19)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(spacer)
	button_in(panel,"Return to title",show_title)

func show_visual_workshop():
	screen="visual_workshop"
	ui.hide();world.hide();pieces.hide();markers.hide();stage.hide()
	var workshop=load("res://visual_lab.tscn").instantiate()
	canvas.add_child(workshop)
	workshop.closed.connect(func():
		canvas.remove_child(workshop);workshop.queue_free();camera.current=true;show_title())

func show_camp():
	screen="camp";busy=false;selected=null;target=null;origin=null
	game.phase="player"
	var story_key="opening_"+str(game.chapter)
	if story_key not in game.story_seen:
		game.story_seen.append(story_key)
		show_dialogue(story.chapters[game.chapter].opening,show_camp)
		return
	reset_ui()
	var bg=ColorRect.new();bg.color=INK;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(bg);ui.move_child(bg,0)
	var shell=MarginContainer.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:shell.add_theme_constant_override(k,28)
	ui.add_child(shell)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",24);shell.add_child(row)
	var left=VBoxContainer.new();left.custom_minimum_size.x=350;left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(left)
	label_in(left,"POEM / WAR COUNCIL",16,GOLD)
	label_in(left,"%02d  %s"%[game.chapter+1,game.info().title],34)
	label_in(left,game.info().place.to_upper(),17,Color("79755f"))
	label_in(left,game.info().intro,21)
	label_in(left,game.info().get("tactical_brief",""),18,Color("6f6c5e"))
	label_in(left,"OBJECTIVE  /  "+objective_text(),18,GOLD)
	label_in(left,"Recruited %d / 24  ·  Deployed %d / 6"%[game.available().size(),game.deployed.size()],18)
	label_in(left,"Select up to six allies. Healing tiles restore 6 HP each turn. Open a portrait to inspect equipment. Wardens heal within staff range; everyone carries two field tonics.",16,Color("766e5e"))
	var sp=Control.new();sp.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(sp)
	button_in(left,"Deploy company  >",deploy_company,game.deployed.is_empty())
	var tools_row=HBoxContainer.new();tools_row.add_theme_constant_override("separation",8);left.add_child(tools_row)
	button_in(tools_row,"Save campaign",func():save_with_feedback("camp")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(tools_row,"Options",func():show_options("camp")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(left,"Transfer a local save",func():show_save_transfer("camp"))
	button_in(left,"Return to title",show_title)
	label_in(left,"Music: A Standard at Dawn · paired arrangements\nVisuals: original painted art and 3D models",13,Color("827b6c"))
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=650;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(scroll)
	var cards=VBoxContainer.new();cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(cards)
	for u in game.roster:
		var unlocked=int(u.join)<=game.chapter
		var panel=PanelContainer.new();cards.add_child(panel)
		var content=HBoxContainer.new();panel.add_child(content)
		var pic=TextureButton.new();pic.texture_normal=portraits.get_portrait(u.id) if unlocked else unit_portrait(u)
		pic.custom_minimum_size=Vector2(90,90);pic.ignore_texture_size=true;pic.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		pic.disabled=not unlocked;pic.tooltip_text="View "+u.name+"'s dossier" if unlocked else "Not yet recruited"
		pic.pressed.connect(func():show_dossier(u));content.add_child(pic)
		var texts=VBoxContainer.new();texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_child(texts)
		label_in(texts,u.name+"  /  "+game.class_name_for(u)+"  ·  Lv "+str(int(u.level)),19,GOLD if unlocked else Color("9a9588"))
		if unlocked and supports_ready(u):label_in(texts,"Support conversation ready · open portrait",14,GOLD)
		label_in(texts,u.bio if unlocked else "Joins in chapter "+str(int(u.join)+1),14)
		label_in(texts,"HP %d   ATK %d   DEF %d   SPD %d   MOV %d"%[u.max_hp,game.attack_power(u),u.defense,game.attack_speed(u),u.move],13,Color("81775f"))
		button_in(content,"Deployed" if u.id in game.deployed else "Deploy",func():
			if u.id in game.deployed:game.deployed.erase(u.id)
			elif game.deployed.size()<6:game.deployed.append(u.id)
			show_camp(),not unlocked or (game.deployed.size()>=6 and u.id not in game.deployed))

func objective_text() -> String:
	match game.info().objective:
		"rout":return "Defeat every enemy"
		"seize":return "Occupy the golden standard at the eastern gate"
		"survive":return "Survive six enemy phases"
		_:return "Defeat "+game.info().boss

func deploy_company():
	game.start_battle();make_map();show_battle();busy=true;update_side();persist_campaign("battle")
	await announce_phase("player")
	busy=false;update_side()

func announce_phase(side: String):
	phase_skip=false;phase_banner_active=true;play_sfx("phase")
	var banner=PhaseBanner.new();banner.configure(ui,side,game.turn)
	await banner.play(func():return phase_skip)
	ui.remove_child(banner);banner.queue_free();phase_banner_active=false

func show_battle():
	screen="battle";reset_ui()
	var top=PanelContainer.new();top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_left=22;top.offset_right=-22;top.offset_top=18;top.offset_bottom=100;ui.add_child(top)
	var row=HBoxContainer.new();top.add_child(row)
	var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(titles)
	label_in(titles,"%02d  /  %s"%[game.chapter+1,game.info().title.to_upper()],24,GOLD)
	label_in(titles,objective_text(),16)
	status=label_in(row,"TURN %d  /  %s"%[game.turn,game.phase.to_upper()],20)
	status.custom_minimum_size.x=300
	status.autowrap_mode=TextServer.AUTOWRAP_OFF
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);panel.offset_left=-325;panel.offset_right=-22;panel.offset_top=118;panel.offset_bottom=-24;ui.add_child(panel)
	side=VBoxContainer.new();side.add_theme_constant_override("separation",5);panel.add_child(side)
	var bottom=PanelContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=22;bottom.offset_right=-343;bottom.offset_top=-84;bottom.offset_bottom=-22;ui.add_child(bottom)
	label_in(bottom,"Arrows / Enter: select · Q/E: allies · W: wait · R: danger · Space: end phase\nWheel / + −: zoom · Middle drag: pan · Home: reset · M: menu · Esc: undo · Tab: skip",14)
	terrain_card=TerrainCard.new();terrain_card.configure(ui)
	var inspected=game.pos(selected) if selected!=null else game.pos(game.living("player")[0]) if not game.living("player").is_empty() else Vector2i.ZERO
	terrain_card.inspect(game,cursor_tile if cursor_visible else inspected)
	ui.resized.connect(arrange_battle_side)
	update_side();highlight()

func update_side():
	if is_instance_valid(forecast_panel):ui.remove_child(forecast_panel);forecast_panel.queue_free()
	forecast_panel=null
	for n in side.get_children():side.remove_child(n);n.queue_free()
	status.text="TURN %d  /  %s"%[game.turn,game.phase.to_upper()]+("\nSAVE FAILED" if save_failed else "")
	if selected!=null:
		var identity=HBoxContainer.new();identity.add_theme_constant_override("separation",8);side.add_child(identity)
		var portrait=TextureRect.new();portrait.name="UnitPortrait";portrait.texture=portraits.get_unit_portrait(selected);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.flip_h=selected.team=="enemy"
		if portrait.texture==null:portrait.texture=unit_portrait(selected)
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.custom_minimum_size=Vector2(90,100);identity.add_child(portrait)
		var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;identity.add_child(details)
		label_in(details,selected.name,27,GOLD)
		label_in(details,game.class_name_for(selected),16)
		var bond_rank=game.supports.nearby_rank(game,selected)
		label_in(details,("Lv %d / MAX"%selected.level if selected.level>=game.MAX_LEVEL else "Lv %d / XP %d"%[selected.level,selected.xp])+(" · Bond "+game.supports.RANKS[bond_rank] if bond_rank>0 else ""),15)
		label_in(side,"HP %d/%d · ATK %d\nDEF %d · RES %d · SPD %d"%[selected.hp,selected.max_hp,game.attack_power(selected),selected.defense,game.resistance_for(selected),game.attack_speed(selected)],17)
		weapon_label(side,selected.weapon,game.item_for(selected).name+" · "+game.range_text(selected)+" tiles",15)
		if selected.team=="enemy":
			var behavior={"guard":"Holds position","sentry":"Waits until approached","pursue":"Advances toward the company"}
			label_in(side,behavior.get(selected.get("ai","pursue"),"Advances"),17,GOLD)
			label_in(side,"Red tiles show this unit’s possible attacks, including movement. Other units may block its route.",16)
			button_in(side,"All enemy ranges [R]: "+("on" if show_danger else "off"),toggle_danger,busy)
		if target!=null:
			var f=game.forecast(selected,target)
			var versus=label_in(side,("Effective vs " if f.effective else "VS  ")+target.name,19,GOLD)
			versus.autowrap_mode=TextServer.AUTOWRAP_OFF;versus.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;versus.tooltip_text=versus.text
			var counter=game.forecast(target,selected)
			var faces=[]
			for unit in [selected,target]:
				var face=portraits.get_unit_portrait(unit);faces.append(face if face!=null else unit_portrait(unit))
			forecast_panel=BattleForecast.new();forecast_panel.configure(ui,game,selected,target,faces)
			label_in(side,("Foe has an effective counter!" if counter.effective else "Counter if both survive.") if f.counter else "Foe cannot counter at this range.",14,GOLD)
			button_in(side,"Confirm attack",func():player_attack(),busy)
		if selected.team=="player" and not selected.acted:
			button_in(side,"Wait / secure position",wait_action,busy)
			button_in(side,"Field tonic (+12 HP)  ·  "+str(int(selected.potions)),tonic,busy or selected.potions<=0 or selected.hp>=selected.max_hp)
			if selected.weapon=="staff":label_in(side,"Heal %d HP · range %s. Click an injured ally."%[game.healing_power(selected),game.range_text(selected)],16,GOLD)
	else:
		label_in(side,"THE COMPANY",15,GOLD)
		label_in(side,"%d allies  ·  %d enemies"%[game.living("player").size(),game.living("enemy").size()],18)
		label_in(side,"Choose your next move.",25)
		label_in(side,"Forest and hills cost 2 movement and grant cover. Cross water at bridges. Golden tiles mark objectives; pale crosses restore health.",17,Color("6f6c5e"))
		button_in(side,"Enemy ranges [R]: "+("on" if show_danger else "off"),toggle_danger,busy)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;side.add_child(spacer)
	button_in(side,"End player phase",end_turn,busy)
	button_in(side,"Menu [M]",show_battle_menu,busy)
	arrange_battle_side()

func arrange_battle_side():
	if not is_instance_valid(side) or not is_instance_valid(ui) or screen not in ["battle","battle_menu"]:return
	var compact=ui.size.y<760
	var theme=Theme.new();theme.default_font_size=17
	for state in ["normal","hover","pressed","disabled"]:
		var style=ui.theme.get_stylebox(state,"Button").duplicate()
		style.content_margin_top=6 if compact else 12;style.content_margin_bottom=style.content_margin_top
		theme.set_stylebox(state,"Button",style)
	side.theme=theme
	for button in side.find_children("*","Button",true,false):button.custom_minimum_size.y=34 if compact else 42
	for portrait in side.find_children("UnitPortrait","TextureRect",true,false):portrait.custom_minimum_size=Vector2(76,84) if compact else Vector2(90,100)

func show_battle_menu():
	if screen!="battle" or busy or game.phase!="player":return
	map_navigation.stop();play_sfx("select");screen="battle_menu"
	battle_menu=Control.new();battle_menu.name="BattleMenu";ui.add_child(battle_menu)
	battle_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battle_menu.mouse_filter=Control.MOUSE_FILTER_STOP;battle_menu.z_index=20
	var shade=ColorRect.new();shade.color=Color(0.04,.06,.08,.55);battle_menu.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame=PanelContainer.new();frame.name="MenuFrame";battle_menu.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER);frame.offset_left=-220;frame.offset_right=220;frame.offset_top=-215;frame.offset_bottom=215
	var commands=VBoxContainer.new();commands.add_theme_constant_override("separation",8);frame.add_child(commands)
	label_in(commands,"Battle menu",40,GOLD)
	label_in(commands,"Turn %d · %s"%[game.turn,game.info().title],17)
	button_in(commands,"Return to battle",close_battle_menu).grab_focus()
	button_in(commands,"Save",func():close_battle_menu();save_with_feedback("battle"))
	button_in(commands,"Transfer code",func():close_battle_menu();show_save_transfer("battle"))
	button_in(commands,"Options / audio",func():close_battle_menu();show_options("battle"))
	button_in(commands,"War council (restart map)",func():close_battle_menu();show_camp())
	var buttons=commands.find_children("*","Button",true,false)
	for i in range(buttons.size()):
		var button=buttons[i]
		button.focus_next=button.get_path_to(buttons[(i+1)%buttons.size()]);button.focus_neighbor_bottom=button.focus_next
		button.focus_previous=button.get_path_to(buttons[(i-1+buttons.size())%buttons.size()]);button.focus_neighbor_top=button.focus_previous
		button.focus_neighbor_left=NodePath(".");button.focus_neighbor_right=NodePath(".")

func close_battle_menu():
	if not is_instance_valid(battle_menu):return
	get_viewport().gui_release_focus();ui.remove_child(battle_menu);battle_menu.queue_free();battle_menu=null;screen="battle"

func highlight():
	for id in unit_nodes:unit_nodes[id].selected=selected!=null and selected.id==id
	route_preview=null;last_hover=Vector2i(-1,-1)
	for n in markers.get_children():n.queue_free()
	var danger={}
	if show_danger:
		for enemy in game.living("enemy"):danger.merge(tactics.threatened_tiles(game,enemy))
	if selected!=null and selected.team=="enemy":danger.merge(tactics.threatened_tiles(game,selected))
	MapOverlay.tiles(markers,danger.keys(),Color(.69,.21,.31,.24),.025,"DangerRange",map_height)
	if cursor_visible:draw_map_cursor()
	if selected==null or selected.team!="player" or selected.acted:return
	var range_map=game.reachable(selected) if origin==null else {game.pos(selected):0}
	MapOverlay.tiles(markers,range_map.keys(),Color(.18,.49,.85,.30),.032,"MovementRange",map_height)
	var attackable=[]
	for e in game.living("enemy"):
		if game.can_attack(selected,e):attackable.append(game.pos(e))
	MapOverlay.tiles(markers,attackable,Color(.87,.29,.16,.38),.039,"AttackRange",map_height)

func toggle_danger():
	if busy or screen!="battle":return
	show_danger=not show_danger;highlight();update_side()

func _input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed:map_navigation.dragging=false
	if screen=="battle_menu" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_M]:
		close_battle_menu();get_viewport().set_input_as_handled();return
	if screen=="battle" and not busy and game.phase=="player" and event is InputEventKey and event.pressed:
		if event.keycode==KEY_M and not event.echo:show_battle_menu();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_HOME:map_camera();get_viewport().set_input_as_handled();return
		if event.keycode in [KEY_EQUAL,KEY_PLUS,KEY_MINUS]:
			var anchor=camera.unproject_position(map_position(cursor_tile)) if cursor_visible else Vector2((ui.size.x-325)*.5,ui.size.y*.5)
			map_navigation.zoom(-1 if event.keycode==KEY_MINUS else 1,anchor);get_viewport().set_input_as_handled();return
		var steps={KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
		if steps.has(event.keycode):
			move_map_cursor(steps[event.keycode]);get_viewport().set_input_as_handled();return
		if event.keycode in [KEY_Q,KEY_E] and not event.echo:
			cycle_ready_ally(-1 if event.keycode==KEY_Q else 1);get_viewport().set_input_as_handled();return
	if is_instance_valid(reward_panel) and event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_TAB]:
		reward_skip=true;get_viewport().set_input_as_handled();return
	if screen=="battle" and busy and event is InputEventKey and event.pressed and event.keycode==KEY_TAB:
		if phase_banner_active:phase_skip=true
		else:skip_combat=true
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if screen=="credits" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		show_title();get_viewport().set_input_as_handled();return
	if screen=="model" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close_model_view();get_viewport().set_input_as_handled();return
	if screen=="dossier" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		show_camp();get_viewport().set_input_as_handled();return
	if screen=="dialogue" and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE,KEY_ENTER]:advance_dialogue();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:finish_dialogue();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_TAB:skip_combat=true
		if screen=="battle" and not busy:
			if event.keycode==KEY_ESCAPE:cancel_selection()
			if event.keycode==KEY_SPACE:end_turn()
			if event.keycode==KEY_R:toggle_danger()
			if event.keycode==KEY_W and not event.echo:wait_action()
			if event.keycode==KEY_ENTER and not event.echo:activate_map_cursor();get_viewport().set_input_as_handled()
	if screen!="battle" or busy or game.phase!="player":return
	if event is InputEventMouseMotion:
		if map_navigation.dragging:map_navigation.drag(event.position);return
		var ray_start=camera.project_ray_origin(event.position);var ray_direction=camera.project_ray_normal(event.position)
		var ground=Plane(Vector3.UP,0).intersects_ray(ray_start,ray_direction)
		if ground!=null:preview_route(Vector2i(roundi(ground.x),roundi(ground.z)))
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			map_navigation.zoom(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1,event.position);return
		if event.button_index==MOUSE_BUTTON_MIDDLE:map_navigation.begin_drag(event.position);return
		if event.button_index==MOUSE_BUTTON_RIGHT:cancel_selection();return
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		cursor_visible=false;highlight()
		var picked=pick_map_unit(event.position)
		if picked!=null:click_tile(game.pos(picked));return
		var start=camera.project_ray_origin(event.position)
		var dir=camera.project_ray_normal(event.position)
		var hit=Plane(Vector3.UP,0).intersects_ray(start,dir)
		if hit!=null:click_tile(Vector2i(roundi(hit.x),roundi(hit.z)))

func pick_map_unit(point: Vector2):
	var picked=null;var front=-INF
	for unit in game.units:
		if unit.hp<=0 or not unit_nodes.has(unit.id):continue
		var actor=unit_nodes[unit.id]
		if not actor.screen_bounds(camera).has_point(point):continue
		var depth=camera.unproject_position(actor.global_position).y
		if depth>front:picked=unit;front=depth
	return picked

func cancel_selection():
	if selected!=null and origin!=null and not selected.acted:
		game.undo_move(selected)
	selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()

func click_tile(p: Vector2i):
	if busy:return
	if is_instance_valid(terrain_card):terrain_card.inspect(game,p)
	var u=game.at(p)
	if selected!=null and selected.team=="player" and not selected.acted and u!=null:
		if game.can_attack(selected,u):target=u;update_side();return
		if game.can_heal(selected,u):
			var before=game.progress_snapshot()
			var old_hp=u.hp
			if game.heal(selected,u):
				play_sfx("heal");busy=true;update_side();await map_heal_feedback(selected,u,u.hp-old_hp);await show_progress(before);busy=false;finish_action();return
	if u!=null and u.team=="player":
		cancel_selection();selected=u;play_sfx("select");highlight();update_side();return
	if u!=null and u.team=="enemy" and (selected==null or selected.team=="enemy"):
		selected=u;target=null;play_sfx("select");highlight();update_side();return
	if selected!=null and selected.team=="player" and not selected.acted and origin==null and u==null and game.reachable(selected).has(p):
		origin=game.pos(selected)
		var path=game.movement_path(selected,p)
		if game.move_unit(selected,p):
			target=null;busy=true;highlight();update_side()
			await animate_map_move(selected,path)
			busy=false;refresh_pieces();highlight();update_side()
		else:origin=null

func wait_action():
	if busy or selected==null:return
	if game.wait_unit(selected):finish_action()

func tonic():
	if busy or selected==null:return
	var unit=selected;var old_hp=unit.hp
	if game.use_tonic(unit):
		busy=true;play_sfx("heal");update_side();await map_heal_feedback(unit,unit,unit.hp-old_hp);busy=false;finish_action()

func player_attack():
	if busy or selected==null or target==null:return
	busy=true
	update_side()
	var a=selected;var b=target
	var initial_hp={a.id:a.hp,b.id:b.hp}
	var before=game.progress_snapshot()
	var events=game.combat(a,b)
	await cinematic(a,b,events,initial_hp)
	await show_progress(before)
	busy=false;finish_action()

func finish_action():
	selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()
	if await check_result():return
	persist_campaign("battle")
	if preferences.values.auto_end and game.living("player").all(func(u):return u.acted):end_turn()

func end_turn():
	if busy or screen!="battle":return
	cancel_selection();busy=true;game.begin_enemy_phase();update_side();await announce_phase("enemy")
	for e in game.living("enemy"):
		if game.living("player").is_empty():break
		var choice=tactics.plan(game,e)
		var candidates=game.units.filter(func(u):return u.id==choice.target)
		var chosen=candidates[0] if not candidates.is_empty() else null
		var initial_hp={e.id:e.hp}
		if chosen!=null:initial_hp[chosen.id]=chosen.hp
		var before=game.progress_snapshot()
		var path=game.movement_path(e,choice.position)
		await animate_map_move(e,path)
		var events=tactics.apply_plan(game,e,choice)
		refresh_pieces();highlight();await get_tree().create_timer(.12).timeout
		if chosen!=null and not events.is_empty():
			await cinematic(e,chosen,events,initial_hp)
			await show_progress(before)
		refresh_pieces()
		if game.result()!="":break
	game.next_player_turn();update_side();refresh_pieces();highlight()
	if await check_result():busy=false;return
	await announce_phase("player");busy=false;update_side()
	persist_campaign("battle")

func make_fighter(u,position) -> Node3D:
	return fighters.build(stage,u,position)

func cinematic(a,b,events,initial_hp={}):
	if events.is_empty():return
	map_navigation.stop()
	if not preferences.show_cinematic(a.team):
		await map_combat_feedback(events)
		return
	skip_combat=false;music_mix(true)
	var old_pos=camera.position;var old_rot=camera.rotation;var old_size=camera.size;var old_offset=camera.h_offset;var old_vertical_offset=camera.v_offset;var old_fov=camera.fov
	var focus=Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5)
	markers.hide()
	var tactical_controls={}
	for control in ui.get_children():tactical_controls[control]=control.visible;control.hide()
	var veil=CombatTransition.new();veil.configure(ui,func():return camera.unproject_position(focus))
	veil.conceal()
	var push=map_navigation.approach_combat(focus)
	await push.finished
	if veil.motion.is_running():await veil.motion.finished
	for n in stage.get_children():n.queue_free()
	stage.visible=true
	var old_lighting=battle_lighting(game.info().get("environment","village"))
	scenery.battle_landscape(stage,Vector3(35,0,0),scenery.combat_context(game,a,b))
	world.hide();pieces.hide()
	var ranged=game.distance(a,b)>1 or a.weapon in ["bow","magic"] or b.weapon in ["bow","magic"]
	var spacing=2.0 if ranged else 1.6
	var actor=make_fighter(a,Vector3(35-spacing,0,0));var defender=make_fighter(b,Vector3(35+spacing,0,0))
	actor.rotation.y=-PI/2;defender.rotation.y=PI/2
	var director=CombatCamera.new();stage.add_child(director);director.configure(camera)
	var mounted=a.job=="Rider" or b.job=="Rider"
	director.establish(actor.position,defender.position,ranged,mounted)
	await veil.reveal().finished
	veil.hide()
	var displayed_hp={};var entries=[]
	for unit in [a,b]:
		var hp=int(initial_hp.get(unit.id,unit.hp))
		if initial_hp.is_empty():
			for strike_event in events:
				if strike_event.target==unit.id:hp+=strike_event.damage
		displayed_hp[unit.id]=mini(hp,unit.max_hp)
		entries.append({"unit":unit,"hp":displayed_hp[unit.id],"portrait":portraits.get_unit_portrait(unit),"class_name":game.class_name_for(unit),"weapon":game.item_for(unit).name})
	var banner=CombatHUD.new();banner.configure(ui,entries)
	var caption=Label.new();caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);caption.offset_top=36;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",30);caption.add_theme_color_override("font_color",Color("f7edce"));caption.add_theme_color_override("font_outline_color",Color("373d42"));caption.add_theme_constant_override("outline_size",7)
	caption.text="Tab to skip";ui.add_child(caption)

	await get_tree().create_timer(.3).timeout
	for event in events:
		if skip_combat:break
		var who=actor if event.actor==a.id else defender
		var whom=defender if who==actor else actor
		var unit=a if who==actor else b
		var spell=game.item_for(unit).id if unit.weapon=="magic" else ""
		banner.mark_actor(unit.id)
		var base=who.position
		var direction=1.0 if who==actor else -1.0
		var is_ranged=unit.weapon in ["bow","magic"] or (unit.weapon=="lance" and game.distance(a,b)>1)
		caption.text=unit.name+"  /  "+("Critical strike" if event.crit else unit.weapon.capitalize())
		if not is_ranged:
			var distance_to_close=absf(whom.position.x-who.position.x)-Fighters.Actor.melee_spacing(unit.weapon)
			if absf(distance_to_close)>.08:
				who.pose("advance" if distance_to_close>0 else "idle",.2)
				var approach=create_tween().set_trans(Tween.TRANS_SINE)
				approach.tween_property(who,"position:x",base.x+direction*distance_to_close,.24)
				await approach.finished
		if who.has_method("aim_at"):who.aim_at(whom.socket_position("impact"))
		director.shot(who.position,whom.position,"windup",is_ranged,mounted,.28)
		await who.pose("throw_windup" if is_ranged and unit.weapon=="lance" else "windup",.28 if not event.crit else .4).finished
		if skip_combat:break
		if event.crit:
			await critical_cutin(unit)
			if skip_combat:break
		play_sfx("magic" if unit.weapon=="magic" else "swing")
		var contact_point=whom.socket_position("impact")
		if not event.hit:
			whom.pose("evade",.12)
			var dodge=create_tween()
			dodge.tween_property(whom,"position:z",-.32,.12)
			dodge.tween_interval(.35 if is_ranged else .12)
			dodge.tween_property(whom,"position:z",0.0,.16)
		await who.pose("throw" if is_ranged and unit.weapon=="lance" else "strike",.12).finished
		if not is_ranged:
			var trail=CombatTrail.new();stage.add_child(trail)
			trail.start(contact_point+Vector3(-direction*.28,0,.18),unit.weapon,direction,event.crit)
		if is_ranged:
			var release=who.socket_position("projectile")
			if who.has_method("release_projectile"):who.release_projectile()
			await projectile(release,contact_point,unit.weapon,spell)
		director.shot(who.position,whom.position,"impact",is_ranged,mounted,.16)
		if event.hit:
			play_sfx("critical" if event.crit else "hit")
			whom.pose("hit",.12)
		displayed_hp[event.target]=maxi(0,displayed_hp[event.target]-event.damage)
		banner.set_health(event.target,int(displayed_hp[event.target]))
		show_impact(whom.socket_position("impact"),event,spell)
		caption.text=unit.name+(" — CRITICAL! " if event.crit else " — ")+(str(int(event.damage))+" damage" if event.hit else "Miss")
		if event.hit:director.impact(event.crit)
		await get_tree().create_timer(.22 if not event.crit else .34).timeout
		who.pose("idle",.16)
		if event.remaining<=0:
			await whom.pose("down",.3).finished
		else:
			await whom.pose("idle",.16).finished
	director.shot(actor.position,defender.position,"wide",ranged,mounted,.2)
	await get_tree().create_timer(.18).timeout

	banner.queue_free();caption.queue_free()
	veil.show();await veil.conceal(.12,false).finished
	director.stop();director.queue_free()
	stage.visible=false
	restore_lighting(old_lighting)
	world.show();pieces.show();markers.show()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position=old_pos;camera.rotation=old_rot;camera.h_offset=old_offset;camera.v_offset=old_vertical_offset;camera.fov=old_fov
	veil.reveal(.25)
	var pull=create_tween();pull.tween_property(camera,"size",old_size,.25);await pull.finished
	if veil.motion.is_running():await veil.motion.finished
	veil.queue_free()
	for control in tactical_controls:
		if is_instance_valid(control):control.visible=tactical_controls[control]
	music_mix(false)

func lighting_state() -> Dictionary:
	var sky=environment.sky.sky_material
	var fog={}
	for field in FOG_FIELDS:fog[field]=environment.get(field)
	return {"energy":sunlight.light_energy,"color":sunlight.light_color,"ambient":environment.ambient_light_energy,"top":sky.sky_top_color,"horizon":sky.sky_horizon_color,"ground":sky.ground_horizon_color,"fog":fog}

func battle_lighting(theme: String,arena=true) -> Dictionary:
	var old=lighting_state()
	if not default_lighting.is_empty():restore_lighting(default_lighting)
	var sky=environment.sky.sky_material
	if theme in ["forest","mountain"]:
		sunlight.light_energy=.7;environment.ambient_light_energy=.6
		sky.sky_top_color=Color("536c82");sky.sky_horizon_color=Color("b5b9ab");sky.ground_horizon_color=Color("b5b9ab")
	elif theme in ["observatory","engine","furnace"]:
		sunlight.light_energy=.45;environment.ambient_light_energy=.7
		sunlight.light_color=Color("bbbdde") if theme=="observatory" else Color("efb17f")
		sky.sky_top_color=Color("14243b") if theme=="observatory" else Color("3c343a")
		sky.sky_horizon_color=Color("596179") if theme=="observatory" else Color("98725e")
		sky.ground_horizon_color=sky.sky_horizon_color
	environment.fog_enabled=arena;environment.fog_mode=Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin=12.0;environment.fog_depth_end=65.0;environment.fog_depth_curve=1.3
	environment.fog_density=.55 if theme=="forest" else .48 if theme in ["river","harbor","mountain"] else .28 if theme in ["observatory","engine","furnace","castle","abbey"] else .38
	environment.fog_light_color=sky.sky_horizon_color.lerp(sky.sky_top_color,.3);environment.fog_light_energy=1.0;environment.fog_sky_affect=0.0
	return old

func restore_lighting(old: Dictionary):
	var sky=environment.sky.sky_material
	sunlight.light_energy=old.energy;sunlight.light_color=old.color;environment.ambient_light_energy=old.ambient
	sky.sky_top_color=old.top;sky.sky_horizon_color=old.horizon;sky.ground_horizon_color=old.ground
	for field in FOG_FIELDS:environment.set(field,old.fog[field])

func projectile(from: Vector3,to: Vector3,kind: String,spell=""):
	var visual=CombatProjectile.new();stage.add_child(visual)
	await visual.launch(from,to,kind,.23,spell).finished

func show_impact(point,event,spell=""):
	var impact=CombatImpact.new();stage.add_child(impact);impact.configure(point,event,camera,spell)

func check_result() -> bool:
	var outcome=game.result()
	if outcome=="":return false
	persist_campaign("battle")
	screen="result";reset_ui()
	var v=panel_at(ui,210,170,-210,-170)
	if outcome=="victory":
		label_in(v,"CHAPTER COMPLETE",18,GOLD);label_in(v,game.info().title,38)
		label_in(v,game.info().outro,24)
		label_in(v,"%d turns  ·  %d allies standing  ·  %d foes defeated"%[game.turn,game.living("player").size(),game.units.filter(func(u):return u.team=="enemy" and u.hp<=0).size()],18,GOLD)
		var summary=GridContainer.new();summary.columns=2;summary.add_theme_constant_override("h_separation",24);summary.add_theme_constant_override("v_separation",8);v.add_child(summary)
		for unit in game.units:
			if unit.team!="player":continue
			var row=HBoxContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;summary.add_child(row)
			var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(55,55);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
			label_in(row,"%s · Lv %d\n%s"%[unit.name,unit.level,"Ready for the next march" if unit.hp>0 else "Recovering at camp"],16)
		button_in(v,"Continue the chronicle",func():
			show_dialogue(story.chapters[game.chapter].closing,func():
				game.finish_chapter()
				persist_campaign("ending" if game.completed else "camp")
				if game.completed:show_ending()
				else:show_camp()))
	else:
		label_in(v,"THE STANDARD FALLS",38,GOLD)
		label_in(v,"Your company is scattered. Regroup at the war council and choose a new approach.",24)
		button_in(v,"Regroup and retry",show_camp)
	return true

func show_ending():
	screen="ending";reset_ui()
	var v=panel_at(ui,120,60,-120,-60)
	label_in(v,"DAWN WITHOUT KINGS",40,GOLD)
	label_in(v,game.content.chapters[-1].outro,22)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for u in game.roster:
		label_in(list,u.name+" · "+game.class_name_for(u)+" · Level "+str(int(u.level)),19,Color(u.color))
		label_in(list,profiles.get(u.id,{}).get("ending",u.bio),17)
	button_in(v,"Return to title",show_title)

func show_dialogue(lines: Array,on_complete: Callable):
	screen="dialogue";reset_ui()
	dialogue_lines=lines;dialogue_index=0;dialogue_callback=on_complete
	dialogue_stage=preload("res://scripts/dialogue_stage.gd").new();ui.add_child(dialogue_stage)
	dialogue_stage.configure(advance_dialogue,finish_dialogue)
	dialogue_name=dialogue_stage.heading;dialogue_label=dialogue_stage.speech
	refresh_dialogue()

func refresh_dialogue():
	if dialogue_index>=dialogue_lines.size():finish_dialogue();return
	var line=dialogue_lines[dialogue_index]
	var speaker=game.roster.filter(func(u):return u.id==line.speaker)
	var display_name=speaker[0].name if not speaker.is_empty() else line.speaker.capitalize()
	dialogue_portrait=dialogue_stage.show_speaker(line.speaker,display_name,portraits.get_dialogue_portrait(line.speaker))
	dialogue_label.text=line.text;dialogue_label.visible_characters=-1 if preferences.values.text_speed==0 else 0;dialogue_reveal=0.0

func advance_dialogue():
	if screen!="dialogue":return
	if dialogue_label.visible_characters>=0 and dialogue_label.visible_characters<dialogue_label.text.length():
		dialogue_reveal=dialogue_label.text.length();dialogue_label.visible_characters=dialogue_label.text.length();return
	dialogue_index+=1;refresh_dialogue()

func finish_dialogue():
	var callback=dialogue_callback;dialogue_callback=Callable()
	if callback.is_valid():callback.call()

func show_dossier(unit):
	screen="dossier";reset_ui()
	var panel=panel_at(ui,70,60,-70,-60)
	label_in(panel,"COMPANY RECORD",17,GOLD)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",36);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(row)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(400,400)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
	var info=VBoxContainer.new();info.add_theme_constant_override("separation",16);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(info)
	var profile=profiles.get(unit.id,{})
	label_in(info,unit.name,46,GOLD);label_in(info,profile.get("title",unit.job),26)
	label_in(info,"%s  /  Level %d  /  %s"%[game.class_name_for(unit),unit.level,"MAX" if unit.level>=game.MAX_LEVEL else "%d XP"%unit.xp],20)
	label_in(info,"HP %d    ATK %d    DEF %d    RES %d    SPD %d    MOV %d"%[unit.max_hp,game.attack_power(unit),unit.defense,game.resistance_for(unit),game.attack_speed(unit),unit.move],21)
	label_in(info,profile.get("biography",unit.bio),22)
	label_in(info,"PERSONAL NOTE",16,GOLD);label_in(info,profile.get("note",""),20)
	var records=HBoxContainer.new();records.add_theme_constant_override("separation",12);panel.add_child(records)
	button_in(records,"Equipment · "+game.item_for(unit).name,func():show_equipment(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(records,"Support conversations"+(" · Ready" if supports_ready(unit) else ""),func():show_supports(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);panel.add_child(actions)
	button_in(actions,"View combat model",func():show_model_view(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(actions,"Advanced training",func():show_promotions(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(panel,"Return to war council",show_camp)

func load_campaign():
	var saved=game.load_game(save_path)
	if saved=="":show_notice("No readable campaign save was found on this device.");return
	if not music.playing:music.play()
	if saved=="ending":show_ending()
	elif saved=="battle":make_map();show_battle();await check_result()
	else:show_camp()

func show_equipment(unit):
	screen="equipment";reset_ui()
	var panel=panel_at(ui,70,45,-70,-45)
	label_in(panel,"COMPANY ARSENAL",17,GOLD)
	label_in(panel,unit.name+"  /  "+game.class_name_for(unit),40,GOLD)
	label_in(panel,"Equipment is shared freely. New supplies become available as the campaign advances.",19)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",28);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(row)
	var summary=VBoxContainer.new();summary.custom_minimum_size.x=280;row.add_child(summary)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(280,310)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;summary.add_child(portrait)
	label_in(summary,"EQUIPPED",16,GOLD);weapon_label(summary,unit.weapon,game.item_for(unit).name,25)
	label_in(summary,"Attack %d   Speed %d\nRange %s"%[game.attack_power(unit),game.attack_speed(unit),game.range_text(unit)],21)
	label_in(summary,"Weight reduces speed. A 4-point speed lead grants a follow-up attack.",17)
	var scroll=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
	for item in game.equipment:
		if item.kind!=unit.weapon:continue
		var card=PanelContainer.new();list.add_child(card)
		var details=VBoxContainer.new();details.add_theme_constant_override("separation",5);card.add_child(details)
		weapon_label(details,item.kind,item.name,26);label_in(details,item.description,17)
		if item.has("effective_against"):label_in(details,"Triple weapon might against "+", ".join(item.effective_against)+" foes.",17,GOLD)
		var reach=str(int(item.min_range)) if item.min_range==item.max_range else "%d–%d"%[item.min_range,item.max_range]
		if item.kind=="staff":label_in(details,"Heal %d   Weight %d   Range %s"%[int(item.heal)+game.promotion_bonus(unit,"heal"),item.weight,reach],18)
		else:label_in(details,"Might %d   Hit %+d   Crit +%d   Weight %d   Range %s"%[item.might,item.hit,item.crit,item.weight,reach],18)
		var locked=int(item.unlock)>game.chapter;var equipped=unit.item==item.id
		button_in(details,"Available in chapter %d"%(int(item.unlock)+1) if locked else ("Equipped" if equipped else "Equip"),func():
			if game.equip(unit,item.id):show_equipment(unit);persist_campaign("camp")
		,locked or equipped)
	button_in(panel,"Return to company record",func():show_dossier(unit))
	button_in(panel,"Return to war council",show_camp)

func show_model_view(unit):
	screen="model";preview_unit=unit;reset_ui()
	for child in stage.get_children():stage.remove_child(child);child.queue_free()
	world.hide();pieces.hide();markers.hide();stage.show()
	scenery.battle_landscape(stage,Vector3(35,0,0),{"environment":game.info().get("environment","village")})
	var actor_data=unit.duplicate(true);actor_data.team="player"
	preview_actor=make_fighter(actor_data,Vector3(35,0,0));preview_actor.rotation.y=PI-.35
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=-.25;camera.fov=35
	camera.position=Vector3(35,1.4,4.7 if unit.job!="Rider" else 6.5);camera.look_at(Vector3(35,1.05,0))
	var panel=panel_at(ui,28,30,-1060,-30)
	label_in(panel,"COMPANY / COMBAT MODEL",15,GOLD);label_in(panel,unit.name,38)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(220,240)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;panel.add_child(portrait)
	label_in(panel,game.class_name_for(unit)+" · "+game.item_for(unit).name,21)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(spacer)
	button_in(panel,"Turn left",func():preview_actor.rotation.y-=PI/6)
	button_in(panel,"Turn right",func():preview_actor.rotation.y+=PI/6)
	button_in(panel,"Ready",func():preview_actor.pose("idle"))
	button_in(panel,"Windup",func():preview_actor.pose("windup"))
	button_in(panel,"Strike",func():preview_actor.pose("strike"))
	button_in(panel,"Return to record [Esc]",close_model_view)

func close_model_view():
	make_map();show_dossier(preview_unit)

func show_progress(before: Dictionary):
	for change in game.progress_since(before):
		var unit=change.unit;var leveled=int(unit.level)>change.before.level
		reward_skip=false
		reward_panel=PanelContainer.new();reward_panel.name="ProgressReward";ui.add_child(reward_panel)
		reward_panel.anchor_left=.5;reward_panel.anchor_right=.5;reward_panel.offset_left=-330;reward_panel.offset_right=330;reward_panel.offset_top=115
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);reward_panel.add_child(row)
		var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(110,130);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
		var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(details)
		label_in(details,("LEVEL UP  /  " if leveled else "EXPERIENCE  /  ")+unit.name,28,GOLD)
		label_in(details,"Level %d  ·  +%d XP"%[unit.level,change.xp_gain],20)
		var progress=ProgressBar.new();progress.max_value=100;progress.value=change.before.xp;progress.show_percentage=false;progress.custom_minimum_size.y=16;details.add_child(progress)
		var fill=StyleBoxFlat.new();fill.bg_color=Color("889d65");progress.add_theme_stylebox_override("fill",fill)
		var tween=reward_panel.create_tween()
		if leveled:
			tween.tween_property(progress,"value",100.0,.25);tween.tween_callback(func():progress.value=0)
		tween.tween_property(progress,"value",100.0 if unit.level>=game.MAX_LEVEL else float(unit.xp),.35)
		label_in(details,"Level limit reached" if unit.level>=game.MAX_LEVEL else "%d / 100 XP"%unit.xp,16)
		if leveled:
			label_in(details,"HP +%d   Power +%d   Defense +%d   Resistance +%d   Speed +%d"%[change.gains.max_hp,change.gains.pow,change.gains.defense,change.gains.resistance,change.gains.speed],17)
		label_in(details,"Space / Enter to continue",14)
		var elapsed=0.0
		while elapsed<(2.0 if leveled else .8) and not reward_skip:
			await get_tree().process_frame;elapsed+=get_process_delta_time()
		reward_panel.queue_free();reward_panel=null

func show_save_transfer(return_screen: String):
	if return_screen=="battle":
		if busy or game.phase!="player":return
		cancel_selection()
	screen="save_transfer";transfer_return=return_screen;reset_ui()
	var panel=panel_at(ui,100,60,-100,-60)
	label_in(panel,"LOCAL SAVE TRANSFER",36,GOLD)
	label_in(panel,"Move your campaign between browsers or the desktop app. Copy the code below, then paste it into this screen on the other build.",21)
	label_in(panel,"Import replaces this device’s current campaign and keeps its previous save as a backup. No code is sent to a server.",17)
	transfer_text=TextEdit.new();transfer_text.name="SaveCode";transfer_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	transfer_text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;transfer_text.add_theme_font_size_override("font_size",14);panel.add_child(transfer_text)
	transfer_text.text=game.export_code(return_screen) if return_screen in ["camp","battle"] else game.export_saved_code(save_path)
	transfer_text.placeholder_text="Paste a POEM1: save code here."
	button_in(panel,"Copy code",func():DisplayServer.clipboard_set(transfer_text.text);show_notice("Save code copied. Keep it in a local text file or paste it into another build."))
	if OS.has_feature("web"):button_in(panel,"Open browser copy / paste",open_browser_transfer)
	else:button_in(panel,"Select all text",func():transfer_text.grab_focus();transfer_text.select_all())
	button_in(panel,"Import pasted code",import_pasted_save)
	button_in(panel,"Return",close_save_transfer)

func import_pasted_save():
	var saved=game.import_code(transfer_text.text)
	if saved=="":show_notice("This code is incomplete or invalid. Your campaign has not changed.");return
	var persisted=persist_campaign(saved,false)
	if not music.playing:music.play()
	if saved=="ending":show_ending()
	elif saved=="battle":make_map();show_battle();await check_result()
	else:show_camp()
	show_notice("Campaign imported and saved on this device." if persisted else "Campaign imported, but this device could not write the save.")

func open_browser_transfer():
	if not OS.has_feature("web"):return
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/web_save_transfer.js"),true)
	if browser_transfer_callback==null:
		browser_transfer_callback=JavaScriptBridge.create_callback(func(arguments):
			if screen=="save_transfer" and is_instance_valid(transfer_text) and arguments.size()>0:transfer_text.text=str(arguments[0])
		)
	var bridge=JavaScriptBridge.get_interface("poemSaveTransfer")
	bridge.open(transfer_text.text,browser_transfer_callback)

func show_promotions(unit):
	screen="promotions";reset_ui()
	var panel=panel_at(ui,70,45,-70,-45)
	label_in(panel,"ADVANCED TRAINING",17,GOLD)
	label_in(panel,unit.name+"  /  "+game.class_name_for(unit),40,GOLD)
	label_in(panel,"Choose one path at level 10. The choice is permanent; level, experience and equipment are retained.",19)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",28);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(row)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(300,340)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
	var scroll=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",20);scroll.add_child(list)
	for path in game.promotion_options(unit):
		var card=PanelContainer.new();list.add_child(card)
		var details=VBoxContainer.new();details.add_theme_constant_override("separation",10);card.add_child(details)
		label_in(details,path.name,32,GOLD);label_in(details,path.description,19)
		var gains=[];var names={"max_hp":"HP","pow":"Power","defense":"Defense","resistance":"Resistance","speed":"Speed","move":"Move","heal":"Staff healing","hit":"Hit","crit":"Crit"}
		var actual_gains=game.promotion_gains(unit,path.id)
		for key in actual_gains:gains.append("%s +%d"%[names[key],actual_gains[key]])
		label_in(details,"   ·   ".join(gains),20)
		var chosen=unit.get("promotion","")==path.id
		var title="Chosen path" if chosen else ("Choose "+path.name if game.can_promote(unit,path.id) else "Requires level 10" if unit.level<10 else "Path unavailable")
		button_in(details,title,func():confirm_promotion(unit,path),not game.can_promote(unit,path.id))
	button_in(panel,"Return to company record",func():show_dossier(unit))

func confirm_promotion(unit,path):
	screen="promotion_confirm";reset_ui()
	var panel=panel_at(ui,280,180,-280,-180)
	label_in(panel,unit.name+" · "+path.name,42,GOLD)
	label_in(panel,path.description,24)
	label_in(panel,"This training choice cannot be changed. Your level, experience and equipped weapon remain the same.",21)
	button_in(panel,"Confirm training",func():
		if game.promote(unit,path.id):
			show_promotions(unit)
			show_notice("Training complete. Campaign saved." if persist_campaign("camp",false) else "Training complete. Save failed; keep the game open and try saving again.")
		else:show_promotions(unit))
	button_in(panel,"Keep considering",func():show_promotions(unit))

func show_supports(unit):
	screen="supports";reset_ui()
	var panel=panel_at(ui,70,45,-70,-45)
	label_in(panel,"COMPANY BONDS",17,GOLD)
	label_in(panel,unit.name+"  /  Support conversations",40,GOLD)
	label_in(panel,"Fight or heal within 2 tiles of your partner: 1 point per pair each turn, up to 3 per chapter. Read conversations to gain ranks.",19)
	label_in(panel,"Nearby partners grant +5 Hit and Avoid per rank; rank A also grants +1 damage. Bonuses are included in combat forecasts.",18)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",16);scroll.add_child(list)
	for entry in game.supports.for_unit(unit.id):
		var partner=game.roster.filter(func(other):return other.id!=unit.id and other.id in entry.members)[0]
		var record=game.supports.progress(entry.id);var available=partner.join<=game.chapter and unit.join<=game.chapter
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",24);list.add_child(row)
		var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(partner.id);portrait.custom_minimum_size=Vector2(250,300)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
		var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",10);row.add_child(details)
		label_in(details,partner.name+" · Rank "+game.supports.RANKS[int(record.rank)],32,GOLD)
		label_in(details,"%d bond points"%record.points if available else "Partner joins in chapter %d"%(int(partner.join)+1),20)
		for index in range(3):
			var scene=entry.scenes[index];var read=index<int(record.rank)
			var ready=index==int(record.rank) and available and game.supports.can_read(entry.id,game.chapter)
			var title="%s · %s"%[game.supports.RANKS[index+1],scene.title]
			label_in(details,title,22,GOLD)
			if not read and not ready:label_in(details,"Requires %d points, chapter %d, and previous rank."%[entry.points[index],int(entry.chapters[index])+1],17)
			button_in(details,"Replay conversation" if read else "Read conversation" if ready else "Not yet available",func():read_support(unit,entry,index),not (read or ready))
	button_in(panel,"Return to company record",func():show_dossier(unit))

func read_support(unit,entry,index: int):
	var rank=int(game.supports.progress(entry.id).rank)
	if index>rank or (index==rank and not game.supports.can_read(entry.id,game.chapter)):return
	show_dialogue(entry.scenes[index].lines,func():
		if index==int(game.supports.progress(entry.id).rank):
			game.supports.complete_scene(entry.id,game.chapter)
			var saved=persist_campaign("camp",false)
			show_supports(unit)
			show_notice("Bond strengthened. Campaign saved." if saved else "Bond strengthened. Save failed; keep the game open and try saving again.")
		else:show_supports(unit))

func supports_ready(unit) -> bool:
	return unit.join<=game.chapter and game.supports.for_unit(unit.id).any(func(entry):return game.supports.can_read(entry.id,game.chapter))

func map_height(point: Vector2i) -> float:
	return MapSurface.height_for(game.terrain(point))

func map_position(point: Vector2i) -> Vector3:
	return Vector3(point.x,map_height(point),point.y)

func animate_map_move(unit,path: Array):
	if path.size()<2 or not unit_nodes.has(unit.id):return
	var visual=unit_nodes[unit.id]
	moving_id=unit.id
	visual.position=map_position(path[0])
	var motion=create_tween()
	for i in range(1,path.size()):
		var point=path[i];var step=point-path[i-1]
		motion.tween_callback(func():visual.face_step(step);map_facings[unit.id]=visual.player.facing)
		var destination=map_position(point)
		var crossing=MapSurface.crossing(map_position(path[i-1]),destination)
		motion.tween_property(visual,"position",crossing,.0525).set_trans(Tween.TRANS_LINEAR)
		motion.tween_property(visual,"position",destination,.0525).set_trans(Tween.TRANS_LINEAR)
	await motion.finished
	visual.finish_move()
	moving_id=""

func preview_route(destination: Vector2i):
	if screen=="battle" and is_instance_valid(terrain_card):terrain_card.inspect(game,destination)
	if destination==last_hover:return
	last_hover=destination
	if is_instance_valid(route_preview):
		for child in route_preview.get_children():route_preview.remove_child(child);child.queue_free()
	if busy or selected==null or selected.team!="player" or selected.acted or origin!=null:return
	var path=game.movement_path(selected,destination)
	if path.size()<2:return
	if not is_instance_valid(route_preview):route_preview=Node3D.new();markers.add_child(route_preview)
	MapOverlay.route(route_preview,path,map_height)

func apply_audio_preferences():
	if is_instance_valid(music):music.volume_db=preferences.volume_db("music")
	for player in sfx_players:player.volume_db=preferences.volume_db("effects")

func show_options(return_to: String):
	if return_to=="battle":cancel_selection()
	options_return=return_to;screen="options";reset_ui()
	var panel=panel_at(ui,240,65,-240,-65)
	label_in(panel,"PLAYBACK & CONTROLS",17,GOLD)
	label_in(panel,"Options",44,GOLD)
	label_in(panel,"These settings stay on this device and do not change combat results.",19)
	label_in(panel,"Battle presentation",21,GOLD)
	var mode=OptionButton.new();mode.name="CombatMode";mode.custom_minimum_size.y=42
	for title in ["All 3D battles","3D for player attacks","Quick map battles"]:mode.add_item(title)
	mode.selected=["all","player","map"].find(preferences.values.combat);panel.add_child(mode)
	mode.item_selected.connect(func(index):preferences.values.combat=["all","player","map"][index])
	for key in ["music","effects"]:
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",20);panel.add_child(row)
		var title=label_in(row,key.capitalize()+" volume",20);title.custom_minimum_size.x=180
		var value_label=Label.new();value_label.custom_minimum_size.x=60
		var slider=HSlider.new();slider.name=key.capitalize()+"Volume";slider.min_value=0;slider.max_value=100;slider.step=5;slider.value=preferences.values[key]*100
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slider.custom_minimum_size.y=48;row.add_child(slider);row.add_child(value_label);value_label.text="%d%%"%slider.value
		slider.value_changed.connect(func(value):preferences.values[key]=value/100.0;value_label.text="%d%%"%value;apply_audio_preferences())
	label_in(panel,"Dialogue text",21,GOLD)
	var speed=OptionButton.new();speed.name="TextSpeed";speed.custom_minimum_size.y=42
	for title in ["Standard","Fast","Instant"]:speed.add_item(title)
	speed.selected=[55,90,0].find(int(preferences.values.text_speed));panel.add_child(speed)
	speed.item_selected.connect(func(index):preferences.values.text_speed=[55,90,0][index])
	var automatic=CheckButton.new();automatic.name="AutoEnd";automatic.text="End the phase when every ally has acted";automatic.button_pressed=preferences.values.auto_end;panel.add_child(automatic)
	automatic.toggled.connect(func(value):preferences.values.auto_end=value)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(spacer)
	button_in(panel,"Restore defaults",func():preferences.reset();apply_audio_preferences();show_options(options_return))
	button_in(panel,"Apply and return",close_options)

func close_options():
	var saved=preferences.save_file(settings_path)
	if options_return=="battle":show_battle()
	elif options_return=="camp":show_camp()
	else:show_title()
	if not saved:show_notice("Settings are active, but could not be saved on this device.")

func map_combat_feedback(events: Array):
	for event in events:
		var targets=game.units.filter(func(unit):return unit.id==event.target)
		if targets.is_empty():continue
		var unit=targets[0]
		var attackers=game.units.filter(func(other):return other.id==event.actor)
		var actor=unit_nodes.get(event.actor);var victim=unit_nodes.get(event.target)
		if actor!=null and not attackers.is_empty():
			actor.act_toward(game.pos(unit),game.pos(attackers[0]));map_facings[event.actor]=actor.player.facing
		await get_tree().create_timer(.12).timeout
		if victim!=null:
			victim.react(event.hit,int(event.remaining));victim.hp_ratio=clampf(float(event.remaining)/maxf(1,unit.max_hp),0,1);victim.refresh_health()
		var text_label=Label.new();ui.add_child(text_label)
		text_label.text="MISS" if not event.hit else ("CRIT " if event.crit else "")+str(int(event.damage))
		text_label.add_theme_font_size_override("font_size",28);text_label.add_theme_color_override("font_color",Color("ffe5a1"));text_label.add_theme_color_override("font_outline_color",Color("30353a"));text_label.add_theme_constant_override("outline_size",5)
		text_label.position=camera.unproject_position(map_position(game.pos(unit))+Vector3.UP*1.1)-Vector2(25,20);text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		play_sfx("critical" if event.crit else "hit" if event.hit else "swing")
		var fade=create_tween().set_parallel(true);fade.tween_property(text_label,"position:y",text_label.position.y-24,.24);fade.tween_property(text_label,"modulate:a",0.0,.24)
		await fade.finished
		text_label.queue_free()
		if actor!=null:actor.finish_move()
		if victim!=null and event.remaining>0:victim.finish_move()
	refresh_pieces()

func map_heal_feedback(healer,recipient,amount: int):
	var actor=unit_nodes.get(healer.id);var patient=unit_nodes.get(recipient.id)
	if actor!=null:
		if healer.id!=recipient.id:actor.act_toward(game.pos(recipient),game.pos(healer))
		else:actor.player.play("act","",true)
		map_facings[healer.id]=actor.player.facing
	await get_tree().create_timer(.12).timeout
	var glow=Node3D.new();pieces.add_child(glow);glow.position=map_position(game.pos(recipient))+Vector3.UP*.08
	var ring=MeshInstance3D.new();var shape=TorusMesh.new();shape.inner_radius=.28;shape.outer_radius=.32;ring.mesh=shape;glow.add_child(ring)
	var material=mat(Color(.55,.95,.76,.8));material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=material
	var text_label=Label.new();ui.add_child(text_label);text_label.text="+"+str(amount)
	text_label.position=camera.unproject_position(map_position(game.pos(recipient))+Vector3.UP*1.1)-Vector2(20,20)
	text_label.add_theme_font_size_override("font_size",28);text_label.add_theme_color_override("font_color",Color("b4efd1"));text_label.add_theme_color_override("font_outline_color",Color("263e36"));text_label.add_theme_constant_override("outline_size",5);text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if patient!=null:patient.hp_ratio=float(recipient.hp)/maxf(1,recipient.max_hp);patient.refresh_health()
	var bloom=create_tween().set_parallel(true)
	bloom.tween_property(glow,"scale",Vector3.ONE*1.7,.35);bloom.tween_property(material,"albedo_color:a",0.0,.35)
	bloom.tween_property(text_label,"position:y",text_label.position.y-22,.35);bloom.tween_property(text_label,"modulate:a",0.0,.35)
	await bloom.finished;glow.queue_free();text_label.queue_free()
	if actor!=null:actor.finish_move()

func initialize_map_cursor():
	if cursor_visible:return
	var allies=game.living("player")
	if selected!=null:cursor_tile=game.pos(selected)
	elif not allies.is_empty():cursor_tile=game.pos(allies[0])
	cursor_visible=true

func move_map_cursor(direction: Vector2i):
	if screen!="battle" or busy or game.phase!="player":return
	if direction!=Vector2i.ZERO and target!=null:target=null;update_side()
	initialize_map_cursor()
	var focus=get_viewport().gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	var size=game.board_size();cursor_tile+=direction
	cursor_tile=Vector2i(clampi(cursor_tile.x,0,size.x-1),clampi(cursor_tile.y,0,size.y-1))
	map_navigation.keep_visible(map_position(cursor_tile),terrain_card.get_global_rect() if is_instance_valid(terrain_card) else Rect2())
	highlight();preview_route(cursor_tile)

func cycle_ready_ally(direction: int):
	if screen!="battle" or busy or game.phase!="player":return
	var ready=game.living("player").filter(func(unit):return not unit.acted)
	if ready.is_empty():return
	var index=ready.find(selected)
	index=(0 if direction>0 else ready.size()-1) if index<0 else posmod(index+direction,ready.size())
	var unit=ready[index]
	cancel_selection();cursor_tile=game.pos(unit);cursor_visible=true
	var focus=get_viewport().gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	click_tile(cursor_tile)
	map_navigation.keep_visible(map_position(cursor_tile),terrain_card.get_global_rect() if is_instance_valid(terrain_card) else Rect2())

func activate_map_cursor():
	if screen!="battle" or busy or game.phase!="player":return
	initialize_map_cursor()
	if target!=null and game.pos(target)==cursor_tile and selected!=null and game.can_attack(selected,target):player_attack()
	else:click_tile(cursor_tile)
	highlight()

func draw_map_cursor():
	var root=Node3D.new();root.name="MapCursor";markers.add_child(root)
	root.position.y=map_height(cursor_tile)
	for sign_x in [-1,1]:
		for sign_y in [-1,1]:
			cube(root,Vector3(cursor_tile.x+sign_x*.36,.085,cursor_tile.y+sign_y*.46),Vector3(.22,.035,.055),Color("fff6d6"))
			cube(root,Vector3(cursor_tile.x+sign_x*.46,.085,cursor_tile.y+sign_y*.36),Vector3(.055,.035,.22),Color("fff6d6"))

func critical_cutin(unit: Dictionary):
	if skip_combat:return
	var cutin=CriticalCutin.new()
	var quote=fighters.profiles.get(unit.id,{}).get("critical_quote","Stand aside!")
	cutin.configure(ui,unit,portraits.get_unit_portrait(unit),quote)
	await cutin.play(func():return skip_combat,unit.team=="enemy")
	cutin.queue_free()

func persist_campaign(stage_name: String,notify_failure=true) -> bool:
	var saved=game.save_game(save_path,stage_name)
	save_failed=not saved
	if screen=="battle" and is_instance_valid(status):
		status.text="TURN %d  /  %s"%[game.turn,game.phase.to_upper()]+("\nSAVE FAILED" if save_failed else "")
	if not saved and notify_failure and not save_warning_queued:
		save_warning_queued=true;call_deferred("show_save_warning")
	return saved

func show_save_warning():
	save_warning_queued=false
	if save_failed:show_notice("Autosave failed. Keep this game open. Try Save again, or use Transfer code to keep a copy of your current progress.",8.0)

func close_save_transfer():
	if transfer_return=="battle":show_battle()
	elif transfer_return=="camp":show_camp()
	else:show_title()
