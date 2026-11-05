extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Sword=preload("res://scripts/authored_sword.gd")
func _initialize():call_deferred("run")
func sample(actor,mapping: Dictionary,time: float):
 actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();var specs=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var count=0;var furthest=0.0;var source_open=0.0
 for pair in [["female","nell"],["male","silas"]]:
  var unit=rules.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player"
  var spec=specs[pair[0]].duplicate(true);var baseline_spec=spec.duplicate(true);baseline_spec.erase("equipment")
  var baseline_library=Models.new("");baseline_library.catalog={"characters":{unit.id:baseline_spec}}
  var original=baseline_library.build(world,unit,Vector3.ZERO);await process_frame
  var source_rig=original.model.get_node("Rig/Armature/Skeleton3D");var fingers=Sword.finger_names();var original_death=original.player.get_animation("Death01")
  var source_tracks=original_death.get_track_count()
  for item in spec.supported_items:
   unit.item=item;var library=Models.new("");library.catalog={"characters":{unit.id:spec}}
   var actor=library.build(world,unit,Vector3.ZERO);assert(actor!=null and library.issues.is_empty());await process_frame
   var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var weapon=actor.model.get_node(spec.equipment).get_node("Weapon")
   assert(is_equal_approx(weapon.get_node("WeaponGrip").scale.x*.027,actor.model.get_node(spec.equipment).handle_radius),"The actual hilt fits the imported hand without changing its length")
   assert(actor.player.get_animation("Death01")!=original_death,"Grip changes only the adapter's private clips")
   for facing in [-PI/2,PI/2]:
    actor.rotation.y=facing;original.rotation.y=facing
    for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
     var mapping=actor.poses[key]
     for step in range(17):
      var time=lerpf(mapping.from,mapping.to,step/16.0);sample(original,mapping,time);sample(actor,mapping,time)
      var a=weapon.to_global(Vector3(0,0,-.195));var b=weapon.to_global(Vector3(0,0,.035))
      for digit in ["thumb","index","middle","ring","pinky"]:
       var point=rig.to_global(rig.get_bone_global_pose(rig.find_bone(digit+"_04_leaf_r")).origin)
       var gap=point.distance_to(Geometry3D.get_closest_point_to_segment(point,a,b));furthest=maxf(furthest,gap)
       assert(gap<.045,"Every fingertip remains near the actual held hilt through travel, attack, recoil and defeat")
      for bone in range(rig.get_bone_count()):
       assert(rig.get_bone_pose_position(bone).is_equal_approx(source_rig.get_bone_pose_position(bone)) and rig.get_bone_pose_scale(bone).is_equal_approx(source_rig.get_bone_pose_scale(bone)),"Equipped grip never translates or scales any bone")
       if rig.get_bone_name(bone) not in fingers:assert(rig.get_bone_pose_rotation(bone).is_equal_approx(source_rig.get_bone_pose_rotation(bone)),"Free hand, wrist, arm, body and face preserve their source rotations")
      if key=="down" and step==16:
       var tip=source_rig.to_global(source_rig.get_bone_global_pose(source_rig.find_bone("middle_04_leaf_r")).origin)
       source_open=maxf(source_open,tip.distance_to(Geometry3D.get_closest_point_to_segment(tip,a,b)))
      count+=1
   var before=actor.player.get_animation("Death01").get_track_count()
   assert(actor.model.get_node(spec.equipment).configure_animations(actor.player).is_empty() and actor.player.get_animation("Death01").get_track_count()==before,"Rebinding equipment does not accumulate finger tracks")
   actor.queue_free();await process_frame
  assert(original_death.get_track_count()==source_tracks and source_open>.09,"The unmodified source still demonstrates the open-hand defect")
  original.queue_free();await process_frame
 var equipment=Sword.new();var invalid=AnimationPlayer.new();root.add_child(invalid)
 assert(not equipment.configure_animations(invalid).is_empty(),"Missing grip profiles report a configuration error")
 var library=AnimationLibrary.new();library.add_animation("Sword_Idle",Animation.new());invalid.add_animation_library("",library)
 assert(not equipment.configure_animations(invalid).is_empty(),"Incomplete finger profiles cannot silently leave an open grip")
 equipment.free();invalid.queue_free();world.queue_free();await process_frame
 print("PASS: ",count," equipped grip samples across both rigs, three swords and both headings; max fingertip/hilt gap ",furthest," m versus open source ",source_open," m; unchanged non-finger bones/source clips, idempotent setup and missing-profile errors")
 quit()
