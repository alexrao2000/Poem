extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var calm=load("res://assets/calm.wav") as AudioStreamWAV
 var ablaze=load("res://assets/ablaze.wav") as AudioStreamWAV
 assert(calm.stereo and ablaze.stereo,"Both arrangements use stereo")
 assert(calm.mix_rate==ablaze.mix_rate and calm.get_length()==ablaze.get_length(),"Exact shared decoded sample timeline")
 assert(calm.get_length()>70 and calm.get_length()<72,"Full 32-bar arrangement")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test_audio-ui-save.json";root.add_child(app);await process_frame
 var expected=roundi(calm.get_length()*calm.mix_rate)
 for i in range(2):
  var track=app.score.get_sync_stream(i)
  assert(track.loop_end==expected,"Loop endpoint uses decoded frames, never compressed byte count")
  assert(track.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 for name_value in ["swing","hit","critical","heal","magic","phase","select","guard","cutin","levelup"]:
  assert(app.sfx_streams[name_value]!=null,"Effect resource available")
 assert(app.sfx_players.size()>=2 and app.sfx_players[0]!=app.sfx_players[1],"Independent effect channels")
 var release_data=[]
 for family in ["sword","axe","lance","bow","ember","gale","thunder"]:
  var stream=app.sfx_streams["release_"+family]
  assert(stream is AudioStreamWAV and stream.mix_rate==22050 and not stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Release cues are short nonlooping mono effects")
  assert(stream.get_length()>=.13 and stream.get_length()<=.35)
  assert(not stream.data in release_data,"Each weapon/element owns different audio")
  release_data.append(stream.data)
 await verify_elemental_contacts(app)
 assert(app.sfx_streams.guard.get_length()>.2 and app.sfx_streams.guard.get_length()<.23,"Guard is a short distinct steel accent")
 assert(app.sfx_streams.cutin.get_length()>.31 and app.sfx_streams.cutin.get_length()<.33,"Portrait cue ends before the strike resumes")
 assert(app.sfx_streams.levelup.get_length()>.71 and app.sfx_streams.levelup.get_length()<.73,"Level-up bell ends within the stat reveal")
 await verify_themes(app)
 await verify_authored_themes(app)
 await verify_chapter_exchange(app,2,"standard","greywood",Vector2i(3,3),Vector2i(4,3))
 await verify_chapter_exchange(app,3,"greywood","abbey",Vector2i(11,4),Vector2i(12,4))
 await verify_chapter_exchange(app,5,"road","glass_harbor",Vector2i(8,4),Vector2i(9,4))
 await verify_chapter_exchange(app,8,"road","starfall",Vector2i(9,1),Vector2i(10,1))
 await verify_chapter_exchange(app,11,"dawnless","sun_engine",Vector2i(9,2),Vector2i(10,2))
 await verify_quick_battles(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: eight exact Calm/Ablaze pairs, 12 chapter mappings, compensated arrangement curve and seamless reversal, continuous combat mixing, bounded theme crossfades, mute/interruption and independent effects")
 quit()

func verify_themes(app):
 var director=app.score_director
 assert(director.profiles.size()==8)
 for profile in director.profiles:
  var pair=director.make_pair(profile)
  var calm=pair.get_sync_stream(0);var ablaze=pair.get_sync_stream(1)
  assert(calm.stereo and ablaze.stereo and calm.mix_rate==profile.sample_rate and ablaze.mix_rate==profile.sample_rate,"Every theme uses the same stereo sample format")
  assert(roundi(calm.get_length()*calm.mix_rate)==profile.frames and roundi(ablaze.get_length()*ablaze.mix_rate)==profile.frames,"Paired arrangements have exactly the declared PCM frame count")
  for stream in [calm,ablaze]:assert(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_begin==0 and stream.loop_end==profile.frames,"Each independent stream loops on the shared frame boundary")
  assert(absf(calm.get_length()-float(profile.bars)*profile.get("beats_per_bar",4)*60/profile.bpm)<1.0/profile.sample_rate,"Actual audio duration matches the composition's meter and tempo")
  for stream in [calm,ablaze]:verify_decoded_loop(stream)
 for chapter in range(12):
  var theme={2:"greywood",3:"abbey",5:"glass_harbor",8:"starfall",11:"sun_engine"}.get(chapter,["standard","road","dawnless"][chapter/4])
  assert(app.campaign_score_profile(chapter).id==theme)
 assert(director.profile_for(11).id=="dawnless","An explicit finale theme does not change the catalog default")
 var roster=app.game.roster.duplicate(true);var rng=app.game.rng.state
 app.game.chapter=4;app.select_score_theme()
 assert(not app.music.playing and director.outgoing==null,"Loading a later act while stopped never starts unsolicited playback")
 app.music.play();var stable=app.score
 app.game.chapter=6;app.select_score_theme()
 assert(app.score==stable and app.music.stream==stable and director.outgoing==null,"Moving within the same act cannot replace/restart its active pair")
 var old_player=app.music;var old_playback=old_player.get_stream_playback()
 app.game.chapter=8;app.select_score_theme()
 assert(app.score!=stable and app.music.stream==app.score and director.outgoing.stream==stable,"Changing act retains the fading old pair")
 assert(director.outgoing==old_player and director.outgoing.get_stream_playback()==old_playback,"Act changes keep the actual outgoing decoder/playhead instead of restarting a duplicate")
 app.music_mix(true);await create_timer(.5).timeout;await process_frame
 assert(director.outgoing==null and is_equal_approx(app.music.volume_db,app.preferences.volume_db("music")),"Act crossfade cleans up and restores the configured volume")
 assert(absf(app.score.get_sync_stream_volume(1))<.01 and app.score.get_sync_stream_volume(0)<-50,"A combat transition during an act fade still reaches the new Ablaze arrangement")
 stable=app.score;var playing_position=app.music.get_playback_position()
 app.music_mix(false);await create_timer(.5).timeout
 assert(app.score==stable and app.music.stream==stable and app.music.get_playback_position()>=playing_position,"Calm/Ablaze mixing leaves the live pair and its playhead running")
 app.game.chapter=4;app.select_score_theme();app.game.chapter=0;app.select_score_theme()
 assert(director.get_children().filter(func(node):return node is AudioStreamPlayer).size()==2,"Rapid act changes keep at most two live audio players")
 app.preferences.values.music=0;app.apply_audio_preferences();await create_timer(.5).timeout
 assert(app.music.volume_db==-80 and director.outgoing==null,"Muting during a crossfade cancels every outgoing source and cannot be undone by a pending tween")
 app.preferences.values.music=1;app.apply_audio_preferences();assert(app.music.volume_db==-12)
 app.game.chapter=4;app.show_camp();assert(director.current_id=="road","Camp/dialogue entry selects the new act before its opening scene")
 if app.screen=="dialogue":app.finish_dialogue()
 app.game.chapter=8;app.game.start_battle();app.make_map();assert(director.current_id=="starfall","Direct battle/load entry selects the assigned observatory theme")
 await create_timer(.6).timeout
 assert(director.outgoing==null and app.music.playing,"Battlefield replacement completes its fade with only the new pair playing")
 assert(app.game.rng.state==rng and app.game.roster==roster,"Music changes leave the roster and gameplay RNG untouched")
 await verify_arrangement_curve(app)
 director.cancel_fade();app.music.stop()
 await create_timer(.2).timeout

func verify_authored_themes(app):
 var chapters=app.game.content.chapters
 var first=chapters[0].duplicate(true);var third=chapters[2].duplicate(true)
 chapters[0].score_theme="road";chapters[2].score_theme="dawnless"
 app.game.chapter=0;app.select_score_theme()
 assert(app.score_director.current_id=="road" and not app.music.playing)
 app.music.play(9);var pair=app.score;var voice=app.music;var decoder=voice.get_stream_playback()
 app.game.chapter=6;app.select_score_theme()
 assert(app.score==pair and app.music==voice and app.music.get_stream_playback()==decoder,
  "The same authored theme keeps its decoder across separated chapters")
 app.game.chapter=2
 var save=app.game.save_data("camp");var rng=app.game.rng.state
 app.select_score_theme()
 assert(app.score_director.current_id=="dawnless" and app.score_director.outgoing==voice)
 assert(app.score_director.outgoing.get_stream_playback()==decoder)
 assert(app.game.save_data("camp")==save and app.game.rng.state==rng)
 chapters[0].erase("score_theme");chapters[2].score_theme="unassigned"
 assert(app.campaign_score_profile(0).id=="standard" and app.campaign_score_profile(2).id=="standard",
  "An omitted or unknown theme uses the corresponding catalog default")
 chapters[0]=first;chapters[2]=third
 app.score_director.stop()
 await process_frame
 print("PASS: authored chapter themes select their actual paired streams, reuse the live decoder across distant chapters and fall back for omitted or unknown IDs")

func verify_chapter_exchange(app,chapter: int,previous_theme: String,theme: String,ally_tile: Vector2i,foe_tile: Vector2i):
 app.game.chapter=chapter-1;app.select_score_theme()
 app.music.play(8.0)
 var outgoing=app.music;var previous_decoder=outgoing.get_stream_playback()
 assert(app.score_director.current_id==previous_theme and previous_decoder!=null)
 app.game.chapter=chapter;app.game.start_battle()
 var ally=app.game.living("player")[0]
 var foe=app.game.living("enemy")[0]
 ally.x=ally_tile.x;ally.y=ally_tile.y;foe.x=foe_tile.x;foe.y=foe_tile.y
 app.make_map();app.show_battle()
 assert(app.score_director.current_id==theme)
 assert(app.score_director.outgoing==outgoing and outgoing.get_stream_playback()==previous_decoder)
 await create_timer(.52).timeout
 assert(app.score_director.outgoing==null and app.music.playing)
 app.preferences.values.combat="all"
 app.preferences.values.combat_speed="fast"
 app.music.seek(12.0);await process_frame
 var pair=app.score;var voice=app.music;var decoder=voice.get_stream_playback()
 assert(decoder!=null)
 var state=app.game.save_data("battle").duplicate(true)
 var status={"finished":false,"saw_arena":false,"held_ablaze":false}
 var events=[{"actor":ally.id,"target":foe.id,"damage":1,"remaining":foe.hp-1,"hit":true,"crit":false}]
 (func():
  await app.cinematic(ally,foe,events,{ally.id:ally.hp,foe.id:foe.hp})
  status.finished=true).call()
 var deadline=Time.get_ticks_msec()+15000
 while not status.finished and Time.get_ticks_msec()<deadline:
  await process_frame
  assert(app.score==pair and app.music==voice and voice.get_stream_playback()==decoder)
  if app.stage.visible and app.ui.has_node("CombatHUD"):
   status.saw_arena=true
   if absf(pair.get_sync_stream_volume(1))<.01:status.held_ablaze=true
 assert(status.finished and status.saw_arena and status.held_ablaze)
 await create_timer(.52).timeout
 assert(app.score==pair and voice.get_stream_playback()==decoder and voice.get_playback_position()>12.0)
 assert(is_zero_approx(app.score_director.arrangement_blend) and app.game.save_data("battle")==state)
 print("PASS: a full %s exchange switches to Ablaze and back on the same synchronized decoder"%theme)

func verify_arrangement_curve(app):
 var director=app.score_director;var pair=app.score
 var decoder=app.music.get_stream_playback()
 assert(decoder!=null)
 for blend in [0.0,.25,.5,.75,1.0]:
  director.apply_arrangement(blend)
  var calm=db_to_linear(pair.get_sync_stream_volume(0));var ablaze=db_to_linear(pair.get_sync_stream_volume(1))
  if blend==0.0 or blend==1.0:
   assert(is_equal_approx(maxf(calm,ablaze),1.0) and is_equal_approx(minf(calm,ablaze),.001))
  else:
   assert(absf(calm*calm+ablaze*ablaze+.76*calm*ablaze-1.0)<.0001)
   assert(absf(ablaze/(calm+ablaze)-blend)<.0001)
 director.apply_arrangement(.40)
 app.music_mix(true)
 await create_timer(.15).timeout
 var heard=director.arrangement_blend
 assert(heard>.40 and heard<1.0 and app.music_transition.is_running())
 var calm=pair.get_sync_stream_volume(0);var ablaze=pair.get_sync_stream_volume(1)
 app.music_mix(false)
 assert(director.arrangement_blend==heard and pair.get_sync_stream_volume(0)==calm and pair.get_sync_stream_volume(1)==ablaze,
  "Replacing an in-flight fade starts at its exact current balance")
 await create_timer(.53).timeout
 assert(director.arrangement_blend==0.0 and pair.get_sync_stream_volume(0)==0 and pair.get_sync_stream_volume(1)<-50)
 assert(app.score==pair and app.music.get_stream_playback()==decoder,"Gain curves do not seek or restart the live score")

func verify_quick_battles(app):
 app.preferences.values.combat="map"
 app.game.chapter=1;app.game.start_battle()
 var ally=app.game.living("player")[0]
 var foe=app.game.living("enemy")[1]
 ally.x=8;ally.y=4;foe.x=9;foe.y=4
 app.make_map();app.show_battle()
 app.music.play()
 await process_frame
 var score=app.score
 var decoder=app.music.get_stream_playback()
 assert(decoder!=null)
 var state=app.game.save_data("battle").duplicate(true)
 for _repeat in range(2):
  var completed=[false]
  var contact=[{"actor":ally.id,"target":foe.id,"damage":1,"remaining":foe.hp,"hit":true,"crit":false}]
  (func():
   await app.cinematic(ally,foe,contact,{ally.id:ally.hp,foe.id:foe.hp})
   completed[0]=true).call()
  var peak=-80.0
  var deadline=Time.get_ticks_msec()+3500
  while not completed[0] and Time.get_ticks_msec()<deadline:
   await process_frame
   peak=maxf(peak,score.get_sync_stream_volume(1))
   assert(app.score==score and app.music.get_stream_playback()==decoder,"Quick map combat keeps the paired score decoder")
   assert(not app.stage.visible and not app.ui.has_node("CombatPlayback"))
  assert(completed[0] and peak>-12,"Ablaze gain rises during the actual map exchange")
  assert(app.music_transition.is_running(),"Every exchange immediately starts the return to Calm")
 await create_timer(.55).timeout;await process_frame
 assert(absf(score.get_sync_stream_volume(0))<.01 and score.get_sync_stream_volume(1)<-50)
 assert(app.score==score and app.music.get_stream_playback()==decoder and app.game.save_data("battle")==state)
 print("PASS: consecutive Quick map exchanges blend Ablaze and restore Calm on the same live decoder")

func verify_decoded_loop(stream: AudioStreamWAV):
 # Exercise the actual QOA decoder through one complete loop, without waiting
 # in real time or assuming that compressed bytes have a PCM sample stride.
 var playback=stream.instantiate_playback();playback.start()
 var rate=AudioServer.get_mix_rate();var elapsed=0
 var frames=roundi((stream.get_length()+.5)*rate)
 while elapsed<frames:
  var chunk=mini(4096,frames-elapsed)
  var mixed=playback.mix_audio(1,chunk);elapsed+=mixed.size()
  assert(mixed.size()==chunk,"The decoder supplies a complete continuous stream")
  var expected=fmod(float(elapsed)/rate,stream.get_length())
  var difference=absf(playback.get_playback_position()-expected)
  difference=minf(difference,absf(difference-stream.get_length()))
  assert(difference<.015,"Decoded playhead follows the full composition and wraps only at its end")
 assert(playback.get_playback_position()>.48 and playback.get_playback_position()<.52,"Every arrangement reaches the beginning again after its complete musical loop")
 playback.stop()

func verify_elemental_contacts(app):
 var caster=app.game.roster.filter(func(unit):return unit.weapon=="magic")[0].duplicate(true)
 var data=[]
 for element in ["ember","gale","thunder"]:
  caster.item=element;var stream=app.sfx_streams["impact_"+element]
  assert(stream is AudioStreamWAV and stream.mix_rate==22050 and not stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED)
  assert(stream.get_length()>=.37 and stream.get_length()<=.49 and stream.data!=app.sfx_streams["release_"+element].data and not stream.data in data,"Each contact has a distinct short original nonlooping sample")
  data.append(stream.data)
  var playback=stream.instantiate_playback();playback.start()
  var mixed=playback.mix_audio(1,ceili(stream.get_length()*AudioServer.get_mix_rate())+128)
  var peak=0.0;var energy=0.0;var dc=0.0
  for sample in mixed:
   peak=maxf(peak,absf(sample.x));energy+=sample.x*sample.x;dc+=sample.x
  assert(peak>.25 and peak<.62 and sqrt(energy/mixed.size())>.025 and sqrt(energy/mixed.size())<.09,"Decoded cues retain transient headroom and a quieter sustained body")
  assert(absf(dc/mixed.size())<.002 and mixed[-1].length()<.001,"Decoded contact has bounded DC and returns to silence")
  playback.stop()
  for hit in [false,true]:
   for damage in [0,3]:
    for critical in [false,true]:
     var expected=[] if not hit else ["guard"] if damage<=0 else ["impact_"+element,"critical"] if critical else ["impact_"+element]
     assert(app.combat_contact_sounds(caster,{"hit":hit,"damage":damage,"crit":critical})==expected,"Resolved hit/damage/critical state chooses elemental contact without false impacts")
 assert(app.combat_contact_sounds({}, {"hit":true,"damage":3,"crit":false})==["hit"],"Missing actor data retains a safe generic contact")
