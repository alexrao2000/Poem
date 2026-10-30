extends MeshInstance3D
# Two short curved straps follow the actual bridle and free hand. Keep this
# small moving mesh outside rigid batching; rebuild only when endpoints change.
# The outward control points route each strap around the horse's neck.

const STEPS=8
const RADIUS=.006
const BIT=Vector3(.15,-.025,-.22)
var actor: Node3D
var paths=[]
var inputs=[]
var revisions=0

func configure(subject: Node3D,surface: ShaderMaterial):
 actor=subject;name="MountedReins";cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material_override=surface.duplicate();material_override.set_meta("no_character_outline",true)
 update()

func update():
 if actor==null or not actor.bones.has("HorseHead"):return
 var head=actor.bones.HorseHead;var hand=actor.bones.LeftElbow.to_global(Vector3(0,-.29,0))
 var next=[to_local(head.to_global(BIT*Vector3(-1,1,1))),to_local(head.to_global(BIT)),to_local(hand)]
 if next==inputs:return
 inputs=next;paths.clear();revisions+=1
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  var start=inputs[0 if side<0 else 1];var end=inputs[2]+Vector3(side*.012,0,0)
  var control=Vector3(side*.45,maxf(start.y,end.y)+.12,-.55)
  var rings=[];var normals=[];var centers=[]
  for step in range(STEPS+1):
   var t=float(step)/STEPS;var center=start.lerp(control,t).lerp(control.lerp(end,t),t)
   var tangent=(control-start).lerp(end-control,t).normalized()
   var right=tangent.cross(Vector3.UP).normalized()
   if right.length_squared()<.001:right=Vector3.RIGHT
   var up=right.cross(tangent).normalized();var ring=[];var directions=[]
   for corner in range(4):
    var angle=corner*TAU/4;var normal=right*cos(angle)+up*sin(angle)
    directions.append(normal);ring.append(center+normal*RADIUS)
   rings.append(ring);normals.append(directions);centers.append(center)
  paths.append(centers)
  for step in range(STEPS):
   for corner in range(4):
    var next_corner=(corner+1)%4
    var vertices=[rings[step][corner],rings[step+1][corner],rings[step+1][next_corner],rings[step][next_corner]]
    var directions=[normals[step][corner],normals[step+1][corner],normals[step+1][next_corner],normals[step][next_corner]]
    var uv=[Vector2(float(step)/STEPS,corner/4.0),Vector2(float(step+1)/STEPS,corner/4.0),Vector2(float(step+1)/STEPS,(corner+1)/4.0),Vector2(float(step)/STEPS,(corner+1)/4.0)]
    for triangle in [[0,1,2],[0,2,3]]:emit_triangle(surface,triangle,vertices,directions,uv)
  for end_index in [0,STEPS]:
   var normal=(centers[0]-centers[1]).normalized() if end_index==0 else (centers[-1]-centers[-2]).normalized()
   for triangle in [[0,1,2],[0,2,3]]:emit_triangle(surface,triangle,rings[end_index],[normal,normal,normal,normal],[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
 surface.index();surface.generate_tangents();mesh=surface.commit()

static func emit_triangle(surface: SurfaceTool,indices: Array,vertices: Array,normals: Array,uv: Array):
 var order=indices.duplicate()
 var cross=(vertices[order[1]]-vertices[order[0]]).cross(vertices[order[2]]-vertices[order[0]])
 if cross.dot(normals[order[0]]+normals[order[1]]+normals[order[2]])>0:order.reverse()
 for index in order:
  surface.set_normal(normals[index]);surface.set_uv(uv[index]);surface.add_vertex(vertices[index])
