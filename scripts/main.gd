extends Node3D
const Rules = preload("res://scripts/rules.gd")
const Portraits = preload("res://scripts/portraits.gd")
const WeaponIcons=preload("res://scripts/weapon_icons.gd")
const MapUnit=preload("res://scripts/campaign_map_unit.gd")
const ActionRange=preload("res://scripts/action_range.gd")
const MapOverlay=preload("res://scripts/map_overlay.gd")
const MapSurface=preload("res://scripts/map_surface.gd")
const TerrainCard=preload("res://scripts/terrain_card.gd")
const MenuLayout=preload("res://scripts/menu_layout.gd")
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
const CombatHitStop=preload("res://scripts/combat_hit_stop.gd")
const CombatHeal=preload("res://scripts/combat_heal.gd")
const CombatProjectile=preload("res://scripts/combat_projectile.gd")
const CombatCamera=preload("res://scripts/combat_camera.gd")
const CombatHUD=preload("res://scripts/combat_hud.gd")
const CombatTransition=preload("res://scripts/combat_transition.gd")
const ProgressReward=preload("res://scripts/progress_reward.gd")
const ScoreDirector=preload("res://scripts/score_director.gd")
const PhaseBanner=preload("res://scripts/phase_banner.gd")
var phase_skip=false
var phase_banner_active=false
var chapter_card_active=false
var chapter_card_skip=false
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
var battle_hint: Label
var status: Label
var selected = null
var target = null
var origin = null
var busy = false
var screen = "title"
var music: AudioStreamPlayer
var score: AudioStreamSynchronized
var score_director: ScoreDirector
var sfx_streams: Dictionary={}
var sfx_players: Array=[]
var interface_audio=preload("res://scripts/ui_audio.gd").new()
var travel_audio=preload("res://scripts/travel_audio.gd").new()
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
var preview_return=Callable()
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
	add_child(interface_audio);interface_audio.configure(preferences.volume_db("effects"))
	add_child(travel_audio);travel_audio.configure(preferences.volume_db("effects"))
	score_director=ScoreDirector.new();add_child(score_director);score_director.configure(preferences.volume_db("music"))
	music=score_director.player;score=score_director.score
	for effect in ["select","swing","hit","critical","heal","magic","phase","guard","cutin","levelup"]:
		sfx_streams[effect]=load("res://assets/audio/"+effect+".wav")
	for family in ["sword","axe","lance","bow","ember","gale","thunder"]:
		sfx_streams["release_"+family]=load("res://assets/audio/release_"+family+".wav")
	for i in range(6):
		var player=AudioStreamPlayer.new();player.volume_db=-12;sfx_players.append(player);add_child(player)

func play_sfx(effect: String):
	for player in sfx_players:
		if not player.playing:
			player.stream=sfx_streams.get(effect);player.play();return

func combat_release_sound(unit: Dictionary) -> String:
	var family=game.item_for(unit).id if unit.weapon=="magic" else unit.weapon
	var effect="release_"+family
	return effect if sfx_streams.has(effect) else "magic" if unit.weapon=="magic" else "swing"

func select_score_theme():
	if score_director.current_id==score_director.profile_for(game.chapter).id:return
	if music_transition and music_transition.is_valid():music_transition.kill()
	score_director.select_chapter(game.chapter);score=score_director.score;music=score_director.player

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
	battle_hint=null
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
	interface_audio.watch(b,interface_audio.button_tone(text_value))
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

func menu_panel(max_width=1200.0,left_aligned=false) -> VBoxContainer:
	var frame=PanelContainer.new();ui.add_child(frame)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);frame.add_child(column)
	var host=ui
	var arrange=func():
		if not is_instance_valid(frame) or frame.is_queued_for_deletion():return
		var width=minf(max_width,host.size.x-56)
		frame.position=Vector2(28 if left_aligned else (host.size.x-width)*.5,28)
		frame.size=Vector2(width,host.size.y-56)
	host.resized.connect(arrange);frame.minimum_size_changed.connect(arrange)
	arrange.call();MenuLayout.configure(host)
	return column

func scrolling_column(parent,min_width=0.0) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.x=min_width;parent.add_child(scroll)
	var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10);scroll.add_child(column)
	return column

func clear_world():
	for n in [world,markers,pieces,stage]:
		if is_instance_valid(n):remove_child(n);n.queue_free()
	world=Node3D.new();add_child(world)
	markers=Node3D.new();add_child(markers)
	pieces=Node3D.new();add_child(pieces)
	stage=Node3D.new();add_child(stage);stage.hide()
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
	select_score_theme()
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
	title_backdrop()
	var v=menu_panel(500,true)
	label_in(v,"A TACTICAL CHRONICLE",16,GOLD)
	label_in(v,"POEM",64)
	label_in(v,"A broken banner. A borrowed sun.\nTwenty-four lives caught between them.",22)
	label_in(v,"Twelve chapters. Twenty-four paths to dawn.",17,Color("766e5e"))
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(spacer)
	button_in(v,"Begin the chronicle",func():game.new_campaign();music.play();show_camp())
	button_in(v,"Continue saved campaign",load_campaign,not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".bak"))
	button_in(v,"Transfer a local save",func():show_save_transfer("title"))
	var extras=HBoxContainer.new();extras.add_theme_constant_override("separation",8);v.add_child(extras)
	button_in(extras,"Options",func():show_options("title")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(extras,"Credits",show_credits).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(v,"Character & map workshop",show_visual_workshop)
	label_in(v,"Fallen allies return next chapter.\nIf the company falls, regroup and try again.",14,Color("827b6c"))

func show_credits():
	screen="credits";reset_ui()
	title_backdrop()
	var frame=menu_panel(900)
	var panel=scrolling_column(frame)
	label_in(panel,"POEM",42,GOLD)
	label_in(panel,"An original tactical chronicle",22)
	label_in(panel,"ORIGINAL SCORE",20,GOLD)
	label_in(panel,"A Standard at Dawn · The Road Beneath the Ash · Dawn Without Kings\nPaired calm / Ablaze arrangements for the campaign’s three acts.",18)
	label_in(panel,"Instrument recordings: VSCO 2 Community Edition\nVersilian Studios · Sam Gossner and Simon Dalzell\nSample cutting: Elan Hickler / Soundemote\nReleased under CC0 1.0 Universal.",19)
	label_in(panel,"ART & TYPE",20,GOLD)
	label_in(panel,"Original generated illustrations and sprite artwork.\nOriginal 3D environments and character figures.\nCormorant Garamond · Cormorant Project Authors\nSIL Open Font License.",19)
	label_in(panel,"Created with Godot Engine.",19)
	button_in(frame,"Return to title",show_title)

func title_backdrop():
	var backdrop=preload("res://scripts/title_backdrop.gd").new()
	backdrop.configure(ui,[world,pieces,markers])

func show_visual_workshop():
	screen="visual_workshop"
	ui.hide();world.hide();pieces.hide();markers.hide();stage.hide()
	var workshop=load("res://visual_lab.tscn").instantiate()
	canvas.add_child(workshop)
	workshop.closed.connect(func():
		canvas.remove_child(workshop);workshop.queue_free();camera.current=true;show_title())

func show_camp():
	select_score_theme()
	screen="camp";busy=false;selected=null;target=null;origin=null
	game.phase="player"
	var story_key="opening_"+str(game.chapter)
	if story_key not in game.story_seen:
		game.story_seen.append(story_key)
		show_dialogue(story.chapters[game.chapter].opening,show_camp)
		return
	reset_ui()
	# Runtime lookup avoids 4.5.1 shutdown retention observed with this direct preload.
	var backdrop=load("res://scripts/painted_backdrop.gd").new();backdrop.name="CouncilBackdrop"
	backdrop.configure(ui,[world,markers,pieces,stage])
	var bg=ColorRect.new();bg.color=INK;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shell=MarginContainer.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:shell.add_theme_constant_override(k,28)
	ui.add_child(shell)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",24);shell.add_child(row)
	var left=VBoxContainer.new();left.custom_minimum_size.x=320;left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=.85;row.add_child(left)
	label_in(left,"POEM / WAR COUNCIL",16,GOLD)
	label_in(left,"%02d  %s"%[game.chapter+1,game.info().title],34)
	label_in(left,game.info().place.to_upper(),17,Color("79755f"))
	var briefing=scrolling_column(left)
	label_in(briefing,game.info().intro,21)
	label_in(briefing,game.info().get("tactical_brief",""),18,Color("6f6c5e"))
	label_in(briefing,"Select up to six allies. Open a portrait to inspect equipment and support conversations. Wardens heal within staff range; everyone carries two field tonics.",16,Color("766e5e"))
	label_in(left,"OBJECTIVE  /  "+objective_text(),18,GOLD)
	label_in(left,"Recruited %d / 24  ·  Deployed %d / 6"%[game.available().size(),game.deployed.size()],18)
	button_in(left,"Deploy company  >",deploy_company,game.deployed.is_empty())
	var tools_row=HBoxContainer.new();tools_row.add_theme_constant_override("separation",8);left.add_child(tools_row)
	button_in(tools_row,"Save campaign",func():save_with_feedback("camp")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(tools_row,"Options",func():show_options("camp")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(tools_row,"Route",show_campaign_route).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(left,"Transfer a local save",func():show_save_transfer("camp"))
	button_in(left,"Return to title",show_title)
	var roster_column=VBoxContainer.new();roster_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;roster_column.size_flags_stretch_ratio=1.35;row.add_child(roster_column)
	label_in(roster_column,"YOUR COMPANY",20,GOLD)
	var scroll=ScrollContainer.new();scroll.name="CompanyScroll";scroll.custom_minimum_size.x=460;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;roster_column.add_child(scroll)
	var cards=GridContainer.new();cards.name="CompanyCards";cards.columns=2
	cards.add_theme_constant_override("h_separation",10);cards.add_theme_constant_override("v_separation",10)
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(cards)
	for u in game.roster:
		var unlocked=int(u.join)<=game.chapter
		var card=preload("res://scripts/company_card.gd").new();cards.add_child(card)
		card.configure(u,game.class_name_for(u),portraits.get_portrait(u.id) if unlocked else unit_portrait(u),game.item_for(u),u.id in game.deployed,unlocked,unlocked and supports_ready(u),game.deployed.size()>=6)
		interface_audio.watch(card.portrait_button);interface_audio.watch(card.deploy_button)
		card.inspect_requested.connect(func():show_dossier(u))
		card.deployment_requested.connect(func():
			if u.id in game.deployed:game.deployed.erase(u.id)
			elif unlocked and game.deployed.size()<6:game.deployed.append(u.id)
			var previous_scroll=scroll.scroll_vertical
			show_camp()
			# The new grid must finish layout before restoring its reading position.
			var host=weakref(ui)
			(func():
				await get_tree().process_frame
				await get_tree().process_frame
				var current=host.get_ref()
				if current==null or current.is_queued_for_deletion():return
				var replacement=current.find_child("CompanyScroll",true,false)
				if replacement!=null:replacement.scroll_vertical=previous_scroll
				var next_card=current.find_child("Company_"+u.id,true,false)
				if next_card!=null:next_card.deploy_button.grab_focus()).call_deferred())
	MenuLayout.configure(ui)

func show_campaign_route():
	screen="campaign_route";reset_ui()
	var frame=menu_panel(1320)
	label_in(frame,"THE MARCH OF THE STANDARD",30,GOLD)
	label_in(frame,"A chronicle of the valley · Select a reached destination to review its briefing.",16)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",20);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;frame.add_child(row)
	var route=preload("res://scripts/campaign_route.gd").new();route.name="CampaignRoute";row.add_child(route)
	route.configure(game.content.chapters,game.chapter,game.completed)
	for marker in route.markers:interface_audio.watch(marker)
	var details=VBoxContainer.new();details.custom_minimum_size.x=260;row.add_child(details)
	var progress=label_in(details,"",16,GOLD)
	var title=label_in(details,"",28)
	var place=label_in(details,"",17,GOLD)
	var reading=scrolling_column(details)
	var briefing=label_in(reading,"",20)
	var tactics_text=label_in(reading,"",17,Color("766e5e"))
	var refresh=func(index):
		var chapter=game.content.chapters[index]
		progress.text="CHAPTER %02d / %02d · %s"%[index+1,game.content.chapters.size(),"COMPLETED" if index<game.chapter or game.completed else "CURRENT"]
		title.text=chapter.title;place.text=chapter.place.to_upper()
		briefing.text=chapter.intro;tactics_text.text=chapter.get("tactical_brief","")
		reading.get_parent().scroll_vertical=0
	route.chapter_selected.connect(refresh);refresh.call(game.chapter)
	label_in(frame,"Numbered seals mark the road traveled. The standard marks your company’s current chapter.",15,Color("766e5e"))
	button_in(frame,"Return to war council",show_camp)

func objective_text() -> String:
	match game.info().objective:
		"rout":return "Defeat every enemy"
		"seize":return "Occupy the golden standard at the eastern gate"
		"survive":return "Survive six enemy phases"
		_:return "Defeat "+game.info().boss

func deploy_company():
	game.start_battle();make_map();show_battle();busy=true;update_side();persist_campaign("battle")
	await announce_chapter()
	await announce_phase("player")
	busy=false;update_side()

func announce_chapter():
	chapter_card_skip=false;chapter_card_active=true
	var card=preload("res://scripts/chapter_card.gd").new();card.configure(ui,game.chapter,game.info().title,game.info().place)
	await card.play(func():return chapter_card_skip)
	ui.remove_child(card);card.queue_free();chapter_card_active=false

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
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);panel.offset_left=-325;panel.offset_right=-22;panel.offset_top=118;panel.offset_bottom=118;panel.custom_minimum_size.x=303;ui.add_child(panel)
	side=VBoxContainer.new();side.add_theme_constant_override("separation",5);panel.add_child(side)
	var bottom=PanelContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=22;bottom.offset_right=-343;bottom.offset_top=-64;bottom.offset_bottom=-22;ui.add_child(bottom)
	battle_hint=label_in(bottom,"",14)
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
		label_in(details,game.class_name_for(selected)+(" · Commander" if selected.get("boss",false) and selected.team=="enemy" else ""),16)
		var bond_rank=game.supports.nearby_rank(game,selected)
		label_in(details,("Lv %d / MAX"%selected.level if selected.level>=game.MAX_LEVEL else "Lv %d / XP %d"%[selected.level,selected.xp])+(" · Bond "+game.supports.RANKS[bond_rank] if bond_rank>0 else ""),15)
		var health_row=HBoxContainer.new();health_row.add_theme_constant_override("separation",8);side.add_child(health_row)
		var hp_text=label_in(health_row,"HP %d/%d"%[selected.hp,selected.max_hp],16);hp_text.autowrap_mode=TextServer.AUTOWRAP_OFF
		var meter=CombatHUD.HealthMeter.new();meter.name="SelectedHealth";meter.maximum=maxf(1,selected.max_hp)
		meter.custom_minimum_size=Vector2(40,9);meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;meter.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		var ratio=float(selected.hp)/meter.maximum
		meter.accent=Color("96bd82") if ratio>.5 else Color("e0b366") if ratio>.25 else Color("d47d6e")
		health_row.add_child(meter);meter.change_to(selected.hp,true)
		var attack_text=label_in(health_row,"ATK %d"%game.attack_power(selected),16);attack_text.autowrap_mode=TextServer.AUTOWRAP_OFF
		label_in(side,"DEF %d · RES %d · SPD %d"%[selected.defense,game.resistance_for(selected),game.attack_speed(selected)],17)
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
				var face=portraits.get_forecast_portrait(unit);faces.append(face if face!=null else unit_portrait(unit))
			forecast_panel=BattleForecast.new();forecast_panel.configure(ui,game,selected,target,faces)
			var target_id=target.id
			forecast_panel.track_target(func():
				if not unit_nodes.has(target_id):return Vector2(-1000,-1000)
				var figure=unit_nodes[target_id]
				if camera.is_position_behind(figure.global_position):return Vector2(-1000,-1000)
				var bounds=figure.screen_bounds(camera)
				return Vector2(bounds.get_center().x,bounds.position.y))
			label_in(side,("Foe has an effective counter!" if counter.effective else "Counter if both survive.") if f.counter else "Foe cannot counter at this range.",14,GOLD)
			button_in(side,"Confirm attack",func():player_attack(),busy)
		if selected.team=="player" and not selected.acted:
			button_in(side,"Wait / secure position",wait_action,busy)
			button_in(side,"Field tonic (+12 HP)  ·  "+str(int(selected.potions)),tonic,busy or selected.potions<=0 or selected.hp>=selected.max_hp)
			if selected.weapon=="staff":label_in(side,"Heal %d HP · range %s. Click an injured ally."%[game.healing_power(selected),game.range_text(selected)],16,GOLD)
	else:
		label_in(side,"THE COMPANY",15,GOLD)
		label_in(side,"%d allies  ·  %d enemies"%[game.living("player").size(),game.living("enemy").size()],18)
		label_in(side,"Choose an ally to move or inspect a foe.",17,Color("6f6c5e"))
		button_in(side,"Enemy ranges [R]: "+("on" if show_danger else "off"),toggle_danger,busy)
	button_in(side,"End player phase",end_turn,busy)
	button_in(side,"Menu [M]",show_battle_menu,busy)
	if is_instance_valid(battle_hint):
		battle_hint.text="Arrows: cursor · Enter: select · Q/E: allies · M: menu"
		if selected!=null:
			battle_hint.text="Blue: move · Orange: reach · Enter: act · Esc: undo"
			if selected.team=="enemy":battle_hint.text="Red tiles: enemy reach · R: all ranges · Esc: close"
			elif selected.weapon=="staff":battle_hint.text="Blue: move · Green: heal · Enter: act · Esc: undo"
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
	# Minimum size is recalculated after the contents and compact theme settle.
	side.get_parent().call_deferred("reset_size")

func show_battle_menu():
	if screen!="battle" or busy or game.phase!="player":return
	map_navigation.stop();interface_audio.cue("confirm");screen="battle_menu"
	battle_menu=Control.new();battle_menu.name="BattleMenu";ui.add_child(battle_menu)
	battle_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battle_menu.mouse_filter=Control.MOUSE_FILTER_STOP;battle_menu.z_index=20
	var shade=ColorRect.new();shade.color=Color(0.04,.06,.08,.55);battle_menu.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame=PanelContainer.new();frame.name="MenuFrame";battle_menu.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER);frame.offset_left=-280;frame.offset_right=280;frame.offset_top=-250;frame.offset_bottom=250
	var commands=VBoxContainer.new();commands.add_theme_constant_override("separation",8);frame.add_child(commands)
	label_in(commands,"Battle menu",40,GOLD)
	label_in(commands,"Turn %d · %s"%[game.turn,game.info().title],17)
	button_in(commands,"Return to battle",close_battle_menu).grab_focus()
	button_in(commands,"Save",func():close_battle_menu();save_with_feedback("battle"))
	button_in(commands,"Transfer code",func():close_battle_menu();show_save_transfer("battle"))
	button_in(commands,"Options / audio",func():close_battle_menu();show_options("battle"))
	button_in(commands,"War council (restart map)",func():close_battle_menu();show_camp())
	label_in(commands,"Arrows / Enter: select · Q/E: allies · W: wait\nR: danger · Space: end phase · Esc: undo\nWheel / + −: zoom · Middle drag: pan · Home: reset\nTab: skip animation · M / Esc: close menu",14,Color("777163"))
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
	for n in markers.get_children():
		markers.remove_child(n);n.queue_free()
	var danger={}
	if show_danger:
		for enemy in game.living("enemy"):danger.merge(tactics.threatened_tiles(game,enemy))
	if selected!=null and selected.team=="enemy":danger.merge(tactics.threatened_tiles(game,selected))
	MapOverlay.tiles(markers,danger.keys(),Color(.69,.21,.31,.24),.025,"DangerRange",map_height)
	if cursor_visible:draw_map_cursor()
	if selected==null or selected.team!="player" or selected.acted:return
	var range_map=game.reachable(selected) if origin==null else {game.pos(selected):0}
	MapOverlay.tiles(markers,range_map.keys(),Color(.18,.49,.85,.30),.032,"MovementRange",map_height)
	var healing=selected.weapon=="staff"
	var reach=ActionRange.tiles(game,selected,range_map)
	for point in range_map:reach.erase(point)
	MapOverlay.tiles(markers,reach.keys(),Color(.22,.68,.45,.23) if healing else Color(.88,.40,.14,.23),.035,"HealingReach" if healing else "ActionReach",map_height)
	var targets=[]
	for unit in game.living(selected.team if healing else "enemy"):
		if game.can_heal(selected,unit) if healing else game.can_attack(selected,unit):targets.append(game.pos(unit))
	MapOverlay.tiles(markers,targets,Color(.25,.78,.49,.40) if healing else Color(.87,.29,.16,.38),.039,"HealingTargets" if healing else "AttackRange",map_height)

func toggle_danger():
	if busy or screen!="battle":return
	show_danger=not show_danger;highlight();update_side()

func _input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed:map_navigation.dragging=false
	if screen=="battle_menu" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_M]:
		interface_audio.cue("back");close_battle_menu();get_viewport().set_input_as_handled();return
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
		if chapter_card_active:chapter_card_skip=true
		elif phase_banner_active:phase_skip=true
		else:skip_combat=true
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if screen=="credits" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		interface_audio.cue("back");show_title();get_viewport().set_input_as_handled();return
	if screen=="model" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		interface_audio.cue("back");close_model_view();get_viewport().set_input_as_handled();return
	if screen in ["dossier","campaign_route"] and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		interface_audio.cue("back");show_camp();get_viewport().set_input_as_handled();return
	if screen=="dialogue" and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE,KEY_ENTER]:advance_dialogue();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:finish_dialogue();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_TAB:skip_combat=true
		if screen=="battle" and not busy:
			if event.keycode==KEY_ESCAPE:
				if selected!=null:interface_audio.cue("back")
				cancel_selection()
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
		if actor.commander_screen_bounds(camera).has_point(point):return unit
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
				busy=true;update_side();await staff_healing(selected,u,u.hp-old_hp);await show_progress(before);busy=false;finish_action();return
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
	var allies=game.living("player")
	if not allies.is_empty():await frame_map_action([allies[0]])
	await announce_phase("player");busy=false;update_side()
	persist_campaign("battle")

func make_fighter(u,position) -> Node3D:
	return fighters.build(stage,u,position)

func staff_healing(healer,recipient,amount: int):
	if not preferences.show_cinematic(healer.team):
		play_sfx("heal");await map_heal_feedback(healer,recipient,amount);return
	await cinematic(healer,recipient,[{"actor":healer.id,"target":recipient.id,"healing":amount}],{healer.id:healer.hp,recipient.id:recipient.hp-amount})

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
	var playback=preload("res://scripts/combat_playback.gd").new();playback.configure(ui)
	var veil=CombatTransition.new();veil.configure(ui,func():return camera.unproject_position(focus))
	veil.conceal()
	var push=map_navigation.approach_combat(focus)
	await push.finished
	if veil.motion.is_running():await veil.motion.finished
	for n in stage.get_children():n.queue_free()
	stage.visible=true
	var old_lighting=battle_lighting(game.info().get("environment","village"))
	var arena_context=scenery.combat_context(game,a,b)
	scenery.battle_landscape(stage,Vector3(35,0,0),arena_context)
	world.hide();pieces.hide()
	var ranged=events[0].has("healing") or game.distance(a,b)>1 or a.weapon in ["bow","magic"] or b.weapon in ["bow","magic"]
	var spacing=2.0 if ranged else 1.6
	var actor=make_fighter(a,Vector3(35-spacing,0,0));var defender=make_fighter(b,Vector3(35+spacing,0,0))
	actor.rotation.y=-PI/2;defender.rotation.y=PI/2
	var contact_terrain="=" if arena_context.environment=="harbor" else arena_context.terrain
	for pair in [[actor,a],[defender,b]]:
		var combatant=pair[0];var job=pair[1].job
		if combatant.has_signal("travel_contact"):
			combatant.travel_contact.connect(func(index):
				if not stage.visible or skip_combat:return
				travel_audio.step(contact_terrain,job,index,arena_context.environment)
				if combatant.has_method("ground_contact_position"):
					preload("res://scripts/combat_dust.gd").spawn(stage,combatant.ground_contact_position(),combatant.travel_direction,job=="Rider",travel_audio.surface_for(contact_terrain,arena_context.environment),index))
	if actor.has_method("face_opponent"):actor.face_opponent(defender)
	if defender.has_method("face_opponent"):defender.face_opponent(actor)
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
				if strike_event.target==unit.id:hp+=strike_event.get("damage",0)-strike_event.get("healing",0)
		displayed_hp[unit.id]=mini(hp,unit.max_hp)
		var opponent=b if unit.id==a.id else a
		var triangle=0 if events[0].has("healing") else game.forecast(unit,opponent).triangle
		entries.append({"unit":unit,"hp":displayed_hp[unit.id],"portrait":portraits.get_unit_portrait(unit),"class_name":game.class_name_for(unit),"weapon":game.item_for(unit).name,"triangle":triangle})
	var banner=CombatHUD.new();banner.configure(ui,entries)
	var caption=Label.new();caption.name="CombatCaption";caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);caption.offset_top=36;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",30);caption.add_theme_color_override("font_color",Color("f7edce"));caption.add_theme_color_override("font_outline_color",Color("373d42"));caption.add_theme_constant_override("outline_size",7)
	caption.hide();ui.add_child(caption)

	var finished_exchange=false
	var dodge: Tween
	await combat_pause(.3)
	for event in events:
		if skip_combat:break
		var who=actor if event.actor==a.id else defender
		var whom=defender if who==actor else actor
		var unit=a if who==actor else b
		if event.has("healing"):
			banner.mark_actor(unit.id)
			director.shot(who.position,whom.position,"windup",true,mounted,.28)
			await combat_wait(who.pose("cast_windup",.36))
			if skip_combat:break
			await combat_wait(who.pose("cast",.18))
			if skip_combat:break
			var recovery=CombatHeal.new();stage.add_child(recovery)
			var healing_motion=recovery.play(who.socket_position("projectile"),whom.socket_position("impact"),whom.global_position,event.healing)
			while not recovery.has_arrived and not skip_combat:await get_tree().process_frame
			if skip_combat:recovery.queue_free();break
			var recipient=b if who==actor else a
			play_sfx("heal");displayed_hp[event.target]=mini(recipient.max_hp,displayed_hp[event.target]+event.healing)
			banner.set_health(event.target,int(displayed_hp[event.target]))
			director.shot(who.position,whom.position,"impact",true,mounted,.24)
			if not await combat_wait(healing_motion):
				if is_instance_valid(recovery):recovery.queue_free()
				break
			if not await combat_wait(who.pose("idle",.18)):break
			continue
		var spell=game.item_for(unit).id if unit.weapon=="magic" else ""
		banner.mark_actor(unit.id)
		var base=who.position
		var direction=1.0 if who==actor else -1.0
		var is_ranged=unit.weapon in ["bow","magic"] or (unit.weapon=="lance" and game.distance(a,b)>1)
		if not is_ranged:
			var distance_to_close=absf(whom.position.x-who.position.x)-Fighters.Actor.melee_spacing(unit.weapon)
			if absf(distance_to_close)>.08:
				who.pose("advance",.2)
				var approach=create_tween().set_trans(Tween.TRANS_SINE)
				approach.tween_property(who,"position:x",base.x+direction*distance_to_close,Fighters.Actor.approach_duration(distance_to_close))
				while approach.is_running():
					if skip_combat:approach.kill();break
					await get_tree().process_frame
				if skip_combat:break
				if who.has_method("update_locomotion"):who.update_locomotion()
		if who.has_method("aim_at"):who.aim_at(whom.socket_position("impact"))
		director.shot(who.position,whom.position,"windup",is_ranged,mounted,.28)
		var preparation="throw_windup" if is_ranged and unit.weapon=="lance" else "windup"
		if event.crit:preparation="critical_"+preparation
		var gathering: Node3D
		if unit.weapon=="magic":
			gathering=preload("res://scripts/combat_charge.gd").new();stage.add_child(gathering)
			gathering.begin(who,spell,.4 if event.crit else .28)
		await combat_wait(who.pose(preparation,.4 if event.crit else .28))
		if skip_combat:
			if is_instance_valid(gathering):gathering.queue_free()
			break
		if event.crit:
			await critical_cutin(unit)
			if skip_combat:
				if is_instance_valid(gathering):gathering.queue_free()
				break
		if not is_ranged:play_sfx(combat_release_sound(unit))
		var contact_point=whom.socket_position("impact")
		if not event.hit:
			whom.pose("evade",.12)
			dodge=create_tween()
			dodge.tween_property(whom,"position:z",-.32,.12)
			dodge.tween_interval(.35 if is_ranged else .12)
			dodge.tween_property(whom,"position:z",0.0,.16)
		var blade_trail: Node3D
		if not is_ranged:
			blade_trail=CombatTrail.new();stage.add_child(blade_trail)
			if not blade_trail.follow(who,unit.weapon,event.crit):blade_trail.queue_free();blade_trail=null
		if not await combat_wait(who.pose("throw" if is_ranged and unit.weapon=="lance" else "strike",.12)):
			if is_instance_valid(blade_trail):blade_trail.queue_free()
			if is_instance_valid(gathering):gathering.queue_free()
			break
		if not is_ranged:
			if is_instance_valid(blade_trail):blade_trail.sample();blade_trail.finish()
			else:
				var trail=CombatTrail.new();stage.add_child(trail)
				trail.start(contact_point+Vector3(-direction*.28,0,.18),unit.weapon,direction,event.crit)
		if is_ranged:
			var release=who.socket_position("projectile")
			if who.has_method("release_projectile"):who.release_projectile()
			if is_instance_valid(gathering):gathering.release()
			play_sfx(combat_release_sound(unit))
			if not await projectile(release,contact_point,unit.weapon,spell,fighters.equipment_profile(unit),not event.hit):break
		director.shot(who.position,whom.position,"impact",is_ranged,mounted,.16)
		if event.hit:
			play_sfx("guard" if event.damage<=0 else "critical" if event.crit else "hit")
			whom.pose("guard" if event.damage<=0 else "critical_hit" if event.crit else "hit",.12)
		displayed_hp[event.target]=maxi(0,displayed_hp[event.target]-event.damage)
		banner.set_health(event.target,int(displayed_hp[event.target]))
		show_impact(whom.socket_position("impact"),event,spell)
		if event.hit and event.damage>0:director.impact(event.crit)
		var hold=CombatHitStop.duration_for(event)
		if hold>0:
			# Let the recoil register before holding the contact silhouette.
			if not await combat_pause(.035):break
			var hit_stop=CombatHitStop.new();stage.add_child(hit_stop)
			if not await combat_wait(hit_stop.play([who,whom],hold)):
				hit_stop.restore();hit_stop.queue_free();break
		await combat_pause((.22 if not event.crit else .34)-(.035 if hold>0 else 0.0))
		if skip_combat:break
		who.pose("recover",.16)
		if event.remaining<=0:
			await combat_wait(whom.pose("down",.3))
			if skip_combat:break
			finished_exchange=true
			var finish=preload("res://scripts/combat_finish.gd").new();stage.add_child(finish)
			var line=finish.quote_for(unit,fighters.profiles)
			caption.text=unit.name+(" — "+line if not line.is_empty() else "");caption.show()
			director.shot(who.position,whom.position,"finish",is_ranged,unit.job=="Rider",.28,unit.weapon)
			await finish.play(who,func():return skip_combat,.95 if not line.is_empty() else .60)
			finish.queue_free()
			break
		else:
			await combat_wait(whom.pose("idle",.16))
		if skip_combat:break
		await combat_wait(who.pose("idle",.12))
	if not finished_exchange:
		director.shot(actor.position,defender.position,"wide",ranged,mounted,.2)
		if not skip_combat:await combat_pause(.18)

	if dodge and dodge.is_valid():dodge.kill()
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
	veil.queue_free();playback.stop();playback.queue_free()
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

func combat_wait(motion: Tween) -> bool:
	while motion.is_valid() and motion.is_running():
		if skip_combat:motion.kill();return false
		await get_tree().process_frame
	return not skip_combat

func combat_pause(duration: float) -> bool:
	var motion=create_tween();motion.tween_interval(duration)
	return await combat_wait(motion)

func projectile(from: Vector3,to: Vector3,kind: String,spell="",appearance={},miss=false) -> bool:
	var visual=CombatProjectile.new();stage.add_child(visual)
	var completed=await combat_wait(visual.launch(from,to,kind,.23,spell,appearance,miss))
	if is_instance_valid(visual):visual.queue_free()
	return completed

func show_impact(point,event,spell=""):
	var impact=CombatImpact.new();stage.add_child(impact);impact.configure(point,event,camera,spell)

func check_result() -> bool:
	var outcome=game.result()
	if outcome=="":return false
	persist_campaign("battle")
	screen="result";reset_ui()
	var frame=menu_panel(1000)
	var v=scrolling_column(frame)
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
		button_in(frame,"Continue the chronicle",func():
			var onward=func():
				game.finish_chapter()
				persist_campaign("ending" if game.completed else "camp")
				if game.completed:show_ending()
				else:show_camp()
			show_dialogue(story.chapters[game.chapter].closing,onward,"closing"))
	else:
		label_in(v,"THE STANDARD FALLS",38,GOLD)
		label_in(v,"Your company is scattered. Regroup at the war council and choose a new approach.",24)
		button_in(frame,"Regroup and retry",show_camp)
	return true

func show_ending():
	screen="ending";reset_ui()
	var v=menu_panel()
	label_in(v,"DAWN WITHOUT KINGS",40,GOLD)
	label_in(v,game.content.chapters[-1].outro,22)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for u in game.roster:
		label_in(list,u.name+" · "+game.class_name_for(u)+" · Level "+str(int(u.level)),19,Color(u.color))
		label_in(list,profiles.get(u.id,{}).get("ending",u.bio),17)
	button_in(v,"Return to title",show_title)

func show_dialogue(lines: Array,on_complete: Callable,kind="opening"):
	screen="dialogue";reset_ui()
	var backdrop=preload("res://scripts/dialogue_backdrop.gd").new()
	backdrop.begin(ui,[world,pieces,markers],game.chapter,kind)
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
	dialogue_stage.refresh_prompt()

func advance_dialogue():
	if screen!="dialogue":return
	if dialogue_label.visible_characters>=0 and dialogue_label.visible_characters<dialogue_label.text.length():
		dialogue_reveal=dialogue_label.text.length();dialogue_label.visible_characters=dialogue_label.text.length();dialogue_stage.refresh_prompt();return
	dialogue_index+=1;refresh_dialogue()

func finish_dialogue():
	var callback=dialogue_callback;dialogue_callback=Callable()
	if callback.is_valid():callback.call()

func show_dossier(unit):
	screen="dossier";reset_ui()
	var panel=menu_panel()
	label_in(panel,"COMPANY RECORD",17,GOLD)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",36);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(row)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id)
	var size_portrait=func():portrait.custom_minimum_size=Vector2(minf(380,ui.size.x*.28),0)
	ui.resized.connect(size_portrait);size_portrait.call()
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
	var info=scrolling_column(row)
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
	button_in(actions,"View character",func():show_model_view(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
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
	var panel=menu_panel()
	label_in(panel,"COMPANY ARSENAL",17,GOLD)
	label_in(panel,unit.name+"  /  "+game.class_name_for(unit),40,GOLD)
	label_in(panel,"Equipment is shared freely. New supplies become available as the campaign advances.",19)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",28);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(row)
	var summary=scrolling_column(row,250);summary.get_parent().size_flags_horizontal=Control.SIZE_FILL
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id);portrait.custom_minimum_size=Vector2(230,200)
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

func show_model_view(unit,on_close=Callable()):
	screen="model";preview_unit=unit;preview_return=on_close;reset_ui()
	for child in stage.get_children():stage.remove_child(child);child.queue_free()
	world.hide();pieces.hide();markers.hide();stage.show()
	var theme=game.info().get("environment","village");battle_lighting(theme)
	scenery.battle_landscape(stage,Vector3(35,0,0),{"environment":theme})
	var actor_data=unit.duplicate(true);actor_data.team="player"
	preview_actor=make_fighter(actor_data,Vector3(35,0,0));preview_actor.rotation.y=PI-.35
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=-.25;camera.fov=35
	camera.position=Vector3(35,1.4,4.7 if unit.job!="Rider" else 6.5);camera.look_at(Vector3(35,1.05,0))
	var panel=menu_panel(310,true)
	label_in(panel,"TRAINING / OUTFIT PREVIEW" if preview_return.is_valid() else "COMPANY / PREVIEW",15,GOLD);label_in(panel,unit.name,38)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id)
	var size_portrait=func():portrait.custom_minimum_size=Vector2(220,150 if ui.size.y<760 else 220)
	ui.resized.connect(size_portrait);size_portrait.call()
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;panel.add_child(portrait)
	label_in(panel,game.class_name_for(unit)+" · "+game.item_for(unit).name,21)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(spacer)
	button_in(panel,"Turn left",func():preview_actor.rotation.y-=PI/6)
	button_in(panel,"Turn right",func():preview_actor.rotation.y+=PI/6)
	label_in(panel,"Preview action",15,GOLD)
	var actions=[["Ready","idle"],["Attack preparation","windup"],["Critical preparation","critical_windup"],["Attack","strike"],["Recovery","recover"]]
	if unit.weapon=="staff":actions=[["Ready","idle"],["Healing preparation","cast_windup"],["Heal","cast"]]
	actions.append_array([["Guard","guard"],["Hit reaction","hit"],["Critical reaction","critical_hit"],["Defeated","down"],["Finishing flourish","victory_flourish"],["Finish","victory"]])
	var choice=OptionButton.new();choice.name="PreviewAction";choice.custom_minimum_size.y=42
	for entry in actions:
		choice.add_item(entry[0]);choice.set_item_metadata(choice.item_count-1,entry[1])
	panel.add_child(choice)
	choice.item_selected.connect(func(index):preview_actor.pose(str(choice.get_item_metadata(index))))
	button_in(panel,"Play again",func():preview_actor.pose(str(choice.get_item_metadata(choice.selected))))
	button_in(panel,"Return to training [Esc]" if preview_return.is_valid() else "Return to record [Esc]",close_model_view)

func close_model_view():
	var return_action=preview_return;preview_return=Callable()
	make_map()
	if return_action.is_valid():return_action.call()
	else:show_dossier(preview_unit)

func show_progress(before: Dictionary):
	for change in game.progress_since(before):
		reward_skip=false
		reward_panel=ProgressReward.new()
		reward_panel.configure(ui,change,portraits.get_dialogue_portrait(change.unit.id),game.class_name_for(change.unit),game.MAX_LEVEL)
		reward_panel.begin(func():play_sfx("levelup"))
		var elapsed=0.0
		while elapsed<(2.0 if reward_panel.leveled else .8) and not reward_skip and not reward_panel.requested_close:
			await get_tree().process_frame;elapsed+=get_process_delta_time()
		reward_panel.queue_free();reward_panel=null

func show_save_transfer(return_screen: String):
	if return_screen=="battle":
		if busy or game.phase!="player":return
		cancel_selection()
	screen="save_transfer";transfer_return=return_screen;reset_ui()
	if return_screen=="title":title_backdrop()
	var panel=menu_panel()
	label_in(panel,"LOCAL SAVE TRANSFER",36,GOLD)
	label_in(panel,"Move your campaign between browsers or the desktop app. Copy the code below, then paste it into this screen on the other build.",21)
	label_in(panel,"Import replaces this device’s current campaign and keeps its previous save as a backup. No code is sent to a server.",17)
	transfer_text=TextEdit.new();transfer_text.name="SaveCode";transfer_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	transfer_text.custom_minimum_size.y=160
	transfer_text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;transfer_text.add_theme_font_size_override("font_size",14);panel.add_child(transfer_text)
	transfer_text.text=game.export_code(return_screen) if return_screen in ["camp","battle"] else game.export_saved_code(save_path)
	transfer_text.placeholder_text="Paste a POEM1: save code here."
	var code_actions=HBoxContainer.new();code_actions.add_theme_constant_override("separation",10);panel.add_child(code_actions)
	button_in(code_actions,"Copy code",func():DisplayServer.clipboard_set(transfer_text.text);show_notice("Save code copied. Keep it in a local text file or paste it into another build.")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if OS.has_feature("web"):button_in(code_actions,"Open browser copy / paste",open_browser_transfer).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	else:button_in(code_actions,"Select all text",func():transfer_text.grab_focus();transfer_text.select_all()).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",10);panel.add_child(actions)
	button_in(actions,"Import pasted code",import_pasted_save).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(actions,"Return",close_save_transfer).size_flags_horizontal=Control.SIZE_EXPAND_FILL

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
	var panel=menu_panel()
	label_in(panel,"ADVANCED TRAINING",17,GOLD)
	label_in(panel,unit.name+"  /  "+game.class_name_for(unit),40,GOLD)
	label_in(panel,"Choose one path at level 10. The choice is permanent; level, experience and equipment are retained.",19)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",28);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(row)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id)
	var size_portrait=func():portrait.custom_minimum_size=Vector2(minf(300,ui.size.x*.25),0)
	ui.resized.connect(size_portrait);size_portrait.call()
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
	var frame=menu_panel(800)
	var panel=scrolling_column(frame)
	label_in(panel,unit.name+" · "+path.name,42,GOLD)
	label_in(panel,path.description,24)
	label_in(panel,"This training choice cannot be changed. Your level, experience and equipped weapon remain the same.",21)
	button_in(frame,"Confirm training",func():
		if game.promote(unit,path.id):
			show_promotions(unit)
			show_notice("Training complete. Campaign saved." if persist_campaign("camp",false) else "Training complete. Save failed; keep the game open and try saving again.")
		else:show_promotions(unit))
	button_in(frame,"Keep considering",func():show_promotions(unit))
	button_in(frame,"Preview outfit",func():
		var preview=unit.duplicate(true);preview.promotion=path.id
		show_model_view(preview,func():confirm_promotion(unit,path)))

func show_supports(unit):
	screen="supports";reset_ui()
	var panel=menu_panel()
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
	var completed=func():
		if index==int(game.supports.progress(entry.id).rank):
			game.supports.complete_scene(entry.id,game.chapter)
			var saved=persist_campaign("camp",false)
			show_supports(unit)
			show_notice("Bond strengthened. Campaign saved." if saved else "Bond strengthened. Save failed; keep the game open and try saving again.")
		else:show_supports(unit)
	show_dialogue(entry.scenes[index].lines,completed,"support")

func supports_ready(unit) -> bool:
	return unit.join<=game.chapter and game.supports.for_unit(unit.id).any(func(entry):return game.supports.can_read(entry.id,game.chapter))

func map_height(point: Vector2i) -> float:
	return MapSurface.height_for(game.terrain(point))

func map_position(point: Vector2i) -> Vector3:
	return Vector3(point.x,map_height(point),point.y)

func action_occlusion() -> Rect2:
	return terrain_card.get_global_rect() if is_instance_valid(terrain_card) and terrain_card.visible else Rect2()

func map_cue_padding(text: String) -> Vector2:
	var width=ui.get_theme_font("font","Label").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
	return Vector2(maxf(18,width*.5+8),50)

func frame_map_action(units: Array,padding=Vector2(18,18)):
	var points=[]
	for unit in units:
		var point=map_position(game.pos(unit));points.append(point);points.append(point+Vector3.UP*1.1)
	var pan=map_navigation.frame_action(points,action_occlusion(),.22,padding)
	if pan!=null:await pan.finished

func track_map_actor(actor: Node3D):
	map_navigation.follow_action([actor.position,actor.position+Vector3.UP*1.1],action_occlusion())

func animate_map_move(unit,path: Array):
	if path.size()<2 or not unit_nodes.has(unit.id):return
	var visual=unit_nodes[unit.id]
	moving_id=unit.id
	visual.position=map_position(path[0])
	var pan=map_navigation.frame_action([visual.position,visual.position+Vector3.UP*1.1],action_occlusion())
	if pan!=null:await pan.finished
	var motion=create_tween()
	for i in range(1,path.size()):
		var point=path[i];var step=point-path[i-1]
		motion.tween_callback(func():visual.face_step(step);map_facings[unit.id]=visual.player.facing)
		var destination=map_position(point)
		var crossing=MapSurface.crossing(map_position(path[i-1]),destination)
		motion.tween_property(visual,"position",crossing,.0525).set_trans(Tween.TRANS_LINEAR)
		motion.parallel().tween_method(func(_progress):track_map_actor(visual),0.0,1.0,.0525)
		motion.tween_property(visual,"position",destination,.0525).set_trans(Tween.TRANS_LINEAR)
		motion.parallel().tween_method(func(_progress):track_map_actor(visual),0.0,1.0,.0525)
		if i%2==1 or i==path.size()-1:
			var stride=i/2+1
			motion.tween_callback(func():travel_audio.step(game.terrain(point),unit.job,stride,game.info().get("environment","village")))
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
	interface_audio.player.volume_db=preferences.volume_db("effects")
	travel_audio.set_volume(preferences.volume_db("effects"))
	if is_instance_valid(score_director):score_director.set_volume(preferences.volume_db("music"))
	for player in sfx_players:player.volume_db=preferences.volume_db("effects")

func show_options(return_to: String):
	if return_to=="battle":cancel_selection()
	options_return=return_to;screen="options";reset_ui()
	if return_to=="title":title_backdrop()
	var frame=menu_panel(800)
	var panel=scrolling_column(frame)
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
	button_in(frame,"Restore defaults",func():preferences.reset();apply_audio_preferences();show_options(options_return))
	button_in(frame,"Apply and return",close_options)

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
		var cue_text="MISS" if not event.hit else "NO DAMAGE" if event.damage<=0 else ("CRIT " if event.crit else "")+str(int(event.damage))
		await frame_map_action([unit]+attackers,map_cue_padding(cue_text))
		var dodge: Tween
		if victim!=null and not attackers.is_empty():
			victim.face_toward(game.pos(attackers[0]),game.pos(unit));map_facings[event.target]=victim.player.facing
			if not event.hit:dodge=victim.evade_from(game.pos(attackers[0]),game.pos(unit))
		if actor!=null and not attackers.is_empty():
			actor.act_toward(game.pos(unit),game.pos(attackers[0]));map_facings[event.actor]=actor.player.facing
		await get_tree().create_timer(.12).timeout
		if victim!=null:
			victim.react(event.hit and event.damage>0,int(event.remaining));victim.hp_ratio=clampf(float(event.remaining)/maxf(1,unit.max_hp),0,1);victim.refresh_health()
		var text_label=Label.new();ui.add_child(text_label)
		text_label.text=cue_text
		text_label.add_theme_font_size_override("font_size",28);text_label.add_theme_color_override("font_color",Color("ffe5a1"));text_label.add_theme_color_override("font_outline_color",Color("30353a"));text_label.add_theme_constant_override("outline_size",5)
		text_label.position=camera.unproject_position(map_position(game.pos(unit))+Vector3.UP*1.1)-Vector2(text_label.get_minimum_size().x*.5,20);text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		play_sfx("swing" if not event.hit else "guard" if event.damage<=0 else "critical" if event.crit else "hit")
		var fade=create_tween().set_parallel(true);fade.tween_property(text_label,"position:y",text_label.position.y-24,.24);fade.tween_property(text_label,"modulate:a",0.0,.24)
		await fade.finished
		if dodge and dodge.is_valid() and dodge.is_running():await dodge.finished
		text_label.queue_free()
		if actor!=null:actor.finish_move()
		if victim!=null and event.remaining>0:victim.finish_move()
	refresh_pieces()

func map_heal_feedback(healer,recipient,amount: int):
	var cue_text="+"+str(amount)
	await frame_map_action([healer,recipient],map_cue_padding(cue_text))
	var actor=unit_nodes.get(healer.id);var patient=unit_nodes.get(recipient.id)
	if actor!=null:
		if healer.id!=recipient.id:actor.act_toward(game.pos(recipient),game.pos(healer))
		else:actor.player.play("act","",true)
		map_facings[healer.id]=actor.player.facing
	await get_tree().create_timer(.12).timeout
	var glow=Node3D.new();pieces.add_child(glow);glow.position=map_position(game.pos(recipient))+Vector3.UP*.08
	var ring=MeshInstance3D.new();var shape=TorusMesh.new();shape.inner_radius=.28;shape.outer_radius=.32;ring.mesh=shape;glow.add_child(ring)
	var material=mat(Color(.55,.95,.76,.8));material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=material
	var text_label=Label.new();ui.add_child(text_label);text_label.text=cue_text
	text_label.add_theme_font_size_override("font_size",28);text_label.add_theme_color_override("font_color",Color("b4efd1"));text_label.add_theme_color_override("font_outline_color",Color("263e36"));text_label.add_theme_constant_override("outline_size",5);text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	text_label.position=camera.unproject_position(map_position(game.pos(recipient))+Vector3.UP*1.1)-Vector2(text_label.get_minimum_size().x*.5,20)
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
	var previous=cursor_tile-direction
	cursor_tile=Vector2i(clampi(cursor_tile.x,0,size.x-1),clampi(cursor_tile.y,0,size.y-1))
	if cursor_tile!=previous:interface_audio.cue("move")
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
	preload("res://scripts/tactical_cursor.gd").new().build(markers,map_position(cursor_tile))

func critical_cutin(unit: Dictionary):
	if skip_combat:return
	var cutin=CriticalCutin.new()
	var quote=fighters.profiles.get(unit.id,{}).get("critical_quote","Stand aside!")
	var commander=fighters.Commanders.profile(unit)
	if not commander.is_empty():quote=commander.critical_quote
	cutin.configure(ui,unit,portraits.get_critical_portrait(unit),quote)
	play_sfx("cutin")
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
