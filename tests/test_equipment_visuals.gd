extends SceneTree
const Looks=preload("res://scripts/equipment_visuals.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Rig=preload("res://tests/test_rig_batching.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var flights=[]
func _initialize():call_deferred("run")

func watch_flight(node):
 if not node is Projectile:return
 await process_frame
 flights.append(node.body.get_node("Tip").mesh.get_aabb().size.x)
 assert(node.body.get_node("Shaft").material_override.albedo_color==Color(Looks.profiles.javelin.grip),"Real cinematic carries equipped shaft color into flight")

func closed_mesh(mesh: Mesh):
 var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={}
 for i in range(0,points.size(),3):
  var normal=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(normal.length()>.000001 and normal.normalized().dot(normals[i])<-.999,"Item geometry has outward normals and no collapsed triangles")
  for j in range(3):
   var a=str(points[i+j].snapped(Vector3.ONE*.000001));var b=str(points[i+(j+1)%3].snapped(Vector3.ONE*.000001))
   var edge=a+":"+b if a<b else b+":"+a;edges[edge]=edges.get(edge,0)+1
 for count in edges.values():assert(count==2,"Every item blade/head is closed")

func visual_signature(hand: Node3D) -> String:
 var signature="";var inverse=hand.global_transform.affine_inverse()
 for mesh in hand.find_children("*","MeshInstance3D",true,false):
  var transform=inverse*mesh.global_transform
  for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:signature+=str((transform*vertex).snapped(Vector3.ONE*.00001))
  var material=mesh.material_override
  signature+=str(material.get_shader_parameter("tint") if material is ShaderMaterial else material.albedo_color)
 return signature.sha256_text()

func run():
 var rules=Rules.new();var painter=Fighters.new();painter.batching_enabled=false
 var stage=Node3D.new();root.add_child(stage);var signatures={};var samples=0
 assert(Looks.profiles.size()==rules.equipment.size())
 for item in rules.equipment:
  assert(Looks.resolve(item.kind,item.id)==item.id and Looks.profiles[item.id].kind==item.kind)
  assert(Looks.resolve(item.kind,"missing")==Looks.DEFAULT[item.kind],"Unknown equipment falls back within its kind")
  if item.kind!="sword":assert(Looks.resolve(item.kind,"iron_sword")==Looks.DEFAULT[item.kind],"Mismatched item/kind cannot attach the wrong weapon")
  if item.kind in ["sword","lance","axe"]:
   var mesh=Looks.blade(item.id);assert(mesh==Looks.blade(item.id),"Each item shares cached source geometry")
   closed_mesh(mesh)
   var reach={"sword":-1.075,"lance":-1.62,"axe":-.97}[item.kind]
   assert(is_equal_approx(mesh.get_aabb().position.z,reach),"New item silhouettes keep their tested class contact reach")
  var unit=rules.roster.filter(func(recruit):return recruit.weapon==item.kind)[0].duplicate(true);unit.team="player";unit.item=item.id
  for direction in [-1,1]:
   var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.rotation.y=-direction*PI/2;actor.pose_tween.kill()
   var hand=actor.bones.Weapon;assert(hand.get_meta("equipment")==item.id)
   if item.id=="war_hammer":assert(hand.has_node("HammerHead") and not hand.has_node("AxeBlade"),"War hammer has its own solid blunt head")
   if direction==1:
    var signature=visual_signature(hand)
    assert(not signatures.has(signature),"All equipped items differ in actual geometry or visible materials")
    signatures[signature]=item.id
   var before=Rig.signature(actor);painter.batch_rig(actor);Rig.equivalent(before,Rig.signature(actor))
   assert(actor.bones.Weapon==hand and hand.get_meta("equipment")==item.id,"Item identity and moving grip survive batching")
   actor.aim_at(Vector3(direction*4,1.1,0))
   for pose in ["idle","windup","strike","recover","victory"]:
    var motion=actor.pose(pose,1)
    for step in range(4):
     motion.custom_step(.25);actor.apply_constraints()
     for mesh in hand.find_children("*","MeshInstance3D",true,false):
      if not mesh.is_visible_in_tree():continue
      for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).y>-.01,"Every item stays above ground through ready, attack and finishing poses: "+item.id+" "+pose)
     if item.kind=="bow":
      var height=hand.get_meta("bow_height")
      for i in range(2):
       var string=actor.bones["BowStringTop" if i==0 else "BowStringBottom"]
       var endpoint=string.to_global(Vector3(0,.5,0))
       assert(endpoint.distance_to(hand.to_global(Vector3(0,height if i==0 else -height,.22)))<.0001,"Bowstrings meet the actual limb tips at every bow size and draw")
     samples+=1
   actor.queue_free();await process_frame
  unit.team="enemy";var enemy=painter.build(stage,unit,Vector3.ZERO)
  assert(enemy.bones.Weapon.get_meta("equipment")==item.id,"Enemies use the same equipped item appearance")
  enemy.queue_free();await process_frame
 var thrown=Node3D.new();stage.add_child(thrown)
 var look=Looks.profiles.javelin;Projectile.physical_geometry(thrown,"lance",look)
 assert(is_equal_approx(thrown.get_node("Tip").mesh.get_aabb().size.x,Looks.blade("javelin").get_aabb().size.x),"Held and thrown javelins share head width")
 assert(thrown.get_node("Shaft").material_override.albedo_color==Color(look.grip) and thrown.get_node("Tip").material_override.albedo_color==Color(look.steel),"Thrown spear retains the equipped material colors")
 assert(signatures.size()==22)
 stage.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-equipment-visuals-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.stage.child_entered_tree.connect(watch_flight)
 var attacker=app.game.units[0];var target=app.game.living("enemy")[0]
 attacker.weapon="lance";attacker.item="javelin";attacker.job="Knight";attacker.x=8;attacker.y=4;target.x=10;target.y=4
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 await app.cinematic(attacker,target,[{"actor":attacker.id,"target":target.id,"hit":true,"crit":false,"damage":1,"remaining":19}],{attacker.id:20,target.id:20})
 assert(flights.size()==1 and is_equal_approx(flights[0],Looks.blade("javelin").get_aabb().size.x),"Actual thrown attack uses its equipped javelin head")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Item art never changes combat outcome or random state")
 await Shutdown.dispose(app);await process_frame
 print("PASS: 22 distinct actual weapon appearances, closed cached blade/head geometry, retained reach, %d grounded pose samples, bowstring endpoints, enemy equipment and thrown spear continuity"%samples)
 quit()
