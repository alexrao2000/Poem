extends RefCounted
# Each actor owns its expression and idle clock. Defeat holds the existing
# closed-eye artwork; critical preparation carries focused brows/eyes through
# release. Atlases share UVs and leave the original nose and mouth untouched.

const SHADER=preload("res://assets/shaders/face-blink.gdshader")
const CLOSED=preload("res://assets/art/face-features-blink-v1.png")
const FOCUSED=preload("res://assets/art/face-features-focus-v1.png")
const DURATION=.105
var surface: ShaderMaterial
var interval=4.0
var clock=0.0
var closed=false
var focused=false

func bind(face: MeshInstance3D,open_atlas: Texture2D,identity: String):
 surface=ShaderMaterial.new();surface.shader=SHADER
 surface.set_shader_parameter("open_face",open_atlas)
 surface.set_shader_parameter("closed_face",CLOSED)
 surface.set_shader_parameter("focused_face",FOCUSED)
 surface.set_shader_parameter("focused",false)
 surface.set_shader_parameter("eyes_closed",false)
 face.material_override=surface
 var seed_value=absi(identity.hash())
 interval=3.1+(seed_value%1700)/1000.0
 clock=.3+((seed_value/1700)%2000)/1000.0

func update(delta: float,pose: String):
 if surface==null:return
 if pose in ["critical_windup","critical_throw_windup"]:set_focused(true)
 elif pose not in ["strike","throw"]:set_focused(false)
 if pose!="idle":
  clock=DURATION
  set_closed(pose=="down")
  return
 clock=fposmod(clock+delta,interval)
 set_closed(clock<DURATION)

func set_closed(value: bool):
 if closed==value:return
 closed=value;surface.set_shader_parameter("eyes_closed",value)

func set_focused(value: bool):
 if focused==value:return
 focused=value;surface.set_shader_parameter("focused",value)
