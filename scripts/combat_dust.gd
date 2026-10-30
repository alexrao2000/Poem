extends Node3D
## Small grounded contact accents, separate from audio and gameplay randomness.

const Impact=preload("res://scripts/combat_impact.gd")
const LIFETIME=.30
var elapsed=0.0
var puffs=[]
var tint: Color
var material: StandardMaterial3D
static var puff_mesh: QuadMesh

static func spawn(parent: Node3D,point: Vector3,direction: Vector3,mounted: bool,surface: String,index: int) -> Node3D:
 if surface=="wood":return null
 var effect=load("res://scripts/combat_dust.gd").new();parent.add_child(effect)
 effect.global_position=point;effect.configure(direction,mounted,surface,index)
 return effect

func configure(direction: Vector3,mounted: bool,surface: String,index: int):
 name="CombatDust"
 if puff_mesh==null:
  puff_mesh=QuadMesh.new();puff_mesh.size=Vector2.ONE
 material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true;material.disable_fog=true
 material.albedo_texture=Impact.radial_texture()
 tint=Color("bba98b") if surface=="soft" else Color("b9b4a8")
 tint.a=(.38 if surface=="soft" else .21)+(.04 if mounted else 0)
 var backward=global_basis.inverse()*-direction.normalized();var side=Vector3(backward.z,0,-backward.x)
 var count=3 if mounted else 2
 for i in range(count):
  var puff=MeshInstance3D.new();puff.name="Puff"+str(i);puff.mesh=puff_mesh;puff.material_override=material
  puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(puff)
  var spread=(float(i)/(count-1)-.5)*2
  var size=(.24 if mounted else .17)*(1.0+float((i+index)%2)*.12)
  puffs.append({"node":puff,"size":size,"drift":backward*(.11+i*.035)+side*spread*.10,"rise":.07+i*.015})
 update_puffs(0)

func update_puffs(progress: float):
 material.albedo_color=Color(tint,tint.a*(1-progress)*(1-progress))
 for puff in puffs:
  var diameter=puff.size*(.50+progress*.65)
  puff.node.scale=Vector3.ONE*diameter
  puff.node.position=puff.drift*progress+Vector3.UP*(diameter*.5+.005+puff.rise*progress)

func _process(dt):
 if not is_visible_in_tree():queue_free();return
 elapsed+=dt
 if elapsed>=LIFETIME:queue_free();return
 update_puffs(elapsed/LIFETIME)
