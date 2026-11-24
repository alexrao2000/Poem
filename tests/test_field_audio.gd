extends SceneTree
const Field=preload("res://scripts/field_audio.gd")
const GreywoodShelter=preload("res://scripts/greywood_shelter.gd")
const CinderfordMarket=preload("res://scripts/cinderford_market.gd")
const Shutdown=preload("helpers/game_shutdown.gd")

func _initialize():call_deferred("run")

func settle(field):
 var deadline=Time.get_ticks_msec()+2500
 while field.fade and field.fade.is_running() and Time.get_ticks_msec()<deadline:
  await process_frame
 assert(not field.fade or not field.fade.is_running(),"The ambience ramp settled within its bounded time")

func verify_voice(field,theme: String):
 var stream=field.player.stream
 assert(field.player.playing and field.playing_theme==theme and stream is AudioStreamWAV)
 assert(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.stereo and stream.mix_rate==22050)
 assert(stream.data.size()==Field.LOOP_FRAMES*4 and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 assert(stream.loop_begin==0 and stream.loop_end==Field.LOOP_FRAMES and is_equal_approx(stream.get_length(),8))
 assert(field.get_child_count()==1)

func run():
 var field=Field.new();root.add_child(field)
 field.select("river")
 await settle(field)
 verify_voice(field,"river")
 assert(is_equal_approx(field.player.volume_db,-26))
 var river_track=field.player.stream
 var river_decoder=field.player.get_stream_playback()
 assert(river_decoder!=null)
 field.select("river")
 assert(field.player.stream==river_track and field.player.get_stream_playback()==river_decoder)
 field.select("forest")
 await process_frame
 field.select("river")
 await settle(field)
 assert(field.player.stream==river_track and field.player.get_stream_playback()==river_decoder,"Returning during a fade retains the live decoder")
 field.select("harbor")
 await settle(field)
 verify_voice(field,"harbor")
 assert(field.player.stream!=river_track and is_equal_approx(field.player.volume_db,-26))
 field.set_volume(-80)
 assert(not field.player.playing and field.player.stream==null)
 field.select("forest")
 assert(not field.player.playing)
 field.set_volume(-18)
 await settle(field)
 verify_voice(field,"forest")
 assert(is_equal_approx(field.player.volume_db,-32))
 field.select("menu")
 await settle(field)
 assert(field.playing_theme.is_empty() and field.player.stream==null and not field.player.playing)
 field.queue_free();await process_frame

 var viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 root.add_child(viewport)
 var app=load("res://main.tscn").instantiate()
 app.settings_path="";app.save_path="/private/tmp/poem-field-audio-%d.json"%Time.get_ticks_usec()
 viewport.add_child(app);await process_frame
 assert(not app.field_audio.player.playing,"Title has no battlefield audio")
 var active_decoder: AudioStreamPlayback
 var locations=[
  Vector2i(8,4),Vector2i(3,4),Vector2i(4,4),Vector2i(3,4),
  Vector2i(8,3),Vector2i(5,4),Vector2i(3,4),Vector2i(3,4),
  Vector2i(4,2),Vector2i(3,4),Vector2i(3,4),Vector2i(10,4),
 ]
 var themes=app.game.content.chapters.map(func(chapter):return chapter.environment)
 assert(locations.size()==themes.size() and Field.TRACKS.size()==themes.size())
 for chapter in locations.size():
  active_decoder=await verify_combat_voice(app,chapter,themes[chapter],locations[chapter])
 app.preferences.values.music=0
 app.apply_audio_preferences()
 assert(app.field_audio.player.get_stream_playback()==active_decoder)
 app.preferences.values.effects=0
 app.apply_audio_preferences()
 assert(not app.field_audio.player.playing and app.field_audio.player.stream==null)
 app.preferences.values.effects=1
 app.apply_audio_preferences()
 await settle(app.field_audio)
 verify_voice(app.field_audio,"engine")
 app.show_camp()
 await settle(app.field_audio)
 assert(not app.field_audio.player.playing and app.field_audio.player.stream==null)
 await Shutdown.dispose(app)
 viewport.queue_free();await process_frame
 print("PASS: twelve eight-second stereo loops, bounded one-voice fades, rapid retargeting and mute, combat and tactical menu continuity in all twelve chapters, score and save isolation")
 quit()

func verify_combat_voice(app,chapter: int,theme: String,point: Vector2i) -> AudioStreamPlayback:
 app.game.chapter=chapter
 app.game.start_battle()
 var ally=app.game.living("player")[0]
 var foe=app.game.living("enemy")[1]
 assert(app.game.terrain(point) not in ["#","~"] and app.game.terrain(point+Vector2i.RIGHT) not in ["#","~"])
 ally.x=point.x;ally.y=point.y;foe.x=point.x+1;foe.y=point.y
 app.make_map();app.show_battle()
 await settle(app.field_audio)
 verify_voice(app.field_audio,theme)
 var score=app.score
 app.music.play();await process_frame
 var music_decoder=app.music.get_stream_playback()
 assert(music_decoder!=null)
 var ambience=app.field_audio.player.stream
 var decoder=app.field_audio.player.get_stream_playback()
 var events=app.game.combat(ally,foe)
 assert(not events.is_empty())
 var frozen=app.game.save_data("battle").duplicate(true)
 app.busy=true
 app.cinematic(ally,foe,events)
 for frame in range(180):
  if app.stage.visible:break
  await process_frame
 assert(app.stage.visible and app.field_audio.player.stream==ambience and app.field_audio.player.get_stream_playback()==decoder)
 if theme=="village":
  verify_canopy_batches(app,"CinderfordMarketStall",CinderfordMarket.canvas_mesh(),CinderfordMarket.paint())
 if theme=="forest":
  verify_canopy_batches(app,"GreywoodShelter",GreywoodShelter.canvas_shape(),GreywoodShelter.paint())
 if theme=="road":
  var canal_material=app.scenery.water_material("road")
  assert(app.stage.get_children().any(func(node):return node is MeshInstance3D and node.material_override==canal_material),
   "The Kingsroad decoder persists in the actual canal backdrop")
 app.ui.get_node("CombatPlayback").request_skip()
 for frame in range(180):
  if not app.ui.has_node("CombatPlayback"):break
  await process_frame
 assert(app.world.visible and not app.stage.visible and not app.ui.has_node("CombatPlayback"))
 assert(app.field_audio.player.get_stream_playback()==decoder and app.score==score and app.music.get_stream_playback()==music_decoder)
 assert(app.game.save_data("battle")==frozen,"Field playback cannot change a resolved action")
 app.busy=false
 var ready=app.game.living("player").filter(func(unit):return app.game.can_act(unit))
 assert(not ready.is_empty())
 var previous_selection=app.selected
 app.selected=ready[0]
 for menu in ["triage","tile_units"]:
  if menu=="triage":app.show_triage()
  else:app.show_tile_units(app.game.pos(app.selected))
  assert(app.screen==menu)
  await create_timer(Field.FADE_SECONDS+.05).timeout
  assert(app.field_audio.requested_theme==theme and app.field_audio.player.stream==ambience)
  assert(app.field_audio.player.get_stream_playback()==decoder and app.music.get_stream_playback()==music_decoder)
  app.show_battle()
  assert(app.field_audio.player.get_stream_playback()==decoder and app.game.save_data("battle")==frozen)
 app.selected=previous_selection
 app.update_side();app.highlight()
 return decoder

func verify_canopy_batches(app,name: String,canvas: Mesh,material: Material):
 for landscape in [app.world,app.stage]:
  var prop=landscape.find_child(name,true,false)
  assert(prop!=null)
  var batches=landscape.get_children().filter(func(node):
   return node is MeshInstance3D and node.material_override==material)
  assert(batches.size()==1 and batches[0].mesh.surface_get_array_len(0)==canvas.surface_get_array_len(0))
  var expected=prop.global_transform*canvas.get_aabb()
  assert((batches[0].global_transform*batches[0].mesh.get_aabb()).is_equal_approx(expected),
   "A live cut retains the canvas after scenery is batched")
