extends SceneTree
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
	var app=load("res://main.tscn").instantiate()
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
		assert(app.sprites.size()==app.game.units.size(),"Every combatant has a map sprite")
		var arena=Node3D.new();app.add_child(arena)
		app.scenery.battle_landscape(arena,Vector3.ZERO,{"environment":app.game.info().environment})
		assert(arena.get_meta("environment")==app.game.info().environment,"Arena matches chapter")
		assert(arena.get_child_count()>5,"Arena includes scenery")
		arena.queue_free()
	app.game.new_campaign()
	for unit in app.game.roster:
		var fighter_data=unit.duplicate(true);fighter_data.team="player"
		var fighter=app.make_fighter(fighter_data,Vector3.ZERO)
		assert(fighter.bone("Arm")!=null,"Every character exposes the weapon animation joint")
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
	var events=app.game.combat(a,b)
	inspect_combat_hud(app)
	await app.cinematic(a,b,events)
	assert(inspected_hud,"Combat HUD inspected during animation")
	assert(not app.stage.visible,"Battle stage hidden on return")
	assert(app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Map camera restored")
	assert(is_equal_approx(app.camera.size,16.0),"Map zoom restored")
	assert(app.world.visible and app.pieces.visible,"Map restored after arena")
	app.music_mix(true)
	await create_timer(.1).timeout
	app.music_mix(false)
	await create_timer(.5).timeout
	assert(absf(app.score.get_sync_stream_volume(0))<.01,"Calm arrangement restored")
	assert(app.score.get_sync_stream_volume(1)<-50,"Intense arrangement faded without overlapping tweens")
	for panel in app.ui.get_children():
		if not panel.is_queued_for_deletion():assert(panel.visible,"Tactical controls restored")
	app.show_ending()
	await process_frame
	app.queue_free()
	await process_frame
	print("PASS: 12 camp/map scenes, combat camera transition, control restoration and ending")
	quit()
