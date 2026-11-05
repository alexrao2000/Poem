extends SceneTree
const Vertices=preload("authored_vertices.gd")
var job="Vanguard"
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var entries={}
 var curves=JSON.parse_string(FileAccess.get_file_as_string("res://data/authored_fall_fit.json"))
 for study in studies.values():
  if study.has("mount"):continue
  if study.has("study_enemy_class"):
   if study.study_enemy_class==job:entries["enemy:"+job]=[study,study.study_character]
  else:
   for id in study.get("campaign_characters",[study.study_character]):
    var recruit=rules.roster.filter(func(value):return value.id==id)[0]
    if recruit.job==job:entries["recruit:"+id]=[study,id]
 var count=0;var lowest=INF
 for key in entries:
  var spec=entries[key][0].duplicate(true);spec.appearance="Identity"
  var unit=rules.roster.filter(func(value):return value.id==entries[key][1])[0].duplicate(true);unit.item=spec.supported_items[0];unit.team="enemy" if key.begins_with("enemy:") else "player"
  if unit.team=="enemy":unit.id=key;unit.job=job
  var raw=load(spec.scene).instantiate();var source=raw.get_node(NodePath(spec.player)).get_animation("Death01");var path=NodePath("Armature/Skeleton3D:root")
  var source_track=source.find_track(path,Animation.TYPE_POSITION_3D);var source_keys=[]
  if source_track>=0:
   for index in range(source.track_get_key_count(source_track)):source_keys.append(source.track_get_key_value(source_track,index))
  var models=load("res://scripts/combat_models.gd").new("");models.catalog={"characters":{unit.id:spec}}
  var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.issues.is_empty());actor.rotation.y=.7;await process_frame;actor.set_process(false)
  var identity=actor.model.get_node("Identity");identity.set_process(false);identity.hair_motion.update(0,"down",2)
  var animation=actor.player.get_animation("Death01");assert(animation!=source and curves.has(key));animation.loop_mode=Animation.LOOP_NONE
  var track=animation.find_track(path,Animation.TYPE_POSITION_3D);assert(track>=0 and animation.track_get_key_count(track)==curves[key].size())
  var cache=Vertices.prepare(actor).filter(func(entry):
   var material=entry[0].get_active_material(0)
   return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
  for listener in actor.pose_listeners:listener.combat_pose("down")
  var previous=0.0;var rig=actor.model.get_node("Rig/Armature/Skeleton3D")
  for step in range(513):
   actor.player.stop();actor.player.play("Death01",0);actor.player.seek(animation.length*step/512.0,true,true);actor.player.pause();actor.refresh_skeleton()
   var floor=Vertices.minimum(actor,cache)-actor.global_position.y;lowest=minf(lowest,floor)
   assert(floor>.010,"Whole falling outfit clears the actual floor: %s step %s height %s"%[key,step,floor])
   var height=rig.get_bone_pose_position(rig.find_bone("root")).y
   assert(step==0 or absf(height-previous)<.025,"Fitted support remains continuous through the fall")
   previous=height;count+=1
  var attachments=rig.find_children("*","BoneAttachment3D",true,false);actor.refresh_skeleton();var direct=attachments.map(func(anchor):return anchor.transform)
  await process_frame;await process_frame
  for index in range(attachments.size()):assert(attachments[index].transform.is_equal_approx(direct[index]),"Fitted fall root agrees in direct and native attachment updates")
  assert(source.find_track(path,Animation.TYPE_POSITION_3D)==source_track,"Shared source clip keeps its original root track")
  if source_track>=0:
   for index in range(source_keys.size()):assert(source.track_get_key_value(source_track,index)==source_keys[index])
  actor.queue_free();raw.free();await process_frame
 assert(entries.size()==4,"Every infantry class includes its three recruits and anonymous enemy")
 world.queue_free();await process_frame
 print("PASS: ",job," ",count," complete falling outfits, minimum ",lowest," m, continuous private root support, native/direct attachments and unchanged source clips")
 quit()
