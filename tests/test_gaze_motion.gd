extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
class Opponent extends Node3D:
 func socket_position(_key):return global_position

func _initialize():call_deferred("run")
func run():
 var painter=Fighters.new();var rules=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var target=Opponent.new();stage.add_child(target);var samples=0;var rng=rules.rng.state
 for recruit in rules.roster:
  var unit=recruit.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false)
  var neck=actor.bones.Gaze;var head=actor.bones.Head
  assert(head.get_parent()==neck and actor.gaze_motion.neck==neck,"Separate gaze joint survives batching above the animated head")
  actor.face_opponent(target)
  for direction in [-1,1]:
   actor.rotation.y=-direction*PI/2
   for height in [1.79,2.54]:
    target.position=Vector3(direction*2,height,.30)
    for pose in ["idle","windup","strike","recover"]:
     actor.pose(pose,1).custom_step(1)
     actor.gaze_motion.rotation=Vector2.ZERO;neck.rotation=Vector3.ZERO
     var head_pose=head.rotation;var root_transform=actor.transform
     var before=(-head.global_basis.z).normalized().dot((target.global_position-head.global_position).normalized())
     for frame in range(8):actor.gaze_motion.update(pose,.1)
     var after=(-head.global_basis.z).normalized().dot((target.global_position-head.global_position).normalized())
     assert(after>=before-.00001,"Gaze moves the actual face toward infantry/cavalry eye height")
     assert(absf(neck.rotation.x)<=.320001 and absf(neck.rotation.y)<=.450001 and is_zero_approx(neck.rotation.z),"Tracking stays within restrained neck limits")
     assert(head.rotation==head_pose and actor.transform==root_transform,"Gaze cannot overwrite local head animation or actor movement")
     assert(actor.socket_position("gaze")==head.global_position)
     samples+=1
  for reaction in ["hit","evade","down","victory"]:
   actor.pose(reaction,1).custom_step(1);var head_pose=head.rotation
   actor.gaze_motion.update(reaction,1.0)
   assert(actor.gaze_motion.rotation.length()<.0001 and head.rotation==head_pose,"Recoil, defeat and finishing poses relax tracking without losing their authored head pose")
  actor.queue_free();await process_frame
 assert(samples==384 and rules.rng.state==rng)
 var unit=rules.roster[0].duplicate(true);unit.team="player"
 var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose("idle",1).custom_step(1);actor.face_opponent(target)
 target.position=Vector3(.4,2.54,-2);actor.gaze_motion.update("idle",1)
 var before=actor.gaze_motion.rotation
 target.position=Vector3(-.4,1.2,-2);actor.gaze_motion.update("idle",.1)
 assert(actor.gaze_motion.rotation.distance_to(before)>.01,"Moving opponent updates the live target rather than a stale position")
 actor.set_process(true)
 var hold=HitStop.new();root.add_child(hold);hold.play([actor],.2);hold.motion.pause();before=actor.gaze_motion.rotation
 for frame in range(3):await process_frame
 assert(actor.gaze_motion.rotation==before,"Local hit-stop freezes neck tracking")
 hold.queue_free();await process_frame;actor.hide();before=actor.gaze_motion.rotation
 for frame in range(3):await process_frame
 assert(actor.gaze_motion.rotation==before,"Hidden model suspends tracking")
 actor.show();actor.set_process(false);target.queue_free();await process_frame
 actor.gaze_motion.update("idle",1.0)
 assert(actor.gaze_motion.rotation.length()<.0001,"Removing the weakly held target settles the neck safely")
 stage.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-gaze-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle()
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var saved=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"hit":true,"crit":false,"damage":1,"remaining":19}],{a.id:20,b.id:20})
 var actors=app.stage.get_children().filter(func(node):return node is Fighters.Actor and not node.is_queued_for_deletion())
 assert(actors.size()==2 and actors[0].gaze_motion.target.get_ref()==actors[1] and actors[1].gaze_motion.target.get_ref()==actors[0],"The real cinematic binds both combatants to one another")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Gaze is presentation only")
 await Shutdown.dispose(app);await process_frame
 print("PASS: 384 actual face-direction samples, bounded infantry/cavalry gaze, separate head poses, live/weak targets, hit-stop/visibility and real mutual cinematic binding")
 quit()
