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
 await Shutdown.dispose(app);await process_frame
 print("PASS: three exact calm/Ablaze pairs, 12 chapter mappings, continuous combat mixing, bounded act crossfades, mute/interruption and independent effects")
 quit()

func verify_themes(app):
 var director=app.score_director
 assert(director.profiles.size()==3)
 for profile in director.profiles:
  var pair=director.make_pair(profile)
  var calm=pair.get_sync_stream(0);var ablaze=pair.get_sync_stream(1)
  assert(calm.stereo and ablaze.stereo and calm.mix_rate==profile.sample_rate and ablaze.mix_rate==profile.sample_rate,"Every theme uses the same stereo sample format")
  assert(roundi(calm.get_length()*calm.mix_rate)==profile.frames and roundi(ablaze.get_length()*ablaze.mix_rate)==profile.frames,"Paired arrangements have exactly the declared PCM frame count")
  for stream in [calm,ablaze]:assert(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_begin==0 and stream.loop_end==profile.frames,"Each independent stream loops on the shared frame boundary")
  assert(absf(calm.get_length()-float(profile.bars)*4*60/profile.bpm)<1.0/profile.sample_rate,"Actual audio duration matches the composition's bar/tempo timeline")
  for stream in [calm,ablaze]:verify_decoded_loop(stream)
 for chapter in range(12):
  assert(director.profile_for(chapter).id==["standard","road","dawnless"][chapter/4],"Each campaign act owns its paired theme")
 var roster=app.game.roster.duplicate(true);var rng=app.game.rng.state
 app.game.chapter=4;app.select_score_theme()
 assert(not app.music.playing and director.outgoing==null,"Loading a later act while stopped never starts unsolicited playback")
 app.music.play();var stable=app.score
 app.game.chapter=5;app.select_score_theme()
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
 app.game.chapter=8;app.game.start_battle();app.make_map();assert(director.current_id=="dawnless","Direct battle/load entry selects the matching act")
 await create_timer(.6).timeout
 assert(director.outgoing==null and app.music.playing,"Battlefield replacement completes its fade with only the new pair playing")
 assert(app.game.rng.state==rng and app.game.roster==roster,"Music changes leave the roster and gameplay RNG untouched")
 director.cancel_fade();app.music.stop()
 await create_timer(.2).timeout

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
