extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Trail=preload("res://scripts/combat_trail.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var observed=[]
func _initialize():call_deferred("run")

func watch_trail(node):
 if not node is Trail:return
 await process_frame
 assert(node.sampling,"Real melee begins its trail during the moving strike")
 var actor=node.followed.get_ref()
 assert(actor!=null and actor.pose_name=="strike")
 while node.sampling:await process_frame
 assert(node.samples.size()>1 and node.stroke.mesh!=null,"Actual strike leaves a swept ribbon before contact")
 observed.append(weakref(node))

func run():
 var fighters=Fighters.new();fighters.batching_enabled=false;var game=Rules.new();var rng=game.rng.state
 var stage=Node3D.new();root.add_child(stage);stage.position=Vector3(35,.3,2);stage.rotation.y=.4
 var cases=0;var retained=[]
 for item in fighters.EquipmentVisuals.profiles:
  var look=fighters.EquipmentVisuals.profiles[item]
  if look.kind not in ["sword","axe","lance"]:continue
  for direction in [-1,1]:
   var unit=game.roster.filter(func(entry):return entry.weapon==look.kind)[0].duplicate(true)
   unit.team="player";unit.item=item
   var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.rotation.y=direction*PI/2
   actor.aim_at(actor.global_position+Vector3(-direction*2,1.1,0));actor.pose("windup",1).custom_step(1)
   var steel=actor.bones.Weapon.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return str(mesh.name) in ["SwordBlade","SpearBlade","AxeBlade","HammerHead"])[0]
   var far=actor.trail_edge[1];var matched=false;var minimum=INF
   for vertex in steel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
    var local=actor.bones.Weapon.to_local(steel.to_global(vertex));minimum=minf(minimum,local.z)
    if local.distance_to(far)<.0001:matched=true
   assert(matched and absf(far.z-minimum)<.0001,"Swept tip is an actual furthest blade/head vertex, including each equipped width")
   var trail=Trail.new();stage.add_child(trail);assert(trail.follow(actor,look.kind));trail.set_process(false)
   var motion=actor.pose("strike",1)
   for step in range(16):
    motion.custom_step(1.0/16);actor.apply_constraints();trail.sample()
    var edge=actor.weapon_trail_points()
    if look.kind=="lance" or item=="estoc":
     var tip=actor.bones.Weapon.to_global(actor.trail_edge[1]);var width=.032 if item=="estoc" else .05
     assert(((edge[0]+edge[1])*.5).distance_to(tip)<.0001 and absf(edge[0].distance_to(edge[1])-width)<.0001,"Point-first weapons leave a narrow trail centered on their actual tip")
     var forward=tip-actor.bones.Weapon.global_position
     assert(absf((edge[1]-edge[0]).normalized().dot(forward.normalized()))<.0003,"Thrust ribbons retain width perpendicular to the weapon, rather than collapsing along its shaft")
    assert(trail.to_global(trail.samples[-1][0]).distance_to(edge[0])<.0001 and trail.to_global(trail.samples[-1][1]).distance_to(edge[1])<.0001,"Ribbon follows both live weapon endpoints under transformed parents and either facing")
    assert(trail.samples.size()<=12,"Sweep history has a fixed geometry budget")
   assert(trail.stroke.mesh!=null and trail.stroke.mesh.get_surface_count()==1,"Sword, axe and thrust all form a real swept surface")
   var vertices=trail.stroke.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   assert(vertices.size()<=66)
   for i in range(0,vertices.size(),3):assert((vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()>1e-12,"Sweep excludes degenerate triangles")
   var count=trail.samples.size();trail.sample();assert(trail.samples.size()==count,"A stationary weapon adds no redundant geometry")
   trail.finish();assert(not trail.sampling);retained.append(weakref(trail))
   actor.queue_free();await process_frame;cases+=1
 var deadline=Time.get_ticks_msec()+300
 while Time.get_ticks_msec()<deadline:await process_frame
 for reference in retained:assert(reference.get_ref()==null,"Finished strips release after their short fade")
 assert(game.rng.state==rng)
 var unsupported=Node3D.new();stage.add_child(unsupported);var fallback=Trail.new();stage.add_child(fallback)
 assert(not fallback.follow(unsupported,"sword"),"Authored models without edge sockets retain the existing fallback")
 fallback.queue_free();stage.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-trail-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch_trail)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var saved=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 for item in ["iron_sword","estoc"]:
  a.item=item;saved=app.game.save_data("battle").duplicate(true)
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Weapon trails never change resolved combat")
 assert(observed.size()==2 and observed.all(func(reference):return reference.get_ref()==null),"Live slash/thrust cinematics own and release one swept melee trail each")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",cases," equipped-weapon/facing sweeps, actual transformed endpoints, narrow estoc/lance tip ribbons, bounded nondegenerate ribbons, stationary suppression, fades, fallback and real cinematic lifecycle")
 quit()
