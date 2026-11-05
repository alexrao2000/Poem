extends Node
# Original segmented plates and shield fitted in the source skeleton's rest
# space. Each rigid plate follows its own bone; source meshes stay untouched.
var anchors=[]
var surfaces=[]
func anchor(rig: Skeleton3D,bone: String,label: String,transform: Transform3D) -> Node3D:
 var attachment=rig.get_node_or_null(NodePath(label)) as BoneAttachment3D
 if attachment==null:
  attachment=BoneAttachment3D.new();attachment.name=label;attachment.bone_name=bone;rig.add_child(attachment)
 anchors.append(attachment)
 var shape=attachment.get_node_or_null("Plate") as Node3D
 if shape==null:shape=Node3D.new();shape.name="Plate";attachment.add_child(shape)
 shape.transform=rig.get_bone_global_rest(rig.find_bone(bone)).affine_inverse()*transform
 return shape
func configure(model: Node3D,rig: Skeleton3D,painter,appearance: Dictionary,light=false):
 var steel=painter.painted(Color(appearance.get("steel","d3d7dc")),1,true).duplicate();var gold=painter.painted(Color(appearance.get("metal","bca26b")),1,true).duplicate()
 for surface in [steel,gold]:surface.set_shader_parameter("paint_average",Vector3(.229348,.231699,.239027));surface.set_shader_parameter("fabric_detail",.15)
 surfaces=[steel,gold]
 var shoulder=rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin;var neck=rig.get_bone_global_rest(rig.find_bone("neck_01")).origin
 var broad=shoulder.x>.17;var base=neck.y-.38
 var cuirass=anchor(rig,"spine_03","KnightCuirass",Transform3D(Basis(Vector3.UP,PI).scaled(Vector3(1 if broad else .86,.98,1.38 if broad else 1.18)),Vector3(0,base,-.075)))
 painter.geo.mesh(cuirass,load("res://scripts/cuirass.gd").mesh(),Vector3.ZERO,Vector3.ONE,steel).name="Cuirass"
 painter.geo.mesh(cuirass,load("res://scripts/cuirass.gd").trim_mesh(),Vector3.ZERO,Vector3.ONE,gold).name="CuirassTrim"
 if not light:
  var waist=anchor(rig,"spine_01","KnightFauld",Transform3D(Basis(Vector3.UP,PI),Vector3(0,base-.07,-.025)))
  painter.shell(waist,Vector3.ZERO,[[0,.18,.145],[.055,.185,.155],[.115,.185,.155]],Color(appearance.get("steel","a8b3bb")))
 for sign_value in [-1,1]:
  var side="l" if sign_value>0 else "r";var upper=rig.get_bone_global_rest(rig.find_bone("upperarm_"+side)).origin
  var cap=anchor(rig,"upperarm_"+side,"KnightShoulder"+side,Transform3D(Basis(Vector3.BACK,sign_value*PI/2),upper+Vector3(sign_value*.03,0,0)))
  painter.geo.mesh(cap,load("res://scripts/pauldron.gd").mesh(sign_value,true),Vector3.ZERO,Vector3.ONE*.8,steel).name="Pauldron"
  painter.geo.mesh(cap,load("res://scripts/pauldron.gd").rim(sign_value,true),Vector3.ZERO,Vector3.ONE*.8,gold).name="PauldronRim"
  if not light:
   var knee=rig.get_bone_global_rest(rig.find_bone("calf_"+side)).origin
   var leg=anchor(rig,"calf_"+side,"KnightGreave"+side,Transform3D(Basis(Vector3.UP,PI),knee+Vector3(0,0,.015)))
   painter.geo.mesh(leg,load("res://scripts/knee_guard.gd").mesh(),Vector3.ZERO,Vector3.ONE*.82,steel).name="KneeGuard"
   painter.shell(leg,Vector3.ZERO,[[-.31,.073,.075],[-.22,.086,.089],[-.08,.092,.095]],Color(appearance.get("steel","a8b3bb")))
   var thigh=rig.get_bone_global_rest(rig.find_bone("thigh_"+side)).origin
   var flap=anchor(rig,"thigh_"+side,"KnightTasset"+side,Transform3D(Basis(Vector3.UP,PI),thigh+Vector3(0,-.04,.10)))
   painter.cloth(flap,[Vector3(-.08,0,-.012),Vector3(.08,0,-.012),Vector3(.085,-.20,-.04),Vector3(-.085,-.20,-.04)],Color(appearance.get("steel","a8b3bb")))
   painter.cloth(flap,[Vector3(-.085,-.182,-.041),Vector3(.085,-.182,-.041),Vector3(.085,-.20,-.041),Vector3(-.085,-.20,-.041)],Color(appearance.get("metal","bca26b")))
  var elbow=rig.get_bone_global_rest(rig.find_bone("lowerarm_"+side)).origin
  var forearm=anchor(rig,"lowerarm_"+side,"KnightVambrace"+side,Transform3D(Basis(Vector3.BACK,sign_value*PI/2),elbow))
  painter.geo.mesh(forearm,load("res://scripts/elbow_guard.gd").mesh(),Vector3.ZERO,Vector3.ONE*.8,steel).name="ElbowGuard"
  painter.shell(forearm,Vector3.ZERO,[[-.19,.053,.06],[-.08,.064,.068],[-.045,.071,.077]],Color(appearance.get("steel","a8b3bb")))
 if not light:
  var shield_origin=rig.get_bone_global_rest(rig.find_bone("lowerarm_l")).origin+Vector3(.13,0,.12)
  var shield=anchor(rig,"lowerarm_l","KnightShield",Transform3D(Basis(Vector3.DOWN,Vector3.LEFT,Vector3.FORWARD),shield_origin))
  painter.geo.mesh(shield,load("res://scripts/knight_shield.gd").body_mesh(),Vector3.ZERO,Vector3.ONE*.83,painter.painted(Color(appearance.cloth),0)).name="ShieldBody"
  painter.geo.mesh(shield,load("res://scripts/knight_shield.gd").trim_mesh(),Vector3.ZERO,Vector3.ONE*.83,gold).name="ShieldTrim"
  var leather=painter.geo.material(Color("554337"))
  for y in [-.07,.07]:
   var strap=TorusMesh.new();strap.inner_radius=.064;strap.outer_radius=.079;strap.rings=12;strap.ring_segments=6
   var loop=painter.geo.mesh(shield,strap,Vector3(0,y,.12),Vector3.ONE,leather);loop.name="ForearmStrap";loop.set_meta("shield_mount",true)
   var mount=painter.geo.block(shield,Vector3(0,y,.058),Vector3(.10,.023,.065),Color("554337"));mount.name="ShieldMount";mount.set_meta("shield_mount",true)
 for attachment in anchors:
  for mesh in attachment.find_children("*","MeshInstance3D",true,false):
   if mesh.get_active_material(0) is StandardMaterial3D and not mesh.get_meta("shield_mount",false):mesh.material_override=gold if mesh.get_active_material(0).albedo_color.is_equal_approx(Color(appearance.get("metal","bca26b"))) else steel
  attachment.on_skeleton_update()

func materials_remapped(copies: Dictionary):
 for index in range(surfaces.size()):surfaces[index]=copies.get(surfaces[index],surfaces[index])
