extends Node
## A dedicated interface voice never steals a combat-effect channel. Hover and
## keyboard focus share one cooldown; confirmations briefly suppress hover.
var player: AudioStreamPlayer
var streams={}
var last_move=-1000
var last_press=-1000
var quiet_until=0

func configure(volume: float):
 player=AudioStreamPlayer.new();player.name="InterfaceVoice";add_child(player)
 player.volume_db=volume
 for key in ["move","confirm","back"]:streams[key]=load("res://assets/audio/ui_"+key+".wav")

func cue(kind: String,now=-1) -> bool:
 if player==null or player.volume_db<=-79 or not streams.has(kind):return false
 if now<0:now=Time.get_ticks_msec()
 if kind=="move":
  if now<quiet_until or now-last_move<70:return false
  last_move=now
 else:
  if now-last_press<30:return false
  last_press=now;quiet_until=now+120
 player.stop();player.stream=streams[kind];player.play();return true

func watch(button: BaseButton,kind="confirm"):
 button.mouse_entered.connect(func():
  if not button.disabled:cue("move"))
 button.focus_entered.connect(func():
  if not button.disabled:cue("move"))
 button.pressed.connect(func():
  if not button.disabled:cue(kind))

static func button_tone(caption: String) -> String:
 for prefix in ["Return","Cancel","Back","Undo"]:
  if caption.begins_with(prefix):return "back"
 return "confirm"

func _exit_tree():
 if is_instance_valid(player):player.stop()
