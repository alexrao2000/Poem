extends Node
# Fit the existing promotion patterns to source-body rest joints.
# Lower panels use a private subdivided skin so tabards and sashes follow the
# hips and legs. Upper cloth and segmented plates keep separate bone anchors.
const Costume=preload("res://scripts/promotion_costume.gd")
const BONES=["pelvis","thigh_l","thigh_r","calf_l","calf_r"]
class PatternBones extends RefCounted:
 var joints={}
 func bone(key):return joints[key]
var model: Node3D
var surfaces=[]
var anchors=[]
var panels=[]
var id=""
func attachment(rig: Skeleton3D,bone: String,label: String,rest: Transform3D) -> Node3D:
 var anchor=BoneAttachment3D.new();anchor.name=label;anchor.bone_name=bone;rig.add_child(anchor);anchors.append(anchor)
 var fitted=Node3D.new();fitted.name="Pattern";anchor.add_child(fitted);fitted.transform=rig.get_bone_global_rest(rig.find_bone(bone)).affine_inverse()*rest
 return fitted
func configure(body: Node3D,rig: Skeleton3D,painter,unit: Dictionary,appearance: Dictionary):
 model=body;id=unit.promotion
 var neck=rig.get_bone_global_rest(rig.find_bone("neck_01")).origin
 var shoulder=rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin
 var width=(absf(shoulder.x)+.04)/.28;var depth=1.2 if shoulder.x>.17 else 1.0
 var torso_rest=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3(width,1,depth)),neck+Vector3(0,-.47,0))
 var torso=attachment(rig,"spine_03","PromotionChest",torso_rest)
 var proxy=PatternBones.new()
 for side in [-1,1]:
  var suffix="l" if side<0 else "r"
  for pair in [["LeftArm" if side<0 else "Arm","upperarm_"],["LeftElbow" if side<0 else "Elbow","lowerarm_"]]:
   var bone=pair[1]+suffix;var origin=rig.get_bone_global_rest(rig.find_bone(bone)).origin
   proxy.joints[pair[0]]=attachment(rig,bone,"Promotion"+pair[0],Transform3D(Basis(Vector3.BACK,-side*PI/2)*Basis(Vector3.UP,PI),origin))
 var cloth=Color(appearance.cloth);var cape=Color(appearance.cape);var steel=Color(appearance.get("steel","a8b3bb"));var gold=Color(appearance.get("metal","bca26b"))
 Costume.build(painter,proxy,unit,torso,cloth,cape,steel,gold,Color("554337"))
 var group=torso.get_node("PromotionCostume");var converted={}
 if Costume.looks[id].get("satchel",false):
  var belt_rest=torso_rest;belt_rest.origin.y+=.025
  var hip=attachment(rig,"pelvis","PromotionHip",belt_rest)
  # A belt pouch follows the pelvis during a forward fall; it stays rigid.
  for mesh in group.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh is PrimitiveMesh and mesh.position.y<0:mesh.reparent(hip,false)
 for anchor in anchors:anchor.on_skeleton_update()
 for anchor in anchors:
  for mesh in anchor.find_children("*","MeshInstance3D",true,false):
   var raw=mesh.get_active_material(0);var color=raw.albedo_color;var lower=group.is_ancestor_of(mesh) and mesh.mesh.get_aabb().end.y<-.07
   var cloth_part=group.is_ancestor_of(mesh) and mesh.mesh is ArrayMesh
   var key=str(color)+":"+str(cloth_part)
   if not converted.has(key):
    var metal=color.is_equal_approx(steel) or color.is_equal_approx(gold)
    var material=painter.painted(color,1 if metal else 0,metal).duplicate();material.set_shader_parameter("fabric_detail",.15 if metal else .25)
    material.set_shader_parameter("cloth_amount",0.0);material.set_shader_parameter("cloth_floor_enabled",cloth_part);material.set_shader_parameter("cloth_floor_y",.018)
    converted[key]=material;surfaces.append(material)
   mesh.material_override=converted[key]
   if lower:skin_panel(mesh,rig,group)
 for anchor in anchors:painter.geo.batcher.combine(anchor.get_child(0),false)
 body.set_meta("promotion_look",id)
func skin_panel(mesh: MeshInstance3D,rig: Skeleton3D,group: Node3D):
 var rest=rig.get_bone_global_rest(rig.find_bone("spine_03"))*group.get_parent().transform*group.transform*mesh.transform
 var waist=rig.get_bone_global_rest(rig.find_bone("pelvis")).origin.y+.075
 var pattern_top=-.105 if Costume.looks[id].has("tabard") else -.095
 var lift=waist-(rest*Vector3(0,pattern_top,0)).y
 var broad=rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin.x>.17
 var front=.226 if Costume.looks[id].has("tabard") else .175
 var depth_fit=(.16 if broad else .14)/((1.2 if broad else 1.0)*front)
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
     var point=rest*(points[a]*blend.x+points[b]*blend.y+points[c]*blend.z)
     point.y+=lift;point.z*=depth_fit
     var leg=smoothstep(.06,.5,waist-point.y)*.65;var lower=0.0;var side=smoothstep(-.08,.08,point.x)
     if Costume.looks[id].has("sash"):
      leg=smoothstep(0,.32,waist-point.y);lower=smoothstep(.4,.65,waist-point.y)*.35
     surface.set_bones(PackedInt32Array([0,1,2,3 if point.x>=0 else 4]));surface.set_weights(PackedFloat32Array([1-leg,leg*(1-lower)*side,leg*(1-lower)*(1-side),leg*lower]))
     surface.set_uv(uv[a]*blend.x+uv[b]*blend.y+uv[c]*blend.z);surface.add_vertex(point)
 surface.generate_normals();surface.index()
 var panel=MeshInstance3D.new();panel.name="PromotionPanel";panel.mesh=surface.commit();panel.skin=skin;panel.skeleton=NodePath("..");panel.material_override=mesh.material_override;rig.add_child(panel);panels.append(panel)
 mesh.get_parent().remove_child(mesh);mesh.free()
func materials_remapped(copies: Dictionary):
 for index in range(surfaces.size()):surfaces[index]=copies.get(surfaces[index],surfaces[index])
func _process(_delta):
 if not is_instance_valid(model) or not model.is_visible_in_tree():return
 for material in surfaces:material.set_shader_parameter("cloth_floor_y",model.get_parent().global_position.y+.018)
