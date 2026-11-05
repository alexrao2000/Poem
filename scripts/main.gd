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
const CloudSky=preload("res://scripts/cloud_sky.gd")
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
var drop_mode=false
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
var debug_session=preload("res://scripts/debug_session.gd").new()
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
	sky_material.sky_top_color=Color("6c9dc5");sky_material.sky_horizon_color=Color("d8dbce")
	sky_material.ground_bottom_color=Color("7a8163");sky_material.ground_horizon_color=Color("d8dbce")
	sky_material.sky_cover=CloudSky.texture();sky_material.sky_cover_modulate=CloudSky.tint("road")
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
	for element in ["ember","gale","thunder"]:
		sfx_streams["impact_"+element]=load("res://assets/audio/impact_"+element+".wav")
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

func combat_contact_sounds(unit: Dictionary,event: Dictionary) -> Array:
	if not event.hit:return []
	if event.damage<=0:return ["guard"]
	var family=game.item_for(unit).id if unit.get("weapon","")=="magic" else ""
	var effect="impact_"+family
	if sfx_streams.has(effect):return [effect,"critical"] if event.crit else [effect]
	return ["critical" if event.crit else "hit"]

func play_combat_contact(unit: Dictionary,event: Dictionary):
	for effect in combat_contact_sounds(unit,event):play_sfx(effect)

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
	drop_mode=false
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
		if (u.hp<=0 and not game.DeathDoor.downed(u)) or not u.get("carried_by","").is_empty():continue
		var visual=MapUnit.new();visual.name=str(u.id).validate_node_name();visual.position=map_position(game.pos(u))
		var passenger=game.DeathDoor.passenger(game,u)
		pieces.add_child(visual);visual.configure(map_catalog,u,map_facings.get(u.id,"south"),passenger.name if passenger!=null else "")
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
	label_in(v,"A TACTICAL CHRONICLE"+(" / DEBUG" if debug_session.active else ""),16,GOLD)
	label_in(v,"POEM",64)
	label_in(v,"A broken banner. A borrowed sun.\nTwenty-four lives caught between them.",22)
	label_in(v,"Twelve chapters. Twenty-four paths to dawn.",17,Color("766e5e"))
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(spacer)
	button_in(v,"Begin the chronicle",show_campaign_rules)
	button_in(v,"Continue saved campaign",load_campaign,game.read_saved_data(campaign_save_path()).is_empty())
	button_in(v,"Transfer a local save",func():show_save_transfer("title"))
	var extras=HBoxContainer.new();extras.add_theme_constant_override("separation",8);v.add_child(extras)
	button_in(extras,"Options",func():show_options("title")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(extras,"Credits",show_credits).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(v,"Character & map workshop",show_visual_workshop)
	label_in(v,"Toggle permadeath when you begin.\nYour chronicle, your company.",14,Color("827b6c"))

func show_campaign_rules():
	screen="campaign_rules";reset_ui();title_backdrop()
	var frame=menu_panel(720);var panel=scrolling_column(frame)
	label_in(panel,"A NEW CHRONICLE",17,GOLD)
	label_in(panel,"Campaign options",38)
	var permanent=CheckButton.new();permanent.name="Permadeath";permanent.text="Permadeath";permanent.button_pressed=game.permadeath;panel.add_child(permanent)
	label_in(panel,"On: fallen allies stay lost after a chapter victory. If Lyra or the whole company falls, retry from preparation. Off: fallen allies recover for the next chapter.",20)
	label_in(panel,"You can change this toggle in Options while experimenting. Turning it off does not revive earlier losses; Debug mode has a revival control.",18)
	button_in(frame,"Begin the chronicle",func():game.new_campaign(permanent.button_pressed);music.play();show_camp())
	button_in(frame,"Return to title",show_title)

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
	label_in(panel,"Additional character models and animations: Quaternius\nUniversal Base Characters · Modular Fantasy Outfits\nUniversal Animation Library · CC0 1.0 Universal.",19)
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
	drop_mode=false
	game.ensure_leader()
	select_score_theme()
	screen="camp";busy=false;selected=null;target=null;origin=null
	game.phase="player"
	var story_key="opening_"+str(game.chapter)
	if story_key not in game.story_seen:
		game.story_seen.append(story_key)
		show_dialogue(story.chapters[game.chapter].opening,show_camp)
		return
	var trial_scene=game.trials.next_scene(game)
	if not trial_scene.is_empty():
		persist_campaign("camp");show_dialogue(trial_scene,show_camp);return
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
	label_in(left,"POEM / WAR COUNCIL"+(" / DEBUG" if debug_session.active else ""),16,GOLD)
	label_in(left,"%02d  %s"%[game.chapter+1,game.info().title],34)
	label_in(left,game.info().place.to_upper(),17,Color("79755f"))
	var briefing=scrolling_column(left)
	label_in(briefing,game.info().intro,21)
	if game.trials.flags.values().has(true):
		label_in(briefing,"Section %d / 3 · Reset pressure %d / 10"%[int(game.chapter/4)+1,game.trials.pressure],18,GOLD)
		button_in(briefing,"Campaign experiments & legacy supplies",show_campaign_trials)
	label_in(briefing,game.info().get("tactical_brief",""),18,Color("6f6c5e"))
	label_in(briefing,"Select up to six allies. Open a portrait to inspect equipment and support conversations. Wardens heal within staff range; everyone carries two field tonics.",16,Color("766e5e"))
	label_in(left,"OBJECTIVE  /  "+objective_text(),18,GOLD)
	label_in(left,"%s  ·  Available %d  ·  Deployed %d / 6"%["Permadeath ON" if game.permadeath else "Permadeath OFF",game.available().size(),game.deployed.size()],18)
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
		var unlocked=game.trials.joined(game,u) and not u.get("fallen",false)
		var card=preload("res://scripts/company_card.gd").new();cards.add_child(card)
		card.configure(u,game.class_name_for(u),portraits.get_portrait(u.id) if unlocked or u.get("fallen",false) else unit_portrait(u),game.item_for(u),u.id in game.deployed,unlocked,unlocked and supports_ready(u),game.deployed.size()>=6,game.trials.deployment_condition(game,u))
		if u.id=="lyra" and (game.trials.flags.reset_pressure or (game.trials.flags.section_restarts and game.permadeath)):
			card.deploy_button.disabled=true;card.deploy_button.tooltip_text="The lord leads the company in this experiment."
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
	var sectioned=game.permadeath and game.trials.flags.section_restarts
	route.configure(game.content.chapters,game.chapter,game.completed,sectioned)
	for marker in route.markers:interface_audio.watch(marker)
	var details=VBoxContainer.new();details.custom_minimum_size.x=260;row.add_child(details)
	var progress=label_in(details,"",16,GOLD)
	var title=label_in(details,"",28)
	var place=label_in(details,"",17,GOLD)
	var section_label=label_in(details,"",15,GOLD);section_label.name="RouteSection";section_label.visible=sectioned
	var reading=scrolling_column(details)
	var briefing=label_in(reading,"",20)
	var tactics_text=label_in(reading,"",17,Color("766e5e"))
	var refresh=func(index):
		var chapter=game.content.chapters[index]
		progress.text="CHAPTER %02d / %02d · %s"%[index+1,game.content.chapters.size(),"COMPLETED" if index<game.chapter or game.completed else "CURRENT"]
		title.text=chapter.title;place.text=chapter.place.to_upper()
		var start=game.trials.section_start(index)
		section_label.text="SECTION %d · CHAPTERS %02d–%02d"%[int(index/4)+1,start+1,mini(start+4,game.content.chapters.size())]
		briefing.text=chapter.intro;tactics_text.text=chapter.get("tactical_brief","")
		reading.get_parent().scroll_vertical=0
	route.chapter_selected.connect(refresh);refresh.call(game.chapter)
	var route_hint="Numbered seals mark the road traveled. The standard marks your company’s current chapter."
	if sectioned:route_hint="Diamonds mark section starts."+(" The chronicle is complete." if game.completed else " Your current retreat point is Chapter %02d."%(game.trials.section_start(game.chapter)+1))
	var legend=label_in(frame,route_hint,15,Color("766e5e"));legend.name="RouteLegend"
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
	status.text="TURN %d  /  %s"%[game.turn,game.phase.to_upper()]+(" · DEBUG" if debug_session.active else "")+("\nSAVE FAILED" if save_failed else "")
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
			if selected.has("held_tonics"):label_in(side,"Held tonics: %d%s"%[selected.held_tonics," · Raider" if selected.get("raider",false) else ""],16,GOLD)
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
		if drop_mode:
			label_in(side,"Choose an adjacent gold tile to put your ally down.",17,GOLD)
			button_in(side,"Cancel drop",cancel_drop,busy)
		elif selected.team=="player" and game.can_act(selected):
			button_in(side,"Wait / secure position",wait_action,busy)
			button_in(side,"Field tonic (+12 HP)  ·  "+str(int(selected.potions)),tonic,busy or selected.potions<=0 or selected.hp>=selected.max_hp)
			if selected.weapon=="staff":label_in(side,"Heal %d HP · range %s. Click an injured ally."%[game.healing_power(selected),game.range_text(selected)],16,GOLD)
		var conditions=[];var condition_help=[]
		if game.DeathDoor.downed(selected):
			conditions.append("Downed · %d %s left"%[selected.bleed_turns,"phase" if selected.bleed_turns==1 else "phases"])
			condition_help.append("Rescue or heal this ally. Bleeding continues at the end of each player phase; %d remain. Carrying pauses the countdown."%selected.bleed_turns)
		var passenger=game.DeathDoor.passenger(game,selected)
		if passenger!=null:
			conditions.append("Carrying "+passenger.name)
			condition_help.append("Carrying %s: movement %d. Rescue & triage offers healing or a drop position."%[passenger.name,game.movement_allowance(selected)])
		if selected.get("resolve_until",0)>=game.turn:
			conditions.append("ATK +2");condition_help.append("Sacrifice opening: +2 attack through player turn %d."%selected.resolve_until)
		if selected.get("recovering",false):
			conditions.append("Recovering");condition_help.append("Started this attempt with 4 HP missing and one tonic. Healing can restore normal maximum health.")
		if not conditions.is_empty():
			var condition_label=label_in(side," · ".join(conditions),16,GOLD);condition_label.name="UnitConditions"
			condition_label.mouse_filter=Control.MOUSE_FILTER_PASS
			condition_label.autowrap_mode=TextServer.AUTOWRAP_OFF;condition_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;condition_label.tooltip_text="\n".join(condition_help)
		if not drop_mode and game.can_act(selected) and (game.DeathDoor.passenger(game,selected)!=null or game.units.any(func(patient):return game.DeathDoor.can_rescue(game,selected,patient) or (game.can_heal(selected,patient) and not patient.get("carried_by","").is_empty()))):
			button_in(side,"Rescue & triage",show_triage,busy)
	else:
		label_in(side,"THE COMPANY",15,GOLD)
		label_in(side,"%d allies  ·  %d enemies"%[game.living("player").size(),game.living("enemy").size()],18)
		label_in(side,"Choose an ally to move or inspect a foe.",17,Color("6f6c5e"))
		button_in(side,"Enemy ranges [R]: "+("on" if show_danger else "off"),toggle_danger,busy)
	if save_failed and game.action_saves:button_in(side,"Retry autosave",retry_action_save,busy)
	var expiring=game.units.filter(func(unit):return game.DeathDoor.downed(unit) and unit.bleed_turns==1 and unit.get("carried_by","").is_empty()) if game.phase=="player" else []
	var phase_button=button_in(side,"End player phase" if expiring.is_empty() else "End phase · %d will fall"%expiring.size(),end_turn,busy or game.phase!="player");phase_button.name="EndPlayerPhase"
	if not expiring.is_empty():
		phase_button.add_theme_color_override("font_color",Color("923e33"))
		phase_button.tooltip_text=", ".join(expiring.map(func(unit):return unit.name))+" will bleed out when this player phase ends. Rescue or heal them first."
	button_in(side,"Menu [M]",show_battle_menu,busy)
	if is_instance_valid(battle_hint):
		battle_hint.text="Arrows: cursor · Enter: select · Q/E: allies · M: menu"
		if selected!=null:
			battle_hint.text="Blue: move · Orange: reach · Enter: act · Esc: undo"
			if selected.team=="enemy":battle_hint.text="Red tiles: enemy reach · R: all ranges · Esc: close"
			elif selected.weapon=="staff":battle_hint.text="Blue: move · Green: heal · Enter: act · Esc: undo"
			elif game.units.any(func(unit):return game.DeathDoor.can_rescue(game,selected,unit)):battle_hint.text="Blue: move · Gold: rescue · Enter: act · Esc: undo"
			if game.DeathDoor.downed(selected):battle_hint.text="Needs help: select a nearby ally for Rescue & triage, or heal with a staff."
			if game.action_saves:battle_hint.text=battle_hint.text.replace("Esc: undo","Esc: deselect")
		if drop_mode:battle_hint.text="Gold: drop ally · Arrows / Enter: choose · Esc / right-click: cancel drop"
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
	label_in(commands,"Battle menu"+(" / DEBUG" if debug_session.active else ""),40,GOLD)
	label_in(commands,"Turn %d · %s"%[game.turn,game.info().title],17)
	button_in(commands,"Return to battle",close_battle_menu).grab_focus()
	button_in(commands,"Save",func():close_battle_menu();save_with_feedback("battle"))
	button_in(commands,"Transfer code",func():close_battle_menu();show_save_transfer("battle"))
	button_in(commands,"Options / audio",func():close_battle_menu();show_options("battle"))
	var retreat=label_in(commands,restart_summary(),15,GOLD);retreat.name="RestartPreview"
	button_in(commands,("War council (restart section)" if game.trials.flags.section_restarts and game.permadeath else "War council (restart map)"),func():close_battle_menu();restart_campaign_attempt())
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
	if drop_mode:
		MapOverlay.tiles(markers,game.DeathDoor.drop_positions(game,selected),Color(.86,.66,.23,.42),.039,"DropTargets",map_height)
		return
	var range_map=game.reachable(selected) if origin==null else {game.pos(selected):0}
	MapOverlay.tiles(markers,range_map.keys(),Color(.18,.49,.85,.30),.032,"MovementRange",map_height)
	var healing=selected.weapon=="staff"
	var reach=ActionRange.tiles(game,selected,range_map)
	for point in range_map:reach.erase(point)
	MapOverlay.tiles(markers,reach.keys(),Color(.22,.68,.45,.23) if healing else Color(.88,.40,.14,.23),.035,"HealingReach" if healing else "ActionReach",map_height)
	var targets=[]
	var candidates=game.units.filter(func(unit):return unit.team==selected.team and unit.get("carried_by","").is_empty()) if healing else game.living("enemy")
	for unit in candidates:
		if game.can_heal(selected,unit) if healing else game.can_attack(selected,unit):targets.append(game.pos(unit))
	MapOverlay.tiles(markers,targets,Color(.25,.78,.49,.40) if healing else Color(.87,.29,.16,.38),.039,"HealingTargets" if healing else "AttackRange",map_height)
	if not healing:
		var patients=game.units.filter(func(unit):return game.DeathDoor.can_rescue(game,selected,unit))
		MapOverlay.tiles(markers,patients.map(func(unit):return game.pos(unit)),Color(.86,.66,.23,.42),.039,"RescueTargets",map_height)

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
	if screen=="debug_report" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		show_debug_tools(options_return);get_viewport().set_input_as_handled();return
	if screen=="triage" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		show_battle();get_viewport().set_input_as_handled();return
	if screen=="debug_tools" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		show_options(options_return);get_viewport().set_input_as_handled();return
	if screen in ["credits","campaign_rules"] and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		interface_audio.cue("back");show_title();get_viewport().set_input_as_handled();return
	if screen=="model" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		interface_audio.cue("back");close_model_view();get_viewport().set_input_as_handled();return
	if screen in ["dossier","campaign_route","campaign_trials"] and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		interface_audio.cue("back")
		if screen=="campaign_trials" and game.completed:show_ending()
		else:show_camp()
		get_viewport().set_input_as_handled();return
	if screen=="dialogue" and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE,KEY_ENTER]:advance_dialogue();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:finish_dialogue();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_TAB:skip_combat=true
		if screen=="battle" and not busy:
			if event.keycode==KEY_ESCAPE:
				if selected!=null:interface_audio.cue("back")
				if drop_mode:cancel_drop()
				else:cancel_selection()
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
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if drop_mode:cancel_drop()
			else:cancel_selection()
			return
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
		if (unit.hp<=0 and not game.DeathDoor.downed(unit)) or not unit_nodes.has(unit.id):continue
		var actor=unit_nodes[unit.id]
		if actor.commander_screen_bounds(camera).has_point(point) or actor.rescue_screen_bounds(camera).has_point(point) or actor.carry_screen_bounds(camera).has_point(point):return unit
		if not actor.screen_bounds(camera).has_point(point):continue
		var depth=camera.unproject_position(actor.global_position).y
		if depth>front:picked=unit;front=depth
	return picked

func cancel_selection():
	drop_mode=false
	if selected!=null and origin!=null and not selected.acted:
		game.undo_move(selected)
	selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()

func click_tile(p: Vector2i):
	if busy or not action_save_ready():return
	if is_instance_valid(terrain_card):terrain_card.inspect(game,p)
	if drop_mode:
		if selected!=null and p in game.DeathDoor.drop_positions(game,selected):drop_ally(p)
		return
	var u=game.at(p)
	if selected!=null and selected.team=="player" and not selected.acted and u!=null:
		if game.can_attack(selected,u):target=u;update_side();return
		if game.can_heal(selected,u):
			var before=game.progress_snapshot()
			var old_hp=u.hp
			if game.heal(selected,u):
				if not checkpoint_action():return
				busy=true;update_side();await staff_healing(selected,u,u.hp-old_hp,before);await show_progress(before);busy=false;finish_action();return
		if game.DeathDoor.can_rescue(game,selected,u):show_triage(u);return
	if u!=null and u.team=="player":
		cancel_selection();selected=u;play_sfx("select");highlight();update_side();return
	if u!=null and u.team=="enemy" and (selected==null or selected.team=="enemy"):
		selected=u;target=null;play_sfx("select");highlight();update_side();return
	if selected!=null and selected.team=="player" and not selected.acted and origin==null and u==null and game.reachable(selected).has(p):
		origin=game.pos(selected)
		var path=game.movement_path(selected,p)
		if game.move_unit(selected,p):
			if not checkpoint_action():return
			target=null;busy=true;highlight();update_side()
			await animate_map_move(selected,path)
			busy=false;refresh_pieces();highlight();update_side()
		else:origin=null

func wait_action():
	if busy or drop_mode or selected==null or not action_save_ready():return
	if game.wait_unit(selected) and checkpoint_action():finish_action()

func tonic():
	if busy or selected==null or not action_save_ready():return
	var unit=selected;var old_hp=unit.hp
	if game.use_tonic(unit):
		if not checkpoint_action():return
		busy=true;play_sfx("heal");update_side();await map_heal_feedback(unit,unit,unit.hp-old_hp);busy=false;finish_action()

func player_attack():
	if busy or selected==null or target==null or not action_save_ready():return
	busy=true
	update_side()
	var a=selected;var b=target
	var initial_hp={a.id:a.hp,b.id:b.hp}
	var before=game.progress_snapshot()
	var events=game.combat(a,b)
	if not checkpoint_action():return
	await cinematic(a,b,events,initial_hp)
	await show_progress(before)
	busy=false;finish_action()

func finish_action():
	drop_mode=false
	selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()
	if await check_result():return
	persist_campaign("battle")
	if preferences.values.auto_end and game.living("player").all(func(u):return u.acted):end_turn()

func end_turn(resuming=false):
	if busy or screen!="battle" or (game.phase!="player" and not resuming) or not action_save_ready():return
	cancel_selection();busy=true
	if not resuming:
		var bleeding=game.units.filter(func(unit):return game.DeathDoor.downed(unit)).map(func(unit):return unit.id)
		var had_downed=game.units.any(func(unit):return game.DeathDoor.downed(unit))
		game.begin_enemy_phase()
		if had_downed:refresh_pieces();highlight()
		if not checkpoint_action():return
		var losses=[]
		for unit in game.units:
			if unit.id in bleeding and not game.DeathDoor.downed(unit):losses.append({"target":unit.id,"remaining":0,"hit":true})
		skip_combat=false;await present_casualties(losses)
		if await check_result():busy=false;return
		update_side();await announce_phase("enemy")
	for e in game.living("enemy"):
		if e.acted:continue
		if game.result()!="":break
		var choice=tactics.plan(game,e)
		var candidates=game.units.filter(func(u):return u.id==choice.target)
		var chosen=candidates[0] if not candidates.is_empty() else null
		var initial_hp={e.id:e.hp}
		if chosen!=null:initial_hp[chosen.id]=chosen.hp
		var before=game.progress_snapshot()
		var path=game.movement_path(e,choice.position)
		await animate_map_move(e,path)
		var events=tactics.apply_plan(game,e,choice)
		if not checkpoint_action():return
		if choice.action=="tonic" and e.hp>initial_hp[e.id]:
			play_sfx("heal");await map_heal_feedback(e,e,int(e.hp-initial_hp[e.id]))
		highlight();await get_tree().create_timer(.12).timeout
		if chosen!=null and not events.is_empty():
			await cinematic(e,chosen,events,initial_hp)
			await show_progress(before)
		refresh_pieces()
		if game.result()!="":break
	if await check_result():busy=false;return
	game.next_player_turn();update_side();refresh_pieces();highlight()
	if not checkpoint_action():return
	if await check_result():busy=false;return
	var allies=game.living("player")
	if not allies.is_empty():await frame_map_action([allies[0]])
	await announce_phase("player");busy=false;update_side()
	persist_campaign("battle")

func make_fighter(u,position) -> Node3D:
	return fighters.build(stage,u,position)

func staff_healing(healer,recipient,amount: int,before: Dictionary={}):
	if not preferences.show_cinematic(healer.team):
		play_sfx("heal");await map_heal_feedback(healer,recipient,amount);return
	var old_max=before.get(healer.id,{}).get("max_hp",healer.max_hp)
	var old_hp=healer.hp-(healer.max_hp-old_max)
	var limits={healer.id:old_max,recipient.id:recipient.max_hp}
	await cinematic(healer,recipient,[{"actor":healer.id,"target":recipient.id,"healing":amount,"health_limits":limits}],{healer.id:old_hp,recipient.id:recipient.hp-amount})

func cinematic(a,b,events,initial_hp={}):
	if events.is_empty():return
	skip_combat=false
	map_navigation.stop()
	if not preferences.show_cinematic(a.team):
		await map_combat_feedback(events)
		await present_casualties(events)
		return
	for pair in [[a,b],[b,a]]:
		var visual=unit_nodes.get(pair[0].id)
		if visual!=null:
			visual.face_toward(game.pos(pair[1]),game.pos(pair[0]));map_facings[pair[0].id]=visual.player.facing
	skip_combat=false;music_mix(true)
	var tactical_view=map_navigation.capture_view()
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
	var close_map_view=map_navigation.capture_view()
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
	director.enter(actor.position,defender.position,ranged,mounted)
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
		var snapshot=events[0].get("exchange_forecast",{}).get(unit.id,{})
		var triangle=0 if events[0].has("healing") else snapshot.triangle if not snapshot.is_empty() else game.forecast(unit,opponent).triangle
		entries.append({"unit":unit,"hp":displayed_hp[unit.id],"portrait":portraits.get_unit_portrait(unit),"class_name":game.class_name_for(unit),"weapon":game.item_for(unit).name,"triangle":triangle,"forecast":snapshot,"health_max":events[0].get("health_limits",{}).get(unit.id,snapshot.get("max_hp",unit.max_hp))})
	var banner=CombatHUD.new();banner.configure(ui,entries);banner.reveal()
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
		var blocked=event.hit and event.damage<=0
		var contact_socket="guard" if blocked else "impact"
		if blocked:whom.pose("guard",.18)
		var base=who.position
		var direction=1.0 if who==actor else -1.0
		var is_ranged=unit.weapon in ["bow","magic"] or (unit.weapon=="lance" and game.distance(a,b)>1)
		if not is_ranged:
			var distance_to_close=absf(whom.position.x-who.position.x)-Fighters.Actor.melee_spacing(unit.weapon)
			if absf(distance_to_close)>.08:
				who.pose("advance",.2)
				var travel_duration=Fighters.Actor.approach_duration(distance_to_close)
				var approach=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
				approach.tween_property(who,"position:x",base.x+direction*distance_to_close,travel_duration)
				if who.has_method("update_locomotion"):
					approach.tween_method(func(_progress):who.update_locomotion(),0.0,1.0,travel_duration)
				while approach.is_running():
					if skip_combat:approach.kill();break
					await get_tree().process_frame
				if skip_combat:break
				if who.has_method("update_locomotion"):who.update_locomotion()
		if who.has_method("aim_at"):who.aim_at(whom.socket_position(contact_socket))
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
		var contact_point=whom.socket_position(contact_socket)
		if who.has_method("aim_at"):who.aim_at(contact_point)
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
			play_combat_contact(unit,event)
			if not blocked:whom.pose("critical_hit" if event.crit else "hit",.12)
		displayed_hp[event.target]=maxi(0,displayed_hp[event.target]-event.damage)
		banner.set_health(event.target,int(displayed_hp[event.target]))
		show_impact(whom.socket_position(contact_socket),event,spell,whom.global_position)
		if event.hit and event.damage>0:director.impact(event.crit,whom.position.x-who.position.x)
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
			var departure=preload("res://scripts/combat_defeat.gd").new();stage.add_child(departure);departure.begin(whom)
			var finish=preload("res://scripts/combat_finish.gd").new();stage.add_child(finish)
			var line=finish.quote_for(unit,fighters.profiles)
			caption.text=unit.name+(" — "+line if not line.is_empty() else "");caption.show()
			director.shot(who.position,whom.position,"finish",is_ranged,unit.job=="Rider",.28,unit.weapon)
			await finish.play(who,func():return skip_combat,.95 if not line.is_empty() else .60)
			departure.finish();departure.queue_free()
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
	banner.dismiss(.12);caption.hide()
	veil.show();await veil.conceal(.12,false).finished
	banner.queue_free();caption.queue_free()
	director.stop();director.queue_free()
	stage.visible=false
	refresh_pieces()
	restore_lighting(old_lighting)
	world.show();pieces.show();markers.show()
	var pull=map_navigation.return_from_combat(close_map_view,tactical_view,.25)
	veil.reveal(.25)
	await pull.finished
	if veil.motion.is_running():await veil.motion.finished
	veil.queue_free();playback.stop();playback.queue_free()
	for control in tactical_controls:
		if is_instance_valid(control):control.visible=tactical_controls[control]
	music_mix(false)
	await present_casualties(events)

func present_casualties(events: Array):
	if skip_combat:return
	var Card=preload("res://scripts/casualty_card.gd")
	var shown=[]
	for event in events:
		if not event.get("hit",false) or event.get("remaining",1)>0 or event.target in shown:continue
		var casualties=game.units.filter(func(unit):return unit.id==event.target and unit.team=="player" and unit.hp<=0)
		if casualties.is_empty():continue
		var unit=casualties[0];var quote=Card.quote_for(game,unit)
		if quote.is_empty():continue
		shown.append(unit.id)
		var card=Card.new();card.configure(ui,unit,portraits.get_portrait(unit.id),Card.mode_for(game,unit),quote)
		await card.play(func():return skip_combat)
		card.queue_free()
		if skip_combat:return

func lighting_state() -> Dictionary:
	var sky=environment.sky.sky_material
	var fog={}
	for field in FOG_FIELDS:fog[field]=environment.get(field)
	return {"energy":sunlight.light_energy,"color":sunlight.light_color,"ambient":environment.ambient_light_energy,"top":sky.sky_top_color,"horizon":sky.sky_horizon_color,"ground":sky.ground_horizon_color,"clouds":sky.sky_cover_modulate,"fog":fog}

func battle_lighting(theme: String,arena=true) -> Dictionary:
	var old=lighting_state()
	if not default_lighting.is_empty():restore_lighting(default_lighting)
	var sky=environment.sky.sky_material
	sky.sky_cover_modulate=CloudSky.tint(theme)
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
	sky.sky_top_color=old.top;sky.sky_horizon_color=old.horizon;sky.ground_horizon_color=old.ground;sky.sky_cover_modulate=old.clouds
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

func show_impact(point,event,spell="",ground=null):
	var impact=CombatImpact.new();stage.add_child(impact);impact.configure(point,event,camera,spell,ground)

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
			label_in(row,"%s · Lv %d\n%s"%[unit.name,unit.level,"Rescued after battle" if game.DeathDoor.downed(unit) else "Ready for the next march" if unit.hp>0 else "Fallen — permanently lost" if game.permadeath else "Recovering at camp"],16)
		button_in(frame,"Continue the chronicle",func():
			if not action_save_ready():return
			var onward=func():
				game.finish_chapter()
				persist_campaign("ending" if game.completed else "camp")
				if game.completed:show_ending()
				else:show_camp()
			show_dialogue(story.chapters[game.chapter].closing,onward,"closing"))
	else:
		label_in(v,"THE STANDARD FALLS",38,GOLD)
		label_in(v,"Lyra has fallen. This chapter is lost." if (game.permadeath or game.trials.flags.reset_pressure) and game.units.any(func(u):return u.id=="lyra" and u.hp<=0) else "Your company is scattered.",24)
		label_in(v,"Retry from the beginning of this section. Deaths, legacy supplies and reset pressure remain." if game.trials.flags.section_restarts and game.permadeath else "Retry from preparation. Committed deaths remain lost." if (game.action_saves or game.trials.flags.death_legacies) and game.permadeath else "Retry from chapter preparation. Losses and gains from this failed attempt are discarded; earlier permanent losses remain." if game.permadeath else "Regroup at the war council and choose a new approach.",20)
		var retreat=label_in(v,restart_summary(),18,GOLD);retreat.name="RestartPreview"
		button_in(frame,"Regroup and retry",func():
			if not action_save_ready():return
			if game.retry_battle():persist_campaign("camp");show_camp())
	if save_failed:
		label_in(v,"Autosave failed. Retry saving, or copy a transfer code to keep this position.",18,GOLD)
		button_in(frame,"Retry autosave",func():
			if persist_campaign("battle"):check_result())
	button_in(frame,"Transfer code",func():show_save_transfer("result"))
	return true

func show_ending():
	if game.completed:
		var trial_scene=game.trials.next_scene(game)
		if not trial_scene.is_empty():
			persist_campaign("ending");show_dialogue(trial_scene,show_ending,"closing");return
	screen="ending";reset_ui()
	var v=menu_panel()
	label_in(v,"DAWN WITHOUT KINGS",40,GOLD)
	label_in(v,game.content.chapters[-1].outro,22)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for u in game.roster:
		label_in(list,u.name+" · "+game.class_name_for(u)+" · Level "+str(int(u.level)),19,Color(u.color))
		label_in(list,"Fell in chapter %02d — %s. The company carries their memory."%[int(u.fallen_chapter)+1,game.content.chapters[int(u.fallen_chapter)].title] if u.get("fallen",false) else profiles.get(u.id,{}).get("ending",u.bio),17)
	if not game.trials.read_scenes.is_empty() or not game.trials.events.is_empty():button_in(v,"Company memories",show_campaign_trials)
	button_in(v,"Return to title",show_title)

func show_dialogue(lines: Array,on_complete: Callable,kind="opening"):
	screen="dialogue";reset_ui()
	var backdrop=preload("res://scripts/dialogue_backdrop.gd").new()
	backdrop.begin(ui,[world,pieces,markers],game.chapter,kind)
	var losses=game.lost_ids(kind=="closing")
	dialogue_lines=lines if kind=="support" else lines.filter(func(line):return line.speaker not in losses)
	dialogue_index=0;dialogue_callback=on_complete
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
	var condition=game.trials.deployment_condition(game,unit)
	if condition.recovering:label_in(info,"RECOVERY · Next deployment starts at %d/%d HP with %d tonic. Healing can restore full health."%[condition.hp,unit.max_hp,condition.tonics],19,GOLD)
	label_in(info,profile.get("biography",unit.bio),22)
	label_in(info,"PERSONAL NOTE",16,GOLD);label_in(info,profile.get("note",""),20)
	if unit.get("fallen",false):label_in(info,"IN MEMORIAM · Fell in chapter %02d — %s"%[int(unit.fallen_chapter)+1,game.content.chapters[int(unit.fallen_chapter)].title],22,GOLD)
	var records=HBoxContainer.new();records.add_theme_constant_override("separation",12);panel.add_child(records)
	button_in(records,"Equipment · "+game.item_for(unit).name,func():show_equipment(unit),unit.get("fallen",false)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(records,"Support conversations"+(" · Ready" if supports_ready(unit) else ""),func():show_supports(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);panel.add_child(actions)
	button_in(actions,"View character",func():show_model_view(unit)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(actions,"Advanced training",func():show_promotions(unit),unit.get("fallen",false)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(panel,"Return to war council",show_camp)

func load_campaign():
	var saved=game.load_game(campaign_save_path())
	if saved=="":show_notice("No readable campaign save was found on this device.");return
	if not music.playing:music.play()
	if saved=="ending":show_ending()
	elif saved=="battle":await resume_saved_battle()
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
		var locked=int(item.unlock)>game.chapter and item.id not in game.trials.purchases;var equipped=unit.item==item.id
		button_in(details,"Available in chapter %d"%(int(item.unlock)+1) if locked else ("Equipped" if equipped else "Equip"),func():
			if game.equip(unit,item.id):show_equipment(unit);persist_campaign("camp")
		,locked or equipped)
	button_in(panel,"Return to company record",func():show_dossier(unit))
	button_in(panel,"Return to war council",show_camp)

func show_model_view(unit,on_close=Callable(),model_spec: Dictionary={}):
	screen="model";preview_unit=unit;preview_return=on_close;reset_ui()
	for child in stage.get_children():stage.remove_child(child);child.queue_free()
	world.hide();pieces.hide();markers.hide();stage.show()
	var theme=game.info().get("environment","village");battle_lighting(theme)
	scenery.battle_landscape(stage,Vector3(35,0,0),{"environment":theme})
	var actor_data=unit.duplicate(true);actor_data.team="player"
	if model_spec.is_empty():preview_actor=make_fighter(actor_data,Vector3(35,0,0))
	else:
		var library=preload("res://scripts/combat_models.gd").new("")
		library.catalog={"characters":{unit.id:model_spec}}
		preview_actor=library.build(stage,actor_data,Vector3(35,0,0))
		if preview_actor==null:
			close_model_view();show_notice("The model study could not load.");return
	preview_actor.rotation.y=PI-.35
	var panel=menu_panel(310,true)
	label_in(panel,"DEBUG / MODEL STUDY" if not model_spec.is_empty() else "TRAINING / OUTFIT PREVIEW" if preview_return.is_valid() else "COMPANY / PREVIEW",15,GOLD);label_in(panel,unit.name,38)
	var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(unit.id)
	var size_portrait=func():portrait.custom_minimum_size=Vector2(220,150 if ui.size.y<760 else 220)
	ui.resized.connect(size_portrait);size_portrait.call()
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;panel.add_child(portrait)
	if not model_spec.is_empty():
		portrait.hide()
		label_in(panel,"Quaternius source rig with Poem sword. Pose and grip study; campaign characters are unchanged.",17)
	if model_spec.has("supported_items") and model_spec.has("study_id"):
		var equipment_choice=OptionButton.new();equipment_choice.name="StudyEquipment";equipment_choice.custom_minimum_size.y=42
		for item_id in model_spec.supported_items:
			var item=game.equipment.filter(func(value):return value.id==item_id)[0]
			equipment_choice.add_item(item.name);equipment_choice.set_item_metadata(equipment_choice.item_count-1,item.id)
			if unit.item==item.id:equipment_choice.select(equipment_choice.item_count-1)
		panel.add_child(equipment_choice)
		equipment_choice.item_selected.connect(func(index):
			var facing=preview_actor.rotation.y
			show_source_model_view(model_spec.study_id,equipment_choice.get_item_metadata(index))
			preview_actor.rotation.y=facing)
	else:label_in(panel,game.class_name_for(unit)+" · "+game.item_for(unit).name,21)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(spacer)
	var turns: Control=panel
	if not model_spec.is_empty():
		turns=HBoxContainer.new();panel.add_child(turns)
	button_in(turns,"Turn left",func():preview_actor.rotation.y-=PI/6).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(turns,"Turn right",func():preview_actor.rotation.y+=PI/6).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label_in(panel,"Preview action",15,GOLD)
	var actions=[["Ready","idle"],["Attack preparation","windup"],["Critical preparation","critical_windup"],["Attack","strike"],["Recovery","recover"]]
	if unit.weapon=="staff":actions=[["Ready","idle"],["Healing preparation","cast_windup"],["Heal","cast"]]
	actions.insert(1,["Run / trot","advance"])
	actions.append_array([["Guard","guard"],["Hit reaction","hit"],["Critical reaction","critical_hit"],["Defeated","down"],["Finishing flourish","victory_flourish"],["Finish","victory"]])
	if not model_spec.is_empty():
		actions=actions.filter(func(entry):return model_spec.poses.has(entry[1]))
		actions.append(["Evasion","evade"])
	var choice=OptionButton.new();choice.name="PreviewAction";choice.custom_minimum_size.y=42
	for entry in actions:
		choice.add_item(entry[0]);choice.set_item_metadata(choice.item_count-1,entry[1])
	panel.add_child(choice)
	var action_player=preload("res://scripts/preview_action.gd").new();action_player.name="PreviewActionPlayer";stage.add_child(action_player);action_player.configure(preview_actor)
	choice.item_selected.connect(func(index):action_player.play(str(choice.get_item_metadata(index))))
	if not model_spec.is_empty() and preview_actor.contact!=null:
		var contact_target=preload("res://scripts/model_contact_target.gd").new();preview_actor.add_child(contact_target);contact_target.configure(preview_actor)
		var target_choice=OptionButton.new();target_choice.name="StudyTarget";target_choice.custom_minimum_size.y=42
		for label in ["Target: none","Target: standing foe","Target: mounted foe"]:target_choice.add_item(label)
		panel.add_child(target_choice)
		target_choice.item_selected.connect(func(index):
			contact_target.choose(index)
			for at in range(choice.item_count):
				if choice.get_item_metadata(at)=="strike":choice.select(at);break
			action_player.play("strike"))
	button_in(panel,"Play again",func():action_player.play(str(choice.get_item_metadata(choice.selected))))
	button_in(panel,"Return to debug tools [Esc]" if not model_spec.is_empty() else "Return to training [Esc]" if preview_return.is_valid() else "Return to record [Esc]",close_model_view)
	var framing=preload("res://scripts/preview_camera.gd").new();framing.name="PreviewCamera";stage.add_child(framing)
	framing.configure(preview_actor,camera,panel.get_parent(),actions.map(func(entry):return entry[1]))
	framing.add_hint(ui)

func show_source_model_view(gender: String,item="iron_sword"):
	if not debug_session.active or gender not in ["female","male"]:return
	var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
	if item not in studies[gender].supported_items:return
	var unit=game.roster.filter(func(value):return value.id==("nell" if gender=="female" else "silas"))[0].duplicate(true)
	unit.name="Duelist · "+gender.capitalize();unit.item=item;unit.promotion=""
	var return_to=options_return
	show_model_view(unit,func():show_debug_tools(return_to),studies[gender])

func close_model_view():
	var return_action=preview_return;preview_return=Callable()
	make_map()
	if return_action.is_valid():return_action.call()
	else:show_dossier(preview_unit)

func show_progress(before: Dictionary):
	for change in game.progress_since(before):
		reward_skip=false
		reward_panel=ProgressReward.new()
		reward_panel.configure(ui,change,portraits.get_dialogue_portrait(change.unit.id),game.class_name_for(change.unit),game.MAX_LEVEL,profiles.get(change.unit.id,{}).get("growth_quote",""))
		reward_panel.begin(func():play_sfx("levelup"))
		var elapsed=0.0
		while elapsed<(3.0 if reward_panel.leveled else .8) and not reward_skip and not reward_panel.requested_close:
			await get_tree().process_frame;elapsed+=get_process_delta_time()
		reward_panel.queue_free();reward_panel=null

func show_save_transfer(return_screen: String):
	if return_screen=="result" and (busy or screen!="result"):return
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
	transfer_text.text=game.export_code("battle" if return_screen=="result" else return_screen) if return_screen in ["camp","battle","result"] else game.export_saved_code(campaign_save_path())
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
	elif saved=="battle":await resume_saved_battle()
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
		var record=game.supports.progress(entry.id);var available=game.bond_available(entry)
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",24);list.add_child(row)
		var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(partner.id);portrait.custom_minimum_size=Vector2(250,300)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(portrait)
		var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",10);row.add_child(details)
		label_in(details,partner.name+" · Rank "+game.supports.RANKS[int(record.rank)],32,GOLD)
		label_in(details,"%d bond points"%record.points if available else "A fallen bond. Read conversations remain as memories." if unit.get("fallen",false) or partner.get("fallen",false) else "Partner joins in chapter %d"%(int(partner.join)+1),20)
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
	if index>rank or (index==rank and (not game.bond_available(entry) or not game.supports.can_read(entry.id,game.chapter))):return
	var completed=func():
		if index==int(game.supports.progress(entry.id).rank):
			game.supports.complete_scene(entry.id,game.chapter)
			var saved=persist_campaign("camp",false)
			show_supports(unit)
			show_notice("Bond strengthened. Campaign saved." if saved else "Bond strengthened. Save failed; keep the game open and try saving again.")
		else:show_supports(unit)
	show_dialogue(entry.scenes[index].lines,completed,"support")

func supports_ready(unit) -> bool:
	return unit.join<=game.chapter and not unit.get("fallen",false) and game.supports.for_unit(unit.id).any(func(entry):return game.bond_available(entry) and game.supports.can_read(entry.id,game.chapter))

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
	if busy or drop_mode or selected==null or selected.team!="player" or selected.acted or origin!=null:return
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
	label_in(panel,"Playback settings stay on this device. Permadeath is saved with the campaign.",19)
	var permanent=CheckButton.new();permanent.name="Permadeath";permanent.text="Permadeath";permanent.button_pressed=game.permadeath;panel.add_child(permanent)
	permanent.toggled.connect(func(value):game.permadeath=value)
	label_in(panel,"Turning this off keeps earlier losses. Use Debug tools to experiment with revival.",16)
	var debugging=CheckButton.new();debugging.name="DebugMode";debugging.text="Debug mode · temporary sandbox";debugging.button_pressed=debug_session.active;panel.add_child(debugging)
	debugging.toggled.connect(func(value):
		if value:debug_session.begin(game,options_return)
		else:
			options_return=debug_session.end(game)
			if options_return=="battle":make_map()
		show_options(options_return))
	label_in(panel,"Debug mode keeps a separate save. Turning it off restores your campaign to where you enabled it.",16)
	if debug_session.active:button_in(panel,"Open debug tools",func():show_debug_tools(options_return))
	for setting in [{"key":"action_saves","name":"Save every action","text":"Commit movement and combat before animation. No movement undo. With permadeath, deaths survive retries."},{"key":"death_door","name":"Death’s door & rescue","text":"Downed allies have two player turns for rescue or staff healing. Carrying pauses the countdown and costs 2 movement."}]:
		var toggle=CheckButton.new();toggle.name=setting.key;toggle.text=setting.name;toggle.button_pressed=game.get(setting.key);panel.add_child(toggle)
		toggle.toggled.connect(func(value):game.set(setting.key,value))
		label_in(panel,setting.text,16)
	for setting in [{"key":"section_restarts","name":"Restart the current section","text":"With permadeath: retries return to the start of the four-chapter section. Deaths and legacy supplies remain. Relief recruits arrive at section breaks."},{"key":"reset_pressure","name":"Enemies prepare after resets","text":"Retries and lord defeat increase enemy stats, spend held tonics and advance raiders. Applies with permadeath on or off."},{"key":"hard_campaign","name":"Harder enemy forces","text":"On the next deployment: enemies gain health, attack, speed and later defense. Bonuses grow each section."},{"key":"death_legacies","name":"Death events & legacy supplies","text":"With permadeath: each death commits a loss, grants one supply credit and may bring a volunteer ahead of schedule."},{"key":"sacrifice_cost","name":"Sacrifice costs & openings","text":"Returning allies start attempts through the next chapter 4 HP down, with one tonic. The first fall per recruit in a chapter gives survivors +2 attack through the next player turn."}]:
		var toggle=CheckButton.new();toggle.name=setting.key;toggle.text=setting.name;toggle.button_pressed=game.trials.flags[setting.key];panel.add_child(toggle)
		toggle.toggled.connect(func(value):game.trials.flags[setting.key]=value)
		label_in(panel,setting.text,16)
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
	if options_return in ["camp","battle"]:persist_campaign(options_return)
	if not saved:show_notice("Settings are active, but could not be saved on this device.")

func show_debug_tools(return_to: String):
	if not debug_session.active:return
	options_return=return_to;screen="debug_tools";reset_ui()
	var frame=menu_panel(840);var panel=scrolling_column(frame)
	label_in(panel,"DEBUG / TEMPORARY SANDBOX",17,GOLD)
	label_in(panel,"Experiment with the company",36,GOLD)
	label_in(panel,"Changes save only to the debug slot. Turn Debug mode off in Options to restore the original campaign.",19)
	label_in(panel,"Reproduce a run",23,GOLD)
	var seed_input=SpinBox.new();seed_input.name="DebugSeed";seed_input.min_value=0;seed_input.max_value=2147483647;seed_input.step=1;seed_input.value=debug_session.combat_seed;seed_input.custom_minimum_size.y=42;panel.add_child(seed_input)
	button_in(panel,"Apply seed to next rolls",func():
		if debug_session.set_combat_seed(game,seed_input.value):persist_campaign("battle" if options_return=="battle" else "camp");show_notice("Combat seed applied. Chapter loads and clean resets reuse it."))
	label_in(panel,"The same seed, rules and actions reproduce the same rolls. Clean resets reuse this seed; penalty retreats follow the campaign’s restart rules.",16)
	button_in(panel,"View experiment report",show_debug_report)
	label_in(panel,"CHARACTER MODEL STUDIES",17,GOLD)
	for gender in ["female","male"]:
		var study=button_in(panel,"View "+gender+" duelist rig",func():show_source_model_view(gender));study.name="ModelStudy_"+gender
	var chapters=OptionButton.new();chapters.name="DebugChapter";chapters.custom_minimum_size.y=42
	for index in range(game.content.chapters.size()):chapters.add_item("%02d · %s"%[index+1,game.content.chapters[index].title])
	chapters.selected=game.chapter;panel.add_child(chapters)
	button_in(panel,"Load chapter with fresh roster",func():
		debug_session.load_chapter(game,chapters.selected);make_map();show_battle();persist_campaign("battle"))
	button_in(panel,"Reset current battle",func():debug_session.reset_battle(game);make_map();show_battle();persist_campaign("battle"))
	label_in(panel,"Enemy reset preparation",23,GOLD)
	var pressure_input=SpinBox.new();pressure_input.name="DebugPressure";pressure_input.min_value=0;pressure_input.max_value=10;pressure_input.step=1;pressure_input.value=game.trials.pressure;pressure_input.custom_minimum_size.y=42;panel.add_child(pressure_input)
	label_in(panel,"Enable enemy preparation at the chosen pressure and rebuild this battle with the current seed. Other trial switches and recorded losses remain.",16)
	button_in(panel,"Test pressure and reset battle",func():
		if debug_session.test_pressure(game,pressure_input.value):make_map();show_battle();persist_campaign("battle"))
	label_in(panel,"Company training level",23,GOLD)
	var company_levels=game.available().map(func(unit):return int(unit.level))
	var suggested_level=maxi(game.chapter+1,company_levels.min() if not company_levels.is_empty() else 1)
	var level_input=SpinBox.new();level_input.name="DebugLevel";level_input.min_value=1;level_input.max_value=game.MAX_LEVEL;level_input.step=1;level_input.value=mini(game.MAX_LEVEL,suggested_level);level_input.custom_minimum_size.y=42;panel.add_child(level_input)
	label_in(panel,"Raise available recruits using normal level growth, then reset this battle. Higher levels, promotions and permanent losses remain. The original section checkpoint is unchanged.",16)
	button_in(panel,"Raise company and reset battle",func():
		if debug_session.train_company(game,level_input.value):make_map();show_battle();persist_campaign("battle"))
	label_in(panel,"Use a fresh-roster chapter load to try lower levels. Return to preparation to choose promotions at level 10.",16)
	button_in(panel,"Heal deployed allies",func():
		debug_session.heal(game);persist_campaign("battle" if options_return=="battle" else "camp");show_notice("Living allies restored to full health."))
	button_in(panel,"Revive company and reset battle",func():
		debug_session.revive(game);make_map();show_battle();persist_campaign("battle"))
	button_in(panel,"Test reset / section retreat",func():restart_campaign_attempt())
	var allies=OptionButton.new();allies.name="DebugCasualty";allies.custom_minimum_size.y=42
	for unit in game.living("player"):
		allies.add_item(unit.name);allies.set_item_metadata(allies.item_count-1,unit.id)
	panel.add_child(allies)
	label_in(panel,"Test a lethal hit on a standing ally. Downed, carried and already-fallen allies are excluded.",16)
	button_in(panel,"Test selected ally falling",func():
		if allies.selected<0 or not debug_session.fall_unit(game,allies.get_item_metadata(allies.selected)):return
		make_map();show_battle();persist_campaign("battle");check_result()
	,allies.item_count==0)
	var patients=OptionButton.new();patients.name="DebugPatient";patients.custom_minimum_size.y=42
	for unit in game.units:
		if game.DeathDoor.downed(unit) and unit.get("carried_by","").is_empty():
			patients.add_item("%s · %d phases left"%[unit.name,unit.bleed_turns]);patients.set_item_metadata(patients.item_count-1,unit.id)
	panel.add_child(patients)
	var countdown=SpinBox.new();countdown.name="DebugBleedTurns";countdown.min_value=1;countdown.max_value=2;countdown.step=1;countdown.value=1;countdown.custom_minimum_size.y=42;panel.add_child(countdown)
	label_in(panel,"Set a downed ally’s remaining player-phase endings. One tests the last rescue opportunity without advancing the turn. Carried allies are paused and excluded.",16)
	button_in(panel,"Set rescue countdown",func():
		if patients.selected<0 or not debug_session.set_bleed_turns(game,patients.get_item_metadata(patients.selected),countdown.value):return
		make_map();show_battle();persist_campaign("battle")
	,patients.item_count==0)
	button_in(panel,"Return to preparation",func():game.units.clear();game.phase="player";show_camp();persist_campaign("camp"))
	button_in(frame,"Return to Options",func():show_options(options_return))

func show_debug_report():
	if not debug_session.active:return
	screen="debug_report";reset_ui()
	var panel=menu_panel(1040)
	label_in(panel,"EXPERIMENT REPORT",18,GOLD);label_in(panel,"A reproducible battle record",36,GOLD)
	label_in(panel,"Copy the rules, seed, casualties and unit states for comparison. The included save code can restore this exact position in another debug session.",19)
	var report=TextEdit.new();report.name="DebugReport";report.editable=false;report.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	report.custom_minimum_size.y=160;report.size_flags_vertical=Control.SIZE_EXPAND_FILL;report.add_theme_font_size_override("font_size",14)
	var record=debug_session.report(game,"battle" if options_return=="battle" else "camp")
	report.text=JSON.stringify(record,"\t",false);panel.add_child(report)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);panel.add_child(actions)
	button_in(actions,"Copy report",func():DisplayServer.clipboard_set(report.text);show_notice("Experiment report copied."))
	button_in(actions,"Copy restore code",func():DisplayServer.clipboard_set(record.save_code);show_notice("Restore code copied. Paste it into Transfer a local save in another debug session."))
	button_in(actions,"Select all text",func():report.grab_focus();report.select_all())
	button_in(panel,"Return to debug tools",func():show_debug_tools(options_return))

func action_save_ready() -> bool:
	return not game.action_saves or not save_failed or persist_campaign("battle")

func checkpoint_action() -> bool:
	if not game.action_saves or persist_campaign("battle"):return true
	busy=false;drop_mode=false;selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()
	return false

func retry_action_save():
	if persist_campaign("battle"):await resume_saved_battle()

func resume_saved_battle():
	make_map();show_battle()
	if await check_result():return
	if game.phase=="enemy":await end_turn(true)

func restart_summary() -> String:
	var preview=game.trials.restart_preview(game);var modifiers=preview.enemies
	var text="Return to Chapter %02d"%(preview.chapter+1)
	if game.trials.flags.reset_pressure:text+=" · Pressure %d → %d"%[game.trials.pressure,preview.pressure]
	if game.trials.flags.reset_pressure or game.trials.flags.hard_campaign:
		text+="\nNext enemies: +%d HP · +%d attack · +%d speed · +%d defense"%[modifiers.max_hp,modifiers.pow,modifiers.speed,modifiers.defense]
	if game.trials.flags.reset_pressure:text+="\nHeld tonics: %d · Raiders %s"%[modifiers.held_tonics,"advance before deployment" if modifiers.raiders_advance else "stay at their starting positions"]
	return text

func restart_campaign_attempt():
	if not action_save_ready():return
	if game.trials.restart(game):persist_campaign("camp")
	show_camp()

func show_campaign_trials():
	screen="campaign_trials";reset_ui()
	var frame=menu_panel(880);var panel=scrolling_column(frame)
	label_in(panel,"COMPANY MEMORIES" if game.completed else "CAMPAIGN EXPERIMENTS",18,GOLD)
	label_in(panel,"Section %d · Pressure %d / 10"%[int(game.chapter/4)+1,game.trials.pressure],34,GOLD)
	label_in(panel,"Legacy supply credits: %d"%game.trials.credits,22)
	if not game.completed:
		var preparation=game.trials.enemy_modifiers(game.chapter)
		label_in(panel,"Next deployment · enemies gain %d HP, %d attack, %d speed and %d defense. Held tonics: %d. Raiders %s."%[preparation.max_hp,preparation.pow,preparation.speed,preparation.defense,preparation.held_tonics,"advance before the battle" if preparation.raiders_advance else "start at their usual positions"],19)
	if not game.completed and game.trials.flags.death_legacies and game.permadeath:
		for stock in game.trials.LEGACY_STOCK:
			var item=game.equipment.filter(func(entry):return entry.id==stock.id)[0]
			var bought=stock.id in game.trials.purchases
			button_in(panel,("Secured · " if bought else "Secure · ")+item.name+" · %d credit(s), %d loss(es)"%[stock.cost,stock.losses],func():
				if game.trials.buy(game,stock.id):persist_campaign("camp");show_campaign_trials()
			,bought or game.trials.credits<stock.cost or game.trials.losses.size()<stock.losses)
	label_in(panel,"Company dispatches",24,GOLD)
	if game.trials.events.is_empty():label_in(panel,"No experiment events yet. Change the rules in Options, or test them in Debug mode.",19)
	for event in game.trials.events:label_in(panel,event,19)
	if not game.trials.read_scenes.is_empty():label_in(panel,"Company memories",24,GOLD)
	for id in game.trials.read_scenes:
		button_in(panel,"Replay · "+game.trials.SCENE_TITLES.get(id,id.replace("_"," ").capitalize()),func():show_dialogue(game.trials.scenes[id],show_campaign_trials,"support"))
	button_in(frame,"Return to epilogue" if game.completed else "Return to war council",show_ending if game.completed else show_camp)

func show_triage(focus_patient: Dictionary={}):
	if selected==null or not game.can_act(selected):return
	screen="triage";reset_ui()
	var frame=menu_panel(720);var panel=scrolling_column(frame)
	label_in(panel,"RESCUE & TRIAGE",18,GOLD);label_in(panel,selected.name,36,GOLD)
	label_in(panel,"Carrying pauses bleeding and costs 2 movement. Healing revives the ally with their action spent. Rescue and drop each use your action.",20)
	if not focus_patient.is_empty():
		label_in(panel,"%s · %d player-phase ending(s) before loss"%[focus_patient.name,focus_patient.get("bleed_turns",0)],22,GOLD)
	for patient in game.units:
		if not focus_patient.is_empty() and patient.id!=focus_patient.id:continue
		if game.DeathDoor.can_rescue(game,selected,patient):button_in(panel,"Rescue "+patient.name,func():rescue_ally(patient))
		elif game.can_heal(selected,patient) and not patient.get("carried_by","").is_empty():button_in(panel,"Heal carried "+patient.name,func():heal_carried_ally(patient))
	var carried=game.DeathDoor.passenger(game,selected)
	if carried!=null:
		label_in(panel,"Carrying "+carried.name,22,GOLD)
		var blocked=game.DeathDoor.drop_positions(game,selected).is_empty()
		button_in(panel,"Choose drop tile",begin_drop,blocked)
		if blocked:label_in(panel,"No adjacent tile is free. Move to an open space before dropping your ally.",17)
	button_in(frame,"Return to battle",show_battle)

func begin_drop():
	if busy or selected==null or not game.can_act(selected) or game.DeathDoor.passenger(game,selected)==null:return
	var positions=game.DeathDoor.drop_positions(game,selected)
	if positions.is_empty():return
	drop_mode=true;target=null;cursor_visible=true;cursor_tile=positions[0];show_battle()

func cancel_drop():
	drop_mode=false;show_battle()

func rescue_ally(patient: Dictionary):
	if busy or selected==null or not action_save_ready():return
	var carrier=selected;var departure=patient.duplicate(true)
	if not game.DeathDoor.rescue(game,carrier,patient) or not checkpoint_action():return
	busy=true;skip_combat=false;show_battle()
	await map_rescue_feedback(carrier,patient,departure,true)
	busy=false;finish_action()

func drop_ally(tile: Vector2i):
	if busy or selected==null or not action_save_ready():return
	var carrier=selected;var patient=game.DeathDoor.passenger(game,carrier)
	if game.DeathDoor.drop(game,selected,tile):
		drop_mode=false
		if not checkpoint_action():return
		busy=true;skip_combat=false;show_battle();refresh_pieces()
		await map_rescue_feedback(carrier,patient,patient,false)
		busy=false;finish_action()

func map_rescue_feedback(carrier: Dictionary,patient: Dictionary,field_patient: Dictionary,picking_up: bool):
	var visual=unit_nodes.get(patient.id);var actor=unit_nodes.get(carrier.id)
	if visual==null:return
	var cue_text="RESCUED" if picking_up else "SET DOWN"
	var field_position=map_position(game.pos(field_patient));var carrier_position=map_position(game.pos(carrier))
	visual.position=field_position if picking_up else carrier_position
	visual.begin_rescue_transfer(1.0 if picking_up else 0.0)
	await frame_map_action([carrier,field_patient],map_cue_padding(cue_text))
	if actor!=null:
		actor.act_toward(game.pos(field_patient),game.pos(carrier));map_facings[carrier.id]=actor.player.facing
	var destination=carrier_position if picking_up else field_position
	var cue=Label.new();cue.name="RescueCue";cue.text=cue_text;cue.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cue.add_theme_font_size_override("font_size",28);cue.add_theme_color_override("font_color",GOLD);cue.add_theme_color_override("font_outline_color",Color("30353a"));cue.add_theme_constant_override("outline_size",5)
	ui.add_child(cue);cue.position=camera.unproject_position(destination+Vector3.UP*1.1)-Vector2(cue.get_minimum_size().x*.5,20)
	play_sfx("select")
	var motion=create_tween().set_parallel(true)
	motion.tween_property(visual,"position",destination,.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(visual.set_rescue_opacity,1.0 if picking_up else 0.0,0.0 if picking_up else 1.0,.28)
	motion.tween_property(cue,"position:y",cue.position.y-18,.36);motion.tween_property(cue,"modulate:a",0.0,.36).set_delay(.12)
	await combat_wait(motion)
	if is_instance_valid(cue):cue.queue_free()
	if actor!=null:actor.finish_move()

func heal_carried_ally(patient: Dictionary):
	if busy or selected==null or not action_save_ready():return
	var healer=selected;var before=game.progress_snapshot();var old_hp=patient.hp
	if not game.heal(healer,patient) or not checkpoint_action():return
	busy=true;show_battle();refresh_pieces();update_side()
	await staff_healing(healer,patient,int(patient.hp-old_hp),before);await show_progress(before)
	busy=false;finish_action()

func campaign_save_path() -> String:
	return save_path+".debug" if debug_session.active else save_path

func map_combat_feedback(events: Array):
	for event in events:
		var targets=game.units.filter(func(unit):return unit.id==event.target)
		if targets.is_empty():continue
		var unit=targets[0]
		var attackers=game.units.filter(func(other):return other.id==event.actor)
		var actor=unit_nodes.get(event.actor);var victim=unit_nodes.get(event.target)
		var cue_text="MISS" if not event.hit else "NO DAMAGE" if event.damage<=0 else ("CRIT " if event.crit else "")+str(int(event.damage))
		await frame_map_action([unit]+attackers,map_cue_padding(cue_text))
		var reaction: Tween
		if victim!=null and not attackers.is_empty():
			victim.face_toward(game.pos(attackers[0]),game.pos(unit));map_facings[event.target]=victim.player.facing
			if not event.hit:reaction=victim.evade_from(game.pos(attackers[0]),game.pos(unit))
		if actor!=null and not attackers.is_empty():
			actor.act_toward(game.pos(unit),game.pos(attackers[0]));map_facings[event.actor]=actor.player.facing
		await get_tree().create_timer(.12).timeout
		if victim!=null:
			victim.react(event.hit and event.damage>0,int(event.remaining));victim.hp_ratio=clampf(float(event.remaining)/maxf(1,unit.max_hp),0,1);victim.refresh_health()
			if event.hit and event.damage>0 and not attackers.is_empty():reaction=victim.recoil_from(game.pos(attackers[0]),game.pos(unit),event.crit)
			if event.hit and event.damage>0 and event.remaining<=0:victim.fade_defeat()
		var text_label=Label.new();ui.add_child(text_label)
		text_label.text=cue_text
		text_label.add_theme_font_size_override("font_size",28);text_label.add_theme_color_override("font_color",Color("ffe5a1"));text_label.add_theme_color_override("font_outline_color",Color("30353a"));text_label.add_theme_constant_override("outline_size",5)
		text_label.position=camera.unproject_position(map_position(game.pos(unit))+Vector3.UP*1.1)-Vector2(text_label.get_minimum_size().x*.5,20);text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if not event.hit:play_sfx("swing")
		else:play_combat_contact(attackers[0] if not attackers.is_empty() else {},event)
		var fade=create_tween().set_parallel(true);fade.tween_property(text_label,"position:y",text_label.position.y-24,.24);fade.tween_property(text_label,"modulate:a",0.0,.24)
		await fade.finished
		if reaction and reaction.is_valid() and reaction.is_running():await reaction.finished
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
	var saved=game.save_game(campaign_save_path(),stage_name)
	save_failed=not saved
	if screen=="battle" and is_instance_valid(status):
		status.text="TURN %d  /  %s"%[game.turn,game.phase.to_upper()]+(" · DEBUG" if debug_session.active else "")+("\nSAVE FAILED" if save_failed else "")
	if not saved and notify_failure and not save_warning_queued:
		save_warning_queued=true;call_deferred("show_save_warning")
	return saved

func show_save_warning():
	save_warning_queued=false
	if save_failed:show_notice("Autosave failed. Keep this game open. Try Save again, or use Transfer code to keep a copy of your current progress.",8.0)

func close_save_transfer():
	if transfer_return=="battle":show_battle()
	elif transfer_return=="result":check_result()
	elif transfer_return=="camp":show_camp()
	else:show_title()
