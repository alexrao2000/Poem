extends SceneTree
var study_key="caster"
var character_id="tarin"
var equipped_item="thunder"
var combat_spacing=4.0
var ranged=true
var extra_paths=[]
var pose_keys={}
var prop_path="Rig/Armature/Skeleton3D/BookHand/Folio/Weapon"
func _initialize():call_deferred("run")
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1024,640);root.add_child(viewport);var world=Node3D.new();viewport.add_child(world);var camera=Camera3D.new();world.add_child(camera);camera.current=true
 var models=load("res://scripts/debug_source_models.gd").new([study_key]);var game=load("res://scripts/rules.gd").new();var director=load("res://scripts/combat_camera.gd")
 var failures=[];var count=0
 var framing=director.new();world.add_child(framing)
 for id in [character_id]:
  var unit=game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.item=equipped_item
  var actor=models.build(world,unit,Vector3(35,0,0));await process_frame;actor.set_process(false);actor.player.pause()
  framing.configure(camera,[actor])
  var expected=framing.frame_for(actor.position,actor.position+Vector3(1.4,0,0),"windup",false)
  await framing.shot(actor.position,actor.position+Vector3(1.4,0,0),"windup",false,false,.01).finished
  assert(framing.anchor.is_equal_approx(expected.anchor),"The actual shot tween uses the imported framing margin")
  var head=actor.model.get_node("Identity").head
  var pieces=head.find_children("*","MeshInstance3D",true,false)
  pieces.append_array(actor.model.get_node(NodePath(prop_path)).find_children("*","MeshInstance3D",true,false))
  for path in extra_paths:pieces.append_array(actor.model.get_node(NodePath(path)).find_children("*","MeshInstance3D",true,false))
  for side in [-1,1]:
   actor.rotation.y=-side*PI/2
   for sample in [["idle","wide",combat_spacing],["windup","windup",combat_spacing],["strike","impact",combat_spacing],["recover","impact",combat_spacing],["evade","impact",combat_spacing],["victory","finish",combat_spacing]]:
    sample[0]=pose_keys.get(sample[0],sample[0])
    for listener in actor.pose_listeners:listener.combat_pose(sample[0])
    var mapping=actor.poses[sample[0]];var other=actor.position+Vector3(side*sample[2],0,0)
    actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
    for mounted in [false,true]:
     actor.aim_at(other+Vector3.UP*(1.85 if mounted else 1.1))
     for step in range(9):
      actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,float(step)/8),true,true);actor.player.pause();actor.refresh_skeleton()
      for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
       viewport.size=size_value
       var frame=framing.frame_for(actor.position,other,sample[1],ranged,mounted if sample[1]!="finish" else false,unit.weapon)
       camera.position=frame.anchor;camera.look_at(frame.focus);camera.fov=frame.lens
       var palm=camera.unproject_position(actor.socket_position("projectile"))
       var low=palm;var high=palm
       var visible_pieces=pieces.duplicate()
       if sample[1] in ["wide","finish"]:visible_pieces.append(actor.model.get_node("Identity").cloak.cloth)
       for mesh in visible_pieces:
        for surface in range(mesh.mesh.get_surface_count()):
         for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
          var point=camera.unproject_position(mesh.to_global(vertex));low=low.min(point);high=high.max(point)
       if sample[1] in ["wide","finish"] and actor.model.get_node("Identity").robe!=null:
        for mesh in actor.model.get_node("Identity").robe.pieces:
         for vertex in garment_points(mesh):
          var point=camera.unproject_position(vertex);low=low.min(point);high=high.max(point)
       if low.x<24 or high.x>size_value.x-24 or low.y<88 or high.y>size_value.y-160:
        failures.append([id,side,sample[0],mounted,step,str(size_value),str(low),str(high)])
       count+=1
  actor.queue_free();await process_frame
 for failure in failures.slice(0,30):print(failure)
 assert(failures.is_empty(),"Original head, casting palm and equipped folio stay inside the clear combat frame, with full cloaks in wide/finish shots")
 framing.configure(camera,[])
 var ordinary=director.frame_pair(Vector3.ZERO,Vector3(1.4,0,0),"windup",false)
 assert(framing.frame_for(Vector3.ZERO,Vector3(1.4,0,0),"windup",false)==ordinary,"Ordinary fighters retain their existing shot")
 print("PASS: ",count," authored camera layouts across both directions, foot/mounted opponents, cast/recover/dodge/finish poses and three viewport sizes, actual shot tweens and unchanged baseline")
 world.queue_free();viewport.queue_free();await process_frame;quit()

func garment_points(mesh: MeshInstance3D) -> PackedVector3Array:
 var rig=mesh.get_node(mesh.skeleton);var arrays=mesh.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var transforms=[];var result=PackedVector3Array()
 for index in range(mesh.skin.get_bind_count()):transforms.append(rig.get_bone_global_pose(rig.find_bone(mesh.skin.get_bind_name(index)))*mesh.skin.get_bind_pose(index))
 for index in range(vertices.size()):
  var point=Vector3.ZERO
  for influence in range(4):
   var at=index*4+influence;point+=(transforms[arrays[Mesh.ARRAY_BONES][at]]*vertices[index])*arrays[Mesh.ARRAY_WEIGHTS][at]
  point=rig.to_global(point);point.y=maxf(point.y,mesh.material_override.get_shader_parameter("cloth_floor_y"));result.append(point)
 return result
