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
 await verify_shields(painter,rules,stage)
 await verify_quivers(painter,rules,stage)
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
 print("PASS: 22 distinct actual weapon appearances, closed cached blade/head geometry, retained reach, %d grounded pose samples, bowed shields, open quivers/feather clearance, bowstring endpoints, enemy equipment and thrown spear continuity"%samples)
 quit()

func shield_intersection(mesh: Mesh,xy: Vector2) -> Variant:
 var points=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var nearest=null
 for i in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(xy.x,xy.y,-1),Vector3.BACK,points[i],points[i+1],points[i+2])
  if hit!=null and (nearest==null or hit.z<nearest.z):nearest=hit
 return nearest

func verify_shields(painter,rules,stage):
 var shape=preload("res://scripts/knight_shield.gd")
 var body=shape.body_mesh();var trim=shape.trim_mesh()
 assert(body==shape.body_mesh() and trim==shape.trim_mesh(),"Knights share cached shield geometry")
 closed_mesh(body)
 var vertex_total=0
 for mesh in [body,trim]:
  var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
  vertex_total+=points.size()
  for i in range(0,points.size(),3):
   var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
   assert(cross.length()>.000001 and cross.normalized().dot(normals[i])<-.999)
  if mesh==trim:
   for vertex in points:
    var behind=shield_intersection(body,Vector2(vertex.x,vertex.y))
    assert(behind!=null and behind.z-vertex.z>.0009 and behind.z-vertex.z<.04,"Metal rim and crest remain just in front of the bowed panel without buried trim")
    assert(normals[0].z<-.9,"Shield ornament faces outward")
 assert(vertex_total==192,"Shield body and ornament share a 64-triangle budget")
 assert(shield_intersection(body,Vector2(0,-.35))!=null and shield_intersection(body,Vector2(.15,-.30))==null,"Heater shield tapers to a physical lower point")
 var center=shield_intersection(body,Vector2.ZERO);var side=shield_intersection(body,Vector2(.2,0))
 assert(center.z<side.z-.02,"Shield face bows outward from its rim")
 var knights=rules.roster.filter(func(unit):return unit.job=="Knight")
 for source in knights:
  for team in ["player","enemy"]:
   var unit=source.duplicate(true);unit.team=team
   var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
   var elbow=actor.bones.Shield
   assert(elbow.get_node("ShieldBody").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] and elbow.get_node("ShieldTrim").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==trim.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Every heavy shield follows the actual off-hand forearm")
   for pose in ["idle","advance","windup","strike","guard","hit","victory"]:
    actor.pose(pose,1).custom_step(1);actor.apply_constraints()
    for vertex in body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:assert(elbow.get_node("ShieldBody").to_global(vertex).y>0,"Shield stays above the floor in living combat poses")
    assert(actor.socket_position("guard").distance_to(elbow.get_node("ShieldBody").to_global(center))<.00001,"Guard contact follows the actual bowed panel center through every pose")
    if pose=="guard":assert((-elbow.global_basis.z).dot(-actor.global_basis.z)>.999,"Raised shield faces the incoming opponent instead of rotating backward with the forearm")
   actor.queue_free();await process_frame

func quiver_floor(mesh: Mesh,point: Vector2) -> Variant:
 var points=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var nearest=null
 for i in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(point.x,1,point.y),Vector3.DOWN,points[i],points[i+1],points[i+2])
  if hit!=null and (nearest==null or hit.y>nearest.y):nearest=hit
 return nearest

func verify_quivers(painter,rules,stage):
 var shape=preload("res://scripts/quiver_visuals.gd")
 var body=shape.mesh("body");closed_mesh(body)
 var center=quiver_floor(body,Vector2.ZERO);var rim=quiver_floor(body,Vector2(.067,0))
 assert(center!=null and is_equal_approx(center.y,-.20) and rim!=null and is_equal_approx(rim.y,.24),"Quiver has an actual open cavity, solid floor and annular lip")
 assert(quiver_floor(body,Vector2(.09,0))==null)
 for tail in shape.TAILS:
  assert(tail.y>.45 and tail.y<.50)
  var floor_hit=quiver_floor(body,Vector2(tail.x,tail.z))
  assert(floor_hit!=null and is_equal_approx(floor_hit.y,-.20),"Each arrow is aligned with the opening rather than emerging through the cap or side")
 var shafts=shape.mesh("shafts").get_aabb();var feathers=shape.mesh("feathers").get_aabb()
 assert(shafts.position.y<.24 and shafts.end.y>.45 and feathers.position.y>.24,"Arrow shafts enter the container and all feathers clear the rim")
 assert(feathers.size.x<.12 and feathers.size.z<.12,"Feathered tails retain the archer's compact back silhouette")
 for part in ["body","rim","shafts","feathers"]:assert(shape.mesh(part)==shape.mesh(part),"Quiver source parts are cached")
 for source in rules.roster.filter(func(unit):return unit.weapon=="bow"):
  var unit=source.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
  var quiver=actor.find_child("Quiver",true,false)
  assert(quiver!=null and quiver.get_child_count()==4,"All four quiver parts share one tilted attachment")
  assert(is_equal_approx(quiver.rotation.z,-.22))
  var feather=quiver.get_node("QuiverFeathers")
  assert(feather.material_override.next_pass.get_shader_parameter("width")==.001,"Fine feather edges retain their own narrow ink outline")
  for pose in ["idle","advance","windup","critical_windup","strike","recover","victory"]:
   actor.pose(pose,1).custom_step(1);actor.apply_constraints()
   for part in quiver.get_children():
    for vertex in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:assert(part.to_global(vertex).y>0,"Attached quiver clears the ground through bow animation")
  actor.queue_free();await process_frame
