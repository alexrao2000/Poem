extends SceneTree
# Compare consecutive world-space hoof contacts during scaled, reversed travel,
# then check real mounted approach frame order and the complete outfit geometry.

const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Stride=preload("res://scripts/mount_stride.gd")
const Mount=preload("res://scripts/mount_visuals.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var planted_samples=0
var max_drift=0.0
var real_samples=0
var watching=false

func _initialize():call_deferred("run")

func contact(actor,index: int) -> Vector3:
 return actor.bones["HorseFoot"+str(index)].to_global(Mount.LEVEL_HOOF_CENTER-Vector3.UP*Mount.HOOF_RADII.y)

func inspect_contact(actor,previous: Dictionary,live=false) -> Dictionary:
 var planted={}
 for index in range(4):
  var foot=actor.bones["HorseFoot"+str(index)]
  assert(foot.global_basis.y.normalized().dot(Vector3.UP)>.99999,"Articulated hoof stays level through each front/hind knee bend")
  if Stride.phase_for(actor.gait_phase,index)>.5:continue
  var point=contact(actor,index);planted[index]=point
  assert(absf(point.y-actor.global_position.y)<.00001,"Diagonal support hooves share the actual floor")
  if previous.has(index):
   var drift=point.distance_to(previous[index]);max_drift=maxf(max_drift,drift)
   assert(drift<.0001,"A support hoof stays fixed in world space while the horse advances or retreats")
   planted_samples+=1
   if live:real_samples+=1
 return planted

func run():
 var rules=Rules.new();var painter=Fighters.new();var stage=Node3D.new();root.add_child(stage)
 stage.position=Vector3(35,.4,-8);stage.rotation.y=.37;stage.scale=Vector3.ONE*1.15
 var units=rules.roster.filter(func(unit):return unit.job=="Rider").duplicate(true)
 var enemy=units[0].duplicate(true);enemy.id="enemy_hoof_test";enemy.team="enemy";units.append(enemy)
 for unit in units:
  if not unit.has("team"):unit.team="player"
  for facing in [-PI/2,PI/2]:
   for direction in [-1,1]:
    for scale_value in [.8,1.0,1.4]:
     var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.rotation.y=facing;actor.scale=Vector3.ONE*scale_value
     actor.pose("advance",1).custom_step(1);var previous={}
     for step in range(96):
      actor.position+=-actor.basis.z*.02*direction;actor.update_locomotion()
      previous=inspect_contact(actor,previous)
     var clock=actor.gait_phase;var stopped=contact(actor,0)
     actor.update_locomotion();assert(actor.gait_phase==clock and contact(actor,0)==stopped,"Stationary mounts do not pump or drift their hooves")
     actor.queue_free();await process_frame
 stage.transform=Transform3D.IDENTITY;painter.batching_enabled=false
 var outfits=0
 for source in units:
  var choices=[""]
  if source.team=="player":
   for promotion in rules.promotions.filter(func(path):return path.base=="Rider"):choices.append(promotion.id)
  for promotion in choices:
   var unit=source.duplicate(true);unit.promotion=promotion
   var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose("advance",1).custom_step(1)
   for step in range(48):
    actor.position.z-=Stride.LENGTH/48;actor._process(.01);var lowest=INF
    for mesh in actor.find_children("*","MeshInstance3D",true,false):
     for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:lowest=minf(lowest,mesh.to_global(vertex).y)
    assert(lowest>-.001 and lowest<.02,"Full cavalry outfit, equipment and horse stay above the floor with planted hooves")
   outfits+=1;actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-mounted-stride.json";root.add_child(app);await process_frame
 app.game.start_battle();var a=app.game.units[0];var b=app.game.living("enemy")[0]
 a.job="Rider";a.weapon="lance";a.item="iron_lance";a.x=8;a.y=4;b.x=9;b.y=4
 app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch_approach)
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var camera=app.camera.transform
 watching=true
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":b.hp-1,"hit":true,"crit":false}],{a.id:a.hp,b.id:b.hp})
 watching=false
 assert(real_samples>=4,"The actual mounted approach exercises planted contacts after the root tween updates")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.camera.transform.is_equal_approx(camera),"Mounted presentation preserves resolved state and restores the tactical camera")
 await Shutdown.dispose(app);await process_frame
 print("PASS: %d transformed/reversed hoof-plant samples, max drift %.8f m, %d full mounted outfits, level hoof joints and %d actual approach contacts"%[planted_samples,max_drift,outfits,real_samples])
 quit()

func watch_approach(node):
 if not node is Fighters.Actor:return
 await process_frame
 if not node.mounted:return
 var previous={}
 while watching and is_instance_valid(node):
  if node.pose_name=="advance" and node.mounted_gait_weight>.999:
   assert(node.travel_previous.is_equal_approx(node.global_position),"Mounted joints use the current tween-written position")
   previous=inspect_contact(node,previous,true)
  else:previous.clear()
  await process_frame
