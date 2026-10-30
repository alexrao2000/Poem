extends RefCounted
## Bind only cape materials after batching/outline creation. Every actor owns
## its two passes, while body materials remain shared and undeformed.
const MARGIN=.10
const DRIVE={"advance":.9,"strike":.75,"recover":.55,"windup":.35,"critical_windup":.45,"throw":.7,"evade":.8,"hit":.65,"critical_hit":.9}
var surfaces: Array[ShaderMaterial]=[]
var drive=0.0

func bind(actor):
 surfaces.clear()
 var cape=actor.bone("Cape")
 if cape==null:return
 for mesh in cape.find_children("*","MeshInstance3D",true,false):
  var material=mesh.material_override
  if not material is ShaderMaterial or material.get_shader_parameter("cloth_amount")!=1.0:continue
  surfaces.append(material)
  if material.next_pass is ShaderMaterial:surfaces.append(material.next_pass)
  mesh.extra_cull_margin=maxf(mesh.extra_cull_margin,MARGIN)
 update(actor.elapsed,actor.pose_name,0.0)

func update(clock: float,pose: String,dt: float):
 if surfaces.is_empty():return
 var target=DRIVE.get(pose,.12)
 drive=lerpf(drive,target,1.0-exp(-maxf(0,dt)*7.0))
 for material in surfaces:
  material.set_shader_parameter("cloth_clock",clock)
  material.set_shader_parameter("cloth_drive",drive)
