extends SceneTree
func _initialize():call_deferred("run")
func seek(actor,clip,time):
 actor.player.get_animation(clip).loop_mode=Animation.LOOP_NONE
 actor.player.play(clip,0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var models=load("res://scripts/debug_source_models.gd").new(["caster","caster_female"])
 var count=0;var lowest=INF;var minimum_lift=INF;var maximum_step=0.0
 for id in ["tarin","vela","noor"]:
  var source=rules.roster.filter(func(value):return value.id==id)[0]
  for promotion in ["","star_sage","spellwarden"]:
   for item in ["ember","gale","thunder"]:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty());await process_frame;actor.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var folio=rig.get_node("BookHand/Folio");var book=folio.get_node("Weapon");var arm=rig.find_bone("upperarm_l")
    for side in [-1,1]:
     actor.rotation.y=-side*PI/2
     for key in ["critical_windup","critical_strike"]:
      var mapping=actor.poses[key];var normal="Spell_Simple_Enter" if key=="critical_windup" else "Spell_Simple_Shoot";var previous=null
      for step in range(65):
       var time=lerpf(mapping.from,mapping.to,step/64.0);seek(actor,normal,time)
       var original=[]
       for bone in range(rig.get_bone_count()):original.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone),rig.get_bone_pose_rotation(bone)])
       var hand=rig.get_node("BookHand").transform;var palm=actor.socket_position("projectile")
       seek(actor,mapping.clip,time)
       for bone in range(rig.get_bone_count()):
        assert(rig.get_bone_pose_position(bone)==original[bone][0] and rig.get_bone_pose_scale(bone)==original[bone][1])
        if bone!=arm:assert(rig.get_bone_pose_rotation(bone).is_equal_approx(original[bone][2]),"Only the casting upper-arm rotation differs from its source")
       assert(rig.get_node("BookHand").transform.is_equal_approx(hand),"Critical gathering keeps the actual folio support unchanged")
       var current=rig.get_bone_pose_rotation(arm)
       if previous!=null:
        var angle=previous.angle_to(current);maximum_step=maxf(maximum_step,angle);assert(angle<.13)
       previous=current
       for mesh in book.find_children("*","MeshInstance3D",true,false):
        for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
         var y=mesh.to_global(vertex).y;lowest=minf(lowest,y);assert(y>.01)
       if step==64:
        if key=="critical_windup":
         var lift=actor.socket_position("projectile").y-palm.y;minimum_lift=minf(minimum_lift,lift);assert(lift>.06,"Critical gathering raises the free casting palm: "+str(lift))
        else:assert(actor.socket_position("projectile").distance_to(palm)<.00001,"Critical release returns to the exact ordinary launch point")
       count+=1
     for key in ["idle","windup","recover","hit","critical_hit","evade","down","guard","victory"]:
      folio.combat_pose("critical_windup");folio.combat_pose(key);assert(not folio.critical_prepared)
    actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," critical casting samples, nine outfits, three folios, both headings, unchanged source bones/book support, minimum palm lift ",minimum_lift," m, book floor ",lowest," m, maximum arm step ",maximum_step," rad and exact ordinary launch endpoint")
 quit()
