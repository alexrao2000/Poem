extends SceneTree
const Models=preload("res://scripts/debug_source_models.gd")
const Vertices=preload("helpers/authored_vertices.gd")
var study_ids=["female","male","vanguard","vanguard_male"]
var character_ids=["lyra","cassian","rhea","nell","silas","yuna"]
var item_ids=["iron_sword","dueling_sword","tempered_sword","estoc"]
var critical_clip="SwordCriticalAttack"
func _initialize():call_deferred("run")
func seek(actor,clip,time):
 actor.player.get_animation(clip).loop_mode=Animation.LOOP_NONE
 actor.player.play(clip,0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new()
 var models=Models.new(study_ids);var count=0;var lowest=INF;var gap=0.0
 for id in character_ids:
  var source=rules.roster.filter(func(unit):return unit.id==id)[0];var promotions=[""]
  promotions.append_array(rules.promotions.filter(func(value):return value.base==source.job).map(func(value):return value.id))
  for promotion in promotions:
   for item in item_ids:
    var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty(),str(models.models.issues));await process_frame;actor.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip")
    var cache=Vertices.prepare(actor).filter(func(entry):return grip.is_ancestor_of(entry[0]))
    var normal=actor.player.get_animation("Sword_Attack");var critical=actor.player.get_animation(critical_clip)
    assert(normal!=critical)
    var track=normal.find_track(NodePath("Armature/Skeleton3D:spine_02"),Animation.TYPE_ROTATION_3D)
    var extra=critical.find_track(NodePath("Armature/Skeleton3D:spine_02"),Animation.TYPE_ROTATION_3D)
    assert(normal.rotation_track_interpolate(track,.36).angle_to(critical.rotation_track_interpolate(extra,.36))>.25,"Critical preparation has a distinct restrained torso turn")
    assert(normal.rotation_track_interpolate(track,.433).is_equal_approx(critical.rotation_track_interpolate(extra,.433)),"Critical strike returns to the exact ordinary torso contact pose")
    for facing in [-PI/2,PI/2]:
     actor.rotation.y=facing;var target=actor.to_global(Vector3(0,1.85,-actor.approach_spacing(item)));actor.aim_at(target)
     for key in ["critical_windup","strike"]:
      for listener in actor.pose_listeners:listener.combat_pose(key)
      var chosen=grip.animation_pose(key);assert(chosen==("critical_strike" if key=="strike" else key))
      var mapping=actor.poses[chosen]
      if actor.contact!=null:actor.contact.influence=1 if key=="strike" else 0
      for step in range(17):
       var time=lerpf(mapping.from,mapping.to,step/16.0)
       seek(actor,"Sword_Attack",time);var legs=[]
       for bone in ["pelvis","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"]:legs.append(rig.get_bone_global_pose(rig.find_bone(bone)))
       seek(actor,mapping.clip,time)
       for index in range(legs.size()):assert(rig.get_bone_global_pose(rig.find_bone(["pelvis","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"][index])).is_equal_approx(legs[index]),"Anticipation keeps the source lower-body support")
       lowest=minf(lowest,Vertices.minimum(actor,cache));assert(lowest>.01,"Critical preparation retains weapon floor clearance")
       count+=1
      if key=="strike":
       var edge=actor.weapon_trail_points();var distance=actor.sockets.trail_tip.global_position.distance_to(target) if item=="estoc" else Geometry3D.get_closest_point_to_segment(target,edge[0],edge[1]).distance_to(target)
       gap=maxf(gap,distance);assert(distance<.006,"Critical contact retains the actual elevated target")
     for key in ["idle","guard","windup","hit","evade","down","victory"]:
      grip.combat_pose("critical_windup");grip.combat_pose(key);assert(grip.animation_pose("strike")=="strike","Ordinary pose selection clears critical anticipation")
    actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," ",critical_clip," preparation/contact samples, ",character_ids.size()*3," outfits, four weapons, both headings, unchanged lower-body support, floor ",lowest," m, elevated contact gap ",gap," m and ordinary-pose reset")
 quit()
