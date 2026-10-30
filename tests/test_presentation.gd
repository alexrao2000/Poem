extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
var inspected_hud=false

func inspect_combat_hud(app):
	await create_timer(.9).timeout
	var hud=app.ui.get_node("CombatHUD")
	var bounds=hud.get_global_rect()
	assert(bounds.end.y<=app.ui.get_global_rect().end.y,"Combat HP panel stays inside viewport")
	for heading in hud.find_children("*","Label",true,false):
		assert(heading.size.x>70,"Health text has enough horizontal space")
		assert(heading.size.y<55,"Health text never wraps into a vertical column")
	inspected_hud=true

func _initialize():
	call_deferred("run")

func run():
	var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test_presentation-ui-save.json"
	root.add_child(app)
	await process_frame
	for chapter in range(12):
		app.game.chapter=chapter
		app.show_camp()
		await process_frame
		app.game.start_battle()
		app.make_map()
		app.show_battle()
		await process_frame
		assert(not app.environment.fog_enabled,"Tactical camera keeps the full grid clear of arena haze")
		assert(app.sprites.size()==app.game.units.size(),"Every combatant has a map sprite")
		var arena=Node3D.new();app.add_child(arena)
		var context=app.scenery.combat_context(app.game,app.game.living("player")[0],app.game.living("enemy")[0])
		var rng_before=app.game.rng.state
		app.scenery.battle_landscape(arena,Vector3.ZERO,context)
		assert(arena.get_meta("environment")==app.game.info().environment,"Arena matches chapter")
		assert(arena.get_meta("terrain")==context.terrain and arena.get_meta("backdrop_count")==context.landmarks.size(),"Combat uses target terrain and nearby map landmarks")
		assert(context.landmarks.size()<=2 and app.game.rng.state==rng_before,"Backdrop selection is bounded and independent of gameplay RNG")
		for landmark in context.landmarks:assert(absf(landmark.x)<=11 and landmark.z<=-7,"Landmarks remain behind the action")
		assert(arena.get_meta("batch_stats").sources>5,"Arena includes batched scenery")
		arena.queue_free()
		var lighting=app.lighting_state();var previous=app.battle_lighting(app.game.info().environment)
		assert(previous==lighting and app.environment.fog_enabled,"Battle atmosphere saves the complete previous state")
		assert(app.environment.fog_depth_begin>=12 and app.environment.fog_density<.6,"Distance haze starts behind combatants and remains translucent")
		app.restore_lighting(previous);assert(app.lighting_state()==lighting,"Chapter atmosphere cannot leak into the tactical map")
	for tile in [".","f","h","p","o","+"]:
		var arena=Node3D.new();app.add_child(arena)
		app.scenery.battle_landscape(arena,Vector3.ZERO,{"environment":"village","terrain":tile})
		assert(arena.get_meta("arena_surface")== (2 if tile=="h" else 1 if tile in ["p","o","+"] else 0),"Forest/field fights do not become paved roads")
		arena.queue_free()
	app.game.new_campaign()
	for unit in app.game.roster:
		var fighter_data=unit.duplicate(true);fighter_data.team="player"
		var fighter=app.make_fighter(fighter_data,Vector3.ZERO)
		if fighter.has_meta("source_model"):
			assert(fighter.player!=null and fighter.poses.has("strike"),"Authored model has valid animation adapter")
		else:
			assert(fighter.find_child("PaintedFace",true,false)!=null,"Original painted face on each recruit")
			assert(fighter.bone("Arm")!=null,"Every procedural character exposes the weapon animation joint")
			assert(fighter.bone("Elbow")!=null and fighter.bone("RightKnee")!=null,"Articulated limbs")
		await fighter.pose("windup",.01).finished
		assert(fighter.pose_name=="windup","Attack preparation pose")
		await fighter.pose("strike",.01).finished
		await fighter.pose("idle",.01).finished
		fighter.queue_free()
	await process_frame
	app.game.start_battle()
	app.make_map()
	app.show_battle()
	var a=app.game.units[0]
	var b=app.game.living("enemy")[0]
	app.click_tile(app.game.pos(b));await process_frame
	assert(app.selected==b and app.target==null,"Enemy inspection never arms a player attack")
	assert(app.markers.get_child_count()>0,"Enemy inspection shows threat tiles")
	var old_enemy_position=app.game.pos(b)
	app.click_tile(Vector2i(5,5));assert(app.game.pos(b)==old_enemy_position,"Inspection cannot move enemies")
	app.toggle_danger();assert(app.show_danger,"All-enemy danger toggle")
	app.cancel_selection();assert(app.selected==null)
	app.toggle_danger();assert(not app.show_danger)
	a.x=8;a.y=4;b.x=9;b.y=4
	app.selected=a;app.target=b;app.update_side();await process_frame;await process_frame
	for control in app.side.get_children():
		assert(control.get_global_rect().end.y<=app.ui.size.y,"Forecast and action controls fit viewport")
	app.camera.size=15.25;app.camera.h_offset=1.5;app.camera.v_offset=.3;app.camera.fov=62
	app.environment.fog_enabled=true;app.environment.fog_density=.08;app.environment.fog_light_color=Color("c2b491")
	var original_lighting=app.lighting_state()
	var events=app.game.combat(a,b)
	inspect_combat_hud(app)
	await app.cinematic(a,b,events)
	assert(inspected_hud,"Combat HUD inspected during animation")
	assert(not app.stage.visible,"Battle stage hidden on return")
	assert(app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Map camera restored")
	assert(is_equal_approx(app.camera.size,15.25) and is_equal_approx(app.camera.h_offset,1.5),"Map zoom restored")
	assert(is_equal_approx(app.camera.v_offset,.3) and is_equal_approx(app.camera.fov,62),"Battle framing does not overwrite map camera settings")
	assert(app.world.visible and app.pieces.visible,"Map restored after arena")
	assert(app.lighting_state()==original_lighting,"Full cinematic restores custom lighting and fog values")
	app.music_mix(true)
	await create_timer(.1).timeout
	app.music_mix(false)
	await create_timer(.5).timeout
	assert(absf(app.score.get_sync_stream_volume(0))<.01,"Calm arrangement restored")
	assert(app.score.get_sync_stream_volume(1)<-50,"Intense arrangement faded without overlapping tweens")
	for panel in app.ui.get_children():
		if not panel.is_queued_for_deletion():assert(panel.visible,"Tactical controls restored")
	app.show_model_view(app.game.roster[0]);await process_frame
	assert(app.screen=="model" and app.stage.visible and not app.world.visible,"Model gallery isolates presentation")
	app.close_model_view();await process_frame
	assert(app.screen=="dossier" and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Gallery restores map camera")
	app.show_ending()
	await process_frame
	await Shutdown.dispose(app)
	await process_frame
	print("PASS: 12 camp/map scenes, combat camera transition, control restoration and ending")
	quit()
