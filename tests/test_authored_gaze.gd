extends SceneTree
const Models=preload("res://scripts/debug_duelist_models.gd")
const Rules=preload("res://scripts/rules.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();var models=Models.new();var count=0
 for id in ["nell","silas"]:
  var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player"
  var actor=models.build(world,unit,Vector3(35,0,0));assert(actor!=null);await process_frame
  var identity=actor.model.get_node("Identity");var gaze=identity.gaze;var rig=gaze.rig;var face=rig.get_node("Face")
  var neck=rig.get_node("PortraitNeck");var source=identity.source_meshes.filter(func(mesh):return str(mesh.name).begins_with("Head_") and str(mesh.name) not in ["Head_Eyes","Head_Eyebrows"])[0]
  var original=source.mesh.surface_get_arrays(0);var cropped=neck.mesh.surface_get_arrays(0)
  assert(neck.mesh!=source.mesh and neck.skeleton==source.skeleton and neck.transform==source.transform)
  assert(cropped[Mesh.ARRAY_INDEX].size()<original[Mesh.ARRAY_INDEX].size(),"Neck geometry excludes the supplied face")
  for index in range(cropped[Mesh.ARRAY_VERTEX].size()):
   var total=0.0
   assert(original[Mesh.ARRAY_VERTEX].has(cropped[Mesh.ARRAY_VERTEX][index]),"Neck preserves source positions and bind coordinates")
   for slot in range(4):
    var at=index*4+slot;var weight=cropped[Mesh.ARRAY_WEIGHTS][at]
    assert(weight>=0 and weight<=1 and cropped[Mesh.ARRAY_BONES][at]<neck.skin.get_bind_count());total+=weight
   assert(absf(total-1)<.0001,"Neck deformation retains normalized weights")
   assert(cropped[Mesh.ARRAY_NORMAL][index].is_finite() and cropped[Mesh.ARRAY_TEX_UV][index].is_finite())
  var poses=[]
  rig.skeleton_updated.connect(func():
   poses.clear()
   for bone in range(rig.get_bone_count()):poses.append(rig.get_bone_global_pose(bone)))
  var second=models.build(world,unit,Vector3(40,0,0));await process_frame
  assert(second.model.get_node("Rig/Armature/Skeleton3D/PortraitNeck").mesh==neck.mesh,"Repeated previews share immutable neck geometry")
  assert(second.model.get_node("Rig/Armature/Skeleton3D/PortraitNeck").material_override!=neck.material_override,"Skin tint/fade belongs to each actor")
  second.queue_free();await process_frame
  var target=Marker3D.new();world.add_child(target);actor.face_opponent(target)
  for facing in [-PI/2,0.0,PI/2]:
   actor.rotation.y=facing
   for height in [1.5,2.4]:
    for side in [-.8,0.0,.8]:
     target.global_position=actor.to_global(Vector3(side,height,-2.0))
     actor.pose("idle",.01);actor.player.advance(.1);actor.player.pause()
     var position=rig.get_bone_global_pose(gaze.head).origin
     await create_timer(.4).timeout
     assert(gaze.modifier.active and gaze.modifier.influence>.98)
     var direction=(gaze.target.global_position-face.global_position).normalized()
     var forward=face.global_basis.z.normalized()
     assert(forward.dot(direction)>.998,"Both original faces follow the bounded opponent direction")
     var local=actor.global_basis.orthonormalized().inverse()*direction
     assert(absf(atan2(-local.x,-local.z))<=gaze.YAW+.001 and absf(atan2(local.y,Vector2(local.x,local.z).length()))<=gaze.PITCH+.001)
     assert(rig.get_bone_global_pose(gaze.head).origin.is_equal_approx(position),"Head tracking never translates or stretches the bone")
     assert(poses[gaze.head].is_equal_approx(face.transform),"The skin and original head share the same final modified pose")
     var neck_bone=rig.find_bone("neck_01")
     for vertex in skin_vertices(rig,neck,poses):
      assert(vertex.is_finite() and vertex.distance_to(poses[neck_bone].origin)<.22,"Gaze cannot stretch the cropped neck away from its collar")
     count+=1
  actor.rotation.y=0;target.position=actor.position+Vector3(0,2.4,-2)
  for key in ["hit","critical_hit","evade","down","victory"]:
   actor.pose(key,.01);assert(not gaze.modifier.active and gaze.modifier.influence==0,"Reaction and finishing clips retain their authored head pose immediately")
   await create_timer(.03).timeout;assert(not gaze.modifier.active)
   assert(face.transform.is_equal_approx(rig.get_bone_global_pose(gaze.head)),"Reaction attachment matches the authored pose exactly after tracking releases")
  actor.pose("idle",.01);await create_timer(.4).timeout
  var held=face.global_transform;var marker=gaze.target.global_position;var weight=gaze.modifier.influence
  var stop=HitStop.new();world.add_child(stop);var motion=stop.play([actor],.09);target.position+=Vector3(.8,-.3,0)
  await create_timer(.03).timeout
  assert(face.global_transform.is_equal_approx(held) and gaze.target.global_position==marker and gaze.modifier.influence==weight,"Hit-stop freezes head tracking along with the fighter")
  await motion.finished;await create_timer(.1).timeout
  assert(gaze.target.global_position!=marker)
  target.position=actor.position+Vector3(0,2,2);await process_frame;await process_frame
  assert(not gaze.modifier.active,"Targets behind the actor cannot twist the head around")
  target.position=Vector3(INF,0,0);await process_frame;assert(not gaze.modifier.active)
  target.queue_free();await process_frame;await process_frame;assert(not gaze.modifier.active,"Freed opponents release gaze without stale node paths")
  assert(source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==original[Mesh.ARRAY_VERTEX] and source.mesh.surface_get_arrays(0)[Mesh.ARRAY_WEIGHTS]==original[Mesh.ARRAY_WEIGHTS],"Head tracking never edits shared source geometry or weights")
  world.remove_child(actor);actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," bounded native head-tracking cases across both rigs/directions/target heights, unchanged bone origins, normalized cached neck skin, unchanged source geometry, authored reactions/finishes, hit-stop, rear/invalid/freed targets and immediate teardown")
 quit()

func skin_vertices(rig: Skeleton3D,mesh: MeshInstance3D,poses: Array) -> PackedVector3Array:
 var arrays=mesh.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var binds=[];var result=PackedVector3Array()
 for index in range(mesh.skin.get_bind_count()):binds.append(poses[rig.find_bone(mesh.skin.get_bind_name(index))]*mesh.skin.get_bind_pose(index))
 for index in range(vertices.size()):
  var point=Vector3.ZERO
  for influence in range(4):
   var slot=index*4+influence;point+=(binds[bones[slot]]*vertices[index])*weights[slot]
  result.append(point)
 return result
