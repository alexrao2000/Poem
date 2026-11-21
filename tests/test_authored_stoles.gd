extends SceneTree
# Sample both independently skinned pieces at their shared waist seam.
const Models=preload("res://scripts/debug_source_models.gd")
func _initialize():call_deferred("run")
func vertex_position(panel: MeshInstance3D,index: int,rig: Skeleton3D) -> Vector3:
 var arrays=panel.mesh.surface_get_arrays(0);var vertex=arrays[Mesh.ARRAY_VERTEX][index];var result=Vector3.ZERO
 for influence in range(4):
  var at=index*4+influence;var bind=arrays[Mesh.ARRAY_BONES][at];var bone=rig.find_bone(panel.skin.get_bind_name(bind))
  result+=(rig.get_bone_global_pose(bone)*panel.skin.get_bind_pose(bind)*vertex)*arrays[Mesh.ARRAY_WEIGHTS][at]
 return rig.to_global(result)
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var models=Models.new(["caster","caster_female"])
 var count=0;var gap=0.0
 for id in ["tarin","vela","noor"]:
  for promotion in ["star_sage","spellwarden"]:
   var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.promotion=promotion
   var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null);await process_frame;actor.set_process(false)
   var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var waist=rig.get_bone_global_rest(rig.find_bone("pelvis")).origin.y+.075
   var costume=actor.model.get_node("Identity").promotion;assert(costume.panels.size()==6)
   var upper=[];var lower=[]
   for panel in costume.panels:
    assert(panel.skin.get_bind_count()==6 and panel.get_meta("promotion_stole",false))
    var bounds=panel.mesh.get_aabb();var entries=upper if bounds.end.y>waist+.1 else lower
    var vertices=panel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for index in range(vertices.size()):
     if absf(vertices[index].y-waist)<.00001:entries.append([panel,index,vertices[index]])
   assert(upper.size()>=18 and lower.size()>=18,"Both stoles retain a subdivided waist boundary")
   var pairs=[]
   for entry in upper:
    var matches=lower.filter(func(other):return other[2].distance_to(entry[2])<.00001)
    assert(not matches.is_empty(),"No gap is introduced between upper and lower patterns at rest")
    pairs.append([entry,matches[0]])
   for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
    for listener in actor.pose_listeners:listener.combat_pose(key)
    var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
    for step in range(17):
     actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,step/16.0),true,true);actor.player.pause();actor.refresh_skeleton()
     for pair in pairs:
      var distance=vertex_position(pair[0][0],pair[0][1],rig).distance_to(vertex_position(pair[1][0],pair[1][1],rig));gap=maxf(gap,distance)
      assert(distance<.0001,"The waist boundary remains joined during actual animation");count+=1
   actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," independently skinned stole seam samples across six outfits and nine living/falling actions; maximum gap ",gap," m")
 quit()
