extends SceneTree
const Audio=preload("res://scripts/travel_audio.gd")
const Ground=preload("res://scripts/map_ground.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var contacts=[]
var followed: Node3D

func _initialize():call_deferred("run")

func record_contact(family: String):
 contacts.append({"family":family,"position":followed.position})

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-travel-audio-test.json";root.add_child(app);await process_frame
 var sound=app.travel_audio;var clips=[]
 assert(sound.voices.size()==2 and sound.voices.all(func(voice):return voice not in app.sfx_players and voice!=app.interface_audio.player),"Travel owns independent voices")
 for family in sound.streams:
  var stream=sound.streams[family]
  assert(stream is AudioStreamWAV and stream.mix_rate==22050 and not stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED)
  assert(stream.get_length()>=.099 and stream.get_length()<=.151 and stream.data not in clips,"Six distinct brief contact cues")
  clips.append(stream.data)
 for theme in ["village","river","forest","abbey","road","harbor","mountain","aqueduct","observatory","furnace","castle","engine"]:
  for tile in [".","p","=","f","h","o","+"]:
   var expected="wood" if tile=="=" else "hard" if Ground.surface_for(tile,theme) in [1,3] else "soft"
   assert(Audio.surface_for(tile,theme)==expected,"Contact material follows the same chapter surface as the renderer")
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 var unit=app.game.living("player")[0];followed=app.unit_nodes[unit.id]
 sound.step_played.connect(record_contact)
 var path: Array=[]
 for destination in app.game.reachable(unit):
  var candidate=app.game.movement_path(unit,destination)
  if candidate.size()==5:path=candidate;break
 assert(path.size()==5,"Fixture has a legal four-tile route")
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var score=app.score
 app.preview_route(path[-1]);assert(contacts.is_empty(),"Hovering a route never emits footsteps")
 await app.animate_map_move(unit,path)
 assert(contacts.size()==3,"Four tile movements produce two walking contacts and a final planted step")
 for i in range(3):
  var point=path[[1,3,4][i]]
  assert(contacts[i].position==app.map_position(point),"Travel cue coincides with reaching the actual tile")
  assert(contacts[i].family=="foot_"+Audio.surface_for(app.game.terrain(point),app.game.info().environment))
 assert(followed.player.state=="idle" and app.moving_id=="")
 assert(sound.voices[0].pitch_scale!=sound.voices[1].pitch_scale,"Alternating feet use restrained pitch variation")
 var count=contacts.size()
 await app.animate_map_move(unit,[path[0]])
 assert(contacts.size()==count,"Stationary selection emits no movement cue")
 for surface in [".","p","="]:
  assert(sound.step(surface,"Rider",1))
  assert(contacts[-1].family=="hoof_"+Audio.surface_for(surface),"Mounted units use paired hoof contacts")
 app.preferences.values.effects=0;app.apply_audio_preferences()
 assert(sound.voices.all(func(voice):return voice.volume_db==-80) and not sound.step("=","Rider",2),"Effects mute also silences travel")
 app.preferences.values.effects=.5;app.apply_audio_preferences()
 assert(is_equal_approx(sound.volume,app.preferences.volume_db("effects")-7),"Travel stays seven dB below the effects setting")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.score==score,"Travel never changes campaign, RNG or synchronized score ownership")
 await Shutdown.dispose(app);await process_frame
 print("PASS: six original contacts, 84 matching terrain/chapter surfaces, real movement timing, planted final step, mounted cues, isolated voices, volume/mute and unchanged simulation/score")
 quit()
