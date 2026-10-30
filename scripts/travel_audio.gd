extends Node
## Quiet terrain contacts use their own voices; movement never borrows a
## combat/UI channel or changes the phase-aligned score.
signal step_played(family: String)
var voices: Array=[]
var streams={}
var volume=-12.0
var next_voice=0

func configure(effects_volume: float):
 for kind in ["foot","hoof"]:
  for surface in ["soft","hard","wood"]:
   var family=kind+"_"+surface
   streams[family]=load("res://assets/audio/step_"+family+".wav")
 for index in range(2):
  var voice=AudioStreamPlayer.new();voice.name="TravelVoice"+str(index);add_child(voice);voices.append(voice)
 set_volume(effects_volume)

func set_volume(effects_volume: float):
 volume=-80.0 if effects_volume<=-79 else effects_volume-7.0
 for voice in voices:voice.volume_db=volume

static func surface_for(terrain: String,environment="village") -> String:
 if terrain=="=":return "wood"
 var surface=preload("res://scripts/map_ground.gd").surface_for(terrain,environment)
 return "hard" if surface in [1,3] else "soft"

func step(terrain: String,job: String,index: int,environment="village") -> bool:
 if volume<=-79 or voices.is_empty():return false
 var family=("hoof" if job=="Rider" else "foot")+"_"+surface_for(terrain,environment)
 var voice=voices[next_voice];next_voice=(next_voice+1)%voices.size()
 voice.stop();voice.stream=streams[family]
 voice.pitch_scale=.97 if index%2 else 1.03
 voice.play();step_played.emit(family);return true

func _exit_tree():
 for voice in voices:
  if is_instance_valid(voice):voice.stop()
