extends SceneTree
func _initialize():call_deferred("run")
func seek(actor,clip,time):
 actor.player.get_animation(clip).loop_mode=Animation.LOOP_NONE
 actor.player.play(clip,0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var models=load("res://scripts/debug_source_models.gd").new(["caster","caster_female"])
 var count=0;var lowest=INF;var minimum_lift=INF;var maximum_step=0.0;var book_drift=0.0
 for id in ["tarin","vela","noor"]:
  var source=rules.roster.filter(func(value):return value.id==id)[0]
  for promotion in ["","star_sage","spellwarden"]:
   for item in ["ember","gale","thunder"]:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var folio=rig.get_node("BookHand/Folio");var book=folio.get_node("Weapon");var arm=rig.find_bone("upperarm_l")
    for side in [-1,1]:
     actor.rotation.y=-side*PI/2
     for key in ["victory_flourish"]:
      var mapping=actor.poses[key];var normal="Idle";var previous=null
      for step in range(65):
       var time=lerpf(mapping.from,mapping.to,step/64.0);seek(actor,normal,time)
       var original=[]
       for bone in range(rig.get_bone_count()):original.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone),rig.get_bone_pose_rotation(bone)])
       var hand=rig.get_node("BookHand").transform;var palm=actor.socket_position("projectile")
       seek(actor,mapping.clip,time)
       for bone in range(rig.get_bone_count()):
        assert(rig.get_bone_pose_position(bone)==original[bone][0] and rig.get_bone_pose_scale(bone)==original[bone][1])
        if bone not in [arm,rig.find_bone("hand_l")]:assert(rig.get_bone_pose_rotation(bone).is_equal_approx(original[bone][2]),"Only the free upper-arm and wrist rotations differ from idle")
       var current_book=rig.get_node("BookHand").transform
       book_drift=maxf(book_drift,current_book.origin.distance_to(hand.origin))
       assert(book_drift<.00005 and current_book.basis.x.distance_to(hand.basis.x)<.00005 and current_book.basis.y.distance_to(hand.basis.y)<.00005 and current_book.basis.z.distance_to(hand.basis.z)<.00005,"Spell finishing keeps the folio support within floating-point sampling tolerance")
       var current=[rig.get_bone_pose_rotation(arm),rig.get_bone_pose_rotation(rig.find_bone("hand_l"))]
       if previous!=null:
        for index in range(2):
         var angle=previous[index].angle_to(current[index]);maximum_step=maxf(maximum_step,angle);assert(angle<.04)
       previous=current
       for mesh in book.find_children("*","MeshInstance3D",true,false):
        for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
         var y=mesh.to_global(vertex).y;lowest=minf(lowest,y);assert(y>.01)
       var movement=actor.socket_position("projectile").distance_to(palm)
       if step==26:minimum_lift=minf(minimum_lift,movement);assert(movement>.07,"The free casting hand makes a visible finishing gesture")
       if step in [0,64]:assert(movement<.00001,"Finishing starts and ends at the exact idle hand position")
       count+=1
     for key in ["idle","windup","recover","hit","critical_hit","evade","down","guard","victory"]:
      folio.combat_pose("critical_windup");folio.combat_pose(key);assert(not folio.critical_prepared)
    actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," spell finishing samples, nine outfits, three folios, both headings, unchanged source bones/book support, minimum palm movement ",minimum_lift," m, book floor ",lowest," m, book drift ",book_drift," m, maximum arm/wrist step ",maximum_step," rad and exact idle endpoints")
 quit()
