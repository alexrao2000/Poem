extends Node
# One synchronized pair owns each act. Re-selecting an act leaves its playback
# untouched; chapter changes crossfade at most one outgoing pair into the new one.
var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/themes.json")).profiles
var player: AudioStreamPlayer
var score: AudioStreamSynchronized
var outgoing: AudioStreamPlayer
var fade: Tween
var current_id=""
var volume_db=-12.0

func configure(volume=-12.0):
 volume_db=volume;player=AudioStreamPlayer.new();player.name="CampaignScore"
 player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(player)
 select_chapter(0)

func profile_for(chapter: int) -> Dictionary:
 var chosen=profiles[0]
 for profile in profiles:
  if chapter>=int(profile.first_chapter):chosen=profile
 return chosen

func make_pair(profile: Dictionary) -> AudioStreamSynchronized:
 var pair=AudioStreamSynchronized.new();pair.stream_count=2
 for i in range(2):
  var mode="calm" if i==0 else "ablaze"
  var stream=(load(profile.arrangements[mode].path) as AudioStreamWAV).duplicate() as AudioStreamWAV
  stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=int(profile.frames)
  pair.set_sync_stream(i,stream)
 pair.set_sync_stream_volume(1,-60)
 return pair

func cancel_fade():
 if fade and fade.is_valid():fade.kill()
 if is_instance_valid(outgoing):
  outgoing.stop();remove_child(outgoing);outgoing.queue_free();outgoing=null

func select_chapter(chapter: int) -> bool:
 var profile=profile_for(chapter)
 if current_id==profile.id:return false
 var playing=player.playing;var previous_volume=player.volume_db
 cancel_fade()
 if playing:
  # Keep the actual old playhead running; recreating it would seek/restart the
  # decoder and briefly overlap a duplicate while the next score loads.
  outgoing=player;outgoing.name="OutgoingScore"
  player=AudioStreamPlayer.new();player.name="CampaignScore"
  player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(player)
 score=make_pair(profile);current_id=profile.id;player.stream=score;player.volume_db=volume_db
 if playing:
  player.volume_db=-80;player.play()
  var old=outgoing
  fade=create_tween().set_parallel(true)
  fade.tween_method(func(value):player.volume_db=linear_to_db(maxf(value,.0001)),.0001,db_to_linear(volume_db),.45)
  if is_instance_valid(old):
   fade.tween_method(func(value):old.volume_db=linear_to_db(maxf(value,.0001)),db_to_linear(previous_volume),.0001,.45)
  fade.chain().tween_callback(func():
   if is_instance_valid(old):old.stop();remove_child(old);old.queue_free()
   if outgoing==old:outgoing=null)
 return true

func set_volume(value: float):
 volume_db=value;cancel_fade();player.volume_db=value
