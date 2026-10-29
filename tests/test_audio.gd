extends SceneTree
func _initialize():call_deferred("run")
func run():
 var calm=load("res://assets/calm.wav") as AudioStreamWAV
 var ablaze=load("res://assets/ablaze.wav") as AudioStreamWAV
 assert(calm.stereo and ablaze.stereo,"Both arrangements use stereo")
 assert(calm.mix_rate==ablaze.mix_rate and calm.data.size()==ablaze.data.size(),"Exact shared sample timeline")
 assert(calm.get_length()>70 and calm.get_length()<72,"Full 32-bar arrangement")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-test_audio-ui-save.json";root.add_child(app);await process_frame
 var expected=calm.data.size()/4
 for i in range(2):
  var track=app.score.get_sync_stream(i)
  assert(track.loop_end==expected,"Stereo loop endpoint is in frames, not samples")
  assert(track.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 for name_value in ["swing","hit","critical","heal","magic","phase","select"]:
  assert(app.sfx_streams[name_value]!=null,"Effect resource available")
 assert(app.sfx_players.size()>=2 and app.sfx_players[0]!=app.sfx_players[1],"Independent effect channels")
 app.queue_free();await process_frame
 print("PASS: matched stereo score timelines, loop frame counts and independent combat effects")
 quit()
