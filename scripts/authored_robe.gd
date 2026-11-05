extends Node
# Original open-front robe, fitted in skeleton rest space and weighted to hips
# and both leg segments. Source outfit meshes stay intact beneath it. Each actor owns its
# fabric/trim materials; immutable fitted meshes and inverse binds are shared.
const Garments=preload("res://scripts/garments.gd")
const BONES=["pelvis","thigh_l","thigh_r","calf_l","calf_r"]
static var cache={}
var model: Node3D
var surfaces=[]
var pieces=[]

func configure(body: Node3D,rig: Skeleton3D,painter,appearance: Dictionary):
 model=body
 var fit=fitted(rig)
 for index in range(2):
  var mesh=MeshInstance3D.new();mesh.name="TailoredRobe" if index==0 else "RobeHem"
  mesh.mesh=fit.meshes[index];mesh.skin=fit.skin;mesh.skeleton=NodePath("..");rig.add_child(mesh)
  var material=painter.painted(Color(appearance.cloth) if index==0 else Color("bca26b"),0,index==1).duplicate()
  material.set_shader_parameter("fabric_detail",.25)
  material.set_shader_parameter("cloth_amount",0.0);material.set_shader_parameter("cloth_floor_enabled",true);material.set_shader_parameter("cloth_floor_y",.018)
  mesh.material_override=material;surfaces.append(material);pieces.append(mesh)

static func fitted(rig: Skeleton3D) -> Dictionary:
 var rests=BONES.map(func(name_value):return rig.get_bone_global_rest(rig.find_bone(name_value)))
 var key=str(rests)
 if cache.has(key):return cache[key]
 var skin=Skin.new()
 for index in range(BONES.size()):skin.add_named_bind(BONES[index],rests[index].affine_inverse())
 var top=rests[0].origin.y+.075
 var width=(absf(rests[1].origin.x)+.12)/.18
 var height=(top-.23)/.84
 var basis=Basis(Vector3.UP,PI).scaled(Vector3(width,height,1.24))
 var normal_basis=basis.inverse().transposed();var meshes=[]
 for source in [pattern(false),pattern(true)]:
  var arrays=source.surface_get_arrays(0);var positions=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uv=arrays[Mesh.ARRAY_TEX_UV]
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for index in range(positions.size()):
   var point=positions[index];var t=clampf((-point.y-.125)/.84,0,1)
   point=basis*(point+Vector3(0,.125,0))+Vector3(0,top,0)
   var leg=smoothstep(.08,.55,t);var side=1.0 if point.x>0 else 0.0
   var lower=smoothstep(.55,1.0,t)*.85
   if t<=.55:
    surface.set_bones(PackedInt32Array([0,1,2,0]));surface.set_weights(PackedFloat32Array([1-leg,leg*side,leg*(1-side),0]))
   else:
    surface.set_bones(PackedInt32Array([1,2,3,4]));surface.set_weights(PackedFloat32Array([(1-lower)*side,(1-lower)*(1-side),lower*side,lower*(1-side)]))
   surface.set_normal((normal_basis*normals[index]).normalized());surface.set_uv(uv[index]);surface.add_vertex(point)
  surface.index();meshes.append(surface.commit())
 var result={"meshes":meshes,"skin":skin};cache[key]=result;return result

func materials_remapped(copies: Dictionary):
 for index in range(surfaces.size()):surfaces[index]=copies.get(surfaces[index],surfaces[index])

func _process(_delta):
 if not is_instance_valid(model) or not model.is_visible_in_tree():return
 for material in surfaces:material.set_shader_parameter("cloth_floor_y",model.get_parent().global_position.y+.018)

static func pattern(trim: bool) -> ArrayMesh:
 var rows=[.965,1.0] if trim else [0.0,.125,.25,.375,.5,.625,.75,.875,.965]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for panel in range(2):
  for row in range(rows.size()-1):
   for segment in range(Garments.SEGMENTS/2):
    var points=[];var uvs=[]
    for corner in [[row,segment],[row,segment+1],[row+1,segment+1],[row+1,segment]]:
     var t=rows[corner[0]];var fraction=float(corner[1])/(Garments.SEGMENTS/2);var u=(panel+fraction)*.5
     var point=Garments.point(t,u,.85,.08)
     var vent=.30*smoothstep(.10,1.0,t)*(fraction if panel==0 else 1-fraction)
     point=Basis(Vector3.UP,vent if panel==0 else -vent)*point
     points.append(point);uvs.append(Vector2(u,(t-.965)/.035 if trim else t))
    for index in [0,2,1,0,3,2]:surface.set_uv(uvs[index]);surface.add_vertex(points[index])
 surface.generate_normals();return surface.commit()
