extends RefCounted
# One continuous fitting rule spans upper stole, hanging panel and hem. The
# waist seams share positions and weights, while the chest and legs articulate.
const BONES=["spine_03","pelvis","thigh_l","thigh_r","calf_l","calf_r"]
static func fit(mesh: MeshInstance3D,rig: Skeleton3D,group: Node3D) -> MeshInstance3D:
 var rest=rig.get_bone_global_rest(rig.find_bone("spine_03"))*group.get_parent().transform*group.transform*mesh.transform
 var waist=rig.get_bone_global_rest(rig.find_bone("pelvis")).origin.y+.075
 var upper=(rest*Vector3(0,.37,0)).y
 var depth_fit=.215/absf((rest*Vector3(0,0,-.245)).z)
 var arrays=mesh.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var uv=arrays[Mesh.ARRAY_TEX_UV];var indices=arrays[Mesh.ARRAY_INDEX]
 if indices==null or indices.is_empty():indices=range(points.size())
 var skin=Skin.new()
 for bone in BONES:skin.add_named_bind(bone,rig.get_bone_global_rest(rig.find_bone(bone)).affine_inverse())
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for triangle in range(0,indices.size(),3):
  var a=indices[triangle];var b=indices[triangle+1];var c=indices[triangle+2]
  for row in range(8):
   for column in range(8-row):
    var corners=[Vector2(row,column),Vector2(row+1,column),Vector2(row,column+1)]
    if row+column<7:corners.append_array([Vector2(row+1,column),Vector2(row+1,column+1),Vector2(row,column+1)])
    for corner in corners:
     var blend=Vector3(1-(corner.x+corner.y)/8,corner.x/8,corner.y/8)
     var pattern=points[a]*blend.x+points[b]*blend.y+points[c]*blend.z
     var point=rest*pattern;point.y=lerpf(waist,upper,pattern.y/.37) if pattern.y>0 else waist+pattern.y;point.z*=depth_fit
     var chest=smoothstep(0,.3,point.y-waist);var leg=smoothstep(.05,.4,waist-point.y);var calf=smoothstep(.35,.7,waist-point.y)*.65
     var side=0 if point.x>=0 else 1
     surface.set_bones(PackedInt32Array([0,1,2+side,4+side]));surface.set_weights(PackedFloat32Array([chest,1-chest-leg,leg*(1-calf),leg*calf]))
     surface.set_uv(uv[a]*blend.x+uv[b]*blend.y+uv[c]*blend.z);surface.add_vertex(point)
 surface.generate_normals();surface.index()
 var panel=MeshInstance3D.new();panel.name="PromotionStole";panel.mesh=surface.commit();panel.skin=skin;panel.skeleton=NodePath("..");panel.material_override=mesh.material_override;panel.set_meta("promotion_stole",true);rig.add_child(panel)
 mesh.get_parent().remove_child(mesh);mesh.free();return panel
