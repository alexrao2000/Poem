extends Node
## The tactical map and its combat arena share one environmental playhead.
const TRACKS={
 "village":"res://assets/audio/field-village.wav",
 "river":"res://assets/audio/field-river.wav",
 "forest":"res://assets/audio/field-forest.wav",
 "harbor":"res://assets/audio/field-harbor.wav",
 "road":"res://assets/audio/field-road.wav",
 "mountain":"res://assets/audio/field-mountain.wav",
 "furnace":"res://assets/audio/field-furnace.wav",
 "engine":"res://assets/audio/field-engine.wav",
 "abbey":"res://assets/audio/field-abbey.wav",
 "aqueduct":"res://assets/audio/field-aqueduct.wav",
 "observatory":"res://assets/audio/field-observatory.wav",
 "castle":"res://assets/audio/field-castle.wav",
}
const LOOP_FRAMES=176400
const MIX_OFFSET_DB=-14.0
const FADE_SECONDS=.22

var player: AudioStreamPlayer
var requested_theme=""
var playing_theme=""
var effects_db=-12.0
var fade: Tween

func _ready():
 player=AudioStreamPlayer.new()
 player.name="FieldAmbience"
 player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 add_child(player)

func select(theme: String):
 var next_theme=theme if TRACKS.has(theme) else ""
 if requested_theme==next_theme:return
 requested_theme=next_theme
 update_playback()

func set_volume(value: float):
 if is_equal_approx(effects_db,value):return
 effects_db=value
 update_playback()

func cancel_fade():
 if fade and fade.is_valid():fade.kill()
 fade=null

func clear_stream():
 player.stop()
 player.stream=null
 playing_theme=""

func stop():
 cancel_fade()
 requested_theme=""
 if is_instance_valid(player):clear_stream()

func set_gain(gain: float):
 player.volume_db=linear_to_db(maxf(.0001,gain))

func ramp(to_db: float) -> Tween:
 var transition=create_tween()
 transition.tween_method(set_gain,db_to_linear(player.volume_db),db_to_linear(to_db),FADE_SECONDS)
 return transition

func target_volume() -> float:
 return maxf(-79,effects_db+MIX_OFFSET_DB)

func start_requested():
 clear_stream()
 if requested_theme.is_empty() or effects_db<=-79:return
 var track=(load(TRACKS[requested_theme]) as AudioStreamWAV).duplicate() as AudioStreamWAV
 track.loop_mode=AudioStreamWAV.LOOP_FORWARD
 track.loop_begin=0
 track.loop_end=LOOP_FRAMES
 player.stream=track
 player.volume_db=-80
 playing_theme=requested_theme
 player.play()
 fade=ramp(target_volume())

func update_playback():
 cancel_fade()
 if effects_db<=-79:
  clear_stream()
 elif not player.playing:
  start_requested()
 elif playing_theme==requested_theme:
  fade=ramp(target_volume())
 else:
  fade=ramp(-80)
  fade.tween_callback(start_requested)

func _exit_tree():stop()
