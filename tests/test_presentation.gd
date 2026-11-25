extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Draft=preload("res://scripts/campaign_draft.gd")
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
	await verify_abbey_banner(app)
	await verify_aqueduct_exchange(app)
	await verify_reddeep_fires(app)
	await verify_crown_gate_exchange(app)
	await verify_weather_exchange(app)
	await verify_harbor_gulls(app)
	await verify_chimney_exchange(app)
	await verify_valley_lighting(app)
	app.show_ending()
	await process_frame
	await Shutdown.dispose(app)
	await process_frame
	print("PASS: 12 distinct chapter palettes shared by map and arena, 12 camp/map scenes, combat camera transition, control restoration and ending")
	quit()

func verify_valley_lighting(app):
	var previous_game=app.game
	var previous_story=app.story
	var draft=Draft.new();draft.load_poem_template(true)
	var compiled=draft.compile()
	app.game=Draft.Rules.new(compiled.content);app.game.chapter=11;app.story=compiled.story
	app.game.start_battle()
	app.selected=null;app.target=null;app.origin=null
	var ally=app.game.living("player")[0]
	var foe=app.game.living("enemy")[1]
	ally.x=5;ally.y=9;foe.x=6;foe.y=9
	app.make_map();app.show_battle()
	var room=app.lighting_state()
	var river=app.CHAPTER_LIGHTING.river
	assert(room.sky_cover==null and not room.fog.fog_enabled)
	assert(room.horizon==Color(app.WAR_TABLE_LIGHTING.horizon) and room.color==Color(app.WAR_TABLE_LIGHTING.sun))
	var saved=app.game.save_data("battle").duplicate(true)
	var seen={"map":false,"arena":false,"return":false}
	var check_palette=func():
		var veil=app.ui.get_node_or_null("CombatTransition")
		if veil==null or not veil.visible:return
		if app.stage.visible:
			var lighting=app.lighting_state()
			assert(lighting.sky_cover==app.CloudSky.texture() and lighting.fog.fog_enabled)
			assert(lighting.horizon==Color(river.horizon) and lighting.color==Color(river.sun))
			assert(veil.ink==app.CombatTransition.INK.lerp(Color(river.horizon).darkened(.81),.52))
			seen.arena=true
		else:
			assert(veil.ink==app.CombatTransition.INK.lerp(room.horizon.darkened(.81),.52))
			if seen.arena:seen.return=true
			else:seen.map=true
	process_frame.connect(check_palette)
	await app.cinematic(ally,foe,[{"actor":ally.id,"target":foe.id,"damage":1,"remaining":foe.hp-1,"hit":true,"crit":false}])
	process_frame.disconnect(check_palette)
	assert(seen.values().all(func(marker):return marker) and app.lighting_state()==room)
	assert(app.game.save_data("battle")==saved)
	app.game=previous_game;app.story=previous_story
	print("PASS: warm war-table lighting, local river palette on entry, and exact room lighting and save restoration")

func verify_chimney_exchange(app):
	app.game.chapter=0;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=8;a.y=4;b.x=9;b.y=4;app.refresh_pieces()
	var smoke=app.world.get_node("ChimneySmoke")
	var clock=smoke.clock;clock.seek_elapsed(3.25);smoke.update_from_clock()
	var state=app.game.save_data("battle").duplicate(true)
	var events=[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}]
	var phases=[]
	var roof_in_view=[false]
	var enter=func():
		if app.world.visible:return
		var arena=app.stage.get_node("ChimneySmoke")
		assert(arena.clock.elapsed==clock.elapsed and arena.multimesh.instance_count>0)
		phases.append(clock.elapsed)
	var leave=func():
		if app.stage.visible or app.world.visible:return
		var arena=app.stage.get_node("ChimneySmoke")
		assert(arena.clock.elapsed==clock.elapsed and clock.elapsed>phases[0])
		phases.append(clock.elapsed)
	var inspect=func():
		if roof_in_view[0] or not app.stage.visible or not app.ui.has_node("CombatHUD"):return
		var arena=app.stage.get_node("ChimneySmoke")
		var visible_area=app.camera.get_viewport().get_visible_rect().grow(-16)
		roof_in_view[0]=arena.vents.any(func(vent):
			return visible_area.has_point(app.camera.unproject_position(vent.origin+Vector3.UP*1.08)))
	app.world.visibility_changed.connect(enter);app.stage.visibility_changed.connect(leave)
	process_frame.connect(inspect)
	await app.cinematic(a,b,events,{a.id:a.hp,b.id:b.hp})
	process_frame.disconnect(inspect)
	app.world.visibility_changed.disconnect(enter);app.stage.visibility_changed.disconnect(leave)
	assert(phases.size()==2 and clock.elapsed>=phases[1] and app.world.visible and roof_in_view[0])
	assert(app.stage.get_node_or_null("ChimneySmoke")==null)
	assert(app.game.save_data("battle")==state)
	print("PASS: Cinderford chimney smoke follows the houses through a complete 3D exchange and returns at the same phase")

func verify_starfall_exchange(app):
	app.game.chapter=8
	var chapter=app.game.info()
	chapter.lighting={"sun":"f1cfaa","horizon":"6a7e9b","energy":1.18,"haze":.42,"top":"invalid","ambient":-1}
	app.game.start_battle();app.make_map();app.show_battle()
	var night=app.CloudSky.texture(true)
	var map_lighting=app.lighting_state()
	assert(map_lighting.sky_cover==night)
	assert(map_lighting.horizon==Color("6a7e9b") and map_lighting.color==Color("f1cfaa"))
	assert(is_equal_approx(map_lighting.energy,1.18) and is_equal_approx(map_lighting.fog.fog_density,.42))
	var base=app.CHAPTER_LIGHTING.observatory
	assert(map_lighting.top==Color(base.top) and is_equal_approx(map_lighting.ambient,base.ambient),
		"Invalid fields keep their battlefield defaults")
	assert(app.battlefield_palette("forest")==app.CHAPTER_LIGHTING.forest)
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=6;a.y=6;b.x=7;b.y=6;app.refresh_pieces()
	var save=app.game.save_data("battle");var rng=app.game.rng.state
	var observed=[false,false]
	var watch_arena=func():
		var veil=app.ui.get_node_or_null("CombatTransition")
		if veil!=null and veil.visible:
			assert(veil.ink==app.CombatTransition.INK.lerp(map_lighting.horizon.darkened(.81),.52))
			observed[1]=true
		if app.stage.visible and app.ui.has_node("CombatHUD"):
			var arena=app.lighting_state()
			assert(arena.sky_cover==night and app.environment.fog_enabled)
			assert(arena.horizon==map_lighting.horizon and arena.color==map_lighting.color)
			assert(is_equal_approx(arena.energy,map_lighting.energy) and arena.fog.fog_density==map_lighting.fog.fog_density)
			observed[0]=true
	process_frame.connect(watch_arena)
	await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
	process_frame.disconnect(watch_arena)
	assert(observed.all(func(seen):return seen) and app.lighting_state()==map_lighting)
	assert(app.game.save_data("battle")==save and app.game.rng.state==rng)
	chapter.lighting="invalid"
	assert(app.battlefield_palette("observatory")==base)
	chapter.erase("lighting")
	app.battle_lighting("observatory",false)
	assert(app.lighting_state().horizon==Color(base.horizon) and is_equal_approx(app.lighting_state().energy,base.energy))
	app.battle_lighting("village",false)
	assert(app.lighting_state().sky_cover==app.CloudSky.texture())
	print("PASS: Starfall shares one night cover through a complete exchange and restores the daytime cover on chapter change")
	print("PASS: authored battlefield lighting follows the map and arena, inherits invalid fields and leaves the campaign unchanged")

func verify_abbey_banner(app):
	app.game.chapter=3;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=5;a.y=4;b.x=6;b.y=4;app.refresh_pieces()
	var path="EmptyBelfry/AbbeyBanner"
	var field=app.world.get_node(path)
	var state=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
	for skip in [false,true]:
		field.seek_phase(7.50)
		var transfer={"entry":-1.0,"returned":-1.0,"skipped":false}
		var entering=func():
			if app.world.visible:return
			var staged=app.stage.get_node(path)
			assert(staged.cloth.mesh==field.cloth.mesh and staged.phase==field.phase)
			transfer.entry=staged.phase
		var returning=func():
			if app.stage.visible or app.world.visible:return
			var staged=app.stage.get_node(path)
			assert(staged.phase==field.phase)
			assert(staged.material.get_shader_parameter("phase")==field.material.get_shader_parameter("phase"))
			transfer.returned=field.phase
		var request=func():
			if skip and not transfer.skipped and app.stage.visible and app.ui.has_node("CombatHUD"):
				app.ui.get_node("CombatPlayback").request_skip()
				transfer.skipped=true
		app.world.visibility_changed.connect(entering)
		app.stage.visibility_changed.connect(returning)
		process_frame.connect(request)
		await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
		app.world.visibility_changed.disconnect(entering)
		app.stage.visibility_changed.disconnect(returning)
		process_frame.disconnect(request)
		assert(transfer.entry>7.50 and transfer.returned>transfer.entry and transfer.skipped==skip)
		assert(field.phase>=transfer.returned and app.world.visible and not app.stage.visible)
	assert(app.game.save_data("battle")==state and app.game.rng.state==rng)
	print("PASS: Abbey banner preserves the same cloth phase through normal and skipped combat")

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

func verify_reddeep_fires(app):
	app.game.chapter=9;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	var field={}
	for fire in app.world.find_children("HearthFire","Node3D",true,false):
		field[fire.get_meta("hearth_site")]=fire
	assert(field.size()==2)
	for skip in [false,true]:
		if skip:a.x=1;a.y=4;b.x=2;b.y=4
		else:a.x=4;a.y=5;b.x=4;b.y=6
		app.refresh_pieces()
		var state=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
		var transfer={"entry":{},"return":{},"hidden":{},"skipped":false}
		var entering=func():
			if app.world.visible:return
			for fire in app.stage.find_children("HearthFire","Node3D",true,false):
				var site=fire.get_meta("hearth_site")
				assert(fire.phase==field[site].phase and fire.scale==field[site].scale)
				transfer.entry[site]=fire.phase
			for site in field:
				if not transfer.entry.has(site):transfer.hidden[site]=field[site].phase
		var returning=func():
			if app.stage.visible or app.world.visible:return
			for fire in app.stage.find_children("HearthFire","Node3D",true,false):
				var site=fire.get_meta("hearth_site")
				assert(fire.phase==field[site].phase and fire.phase!=transfer.entry[site])
				transfer.return[site]=fire.phase
			for site in transfer.hidden:
				assert(field[site].phase==transfer.hidden[site],"An omitted hearth retains its hidden phase")
		var request=func():
			if skip and not transfer.skipped and app.stage.visible and app.ui.has_node("CombatHUD"):
				app.ui.get_node("CombatPlayback").request_skip();transfer.skipped=true
		app.world.visibility_changed.connect(entering)
		app.stage.visibility_changed.connect(returning)
		process_frame.connect(request)
		await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
		app.world.visibility_changed.disconnect(entering)
		app.stage.visibility_changed.disconnect(returning)
		process_frame.disconnect(request)
		assert(transfer.entry.size()==(1 if skip else 2) and transfer.return.size()==transfer.entry.size())
		assert(transfer.skipped==skip and app.game.save_data("battle")==state and app.game.rng.state==rng)
	print("PASS: both Reddeep fires preserve their exact phase through normal combat, and Skip restores only the staged hearth")

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

func wet_ground_material(world: Node3D) -> Material:
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		var paint=mesh.material_override
		if paint is ShaderMaterial and paint.get_shader_parameter("rain_soaked")==true:return paint
	return null

func verify_weather_exchange(app):
	app.game.chapter=2;app.game.start_battle();app.make_map();app.show_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=7;a.y=4;b.x=8;b.y=4;app.refresh_pieces()
	var bystander=app.game.living("player")[1]
	var rain=app.world.get_node("AmbientDrift")
	var wet_tactical=wet_ground_material(app.world)
	assert(wet_tactical!=null and wet_tactical.get_shader_parameter("blend_edges")==true)
	rain.seek_elapsed(7.25)
	var state=app.game.save_data("battle").duplicate(true)
	for skip in [false,true]:
		await process_frame
		var transfer={"entry":-1.0,"return":-1.0,"skipped":false}
		var idle_phases={}
		var emphasis={}
		var sprites_restored=[0]
		var inspect_idle=func():
			for unit in [a,b,bystander]:
				var piece=app.unit_nodes[unit.id]
				assert(piece.sprite.no_depth_test==(unit!=bystander),
					"Only the focal pair bypasses scenery depth on either side of the close-up")
				assert(is_equal_approx(piece.cutaway_dim,1.0 if unit==bystander else 0.0))
				if unit==bystander:assert(piece.sprite.modulate.is_equal_approx(app.MapUnit.CUTAWAY_TINT))
				if not app.pieces.visible:
					# Set distinct nonzero positions once the hidden sprite clock pauses.
					piece.player.play("idle","",true)
					piece.player.advance(float(piece.player.clip().duration_ms[0])/1000.0+(.02 if unit==bystander else .04))
					piece.update_frame()
					idle_phases[unit.id]=[piece.player.index,piece.player.elapsed_ms,piece.sprite.texture,piece.clock]
				else:
					assert([piece.player.index,piece.player.elapsed_ms,piece.sprite.texture,piece.clock]==idle_phases[unit.id],
						"Both combatants and the bystander return at their exact paused tactical pose")
					sprites_restored[0]+=1
		var enter=func():
			if app.world.visible:return
			var arena=app.stage.get_node("AmbientDrift")
			assert(arena.kind=="rain" and arena.elapsed==rain.elapsed)
			assert(arena.states.slice(0,rain.states.size())==rain.states)
			assert(arena.ripples.multimesh.mesh==rain.ripples.multimesh.mesh)
			for index in rain.states.size():assert(arena.ripple_buffer[index*16+15]==rain.ripple_buffer[index*16+15])
			var wet_arena=wet_ground_material(app.stage)
			assert(wet_arena!=null and wet_arena.shader==wet_tactical.shader)
			transfer.entry=rain.elapsed
		var finish=func():
			if app.stage.visible or app.world.visible:return
			var arena=app.stage.get_node("AmbientDrift")
			assert(arena.elapsed==rain.elapsed and arena.elapsed>transfer.entry)
			for index in rain.states.size():assert(arena.ripple_buffer[index*16+15]==rain.ripple_buffer[index*16+15])
			transfer.return=rain.elapsed
		var handle_skip=func():
			var veil=app.ui.get_node_or_null("CombatTransition")
			if veil!=null and app.world.visible and app.pieces.visible:
				var piece=app.unit_nodes[bystander.id]
				if piece.cutaway_dim>.02 and piece.cutaway_dim<.98:
					assert(piece.sprite.modulate.is_equal_approx(Color.WHITE.lerp(app.MapUnit.CUTAWAY_TINT,piece.cutaway_dim)))
					emphasis[veil.revealing]=true
			var playback=app.ui.get_node_or_null("CombatPlayback")
			if not skip or transfer.skipped or playback==null or not app.stage.visible or not app.ui.has_node("CombatHUD"):return
			playback.request_skip()
			transfer.skipped=true
		app.world.visibility_changed.connect(enter)
		app.stage.visibility_changed.connect(finish)
		app.pieces.visibility_changed.connect(inspect_idle)
		process_frame.connect(handle_skip)
		await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
		app.world.visibility_changed.disconnect(enter)
		app.stage.visibility_changed.disconnect(finish)
		app.pieces.visibility_changed.disconnect(inspect_idle)
		process_frame.disconnect(handle_skip)
		assert(transfer.entry>7.25 and transfer.return>transfer.entry and transfer.skipped==skip)
		assert(sprites_restored[0]==3)
		assert(emphasis.size()==2,"Bystander color moves through intermediate values in both directions")
		assert(rain.elapsed>=transfer.return and app.world.visible and not app.stage.visible)
		assert(wet_ground_material(app.world)==wet_tactical,"Returning reuses the original rain-soaked tactical ground")
		for piece in app.unit_nodes.values():
			assert(piece.sprite.no_depth_test and is_zero_approx(piece.cutaway_dim),"Normal tactical readability returns for every surviving figure")
		assert(app.unit_nodes[bystander.id].sprite.modulate==Color.WHITE)
	assert(app.game.save_data("battle")==state)
	print("PASS: Greywood carries the same seeded rain phases into a complete and a skipped 3D exchange, then continues on the map")
	print("PASS: both combatants and a bystander retain their exact tactical idle phases through full and skipped 3D exchanges")
	print("PASS: both map reveals respect scenery depth for bystanders and restore tactical visibility")
	print("PASS: bystander color follows the camera in both directions through full and skipped 3D exchanges")

func verify_harbor_gulls(app):
	app.game.chapter=5;app.game.start_battle()
	var a=app.game.living("player")[0];var b=app.game.living("enemy")[0]
	a.x=5;a.y=4;b.x=6;b.y=4
	app.make_map();app.show_battle();await process_frame
	var clock=app.world.get_node("AmbientDrift")
	var flock=clock.get_node("HarborGulls")
	assert(flock.multimesh.instance_count==6 and flock.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var wings=flock.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounds=flock.multimesh.custom_aabb
	var samples=0
	for frame in 180:
		clock.seek_elapsed(frame*.19);flock.update_from_clock()
		var data=flock.pose_buffer
		for instance in 6:
			var offset=instance*12
			var basis=Basis(Vector3(data[offset],data[offset+4],data[offset+8]),
				Vector3(data[offset+1],data[offset+5],data[offset+9]),Vector3(data[offset+2],data[offset+6],data[offset+10]))
			var center=Vector3(data[offset+3],data[offset+7],data[offset+11])
			for wing in wings:
				var posed=center+basis*wing
				assert(bounds.has_point(posed) and flock.to_global(posed).z>app.game.board_size().y,"Every wing stays in the cull bounds and outside the playable harbor")
			samples+=1
	var state=app.game.save_data("battle").duplicate(true)
	for skip in [false,true]:
		clock.seek_elapsed(4.25);flock.update_from_clock()
		var transfer={"entry":-1.0,"returned":-1.0,"skipped":false}
		var enter=func():
			if app.world.visible:return
			var sky=app.stage.get_node("AmbientDrift")
			var distant=sky.get_node("HarborGulls")
			assert(clock.elapsed==sky.elapsed and distant.pose_buffer==flock.pose_buffer)
			assert(distant.multimesh.mesh==flock.multimesh.mesh and distant.material_override==flock.material_override)
			transfer.entry=sky.elapsed
		var exit=func():
			if app.stage.visible or app.world.visible:return
			var sky=app.stage.get_node("AmbientDrift")
			assert(clock.elapsed==sky.elapsed and flock.pose_buffer==sky.get_node("HarborGulls").pose_buffer)
			transfer.returned=clock.elapsed
		var request=func():
			if skip and not transfer.skipped and app.stage.visible and app.ui.has_node("CombatHUD"):
				var playback=app.ui.get_node_or_null("CombatPlayback")
				assert(playback!=null,"The next exchange can reuse the playback control name immediately")
				playback.request_skip();transfer.skipped=true
		app.world.visibility_changed.connect(enter)
		app.stage.visibility_changed.connect(exit)
		process_frame.connect(request)
		await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
		app.world.visibility_changed.disconnect(enter)
		app.stage.visibility_changed.disconnect(exit)
		process_frame.disconnect(request)
		assert(transfer.entry>4.25 and transfer.returned>transfer.entry and transfer.skipped==skip)
		assert(clock.elapsed>=transfer.returned and app.world.visible and not app.stage.visible)
	assert(app.game.save_data("battle")==state)
	print("PASS: %d bounded gull wing poses, one shared mesh and exact map/arena motion before and after normal and skipped combat"%samples)
