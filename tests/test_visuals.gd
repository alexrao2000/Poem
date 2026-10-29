extends SceneTree
const Catalog=preload("res://visuals/catalog.gd")
const Player=preload("res://visuals/sprite_player.gd")
var captures=false
func _initialize():call_deferred("run")

func idle(lab):
	var deadline=Time.get_ticks_msec()+15000
	while lab.busy:
		assert(Time.get_ticks_msec()<deadline,"Presentation must finish without an animation deadlock")
		await process_frame

func capture(lab,path: String):
	if not captures:return
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)

func run():
	captures="--capture-visuals" in OS.get_cmdline_user_args()
	var catalog=Catalog.new();assert(catalog.open("res://visuals/units.json"),str(catalog.errors))
	assert(catalog.assets.size()==8)
	var image=load("res://visuals/assets/units-v2.png").get_image()
	assert(image.get_pixel(0,0).a==0,"Sprites have actual alpha transparency")
	for id in catalog.assets:
		assert(catalog.assets[id].frames.size()==12)
		for facing in ["north","south","east","west"]:
			for state in ["idle","move","act","hurt","defeated"]:
				var player=Player.new();player.configure(catalog.assets[id]);player.play(state,facing,true);player.advance(.15)
				assert(catalog.frame_texture(id,player.frame_index())!=null)
	var invalid=catalog.assets["unit.vanguard"].duplicate(true);invalid.frames[0].rect[2]=9000
	catalog.validate_asset(invalid);assert(catalog.errors.any(func(error):return "outside texture" in error),"Reject malformed atlas bounds")
	var player=Player.new();player.configure(catalog.assets["unit.vanguard"])
	var events={"cues":0,"done":0};player.cue.connect(func(_name):events.cues+=1);player.finished.connect(func():events.done+=1)
	player.play("act","south",true);player.advance(.12);assert(events.cues==1);player.skip();player.skip();player.advance(20)
	assert(events.done==1 and events.cues==1,"Skip completes once and never replays contact")
	player.play("move","east",true);player.advance(10000);assert(not player.complete and player.index<2,"Loop phase remains bounded after long pause")
	var lab=load("res://visual_lab.tscn").instantiate();root.add_child(lab);await process_frame;await process_frame
	assert(lab.stage_area.size.y>350,"Header and footer cannot push the map out of the window")
	assert(lab.view.get_global_rect().end.y<lab.get_global_rect().end.y,"World view fits within the window")
	assert(lab.game.units.size()==10 and lab.game.living("player").size()==6)
	var outcomes=[]
	for mode in ["2d","3d"]:
		lab.reset_demo();lab.set_mode(mode);await process_frame
		var before=lab.game.save_data("battle");var rng=lab.game.rng.state
		lab.renderer.actors.lyra.player.play("idle","west")
		lab.set_mode("3d" if mode=="2d" else "2d");lab.set_mode(mode)
		assert(lab.game.save_data("battle")==before and lab.game.rng.state==rng,"Map switching preserves exact simulation and RNG")
		assert(lab.renderer.actors.lyra.player.facing=="west","Map switching preserves unit facing")
		var torso=lab.renderer.cell_to_world(Vector2i(3,3))
		var selection_point=lab.renderer.camera.unproject_position(torso)-Vector2(0,24) if mode=="3d" else torso-Vector2(0,24)
		assert(lab.renderer.unit_at_screen(selection_point)=="oren","Clicking a sprite torso selects its own ground cell")
		for cell in [Vector2i(0,0),Vector2i(6,3),Vector2i(11,9)]:assert(lab.renderer.world_to_cell(lab.renderer.cell_to_world(cell))==cell)
		if mode=="3d":
			for cell in [Vector2i(2,3),Vector2i(6,3),Vector2i(10,6)]:
				var point=lab.renderer.camera.unproject_position(lab.renderer.cell_to_world(cell));assert(lab.renderer.screen_to_cell(point)==cell,"Projected bridge and ground picking agree")
		else:assert(lab.renderer.screen_to_cell(lab.renderer.cell_to_world(Vector2i(6,3)))==Vector2i(6,3))
		lab.threat_visible=true;lab.grid_visible=true;lab.refresh();assert(not lab.renderer.danger.is_empty())
		lab.threat_visible=false;lab.grid_visible=false;lab.refresh()
		await capture(lab,"res://build/visual-"+mode+".png")
		var unit=lab.selected();var start=lab.game.pos(unit)
		lab.click_cell(Vector2i(4,3));await process_frame
		assert(lab.busy,"Movement locks input")
		lab.set_mode("3d" if mode=="2d" else "2d");assert(lab.mode==mode,"No renderer destruction during movement")
		await idle(lab);assert(lab.game.pos(unit)==Vector2i(4,3))
		lab.cancel_selection();assert(lab.game.pos(unit)==start,"Undo restores simulation and visual position")
		assert(lab.renderer.actors[unit.id].position==lab.renderer.cell_to_world(start))
		var enemy=lab.game.living("enemy")[0];unit.x=4;unit.y=3;enemy.x=5;enemy.y=3;lab.refresh()
		lab.click_cell(lab.game.pos(enemy));assert(lab.target_id==enemy.id and not lab.action_button.disabled,"Forecast arms the requested attack")
		lab.confirm_action();await idle(lab)
		assert(unit.acted and not lab.busy)
		outcomes.append({"units":lab.game.units.duplicate(true),"rng":lab.game.rng.state})
		assert(not lab.game.can_act(unit),"Resolved action remains spent")
		lab.reset_demo();lab.set_mode(mode);await process_frame
		var healer=lab.game.units.filter(func(u):return u.id=="ivo")[0];var patient=lab.game.units[0]
		var archer=lab.game.units.filter(func(u):return u.id=="sera")[0];archer.x=1;archer.y=4
		healer.x=2;healer.y=4;lab.selected_id=healer.id;var old_hp=patient.hp;lab.refresh();lab.click_cell(lab.game.pos(patient))
		lab.confirm_action();await idle(lab);assert(patient.hp>old_hp and healer.acted,"Healing works through either renderer")
		lab.end_turn();await idle(lab);assert(lab.game.turn==2 and lab.game.phase=="player","Enemy phase returns to player control")
	assert(outcomes[0]==outcomes[1],"Identical attacks in both renderers yield identical HP, progression, and RNG")
	lab.queue_free();await process_frame
	var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-visuals-test.json";root.add_child(app);await process_frame
	var campaign=app.game.save_data("battle");app.show_visual_workshop();await process_frame
	assert(app.screen=="visual_workshop" and not app.ui.visible)
	var workshop=app.canvas.get_child(app.canvas.get_child_count()-1);workshop.closed.emit();await process_frame
	assert(app.screen=="title" and app.ui.visible and app.camera.current)
	assert(app.game.save_data("battle")==campaign,"Opening and closing the workshop leaves campaign state intact")
	app.queue_free();await process_frame
	print("PASS: visual catalog, 160 state/facing combinations, timing/cues/skip, two renderers, picking, movement locks/undo, deterministic combat, healing, enemy turns and game entry/return")
	quit()
