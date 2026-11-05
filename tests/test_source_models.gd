extends SceneTree
# Imported source geometry only. This does not render the assembled game.
var samples=0
func _initialize():call_deferred("run")

func skin_vertices(mesh: MeshInstance3D,skeleton: Skeleton3D) -> PackedVector3Array:
 var matrices: Array[Transform3D]=[]
 for bind in range(mesh.skin.get_bind_count()):
  var bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
  if bone<0:bone=mesh.skin.get_bind_bone(bind)
  assert(bone>=0 and bone<skeleton.get_bone_count(),"Every skin bind resolves on the shared skeleton")
  matrices.append(skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
 var result=PackedVector3Array()
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays=mesh.mesh.surface_get_arrays(surface)
  var vertices=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
  var influences=bones.size()/vertices.size()
  for index in range(vertices.size()):
   var position=Vector3.ZERO
   for influence in range(influences):
    var at=index*influences+influence
    position+=(matrices[bones[at]]*vertices[index])*weights[at]
   assert(position.is_finite())
   result.append(position)
 return result

func run():
 var total_vertices=0
 for gender in ["female","male"]:
  var scene=load("res://assets/models/quaternius/duelist_"+gender+".gltf").instantiate();root.add_child(scene);await process_frame
  var skeleton=scene.get_node("Armature/Skeleton3D") as Skeleton3D
  var player=scene.get_node("AnimationPlayer") as AnimationPlayer
  assert(skeleton.get_bone_count()==65)
  var meshes=scene.find_children("*","MeshInstance3D",true,false)
  assert(meshes.size()==8,"One outfit, trimmed head, eyes, brows and hair")
  assert(scene.find_children("*","Skeleton3D",true,false).size()==1)
  for mesh in meshes:
   assert(mesh.get_node(mesh.skeleton)==skeleton)
   for surface in range(mesh.mesh.get_surface_count()):
    var material=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
    assert(material!=null)
    for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture,material.metallic_texture]:
     if texture!=null:assert(texture.get_width()<=1024 and texture.get_height()<=1024,"Runtime textures obey the browser import budget")
  for clip in ["Idle","Jog_Fwd","Sword_Idle","Sword_Attack","Hit_Chest","Death01","Roll"]:
   assert(player.has_animation(clip))
   var animation=player.get_animation(clip)
   for track in range(animation.get_track_count()):
    assert(animation.track_get_type(track) in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D],"Source clips have no event, audio or gameplay tracks")
   for phase in [0.0,.25,.5,.75,1.0]:
    player.play(clip);player.seek(animation.length*phase,true);player.pause();skeleton.force_update_all_bone_transforms()
    var bounds=AABB();var first=true
    var head=skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
    for mesh in meshes:
     var points=skin_vertices(mesh,skeleton);total_vertices+=points.size()
     for point in points:
      if first:bounds=AABB(point,Vector3.ZERO);first=false
      else:bounds=bounds.expand(point)
      if mesh.name=="Head_Eyes":assert(point.distance_to(head)<.35,"Eyes follow the head, not a detached rest-pose mesh")
    assert(bounds.size.x<3.0 and bounds.size.y<2.5 and bounds.size.z<3.0,"No exploding skins through imported poses: "+gender+" "+clip)
    assert(bounds.position.y>-.22,"Source pose remains near the floor: "+gender+" "+clip)
    samples+=1
  scene.queue_free();await process_frame
 print("PASS: ",samples," imported source poses, ",total_vertices," skinned vertices, shared skeletons, attached eyes, bounded geometry, animation-only tracks and 1024-pixel runtime textures (not a rendered-game review)")
 quit()
