extends SceneTree
## Revival reverses each already-fitted fall interval, retaining its support
## tracks and equipment constraints, then returns to the ordinary ready pose.
const Rules=preload("res://scripts/rules.gd")
const Models=preload("res://scripts/combat_models.gd")
const Fighters=preload("res://scripts/fighters.gd")
func _initialize():call_deferred("run")
func pose_snapshot(rig):
 var result=[]
 for bone in rig.get_bone_count():result.append(rig.get_bone_pose(bone))
 return result
func run():
 var world=Node3D.new();root.add_child(world)
 var rules=Rules.new();var saved=rules.save_data("camp").duplicate(true);var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var outfits=0;var samples=0
 for spec_source in studies.values():
  if spec_source.has("study_enemy_class"):continue
  var spec=spec_source.duplicate(true);spec.appearance="Identity"
  for id in spec.get("campaign_characters",[spec.study_character]):
   for promotion in [""]+spec.get("supported_promotions",[]):
    var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.promotion=promotion
    var models=Models.new("");models.catalog={"characters":{id:spec}}
    var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.issues.is_empty());await process_frame;actor.set_process(false)
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var mapping=actor.poses.down;var expected=[]
    actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
    for listener in actor.pose_listeners:listener.combat_pose("down")
    for index in range(13):
     actor.player.stop();actor.player.play_section(mapping.clip,mapping.from,mapping.to,0);actor.player.seek(lerpf(mapping.to,mapping.from,index/12.0),true,true);actor.player.pause();actor.refresh_skeleton()
     expected.append(pose_snapshot(rig))
    var rise=actor.pose("revive",.12);rise.pause()
    assert(actor.player.get_playing_speed()<0 and actor.pose_name=="revive")
    for index in range(13):
     if index>0:actor.player.advance(.01);actor.refresh_skeleton()
     assert(is_equal_approx(actor.player.current_animation_position,lerpf(mapping.to,mapping.from,index/12.0)),"Revival traverses the fitted interval backwards")
     var actual=pose_snapshot(rig)
     for bone in actual.size():assert(actual[bone].is_equal_approx(expected[index][bone]),"Reverse playback preserves source bones, support and equipment: %s %s %s"%[id,promotion,index])
     assert(actor.socket_position("impact").is_finite());samples+=1
    rise.custom_step(.13);assert(not actor.player.is_playing() and is_equal_approx(actor.player.current_animation_position,mapping.from))
    await actor.pose("idle",.03).finished
    assert(actor.pose_name=="idle" and actor.player.get_playing_speed()>0,"Standing recovery restores ordinary forward idle")
    actor.queue_free();await process_frame;outfits+=1
 var fighters=Fighters.new()
 for source in rules.roster:
  var unit=source.duplicate(true);unit.team="player"
  var actor=fighters.build(world,unit,Vector3.ZERO);actor.set_process(false)
  actor.pose("down",.1).custom_step(.11);actor.apply_constraints();var low=actor.socket_position("recovery");var low_head=actor.bones.Head.global_position.y
  var rise=actor.pose("revive",.12);rise.pause();actor.apply_constraints()
  assert(actor.socket_position("recovery").distance_to(low)<.0001,"Starting revival keeps the current wounded support, including mounted pelvis height")
  rise.custom_step(.13);actor.apply_constraints()
  assert(actor.bones.Head.global_position.y>low_head+.05 and actor.socket_position("recovery").is_finite(),"The current-model recipient rises to its ready height")
  actor.queue_free();await process_frame
 assert(rules.save_data("camp")==saved)
 world.queue_free();await process_frame
 print("PASS: %d revised recruit/base/promotion outfits, %d reverse fall samples with exact source bones/support and forward idle restoration, plus all 24 current-model continuous recovery starts; campaign unchanged"%[outfits,samples])
 quit()
