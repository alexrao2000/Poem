extends Node3D
const Rules = preload("res://scripts/rules.gd")
const Portraits = preload("res://scripts/portraits.gd")
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
var dialogue_reveal=0.0
const Fighters = preload("res://scripts/fighters.gd")
var fighters: RefCounted
const Scenery = preload("res://scripts/scenery.gd")
var scenery: RefCounted
const CLASSES = ["Vanguard","Knight","Ranger","Arcanist","Warden","Rider","Corsair","Duelist"]
var game = Rules.new()
var tactics=preload("res://scripts/tactics.gd").new()
var camera: Camera3D
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
var muted = false
var sprites: Array = []
var clock = 0.0
var skip_combat = false
const GOLD = Color("8d6a32")
const INK = Color("e8e0cb")
const SAVE = "user://campaign.json"

func _ready():
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
	setup_audio()
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
		dialogue_reveal+=dt*55
		dialogue_label.visible_characters=int(dialogue_reveal)
	for s in sprites:
		if is_instance_valid(s):s.position.y=s.get_meta("base_y",.65)+sin(clock*3+s.position.x)*.015

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
	sprites.clear()

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

func make_map():
	clear_world()
	map_camera()
	battle_lighting(game.info().get("environment","village"))
	scenery.landscape(world,game)
	refresh_pieces()

func refresh_pieces():
	for n in pieces.get_children():n.queue_free()
	sprites.clear()
	for u in game.units:
		if u.hp<=0:continue
		var s=Sprite3D.new();s.texture=unit_portrait(u)
		var height=1.2 if u.job in ["Knight","Rider"] else 1.08
		s.pixel_size=height/s.texture.get_height()
		s.billboard=BaseMaterial3D.BILLBOARD_ENABLED;s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;s.alpha_scissor_threshold=.35
		s.no_depth_test=true;s.render_priority=2
		s.position=Vector3(u.x,height*.5+.07,u.y);s.set_meta("base_y",height*.5+.07)
		s.modulate=(Color(.65,.65,.65) if u.acted else Color.WHITE) if u.team=="player" else Color(1,.66,.62)
		pieces.add_child(s);sprites.append(s)
		scenery.cylinder(pieces,Vector3(u.x,.035,u.y),.035,.31,Color("496f9c") if u.team=="player" else Color("a54b45"))
		# Compact green health bars preserve map readability at normal zoom.
		var health=Sprite3D.new();var image=Image.create(48,5,false,Image.FORMAT_RGBA8)
		image.fill(Color("343b30"));image.fill_rect(Rect2i(1,1,maxi(1,int(46.0*u.hp/u.max_hp)),3),Color("8bc96c") if u.team=="player" else Color("d48c70"))
		health.texture=ImageTexture.create_from_image(image);health.pixel_size=.013;health.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		health.position=Vector3(u.x,.16,u.y+.12);health.no_depth_test=true;health.render_priority=3;pieces.add_child(health)

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
	label_in(v,"ASHEN\nSTANDARD",64)
	label_in(v,"A broken banner. A borrowed sun.\nTwenty-four lives caught between them.",22)
	label_in(v,"12 chapters · 24 recruits · 8 classes\nSprite battlefields / cinematic 3D combat",17,Color("766e5e"))
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(spacer)
	button_in(v,"Begin the chronicle",func():game.new_campaign();music.play();show_camp())
	button_in(v,"Continue saved campaign",load_campaign,not FileAccess.file_exists(SAVE))
	label_in(v,"Original playable prototype • Casual recovery\nFallen allies return next chapter. Losing everyone means retry.",14,Color("827b6c"))

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
	label_in(left,"ASHEN STANDARD / WAR COUNCIL",16,GOLD)
	label_in(left,"%02d  %s"%[game.chapter+1,game.info().title],34)
	label_in(left,game.info().place.to_upper(),17,Color("79755f"))
	label_in(left,game.info().intro,21)
	label_in(left,game.info().get("tactical_brief",""),18,Color("6f6c5e"))
	label_in(left,"OBJECTIVE  /  "+objective_text(),18,GOLD)
	label_in(left,"Recruited %d / 24  ·  Deployed %d / 6"%[game.available().size(),game.deployed.size()],18)
	label_in(left,"Select up to six allies. Healing tiles restore 6 HP each turn. Wardens heal adjacent allies; everyone carries two field tonics.",16,Color("766e5e"))
	var sp=Control.new();sp.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(sp)
	button_in(left,"Deploy company  >",func():game.start_battle();make_map();show_battle();game.save_game(SAVE,"battle"),game.deployed.is_empty())
	button_in(left,"Save campaign",func():game.save_game(SAVE,"camp"))
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
		label_in(texts,u.name+"  /  "+u.job+"  ·  Lv "+str(int(u.level)),19,GOLD if unlocked else Color("9a9588"))
		label_in(texts,u.bio if unlocked else "Joins in chapter "+str(int(u.join)+1),14)
		label_in(texts,"HP %d   ATK %d   DEF %d   SPD %d   MOV %d"%[u.max_hp,u.pow,u.defense,u.speed,u.move],13,Color("81775f"))
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
	var bottom=PanelContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=22;bottom.offset_right=-343;bottom.offset_top=-78;bottom.offset_bottom=-22;ui.add_child(bottom)
	label_in(bottom,"Select ally > move > select foe > confirm attack.\nRight-click / Esc: undo uncommitted move.  Space: end turn.  Tab: skip combat.",15)
	update_side()

func update_side():
	for n in side.get_children():side.remove_child(n);n.queue_free()
	status.text="TURN %d  /  %s"%[game.turn,game.phase.to_upper()]
	if selected!=null:
		var identity=HBoxContainer.new();identity.add_theme_constant_override("separation",8);side.add_child(identity)
		var portrait=TextureRect.new();portrait.texture=portraits.get_portrait(selected.id);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.custom_minimum_size=Vector2(90,100);identity.add_child(portrait)
		var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;identity.add_child(details)
		label_in(details,selected.name,27,GOLD)
		label_in(details,selected.job,16)
		label_in(details,"Lv %d  /  XP %d"%[selected.level,selected.xp],15)
		label_in(side,"HP %d / %d\nATK %d   DEF %d   SPD %d\n%s · range %d"%[selected.hp,selected.max_hp,selected.pow,selected.defense,selected.speed,selected.weapon.to_upper(),selected.reach],18)
		if target!=null:
			var f=game.forecast(selected,target)
			label_in(side,"VS  "+target.name,21,GOLD)
			label_in(side,"%d damage%s\n%d%% hit  ·  %d%% critical"%[f.damage," x 2" if f.double else "",f.hit,f.crit],23)
			label_in(side,"Counterattack: "+str(game.forecast(target,selected).damage if f.counter else 0),16)
			button_in(side,"Confirm attack",func():player_attack(),busy)
		if selected.team=="player" and not selected.acted:
			button_in(side,"Wait / secure position",wait_action,busy)
			button_in(side,"Field tonic (+12 HP)  ·  "+str(int(selected.potions)),tonic,busy or selected.potions<=0 or selected.hp>=selected.max_hp)
			if selected.weapon=="staff":label_in(side,"Click an adjacent ally to heal 12 HP.",16,GOLD)
	else:
		label_in(side,"THE COMPANY",15,GOLD)
		label_in(side,"%d allies  ·  %d enemies"%[game.living("player").size(),game.living("enemy").size()],18)
		label_in(side,"Choose your next move.",25)
		label_in(side,"Forest and hills cost 2 movement and grant cover. Cross water at bridges. Golden tiles mark objectives; pale crosses restore health.",17,Color("6f6c5e"))
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;side.add_child(spacer)
	button_in(side,"End player phase",end_turn,busy)
	button_in(side,"Save battle",func():cancel_selection();game.save_game(SAVE,"battle"),busy)
	button_in(side,"Music: "+("off" if muted else "on"),func():muted=not muted;music.volume_db=-80 if muted else -12;update_side())
	button_in(side,"War council (restart map)",show_camp,busy)

func highlight():
	for n in markers.get_children():n.queue_free()
	if selected==null or selected.team!="player" or selected.acted:return
	var range_map=game.reachable(selected) if origin==null else {game.pos(selected):0}
	for p in range_map:
		cube(markers,Vector3(p.x,.015,p.y),Vector3(.84,.025,.84),Color(0.16,0.46,0.85,0.48))
	for e in game.living("enemy"):
		if game.can_attack(selected,e):cube(markers,Vector3(e.x,.018,e.y),Vector3(.9,.03,.9),Color(0.85,0.22,0.12,0.55))

func _input(event):
	if screen=="battle" and busy and event is InputEventKey and event.pressed and event.keycode==KEY_TAB:
		skip_combat=true
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
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
	if screen!="battle" or busy or game.phase!="player":return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:cancel_selection();return
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		for unit in game.units:
			if unit.hp>0 and camera.unproject_position(Vector3(unit.x,.65,unit.y)).distance_to(event.position)<25:
				click_tile(game.pos(unit));return
		var start=camera.project_ray_origin(event.position)
		var dir=camera.project_ray_normal(event.position)
		var hit=Plane(Vector3.UP,0).intersects_ray(start,dir)
		if hit!=null:click_tile(Vector2i(roundi(hit.x),roundi(hit.z)))

func cancel_selection():
	if selected!=null and origin!=null and not selected.acted:
		game.undo_move(selected)
	selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()

func click_tile(p: Vector2i):
	var u=game.at(p)
	if selected!=null and not selected.acted and u!=null:
		if game.can_attack(selected,u):target=u;update_side();return
		if selected.weapon=="staff" and u.team=="player" and u!=selected and game.distance(selected,u)==1 and u.hp<u.max_hp:
			if game.heal(selected,u):play_sfx("heal");finish_action();return
	if u!=null and u.team=="player":
		cancel_selection();selected=u;play_sfx("select");highlight();update_side();return
	if selected!=null and not selected.acted and origin==null and u==null and game.reachable(selected).has(p):
		origin=game.pos(selected)
		if game.move_unit(selected,p):target=null;refresh_pieces();highlight();update_side()
		else:origin=null

func wait_action():
	if busy or selected==null:return
	if game.wait_unit(selected):finish_action()

func tonic():
	if busy or selected==null:return
	if game.use_tonic(selected):play_sfx("heal");finish_action()

func player_attack():
	if busy or selected==null or target==null:return
	busy=true
	update_side()
	var a=selected;var b=target
	var initial_hp={a.id:a.hp,b.id:b.hp}
	var events=game.combat(a,b)
	await cinematic(a,b,events,initial_hp)
	busy=false;finish_action()

func finish_action():
	selected=null;target=null;origin=null;refresh_pieces();highlight();update_side()
	if await check_result():return
	game.save_game(SAVE,"battle")
	if game.living("player").all(func(u):return u.acted):end_turn()

func end_turn():
	if busy or screen!="battle":return
	cancel_selection();busy=true;game.begin_enemy_phase();play_sfx("phase");update_side()
	for e in game.living("enemy"):
		if game.living("player").is_empty():break
		var choice=tactics.plan(game,e)
		var candidates=game.units.filter(func(u):return u.id==choice.target)
		var chosen=candidates[0] if not candidates.is_empty() else null
		var initial_hp={e.id:e.hp}
		if chosen!=null:initial_hp[chosen.id]=chosen.hp
		var events=tactics.apply_plan(game,e,choice)
		refresh_pieces();await get_tree().create_timer(.18).timeout
		if chosen!=null and not events.is_empty():await cinematic(e,chosen,events,initial_hp)
		refresh_pieces()
		if game.result()!="":break
	game.next_player_turn();play_sfx("phase");busy=false;update_side();refresh_pieces()
	if await check_result():return
	game.save_game(SAVE,"battle")

func make_fighter(u,position) -> Node3D:
	return fighters.build(stage,u,position)

func cinematic(a,b,events,initial_hp={}):
	if events.is_empty():return
	skip_combat=false;music_mix(true)
	var old_pos=camera.position;var old_rot=camera.rotation
	var focus=Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5)
	markers.hide()
	var push=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	push.tween_property(camera,"size",6.0,.32)
	push.tween_property(camera,"h_offset",0.0,.32)
	push.tween_property(camera,"position",old_pos+focus-Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5),.32)
	await push.finished
	var tactical_controls=ui.get_children()
	for control in tactical_controls:control.hide()
	var veil=ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color=Color("101b29");veil.modulate.a=0;veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(veil)
	var close=create_tween();close.tween_property(veil,"modulate:a",1.0,.12);await close.finished
	for n in stage.get_children():n.queue_free()
	stage.visible=true
	var old_lighting=battle_lighting(game.info().get("environment","village"))
	scenery.battle_landscape(stage,Vector3(35,0,0),{"chapter":game.chapter,"terrain":game.terrain(game.pos(b)),"environment":game.info().get("environment","village")})
	world.hide();pieces.hide()
	var ranged=a.weapon in ["bow","magic"] or b.weapon in ["bow","magic"]
	var spacing=2.0 if ranged else 1.6
	var actor=make_fighter(a,Vector3(35-spacing,0,0));var defender=make_fighter(b,Vector3(35+spacing,0,0))
	actor.rotation.y=-PI/2;defender.rotation.y=PI/2
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0;camera.fov=48
	camera.position=Vector3(36.6,2.0,6.8 if ranged else 5.8);camera.look_at(Vector3(35,1.1,0))
	var reveal=create_tween();reveal.tween_property(veil,"modulate:a",0.0,.18);await reveal.finished
	veil.queue_free()
	var banner=PanelContainer.new();banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	banner.name="CombatHUD"
	banner.offset_left=70;banner.offset_right=-70;banner.offset_top=-140;banner.offset_bottom=-30;ui.add_child(banner)
	var battle_ui=HBoxContainer.new();battle_ui.add_theme_constant_override("separation",45);banner.add_child(battle_ui)
	var health_labels={};var health_bars={};var displayed_hp={};var hp_numbers={}
	for unit in [a,b]:
		var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;battle_ui.add_child(column)
		var hp=int(initial_hp.get(unit.id,unit.hp))
		if initial_hp.is_empty():
			for strike_event in events:
				if strike_event.target==unit.id:hp+=strike_event.damage
		displayed_hp[unit.id]=mini(hp,unit.max_hp)
		var heading=HBoxContainer.new();column.add_child(heading)
		health_labels[unit.id]=label_in(heading,unit.name+"  /  "+unit.job,23,GOLD)
		health_labels[unit.id].size_flags_horizontal=Control.SIZE_EXPAND_FILL
		health_labels[unit.id].autowrap_mode=TextServer.AUTOWRAP_OFF
		health_labels[unit.id].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		hp_numbers[unit.id]=label_in(heading,str(int(displayed_hp[unit.id]))+" / "+str(int(unit.max_hp)),23)
		hp_numbers[unit.id].autowrap_mode=TextServer.AUTOWRAP_OFF
		hp_numbers[unit.id].custom_minimum_size.x=100
		hp_numbers[unit.id].horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var bar=ProgressBar.new();bar.max_value=unit.max_hp;bar.value=displayed_hp[unit.id];bar.show_percentage=false;bar.custom_minimum_size.y=16
		var fill=StyleBoxFlat.new();fill.bg_color=Color("718e56") if unit.team=="player" else Color("b35e51")
		var backing=StyleBoxFlat.new();backing.bg_color=Color("c7c1ad")
		bar.add_theme_stylebox_override("fill",fill);bar.add_theme_stylebox_override("background",backing);column.add_child(bar);health_bars[unit.id]=bar
	var caption=Label.new();caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);caption.offset_top=36;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",30);caption.add_theme_color_override("font_color",Color("f7edce"));caption.add_theme_color_override("font_outline_color",Color("373d42"));caption.add_theme_constant_override("outline_size",7)
	caption.text="Tab to skip";ui.add_child(caption)

	await get_tree().create_timer(.3).timeout
	for event in events:
		if skip_combat:break
		var who=actor if event.actor==a.id else defender
		var whom=defender if who==actor else actor
		var unit=a if who==actor else b
		var base=who.position
		var direction=1.0 if who==actor else -1.0
		var is_ranged=unit.weapon in ["bow","magic"]
		caption.text=unit.name+"  /  "+("Critical strike" if event.crit else unit.weapon.capitalize())
		if not is_ranged:
			who.pose_name="advance"
			var approach=create_tween().set_trans(Tween.TRANS_SINE)
			var distance_to_close=absf(whom.position.x-who.position.x)-1.65
			approach.tween_property(who,"position:x",base.x+direction*maxf(0,distance_to_close),.24)
			await approach.finished
		await who.pose("windup",.28 if not event.crit else .4).finished
		if skip_combat:break
		play_sfx("magic" if unit.weapon=="magic" else "swing")
		await who.pose("strike",.12).finished
		if is_ranged:
			await projectile(who.position+Vector3(0,1.2,0),whom.position+Vector3(0,1.1,0),unit.weapon)
		if event.hit:
			play_sfx("critical" if event.crit else "hit")
			whom.pose("hit",.12)
		else:
			whom.pose("evade",.16)
			var dodge=create_tween();dodge.tween_property(whom,"position:z",-.32,.14);dodge.tween_property(whom,"position:z",0.0,.2)
		displayed_hp[event.target]=maxi(0,displayed_hp[event.target]-event.damage)
		hp_numbers[event.target].text=str(int(displayed_hp[event.target]))+" / "+str(int(b.max_hp if event.target==b.id else a.max_hp))
		var hp_tween=create_tween();hp_tween.tween_property(health_bars[event.target],"value",float(displayed_hp[event.target]),.25)
		show_impact(whom.position+Vector3(0,1.1,0),event)
		caption.text=unit.name+(" — CRITICAL! " if event.crit else " — ")+(str(int(event.damage))+" damage" if event.hit else "Miss")
		if event.hit:
			var camera_home=camera.position
			var shake=create_tween();shake.tween_property(camera,"position",camera_home+Vector3(.10 if event.crit else .045,.025,0),.04);shake.tween_property(camera,"position",camera_home,.1)
		await get_tree().create_timer(.22 if not event.crit else .34).timeout
		who.pose("idle",.25)
		var retreat=create_tween().set_trans(Tween.TRANS_SINE);retreat.tween_property(who,"position",base,.3)
		if event.remaining<=0:
			await whom.pose("down",.3).finished
		else:
			await whom.pose("idle",.25).finished
		if retreat.is_running():await retreat.finished
	await get_tree().create_timer(.18).timeout

	banner.queue_free();caption.queue_free()
	stage.visible=false
	restore_lighting(old_lighting)
	world.show();pieces.show();markers.show()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position=old_pos;camera.rotation=old_rot;camera.h_offset=2.0
	var pull=create_tween();pull.tween_property(camera,"size",16.0,.25);await pull.finished
	for control in tactical_controls:
		if is_instance_valid(control):control.show()
	music_mix(false)

func lighting_state() -> Dictionary:
	var sky=environment.sky.sky_material
	return {"energy":sunlight.light_energy,"color":sunlight.light_color,"ambient":environment.ambient_light_energy,"top":sky.sky_top_color,"horizon":sky.sky_horizon_color,"ground":sky.ground_horizon_color}

func battle_lighting(theme: String) -> Dictionary:
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
	return old

func restore_lighting(old: Dictionary):
	var sky=environment.sky.sky_material
	sunlight.light_energy=old.energy;sunlight.light_color=old.color;environment.ambient_light_energy=old.ambient
	sky.sky_top_color=old.top;sky.sky_horizon_color=old.horizon;sky.ground_horizon_color=old.ground

func projectile(from: Vector3,to: Vector3,kind: String):
	var visual=Node3D.new();stage.add_child(visual);visual.position=from
	if kind=="bow":
		var shaft=cube(visual,Vector3.ZERO,Vector3(.5,.018,.018),Color("695344"))
		cube(shaft,Vector3(.5,0,0),Vector3(.12,3,3),Color("d2d8dc"))
		if to.x<from.x:visual.rotation.y=PI
	else:
		var orb=sphere(visual,Vector3.ZERO,.15,Color("8ddae9"))
		orb.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var ring=TorusMesh.new();ring.inner_radius=.2;ring.outer_radius=.225
		var n=MeshInstance3D.new();n.mesh=ring;n.rotation.z=PI/2;n.material_override=orb.material_override;visual.add_child(n)
	var travel=create_tween().set_trans(Tween.TRANS_LINEAR);travel.tween_property(visual,"position",to,.23)
	await travel.finished
	visual.queue_free()

func show_impact(point,event):
	var root=Node3D.new();stage.add_child(root);root.position=point
	var amount=Label3D.new();amount.text=str(int(event.damage)) if event.hit else "MISS"
	amount.font_size=100 if event.crit else 76;amount.pixel_size=.006;amount.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	amount.modulate=Color("ffe2a0") if event.crit else Color("fff8e3");amount.outline_size=12;amount.position.y=.6;amount.no_depth_test=true;root.add_child(amount)
	if event.hit:
		for i in range(9):
			var angle=i*TAU/9
			var spark=cube(root,Vector3(cos(angle)*.17,sin(angle)*.17,.04),Vector3(.025,.3,.025),Color("ffd17c"))
			spark.rotation.z=angle
			var bright=spark.material_override;bright.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			var ray=create_tween().set_parallel(true);ray.tween_property(spark,"position",Vector3(cos(angle)*.55,sin(angle)*.55,.05),.23);ray.tween_property(spark,"scale",Vector3.ZERO,.23)
	var drift=create_tween().set_parallel(true);drift.tween_property(amount,"position:y",1.1,.55);drift.tween_property(amount,"modulate:a",0.0,.55)
	drift.chain().tween_callback(root.queue_free)

func check_result() -> bool:
	var outcome=game.result()
	if outcome=="":return false
	screen="result";reset_ui()
	var v=panel_at(ui,210,170,-210,-170)
	if outcome=="victory":
		label_in(v,"CHAPTER COMPLETE",18,GOLD);label_in(v,game.info().title,38)
		label_in(v,game.info().outro,24)
		button_in(v,"Continue the chronicle",func():
			show_dialogue(story.chapters[game.chapter].closing,func():
				game.finish_chapter()
				game.save_game(SAVE,"ending" if game.completed else "camp")
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
		label_in(list,u.name+" · "+u.job+" · Level "+str(int(u.level)),19,Color(u.color))
		label_in(list,profiles.get(u.id,{}).get("ending",u.bio),17)
	button_in(v,"Return to title",show_title)

func show_dialogue(lines: Array,on_complete: Callable):
	screen="dialogue";reset_ui()
	dialogue_lines=lines;dialogue_index=0;dialogue_callback=on_complete
	var shade=ColorRect.new();shade.color=Color(.08,.10,.13,.55);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(shade)
	dialogue_portrait=TextureRect.new();dialogue_portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	dialogue_portrait.offset_left=65;dialogue_portrait.offset_right=520;dialogue_portrait.offset_top=-710;dialogue_portrait.offset_bottom=-240
	dialogue_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;dialogue_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ui.add_child(dialogue_portrait)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);panel.offset_left=65;panel.offset_right=-65;panel.offset_top=-265;panel.offset_bottom=-55;ui.add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
	dialogue_name=label_in(column,"",25,GOLD)
	dialogue_label=label_in(column,"",25);dialogue_label.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var controls=HBoxContainer.new();column.add_child(controls)
	var hint=label_in(controls,"Space / Enter: continue   ·   Escape: skip",15,Color("827b6c"));hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button_in(controls,"Skip scene",finish_dialogue)
	button_in(controls,"Continue  >",advance_dialogue)
	refresh_dialogue()

func refresh_dialogue():
	if dialogue_index>=dialogue_lines.size():finish_dialogue();return
	var line=dialogue_lines[dialogue_index]
	var speaker=game.roster.filter(func(u):return u.id==line.speaker)
	dialogue_name.text=speaker[0].name if not speaker.is_empty() else line.speaker.capitalize()
	dialogue_portrait.texture=portraits.get_portrait(line.speaker)
	dialogue_label.text=line.text;dialogue_label.visible_characters=0;dialogue_reveal=0.0

func advance_dialogue():
	if screen!="dialogue":return
	if dialogue_label.visible_characters<dialogue_label.text.length():
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
	label_in(info,"%s  /  Level %d  /  %d XP"%[unit.job,unit.level,unit.xp],20)
	label_in(info,"HP %d    ATK %d    DEF %d    SPD %d    MOV %d"%[unit.max_hp,unit.pow,unit.defense,unit.speed,unit.move],21)
	label_in(info,profile.get("biography",unit.bio),22)
	label_in(info,"PERSONAL NOTE",16,GOLD);label_in(info,profile.get("note",""),20)
	button_in(panel,"Return to war council",show_camp)

func load_campaign():
	var saved=game.load_game(SAVE)
	if saved=="":return
	if not music.playing:music.play()
	if saved=="ending":show_ending()
	elif saved=="battle":make_map();show_battle()
	else:show_camp()
