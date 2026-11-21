extends SceneTree
var study_ids=["female","male"]
var character_ids=["nell","silas","yuna"]
var equipped_items=["tempered_sword"]
var unit_team="player"
var promotion_id=""
func create_models():return load("res://scripts/debug_source_models.gd").new(study_ids)
func _initialize():call_deferred("run")
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1024,640);root.add_child(viewport);var world=Node3D.new();viewport.add_child(world);var camera=Camera3D.new();world.add_child(camera);camera.current=true
 var models=create_models();var game=load("res://scripts/rules.gd").new();var director=load("res://scripts/combat_camera.gd")
 var failures=[];var count=0
 var framing=director.new();world.add_child(framing)
 for id in character_ids:
  for item in equipped_items:
   var unit=game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team=unit_team;unit.item=item;unit.promotion=promotion_id
   var actor=models.build(world,unit,Vector3(35,0,0));await process_frame;actor.set_process(false);actor.player.pause()
   var spacing=actor.approach_spacing(unit.item)
   framing.configure(camera,[actor])
   var expected=framing.frame_for(actor.position,actor.position+Vector3(spacing,0,0),"windup",false)
   await framing.shot(actor.position,actor.position+Vector3(spacing,0,0),"windup",false,false,.01).finished
   assert(framing.anchor.is_equal_approx(expected.anchor),"The actual shot tween uses the imported framing margin")
   var head=actor.model.get_node("Identity").head
   var pieces=head.find_children("*","MeshInstance3D",true,false)
   pieces.append_array(actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon").find_children("*","MeshInstance3D",true,false))
   var mantle=actor.model.get_node("Identity").mantle
   if mantle!=null:pieces.append_array(mantle.garment.find_children("*","MeshInstance3D",true,false))
   var costume=actor.model.get_node("Identity").promotion
   if costume!=null:
    for anchor in costume.anchors:pieces.append_array(anchor.find_children("*","MeshInstance3D",true,false))
   for side in [-1,1]:
    actor.rotation.y=-side*PI/2
    for sample in [["idle","wide",3.2],["windup","windup",spacing],["strike","impact",spacing],["evade","impact",spacing],["victory","finish",spacing]]:
     var mapping=actor.poses[sample[0]];var other=actor.position+Vector3(side*sample[2],0,0)
     for mounted in [false,true]:
      actor.aim_at(other+Vector3.UP*(1.85 if mounted else 1.1))
      if actor.contact!=null:actor.contact.influence=1 if sample[0]=="strike" else 0
      for listener in actor.pose_listeners:listener.combat_pose(sample[0])
      for step in range(9):
       actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,float(step)/8),true,true);actor.player.pause();actor.refresh_skeleton()
       for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
        viewport.size=size_value
        var frame=framing.frame_for(actor.position,other,sample[1],false,mounted if sample[1]!="finish" else false,unit.weapon)
        camera.position=frame.anchor;camera.look_at(frame.focus);camera.fov=frame.lens
        var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
        var visible_pieces=pieces.duplicate()
        if sample[1] in ["wide","finish"]:visible_pieces.append(actor.model.get_node("Identity").cloak.cloth)
        if costume!=null and sample[1] in ["wide","finish"]:visible_pieces.append_array(costume.panels)
        for mesh in visible_pieces:
         for vertex in world_vertices(mesh):
          var point=camera.unproject_position(vertex);low=low.min(point);high=high.max(point)
        if low.x<24 or high.x>size_value.x-24 or low.y<88 or high.y>size_value.y-160:
         failures.append([id,side,sample[0],mounted,step,str(size_value),str(low),str(high)])
        count+=1
   actor.queue_free();await process_frame
 for failure in failures.slice(0,30):print(failure)
 assert(failures.is_empty(),"Original heads and equipped weapons stay inside the clear combat frame, with full cloaks in wide/finish shots")
 var unit=game.roster.filter(func(value):return value.id==character_ids[0])[0].duplicate(true);unit.team=unit_team
 for invalid in [null,{"windup":.5},{"windup":INF},{"unknown":1.2},{"wide":"bad"}]:
  models.models.catalog.characters[character_ids[0]].framing=invalid;models.models.issues.clear();var before=world.get_child_count()
  assert(models.build(world,unit,Vector3.ZERO)==null and not models.models.issues.is_empty() and world.get_child_count()==before,"Invalid framing falls back without a partial actor")
 framing.configure(camera,[])
 var ordinary=director.frame_pair(Vector3.ZERO,Vector3(1.4,0,0),"windup",false)
 assert(framing.frame_for(Vector3.ZERO,Vector3(1.4,0,0),"windup",false)==ordinary,"Ordinary fighters retain their existing shot")
 print("PASS: ",count," authored camera layouts across both directions, foot/mounted opponents, windup/contact/dodge/finish poses and three viewport sizes, actual shot tweens, unchanged baseline and invalid framing fallback")
 world.queue_free();viewport.queue_free();await process_frame;quit()

func world_vertices(mesh: MeshInstance3D) -> PackedVector3Array:
 var result=PackedVector3Array();var transforms=[];var rig: Skeleton3D
 if mesh.skin!=null:
  rig=mesh.get_node(mesh.skeleton)
  for index in range(mesh.skin.get_bind_count()):transforms.append(rig.get_bone_global_pose(rig.find_bone(mesh.skin.get_bind_name(index)))*mesh.skin.get_bind_pose(index))
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays=mesh.mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX]
  for index in range(vertices.size()):
   var point=vertices[index]
   if not transforms.is_empty():
    point=Vector3.ZERO
    for influence in range(4):
     var at=index*4+influence;point+=(transforms[arrays[Mesh.ARRAY_BONES][at]]*vertices[index])*arrays[Mesh.ARRAY_WEIGHTS][at]
    point=rig.to_global(point)
   else:point=mesh.to_global(point)
   result.append(point)
 return result
