extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
var inspected_hud=false

func inspect_combat_hud(app):
	await create_timer(.9).timeout
	var hud=app.ui.get_node("CombatHUD")
	var bounds=hud.get_global_rect()
	assert(bounds.end.y<=app.ui.get_global_rect().end.y,"Combat HP panel stays inside viewport")
	for record in hud.records.values():
		var heading=record.hp
		assert(heading.size.x>70,"Health text has enough horizontal space")
		assert(heading.size.y<55,"Health text never wraps into a vertical column")
	inspected_hud=true

func _initialize():
	call_deferred("run")

func run():
	var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test_presentation-ui-save.json"
	root.add_child(app)
	await process_frame
	var chapter_lights={}
	var horizon_colors={}
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
		var flipped=app.scenery.combat_context(app.game,app.game.living("player")[0],app.game.living("enemy")[0],-1.0)
		assert(flipped.terrain==context.terrain and flipped.landmarks.size()==context.landmarks.size())
		for index in context.landmarks.size():
			var normal=context.landmarks[index]
			var mirror=flipped.landmarks[index]
			assert(mirror.kind==normal.kind and mirror.z==normal.z and is_equal_approx(mirror.x,-normal.x),"Mirrored arena landmarks preserve their depth and map-relative side")
		assert(arena.get_meta("batch_stats").sources>5,"Arena includes batched scenery")
		arena.queue_free()
		var theme=app.game.info().environment
		var lighting=app.lighting_state()
		var previous=app.battle_lighting(theme)
		var atmosphere=app.lighting_state()
		chapter_lights[theme]=lighting
		horizon_colors[lighting.horizon]=true
		assert(atmosphere.sky_cover==app.CloudSky.texture(theme=="observatory") and atmosphere.clouds==app.CloudSky.tint(theme),"Starfall uses the night cover and other chapters share the daytime cover")
		assert(previous==lighting and app.environment.fog_enabled,"Battle atmosphere saves the complete previous state")
		for key in ["color","energy","ambient","top","horizon","ground","clouds","sky_cover"]:
			assert(atmosphere[key]==lighting[key],"The map and its arena share the same chapter light")
		assert(atmosphere.ambient>=.5 and atmosphere.energy>=.4,"Shadowed combatants keep a minimum light level")
		assert(app.environment.fog_depth_begin>=12 and app.environment.fog_density<.6,"Distance haze starts behind combatants and remains translucent")
		app.restore_lighting(previous);assert(app.lighting_state()==lighting,"Chapter atmosphere cannot leak into the tactical map")
	assert(chapter_lights.size()==12 and horizon_colors.size()==12,"Every chapter has its own horizon color")
	assert(chapter_lights.harbor.horizon.r>chapter_lights.harbor.horizon.b and chapter_lights.mountain.horizon.b>chapter_lights.mountain.horizon.r,"Harbor dusk stays warm and the mountain pass stays cool")
	assert(chapter_lights.forest.energy<chapter_lights.road.energy and chapter_lights.forest.fog.fog_density>chapter_lights.road.fog.fog_density,"Wet woodland has gentler sun and stronger haze than the open road")
	assert(chapter_lights.furnace.color.r>chapter_lights.furnace.color.b and chapter_lights.observatory.color.b>chapter_lights.observatory.color.r,"Late firelight and observatory moonlight remain distinct")
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
	app.environment.sky.sky_material.sky_cover_modulate=Color(.7,.6,.5,.17)
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
	assert(app.lighting_state()==original_lighting,"Full cinematic restores custom lighting, cloud contrast and fog values")
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
	await verify_starfall_exchange(app)
	await verify_aqueduct_exchange(app)
	await verify_crown_gate_exchange(app)
	await verify_weather_exchange(app)
	app.show_ending()
	await process_frame
	await Shutdown.dispose(app)
	await process_frame
	print("PASS: 12 distinct chapter palettes shared by map and arena, 12 camp/map scenes, combat camera transition, control restoration and ending")
	quit()

func verify_starfall_exchange(app):
	app.game.chapter=8;app.game.start_battle();app.make_map();app.show_battle()
	var night=app.CloudSky.texture(true)
	var map_lighting=app.lighting_state()
	assert(map_lighting.sky_cover==night)
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=6;a.y=6;b.x=7;b.y=6;app.refresh_pieces()
	var observed=[false]
	var watch_arena=func():
		if app.stage.visible and app.ui.has_node("CombatHUD"):
			assert(app.lighting_state().sky_cover==night and app.environment.fog_enabled)
			observed[0]=true
	process_frame.connect(watch_arena)
	await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
	process_frame.disconnect(watch_arena)
	assert(observed[0] and app.lighting_state()==map_lighting)
	app.battle_lighting("village",false)
	assert(app.lighting_state().sky_cover==app.CloudSky.texture())
	print("PASS: Starfall shares one night cover through a complete exchange and restores the daytime cover on chapter change")

func verify_aqueduct_exchange(app):
	app.game.chapter=7;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=5;a.y=5;b.x=6;b.y=5;app.refresh_pieces()
	var map_wheel=app.world.get_node("AqueductWaterwheel")
	map_wheel.seek_phase(1.04)
	var progress={"entry":0.0,"returned":false}
	var entering=func():
		if app.world.visible:return
		var wheel=app.stage.get_node("AqueductWaterwheel")
		assert(wheel.rotor.get_child_count()<=2,"The moving rims, spokes and paddles are batched locally")
		assert(is_equal_approx(wheel.phase,map_wheel.phase) and is_equal_approx(wheel.rotor.rotation.x,map_wheel.rotor.rotation.x))
		progress.entry=wheel.phase
	var returning=func():
		if app.stage.visible or app.world.visible:return
		var wheel=app.stage.get_node("AqueductWaterwheel")
		assert(is_equal_approx(wheel.phase,map_wheel.phase) and not is_equal_approx(wheel.phase,progress.entry))
		progress.returned=true
	app.world.visibility_changed.connect(entering)
	app.stage.visibility_changed.connect(returning)
	var snapshot=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
	await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
	app.world.visibility_changed.disconnect(entering)
	app.stage.visibility_changed.disconnect(returning)
	assert(progress.entry>1 and progress.returned and app.world.visible and not app.stage.visible)
	assert(app.game.save_data("battle")==snapshot and app.game.rng.state==rng)
	print("PASS: the Aqueduct waterwheel retains its motion through a complete combat cut and return without changing the campaign")

func verify_crown_gate_exchange(app):
	app.game.chapter=10;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=7;a.y=4;b.x=8;b.y=4;app.refresh_pieces()
	var sides=["WindStandardLeft","WindStandardRight"]
	var gate=app.world.get_node("CastleGate")
	gate.get_node(sides[0]).seek_phase(1.7);gate.get_node(sides[1]).seek_phase(6.1)
	var moments={"entry":[],"returned":false}
	var entering=func():
		if app.world.visible:return
		var backdrop=app.stage.get_node("CastleGate")
		for side in sides:
			var standard=backdrop.get_node(side)
			assert(is_equal_approx(standard.phase,gate.get_node(side).phase))
			moments.entry.append(standard.phase)
	var returning=func():
		if app.stage.visible or app.world.visible:return
		var backdrop=app.stage.get_node("CastleGate")
		for index in sides.size():
			var side=sides[index]
			assert(is_equal_approx(gate.get_node(side).phase,backdrop.get_node(side).phase))
			assert(gate.get_node(side).phase>moments.entry[index])
		moments.returned=true
	app.world.visibility_changed.connect(entering)
	app.stage.visibility_changed.connect(returning)
	var state=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
	await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
	app.world.visibility_changed.disconnect(entering)
	app.stage.visibility_changed.disconnect(returning)
	assert(moments.entry.size()==2 and moments.returned and not is_equal_approx(moments.entry[0],moments.entry[1]))
	assert(app.game.save_data("battle")==state and app.game.rng.state==rng)
	print("PASS: both Crown Approach standards carry their separate wind phases through a complete 3D exchange")

func verify_weather_exchange(app):
	app.game.chapter=2;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=7;a.y=4;b.x=8;b.y=4;app.refresh_pieces()
	var rain=app.world.get_node("AmbientDrift")
	rain.seek_elapsed(7.25)
	var state=app.game.save_data("battle").duplicate(true)
	for skip in [false,true]:
		await process_frame
		var transfer={"entry":-1.0,"return":-1.0,"skipped":false}
		var enter=func():
			if app.world.visible:return
			var arena=app.stage.get_node("AmbientDrift")
			assert(arena.kind=="rain" and arena.elapsed==rain.elapsed)
			assert(arena.states.slice(0,rain.states.size())==rain.states)
			transfer.entry=rain.elapsed
		var finish=func():
			if app.stage.visible or app.world.visible:return
			var arena=app.stage.get_node("AmbientDrift")
			assert(arena.elapsed==rain.elapsed and arena.elapsed>transfer.entry)
			transfer.return=rain.elapsed
		var handle_skip=func():
			var playback=app.ui.get_node_or_null("CombatPlayback")
			if not skip or transfer.skipped or playback==null or not app.stage.visible or not app.ui.has_node("CombatHUD"):return
			playback.request_skip()
			transfer.skipped=true
		app.world.visibility_changed.connect(enter)
		app.stage.visibility_changed.connect(finish)
		process_frame.connect(handle_skip)
		await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
		app.world.visibility_changed.disconnect(enter)
		app.stage.visibility_changed.disconnect(finish)
		process_frame.disconnect(handle_skip)
		assert(transfer.entry>7.25 and transfer.return>transfer.entry and transfer.skipped==skip)
		assert(rain.elapsed>=transfer.return and app.world.visible and not app.stage.visible)
	assert(app.game.save_data("battle")==state)
	print("PASS: Greywood carries the same seeded rain phases into a complete and a skipped 3D exchange, then continues on the map")
