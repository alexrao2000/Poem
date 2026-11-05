extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
var real_contacts=0
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func watch_contact(node):
 if not node is Impact:return
 await process_frame
 var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.pose_name=="strike")
 assert(actors.size()==1)
 var actor=actors[0];var edge=actor.weapon_trail_points()
 var distance=Geometry3D.get_closest_point_to_segment(node.global_position,edge[0],edge[1]).distance_to(node.global_position)
 print("LIVE CONTACT ",distance)
 assert(distance<.012,"Actual cinematic contact stays on the authored blade")
 real_contacts+=1

func run():
 var world=Node3D.new();root.add_child(world)
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var game=Rules.new();game.start_battle();var saved=game.save_data("battle").duplicate(true);var rng=game.rng.state;var samples=0
 for gender in ["female","male"]:
  var library=Models.new("");library.catalog={"characters":{"lyra":studies[gender]}}
  var actor=library.build(world,game.units[0],Vector3(35,0,0));assert(actor!=null and library.issues.is_empty());await process_frame
  var rig=actor.contact.rig;var local_positions=[];var local_scales=[]
  for bone in range(rig.get_bone_count()):local_positions.append(rig.get_bone_pose_position(bone));local_scales.append(rig.get_bone_pose_scale(bone))
  var grip=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip");var original_grip=grip.transform
  for side in [-1,1]:
   actor.rotation.y=-side*PI/2
   for height in [1.0,1.1,1.35,1.65,1.85]:
    var target=actor.position+Vector3(side*1.4,height,0)
    actor.aim_at(target);await actor.pose("windup",.04).finished
    var start=actor.weapon_trail_points()[1]
    var motion=actor.pose("strike",.08)
    while motion.is_valid() and motion.is_running():
     await process_frame;actor.refresh_skeleton()
     assert(actor.weapon_trail_points()[1].is_finite())
     assert(grip.transform==original_grip,"Contact aiming preserves the original palm fit")
    actor.refresh_skeleton()
    var tip=actor.weapon_trail_points()[1]
    var edge=actor.weapon_trail_points();var distance=Geometry3D.get_closest_point_to_segment(target,edge[0],edge[1]).distance_to(target)
    assert(distance<.006,"Authored blade reaches the target: "+gender+" "+str(height))
    for bone in actor.contact.chain:
     assert(rig.get_bone_pose_position(bone).is_equal_approx(local_positions[bone]) and rig.get_bone_pose_scale(bone).is_equal_approx(local_scales[bone]),"Arm correction never stretches or translates a bone")
    var rotations=[]
    for bone in actor.contact.chain:rotations.append(rig.get_bone_pose_rotation(bone))
    for repeat in range(10):actor.refresh_skeleton();assert(actor.weapon_trail_points()[1].distance_to(tip)<.001,"Repeated contact samples do not accumulate drift")
    for index in range(actor.contact.chain.size()):assert(rotations[index].is_equal_approx(rig.get_bone_pose_rotation(actor.contact.chain[index])),"Manual contact queries restore the authored animation input")
    assert(start.distance_to(tip)>.2)
    await actor.pose("recover",.04).finished
    assert(actor.contact.influence==0 and actor.weapon_trail_points()[1].distance_to(tip)>.1,"Recovery returns to the authored clip")
    samples+=1
  actor.aim_at(actor.position+Vector3(12,9,0));await actor.pose("strike",.04).finished
  assert(actor.weapon_trail_points()[1].is_finite(),"Unreachable target stays finite")
  actor.aim_at(Vector3(INF,0,0));assert(actor.contact.target.is_finite(),"Invalid aim points are ignored")
  assert(grip.transform==original_grip)
  world.remove_child(actor);actor.queue_free();await process_frame
 assert(game.save_data("battle")==saved and game.rng.state==rng)
 for invalid in [{"skeleton":"Missing","bones":["hand_r","lowerarm_r","upperarm_r"]},{"skeleton":"Rig/Armature/Skeleton3D","bones":["Head","lowerarm_r","upperarm_r"]},{"skeleton":"Rig/Armature/Skeleton3D","bones":[17]}]:
  var bad=studies.female.duplicate(true);bad.contact=invalid
  var library=Models.new("");library.catalog={"characters":{"lyra":bad}}
  var before=world.get_child_count()
  assert(library.build(world,game.units[0],Vector3.ZERO)==null and library.issues.size()==1 and world.get_child_count()==before,"Invalid contact bindings fail without leaving a partial actor")
 var misplaced=studies.female.duplicate(true);misplaced.sockets.trail_tip=misplaced.sockets.gaze
 var rejected=Models.new("");rejected.catalog={"characters":{"lyra":misplaced}}
 assert(rejected.build(world,game.units[0],Vector3.ZERO)==null and rejected.issues.size()==1,"Blade sockets on another bone cannot be used for arm correction")
 world.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-authored-contact-save.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(watch_contact)
 var ally=app.game.units[0];var enemy=app.game.living("enemy")[0]
 ally.x=8;ally.y=4;enemy.x=9;enemy.y=4
 for gender in ["female","male"]:
  for counter in [false,true]:
   var striker=enemy if counter else ally;var recipient=ally if counter else enemy
   striker.job="Duelist";striker.weapon="sword";striker.item="iron_sword"
   app.fighters.models.catalog={"characters":{striker.id:studies[gender]}}
   for blocked in [false,true]:
    recipient.job="Knight" if blocked else "Rider";recipient.weapon="lance";recipient.item="iron_lance"
    var before=app.game.save_data("battle").duplicate(true);var seed=app.game.rng.state
    await app.cinematic(ally,enemy,[{"actor":striker.id,"target":recipient.id,"damage":0 if blocked else 1,"remaining":20 if blocked else 19,"hit":true,"crit":counter}],{ally.id:20,enemy.id:20})
    assert(app.game.save_data("battle")==before and app.game.rng.state==seed,"Actual authored exchange preserves resolved state and RNG")
 assert(real_contacts==8)
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",samples," authored arm contacts against infantry/mounted heights on both sides, fixed grips, stable manual sampling, recovery, eight actual shield/mounted cinematic contacts and unchanged simulation")
 quit()
