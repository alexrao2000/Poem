extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var contacts=0
func _initialize():call_deferred("run")

func watch_contact(node):
 if not node is Impact:return
 await process_frame
 var attackers=node.get_parent().get_children().filter(func(child):return child is Fighters.Actor and child.pose_name=="strike")
 assert(attackers.size()==1,"Actual contact has one striking actor")
 var actor=attackers[0]
 assert(contact_on_weapon(actor,actor.aim_target),"Real slash meets the resolved target with its tip or the solid blade at close guard range")
 assert(contact_on_weapon(actor,node.global_position),"Contact effect remains on actual weapon geometry instead of a detached flash")
 contacts+=1

func contact_on_weapon(actor,point: Vector3) -> bool:
 if actor.bones.Weapon.to_global(actor.trail_edge[1]).distance_to(point)<.003:return true
 var normal=actor.bones.Weapon.global_basis.y.normalized()
 for sign_value in [-1,1]:
  var found=false
  for mesh in actor.bones.Weapon.find_children("*","MeshInstance3D",true,false):
   var local=mesh.to_local(point);var direction=mesh.global_basis.inverse()*normal*sign_value
   for surface in range(mesh.mesh.get_surface_count()):
    var arrays=mesh.mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
    if indices==null or indices.is_empty():indices=range(vertices.size())
    for index in range(0,indices.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(local,direction,vertices[indices[index]],vertices[indices[index+1]],vertices[indices[index+2]])
     if hit!=null and mesh.to_global(hit).distance_to(point)<.05:found=true;break
    if found:break
   if found:break
  if not found:return false
 return true

func run():
 var stage=Node3D.new();root.add_child(stage);var painter=Fighters.new();var rules=Rules.new();var samples=0
 for recruit in rules.roster.filter(func(unit):return unit.weapon in ["sword","axe"]):
  for item in rules.equipment.filter(func(item):return item.kind==recruit.weapon):
   var unit=recruit.duplicate(true);unit.team="player";unit.item=item.id
   var actor=painter.build(stage,unit,Vector3(35,0,0));actor.set_process(false)
   var arm_position=actor.bones.Arm.position;var elbow_position=actor.bones.Elbow.position;var grip_position=actor.bones.Weapon.position
   for direction in [-1,1]:
    actor.rotation.y=-direction*PI/2
    for height in [1.1,1.85]:
     var target=actor.position+Vector3(direction*Fighters.Actor.melee_spacing(unit.weapon),height,0);actor.aim_at(target)
     for preparation in ["windup","critical_windup"]:
      actor.pose(preparation,1).custom_step(1)
      assert(actor.slash_weight==0,"Preparation retains the authored swing")
      var strike=actor.pose("strike",1)
      for step in range(8):
       strike.custom_step(.125);actor.apply_constraints()
       assert(actor.bones.Arm.position==arm_position and actor.bones.Elbow.position==elbow_position and actor.bones.Weapon.position==grip_position,"Aiming never stretches bones or slides the weapon through its hand")
       var before=actor.bones.Weapon.global_transform;actor.apply_constraints()
       assert(actor.bones.Weapon.global_transform.is_equal_approx(before),"Repeated constraints do not accumulate rotation drift")
       for mesh in actor.bones.Weapon.find_children("*","MeshInstance3D",true,false):
        for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).y>-.01,"Aimed stroke cannot drag the weapon through the arena floor")
      var tip=actor.bones.Weapon.to_global(actor.trail_edge[1])
      assert(tip.distance_to(target)<.003,"Actual equipped cutting edge meets infantry and riders from either side: "+unit.id+" "+item.id)
      actor.pose("recover",1).custom_step(1);actor.apply_constraints()
      assert(actor.slash_weight==0 and actor.bones.Weapon.to_global(actor.trail_edge[1]).distance_to(tip)>.04,"Recovery blends out of target tracking into its existing follow-through")
      samples+=1
   actor.aim_at(actor.position+Vector3(12,1.1,0));actor.pose("strike",1).custom_step(1);actor.apply_constraints()
   assert(actor.bones.Weapon.global_transform.is_finite() and actor.bones.Elbow.position==elbow_position,"Unreachable external targets clamp to reach without NaNs or stretched arms")
   actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-slash-contact-save.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(watch_contact)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 for kind in ["sword","axe"]:
  a.weapon=kind;a.item="iron_sword" if kind=="sword" else "iron_axe"
  for blocked in [false,true]:
   b.job="Knight" if blocked else "Rider";b.weapon="lance"
   var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
   await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":0 if blocked else 1,"remaining":20 if blocked else 19,"hit":true,"crit":false}],{a.id:20,b.id:20})
   assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Presentation preserves resolved HP, saves and RNG")
 assert(contacts==4,"Real sword and axe contacts cover mounted bodies and prepared shields")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",samples," equipped slash contacts against infantry/riders, both sides and preparations; non-stretched rig, stable constraints, grounded blades, recovery and four real shield/mounted exchanges")
 quit()
