extends RefCounted
## Each procedural actor owns its expression and idle clock. The two unchanged
## atlases share UVs; the shader substitutes only the eyelids, never the mouth.
const SHADER=preload("res://assets/shaders/face-blink.gdshader")
const CLOSED=preload("res://assets/art/face-features-blink-v1.png")
const DURATION=.105
var surface: ShaderMaterial
var interval=4.0
var clock=0.0
var closed=false

func bind(face: MeshInstance3D,open_atlas: Texture2D,identity: String):
 surface=ShaderMaterial.new();surface.shader=SHADER
 surface.set_shader_parameter("open_face",open_atlas)
 surface.set_shader_parameter("closed_face",CLOSED)
 surface.set_shader_parameter("eyes_closed",false)
 face.material_override=surface
 var seed_value=absi(identity.hash())
 interval=3.1+(seed_value%1700)/1000.0
 clock=.3+((seed_value/1700)%2000)/1000.0

func update(delta: float,pose: String):
 if surface==null:return
 if pose!="idle":
  clock=DURATION
  set_closed(false)
  return
 clock=fposmod(clock+delta,interval)
 set_closed(clock<DURATION)

func set_closed(value: bool):
 if closed==value:return
 closed=value;surface.set_shader_parameter("eyes_closed",value)
