extends SceneTree
const Audio=preload("res://scripts/travel_audio.gd")
const Dust=preload("res://scripts/combat_dust.gd")
const Ground=preload("res://scripts/map_ground.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var contacts=[]
var followed: Node3D
var dust_contacts=[]

func watch_dust(node):
 if not node is Dust:return
 await process_frame
 assert(node.puffs.size()==2 and node.material.albedo_color.a>0,"Muted infantry approach still creates visible ground accents")
 assert(absf(node.global_position.y)<.001,"Live contact effect starts on the arena floor")
 dust_contacts.append(weakref(node))

func verify_dust():
 var stage=Node3D.new();root.add_child(stage);stage.position=Vector3(35,.4,2);stage.rotation.y=.4
 var point=Vector3(36,.4,3);var retained=[]
 for surface in ["soft","hard","wood"]:
  for mounted in [false,true]:
   for direction in [-1,1]:
    var forward=Vector3(direction,0,0)
    var dust=Dust.spawn(stage,point,forward,mounted,surface,1)
    if surface=="wood":
     assert(dust==null,"Wooden decks do not emit earth dust");continue
    dust.set_process(false);retained.append(weakref(dust))
    assert(dust.global_position.is_equal_approx(point) and dust.puffs.size()==(3 if mounted else 2))
    assert(dust.material.billboard_keep_scale and not dust.material.no_depth_test and dust.material.disable_fog,"Small dust billboards retain scale, scene occlusion and transparent fog edges")
    assert(dust.material.blend_mode==BaseMaterial3D.BLEND_MODE_MIX,"Dust is softly opaque rather than luminous")
    var initial=dust.material.albedo_color.a
    for step in range(6):
     dust.update_puffs(step/5.0)
     for puff in dust.puffs:
      var center=puff.node.position
      assert(center.y-puff.node.scale.y*.5>=0,"Entire upright puff stays above the contact plane")
      assert(center.y<.3 and center.length()<.4,"Brief contact accents stay below the knees")
      assert((dust.global_basis*puff.drift).dot(forward)<0,"Dust drifts opposite actual movement, including retreat")
      assert(puff.node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    assert(dust.material.albedo_color.a==0 and initial<.5,"Contact fade ends fully transparent")
    dust._process(Dust.LIFETIME+.01)
 await process_frame
 assert(retained.all(func(reference):return reference.get_ref()==null),"Every expired contact releases its meshes and material")
 var hidden=Dust.spawn(stage,point,Vector3.RIGHT,false,"soft",0);var reference=weakref(hidden)
 stage.hide();hidden._process(0);await process_frame
 assert(reference.get_ref()==null,"Hidden cinematic effects release immediately")
 stage.queue_free();await process_frame

func _initialize():call_deferred("run")

func record_contact(family: String):
 contacts.append({"family":family,"position":followed.position})

func run():
 await verify_dust()
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
 sound.step_played.disconnect(record_contact)
 app.preferences.values.effects=0;app.apply_audio_preferences();app.stage.child_entered_tree.connect(watch_dust)
 var dust_a=app.game.units[0];var dust_b=app.game.living("enemy")[0];dust_a.x=8;dust_a.y=4;dust_b.x=9;dust_b.y=4
 saved=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 await app.cinematic(dust_a,dust_b,[{"actor":dust_a.id,"target":dust_b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{dust_a.id:20,dust_b.id:20})
 assert(dust_contacts.size()==2 and dust_contacts.all(func(reference):return reference.get_ref()==null),"Actual muted sword approach emits exactly its two foot contacts and cleans both up")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Ground accents leave resolved simulation untouched")
 app.stage.child_entered_tree.disconnect(watch_dust)
 app.preferences.values.effects=.5;app.apply_audio_preferences()
 app.game.chapter=5;app.game.start_battle();app.make_map();app.show_battle()
 var a=app.game.units[0];var b=app.game.living("enemy")[0]
 a.job="Rider";a.weapon="lance";a.item="iron_lance";a.x=8;a.y=4;b.x=9;b.y=4
 var arena_cues=[];sound.step_played.connect(func(family):arena_cues.append(family))
 saved=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 assert(not arena_cues.is_empty() and arena_cues.all(func(family):return family=="hoof_wood"),"Actual mounted harbor approach uses hoof contacts on the wooden arena floor")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Arena contacts do not change campaign outcomes")
 await Shutdown.dispose(app);await process_frame
 print("PASS: six original contacts, 84 matching terrain/chapter surfaces, real movement timing, planted final step, mounted map/harbor arena cues, grounded dust/wood suppression, muted visual contacts, isolated voices, volume/mute and unchanged simulation/score")
 quit()
