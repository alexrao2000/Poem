extends SceneTree

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
	app.game.new_campaign()
	for unit in app.game.roster:
		var fighter_data=unit.duplicate(true);fighter_data.team="player"
		var fighter=app.make_fighter(fighter_data,Vector3.ZERO)
		assert(fighter.has_node("Arm"),"Every character exposes the weapon animation joint")
		fighter.queue_free()
	await process_frame
	app.game.start_battle()
	app.make_map()
	app.show_battle()
	var a=app.game.units[0]
	var b=app.game.living("enemy")[0]
	a.x=8;a.y=4;b.x=9;b.y=4
	var events=app.game.combat(a,b)
	await app.cinematic(a,b,events)
	assert(not app.stage.visible,"Battle stage hidden on return")
	assert(app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Map camera restored")
	assert(is_equal_approx(app.camera.size,16.0),"Map zoom restored")
	for panel in app.ui.get_children():
		if not panel.is_queued_for_deletion():assert(panel.visible,"Tactical controls restored")
	app.show_ending()
	await process_frame
	app.queue_free()
	await process_frame
	print("PASS: 12 camp/map scenes, combat camera transition, control restoration and ending")
	quit()
