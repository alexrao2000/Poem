## Project adapter and playable art test. Rendering modules under visuals/ are portable.

extends Control
signal closed
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Catalog=preload("res://visuals/catalog.gd")
const Map2D=preload("res://visuals/map_2d.gd")
const Map3D=preload("res://visuals/map_3d.gd")
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const LOGICAL_SIZE=Vector2i(512,344)
var game=Rules.new()
var tactics=Tactics.new()
var catalog=Catalog.new()
var renderer
var viewport: SubViewport
var view: TextureRect
var stage_area: Control
var sidebar: VBoxContainer
var unit_title: Label
var unit_stats: Label
var detail: Label
var log_text: Label
var phase_label: Label
var performance: Label
var portrait: TextureRect
var mode_label: Label
var mode_buttons: Array=[]
var action_button: Button
var wait_button: Button
var undo_button: Button
var end_button: Button
var restart_button: Button
var selected_id=""
var target_id=""
var mode="2d"
var busy=false
var threat_visible=false
var reduced_effects=false
var grid_visible=false
var cursor=Vector2i(2,3)
var route: Array=[]
var log_lines: Array[String]=[]
var frame_times: Array[float]=[]
var stats_clock=0.0
var result_label: Label
var current_visual_event: Dictionary={}

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not catalog.open("res://visuals/units.json"):
		var error=Label.new();error.text="Visual assets could not be loaded:\n"+"\n".join(catalog.errors);add_child(error);push_error(error.text);return
	new_demo();build_ui();set_mode("2d");message("Choose an ally. Cross the bridges and rout the guard.")
	if "--visual-3d" in OS.get_cmdline_user_args():set_mode("3d")

func new_demo():
	var roster=[]
	for id in ["lyra","oren","sera","tarin","ivo","bram"]:
		var unit=game.content.roster.filter(func(u):return u.id==id)[0].duplicate(true)
		unit.join=0;roster.append(unit)
	game.content=game.content.duplicate(true)
	game.content.roster=roster
	game.content.chapters=[{
		"id":0,"title":"The river crossing","place":"Willowmere","objective":"rout","boss":"Bridge captain","deployment":6,"environment":"village","objective_position":[10,6],
		"map":["ffffffffffff","f....~~....f","f....~~..##f","fpppp==pp##f","f....~~....f","f....~~....f","fpppp==pppof","f.#..~~....f","f..h.~~.h..f","ffffffffffff"],
		"deployment_positions":[[2,3],[3,3],[2,4],[3,5],[2,5],[2,6]],
		"enemies":[{"position":[9,6],"job":"Vanguard","ai":"guard"},{"position":[8,3],"job":"Corsair","ai":"sentry"},{"position":[9,4],"job":"Ranger","ai":"sentry"},{"position":[8,7],"job":"Duelist","ai":"pursue"}]
	}]
	game.chapter=0;game.new_campaign();game.deployed=roster.map(func(u):return u.id);game.start_battle()
	game.units[0].hp-=7
	selected_id="lyra";target_id="";busy=false;cursor=Vector2i(2,3);route.clear()

func style(bg: String, border="355657") -> StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=Color(bg);box.border_color=Color(border)
	box.set_border_width_all(1);box.set_content_margin_all(12)
	box.corner_radius_top_left=5;box.corner_radius_top_right=5;box.corner_radius_bottom_left=5;box.corner_radius_bottom_right=5
	return box

func label(parent: Node,text: String,size_value=16,color="d9e4da") -> Label:
	var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",size_value);node.add_theme_color_override("font_color",Color(color));node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(node);return node

func button(parent: Node,text: String,action: Callable) -> Button:
	var node=Button.new();node.text=text;node.custom_minimum_size.y=38;node.pressed.connect(action);parent.add_child(node);return node

func build_ui():
	var theme=Theme.new();theme.default_font_size=15
	theme.set_stylebox("normal","Button",style("243f41"));theme.set_stylebox("hover","Button",style("36595a","a4bba2"));theme.set_stylebox("pressed","Button",style("8d815a","d9c68d"));theme.set_stylebox("disabled","Button",style("1d3235","2d4647"))
	theme.set_color("font_color","Button",Color("e0e8d9"));theme.set_color("font_disabled_color","Button",Color("657c78"));self.theme=theme
	var bg=ColorRect.new();bg.color=Color("142a2e");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(key,22)
	add_child(margin)
	var shell=VBoxContainer.new();shell.add_theme_constant_override("separation",14);margin.add_child(shell)
	var header=HBoxContainer.new();header.add_theme_constant_override("separation",18);shell.add_child(header)
	var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(titles)
	label(titles,"ASHEN STANDARD   /   VISUAL WORKSHOP",12,"a6b79c")
	var title=label(titles,"The river crossing",36,"eee6c8");title.add_theme_font_override("font",FONT)
	var switcher=HBoxContainer.new();switcher.alignment=BoxContainer.ALIGNMENT_END;switcher.size_flags_vertical=Control.SIZE_SHRINK_CENTER;header.add_child(switcher)
	mode_buttons.append(button(switcher,"  2D tilemap  ",func():set_mode("2d")))
	mode_buttons.append(button(switcher,"  3D terrain  ",func():set_mode("3d")))
	button(switcher,"Return",func():if not busy:closed.emit())
	var body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",18);shell.add_child(body)
	var stage_shell=VBoxContainer.new();stage_shell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage_shell.add_theme_constant_override("separation",6);body.add_child(stage_shell)
	var stage_header=HBoxContainer.new();stage_shell.add_child(stage_header)
	mode_label=label(stage_header,"",13,"a6b79c");mode_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mode_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	phase_label=label(stage_header,"PLAYER PHASE",13,"d9c68d")
	phase_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	stage_area=Control.new();stage_area.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage_area.clip_contents=true;stage_area.custom_minimum_size=Vector2(520,0);stage_shell.add_child(stage_area)
	var ground=ColorRect.new();ground.color=Color("203d40");ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);stage_area.add_child(ground)
	viewport=SubViewport.new();viewport.size=LOGICAL_SIZE;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.handle_input_locally=false;viewport.own_world_3d=true;viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	view=TextureRect.new();view.texture=viewport.get_texture();view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;stage_area.add_child(view);view.gui_input.connect(board_input)
	stage_area.resized.connect(layout_view);call_deferred("layout_view")
	var hints=HBoxContainer.new();stage_shell.add_child(hints)
	label(hints,"CLICK  select / move    ·    RIGHT CLICK  undo    ·    TAB  change map",13,"92aaa2").size_flags_horizontal=Control.SIZE_EXPAND_FILL
	performance=label(hints,"",12,"92aaa2")
	performance.autowrap_mode=TextServer.AUTOWRAP_OFF
	var panel=PanelContainer.new();panel.custom_minimum_size.x=270;panel.add_theme_stylebox_override("panel",style("1c3437"));body.add_child(panel)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	sidebar=VBoxContainer.new();sidebar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sidebar.add_theme_constant_override("separation",8);scroll.add_child(sidebar)
	label(sidebar,"COMPANY / INSPECT",12,"a6b79c")
	var identity=HBoxContainer.new();sidebar.add_child(identity)
	portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(66,76);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;identity.add_child(portrait)
	unit_title=label(identity,"",25,"eee6c8");unit_title.add_theme_font_override("font",FONT);unit_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	unit_stats=label(sidebar,"",15)
	var separator=HSeparator.new();sidebar.add_child(separator)
	detail=label(sidebar,"",15,"b6c7b9");detail.custom_minimum_size.y=74
	action_button=button(sidebar,"Confirm attack",confirm_action)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);sidebar.add_child(actions)
	wait_button=button(actions,"Wait",wait_selected);wait_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	undo_button=button(actions,"Undo",cancel_selection);undo_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	end_button=button(sidebar,"End player phase  →",end_turn)
	var stretch=Control.new();stretch.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(stretch)
	label(sidebar,"FIELD NOTES",12,"a6b79c")
	log_text=label(sidebar,"",13,"a9bfb0");log_text.custom_minimum_size.y=64
	var toggles=HBoxContainer.new();sidebar.add_child(toggles)
	var danger_toggle=CheckButton.new();danger_toggle.text="Threats";danger_toggle.toggled.connect(func(value):threat_visible=value;refresh());toggles.add_child(danger_toggle)
	var grid_toggle=CheckButton.new();grid_toggle.text="Grid";grid_toggle.toggled.connect(func(value):grid_visible=value;refresh());toggles.add_child(grid_toggle)
	var effects=CheckButton.new();effects.text="Reduced motion";effects.toggled.connect(func(value):reduced_effects=value);sidebar.add_child(effects)
	restart_button=button(sidebar,"Reset this skirmish",reset_demo)
	var footer=HBoxContainer.new();shell.add_child(footer)
	result_label=label(footer,"One sprite library. Two map renderers. The same battle.",14,"a6b79c");result_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var footer_help=label(footer,"ARROWS + ENTER  navigate    ·    SPACE  end phase    ·    ESC  undo",12,"829f94")
	footer_help.autowrap_mode=TextServer.AUTOWRAP_OFF

func layout_view():
	if not is_instance_valid(view):return
	var factor=maxi(1,floori(minf(stage_area.size.x/LOGICAL_SIZE.x,stage_area.size.y/LOGICAL_SIZE.y)))
	view.size=Vector2(LOGICAL_SIZE)*factor;view.position=((stage_area.size-view.size)*.5).floor()

func set_mode(value: String):
	if busy or (renderer!=null and value==mode):return
	mode=value
	var facings={}
	if renderer!=null:
		for id in renderer.actors:facings[id]=renderer.actors[id].player.facing
		viewport.remove_child(renderer);renderer.queue_free()
	renderer=Map2D.new() if mode=="2d" else Map3D.new();viewport.add_child(renderer);renderer.setup(catalog,game)
	renderer.visual_cue.connect(on_visual_cue)
	for id in facings:
		if renderer.actors.has(id):renderer.actors[id].player.play("idle",facings[id])
	for i in mode_buttons.size():mode_buttons[i].disabled=(i==0 and mode=="2d") or (i==1 and mode=="3d")
	mode_label.text="2D TILEMAP  /  32 PX TILES" if mode=="2d" else "3D TERRAIN  /  ORTHOGRAPHIC CAMERA"
	frame_times.clear();refresh()

func selected():
	for unit in game.units:
		if unit.id==selected_id and unit.hp>0:return unit
	return null

func target():
	for unit in game.units:
		if unit.id==target_id and unit.hp>0:return unit
	return null

func refresh():
	if renderer==null:return
	var unit=selected();var other=target()
	renderer.selected_id=selected_id;renderer.cursor=cursor;renderer.route=route;renderer.show_grid=grid_visible
	renderer.reachable=game.reachable(unit) if unit!=null and unit.team=="player" and not unit.acted and not unit.moved else {}
	renderer.danger={}
	if threat_visible:
		for enemy in game.living("enemy"):
			for cell in tactics.threatened_tiles(game,enemy):renderer.danger[cell]=true
	renderer.refresh()
	phase_label.text=("PLAYER" if game.phase=="player" else "ENEMY")+" PHASE  /  TURN "+str(game.turn)
	if unit!=null:
		unit_title.text=unit.name+"\n"+game.class_name_for(unit)
		unit_stats.text="HP  %d / %d     MOV  %d\nATK  %d     DEF  %d     SPD  %d"%[unit.hp,unit.max_hp,unit.move,game.attack_power(unit),unit.defense,game.attack_speed(unit)]
		portrait.texture=catalog.frame_texture("unit."+Map2D.JOB_VISUAL.get(unit.job,"vanguard"),0)
	else:unit_title.text="Choose a unit";unit_stats.text="Six allies at the river crossing.";portrait.texture=null
	var can_attack=unit!=null and unit.team=="player" and game.can_act(unit) and other!=null and game.can_attack(unit,other)
	var can_heal=unit!=null and other!=null and game.can_heal(unit,other)
	detail.text="Select an ally, then a lit cell to move. Select a foe in range to preview an attack."
	if unit!=null and unit.acted:detail.text="This unit has acted. End the phase to ready the company."
	if unit!=null and unit.team=="enemy":detail.text="Enemy inspection. Toggle Threats to see the guard's attack coverage."
	if can_attack:
		var forecast=game.forecast(unit,other)
		detail.text="TARGET  "+other.name+"\nDamage %d  ·  Hit %d%%\nConfirm to resolve this attack."%[forecast.damage,forecast.hit]
	if can_heal:detail.text="SUPPORT  "+other.name+"\nRestore up to %d HP."%game.healing_power(unit)
	action_button.text="Confirm heal" if can_heal else "Confirm attack";action_button.disabled=busy or not (can_attack or can_heal)
	wait_button.disabled=busy or unit==null or unit.team!="player" or unit.acted or game.phase!="player"
	undo_button.disabled=busy or unit==null
	end_button.disabled=busy or not game.result().is_empty();restart_button.disabled=busy
	for i in mode_buttons.size():mode_buttons[i].disabled=busy or (i==0 and mode=="2d") or (i==1 and mode=="3d")
	if not game.result().is_empty():result_label.text="Crossing secured. Reset to compare another route." if game.result()=="victory" else "The company fell. Reset to try again."

func message(text: String):
	log_lines.append(text)
	while log_lines.size()>3:log_lines.pop_front()
	if is_instance_valid(log_text):log_text.text="\n".join(log_lines)

func board_input(event: InputEvent):
	if busy:return
	if event is InputEventMouseMotion:
		var cell=renderer.screen_to_cell(event.position/view.size*Vector2(LOGICAL_SIZE))
		if cell==cursor:return
		cursor=cell;route.clear();var unit=selected()
		if unit!=null and unit.team=="player" and not unit.acted and not unit.moved and cell.x>=0:route=game.movement_path(unit,cell)
		refresh()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:cancel_selection()
		if event.button_index==MOUSE_BUTTON_LEFT:
			var point=event.position/view.size*Vector2(LOGICAL_SIZE);var id=renderer.unit_at_screen(point)
			var cell=renderer.screen_to_cell(point)
			if not id.is_empty():
				for unit in game.units:
					if unit.id==id:cell=game.pos(unit);break
			click_cell(cell)

func click_cell(cell: Vector2i):
	if busy or cell.x<0 or game.phase!="player" or not game.result().is_empty():return
	cursor=cell;var unit=selected();var other=game.at(cell)
	if unit!=null and unit.team=="player" and game.can_act(unit) and other!=null and (game.can_attack(unit,other) or game.can_heal(unit,other)):
		if target_id==other.id:confirm_action()
		else:target_id=other.id;refresh()
		return
	if other!=null:
		if unit!=null and unit.id!=other.id and unit.team=="player" and not unit.acted:game.undo_move(unit)
		selected_id=other.id;target_id="";route.clear();refresh();return
	if unit!=null and unit.team=="player" and not unit.acted and not unit.moved:
		var path=game.movement_path(unit,cell)
		if not path.is_empty() and game.move_unit(unit,cell):
			busy=true;route.clear();refresh();await renderer.animate_route(unit.id,path);busy=false;refresh()

func cancel_selection():
	if busy:return
	var unit=selected()
	if unit!=null and unit.team=="player" and not unit.acted:game.undo_move(unit)
	target_id="";route.clear();refresh()

func wait_selected():
	var unit=selected()
	if busy or unit==null:return
	if game.wait_unit(unit):message(unit.name+" holds position.");target_id="";refresh()

func confirm_action():
	if busy:return
	var unit=selected();var other=target()
	if unit==null or other==null or unit.team!="player" or not game.can_act(unit):return
	if game.can_heal(unit,other):
		var before=other.hp
		if not game.heal(unit,other):return
		current_visual_event={"actor":unit.id,"target":other.id,"heal":other.hp-before}
		busy=true;refresh();await renderer.play_action(unit.id,other.id,reduced_effects);message(unit.name+" restores "+str(other.hp-before)+" HP.")
	elif game.can_attack(unit,other):
		var events=game.combat(unit,other);busy=true;refresh_controls_only()
		await present_events(events)
	else:return
	current_visual_event={};busy=false;target_id="";route.clear();refresh()

func refresh_controls_only():
	action_button.disabled=true;wait_button.disabled=true;undo_button.disabled=true;end_button.disabled=true;restart_button.disabled=true
	for node in mode_buttons:node.disabled=true

func present_events(events: Array):
	for event in events:
		if not event.has("actor"):continue
		current_visual_event=event
		await renderer.play_action(str(event.actor),str(event.target),reduced_effects)
		if event.get("hit",false) and renderer.actors.has(str(event.target)) and not reduced_effects:await renderer.play_hurt(str(event.target),event.get("remaining",1)<=0)
		var text=str(event.actor)+(" misses." if not event.get("hit",false) else " deals "+str(event.get("damage",0))+" damage." )
		message(text)
	current_visual_event={};renderer.refresh()

func on_visual_cue(id: String, cue_name: String):
	if cue_name!="contact" or current_visual_event.get("actor")!=id:return
	var event=current_visual_event;var caption="MISS";var kind="miss"
	if event.has("heal"):caption="+"+str(event.heal);kind="heal"
	elif event.get("hit",false):
		caption=str(event.damage)+("!" if event.get("crit",false) else "");kind="impact"
		for unit in game.units:
			if unit.id==id and unit.weapon in ["bow","magic"]:kind="projectile"
	renderer.feedback(id,str(event.target),caption,kind,reduced_effects)

func end_turn():
	if busy or not game.result().is_empty():return
	cancel_selection();busy=true;game.begin_enemy_phase();refresh()
	for enemy in game.living("enemy"):
		if game.living("player").is_empty():break
		var choice=tactics.plan(game,enemy);var path=game.movement_path(enemy,choice.position)
		await renderer.animate_route(enemy.id,path)
		var events=tactics.apply_plan(game,enemy,choice);await present_events(events)
		if not game.result().is_empty():break
	game.next_player_turn();busy=false;target_id="";message("The company readies for turn "+str(game.turn)+".");refresh()

func reset_demo():
	if busy:return
	new_demo();log_lines.clear();var previous=mode;renderer.queue_free();renderer=null
	result_label.text="One sprite library. Two map renderers. The same battle.";set_mode(previous);message("Skirmish reset. Your campaign save is untouched.")

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_TAB:
		if busy:renderer.skip_animations()
		else:set_mode("3d" if mode=="2d" else "2d")
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_TAB:
		if busy:renderer.skip_animations()
		else:set_mode("3d" if mode=="2d" else "2d")
	elif event.keycode==KEY_ESCAPE:cancel_selection()
	elif not busy:
		if event.keycode==KEY_SPACE:end_turn()
		if event.keycode==KEY_ENTER:click_cell(cursor)
		var directions={KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
		if directions.has(event.keycode):
			cursor+=directions[event.keycode];cursor.x=clampi(cursor.x,0,game.board_size().x-1);cursor.y=clampi(cursor.y,0,game.board_size().y-1)
			route.clear();var unit=selected()
			if unit!=null and unit.team=="player" and not unit.acted and not unit.moved:route=game.movement_path(unit,cursor)
			refresh()
	get_viewport().set_input_as_handled()

func _process(dt):
	frame_times.append(dt*1000)
	if frame_times.size()>600:frame_times.pop_front()
	stats_clock+=dt
	if stats_clock>1 and is_instance_valid(performance):
		stats_clock=0;var sorted=frame_times.duplicate();sorted.sort()
		performance.text="%d FPS · p95 %.1f ms"%[Engine.get_frames_per_second(),sorted[mini(sorted.size()-1,int(sorted.size()*.95))]]
