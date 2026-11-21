extends SceneTree
# A defeated preview must return to its baseline height in every living pose.
# Fall support lives in private clips and must not linger on unkeyed tracks.

const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var entries=[];var count=0
 for study in studies.values():
  for id in study.get("campaign_characters",[study.study_character]):entries.append([study,id,true])
  if study.study_id in ["knight_female","knight_male"]:entries.append([study,study.study_character,false])
 for entry in entries:
  var spec=entry[0].duplicate(true)
  if entry[2]:spec.appearance="Identity"
  var unit=rules.roster.filter(func(value):return value.id==entry[1])[0].duplicate(true);unit.team="enemy" if spec.has("study_enemy_class") else "player";unit.item=spec.supported_items[0]
  if unit.team=="enemy":unit.id="fall_recovery_enemy";unit.job=spec.study_enemy_class
  var models=Models.new("");models.catalog={"characters":{unit.id:spec}}
  var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.issues.is_empty());await process_frame;actor.set_process(false)
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var root_bone=rig.find_bone("root");var baseline={}
  for key in actor.poses:
   if key=="down":continue
   sample(actor,key,.65);baseline[key]=rig.get_bone_pose_position(root_bone)
  for key in baseline:
   sample(actor,"down",1);sample(actor,key,.65)
   assert(rig.get_bone_pose_position(root_bone).is_equal_approx(baseline[key]),"Fall support must reset: %s %s"%[spec.study_id,key]);count+=1
  await actor.pose("down",.08).finished;await actor.pose("idle").finished
  assert(rig.get_bone_pose_position(root_bone).is_equal_approx(baseline.idle),"Actual preview playback clears support after a fall")
  actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",entries.size()," revised recruit/enemy/unstyled Knight outfits, ",count," fall-to-living pose resets, actual defeat-to-ready playback and preserved authored root tracks")
 quit()
