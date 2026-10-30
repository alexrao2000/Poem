extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var interrupted: WeakRef
var interrupted_position=Vector3.ZERO
func _initialize():call_deferred("run")

func skip_approach(app):
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  for actor in app.stage.get_children():
   if not actor is Fighters.Actor or actor.pose_name!="advance" or absf(actor.gait_phase)<.1:continue
   interrupted=weakref(actor);interrupted_position=actor.position
   var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true;app._unhandled_input(key)
   return
 assert(false,"The real cinematic reaches its moving approach")

func lowest_boot(actor) -> float:
 var lowest=INF
 for boot in actor.find_children("Boot","MeshInstance3D",true,false):
  for point in boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   lowest=minf(lowest,boot.to_global(point).y-actor.global_position.y)
 return lowest

func run():
 verify_boot_mesh()
 verify_knee_mesh()
 var fighters=Fighters.new();fighters.batching_enabled=false;var game=Rules.new();var state=game.rng.state;var samples=0
 var stage=Node3D.new();root.add_child(stage)
 for entry in game.roster:
  var unit=entry.duplicate(true);unit.team="player"
  var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false)
  var bent=[false,false]
  assert(actor.shaped_boots==(not actor.mounted),"Infantry use shaped boots while riders retain their fitted stirrup footwear")
  if not actor.mounted:
   for side in ["Left","Right"]:
    assert(actor.bones[side+"Foot"].get_parent()==actor.bones[side+"Knee"] and actor.bones[side+"Foot"].position==Vector3(0,-.38,0),"Ankle articulation retains the authored shin length")
   for boot in actor.find_children("Boot","MeshInstance3D",true,false):
    assert(boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==Fighters.Actor.Boot.mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Visible infantry soles use the same source geometry as their ground support")
  for facing in [-PI/2,PI/2]:
   actor.rotation.y=facing
   for direction in [-1,1]:
    await actor.pose("advance",.001).finished
    for step in range(24):
     actor.position+=-actor.basis.z*.08*direction;actor._process(.016)
     if not actor.mounted:
      verify_level_feet(actor)
      var height=lowest_boot(actor)
      assert(height>=-.001 and height<.025,"Actual boot vertices stay above the arena floor with a planted support foot")
     else:
      verify_mounted_geometry(actor)
      for index in range(4):
       var knee=actor.bones["HorseKnee"+str(index)];var bend=knee.rotation.x
       assert(knee.get_parent()==actor.bones["HorseLeg"+str(index)] and actor.bones["HorseFoot"+str(index)].get_parent()==knee and actor.bones["HorseFoot"+str(index)].has_node("Hoof"),"Lower leg and hoof articulate from their original knee center")
       assert(absf(bend)<=1.41 and (bend<=0 if index%2==0 else bend>=0),"Front knees and rear hocks fold in opposite anatomical directions")
       if absf(bend)>.6:bent[index%2]=true
      assert(is_equal_approx(actor.bones.LeftLeg.rotation.x,.85) and is_equal_approx(actor.bones.RightKnee.rotation.x,-1.25),"Distance-driven horse gait leaves the rider seated")
     var contact=actor.ground_contact_position()
     assert(absf(contact.y-actor.global_position.y)<.0001,"Analytic contact lies on the arena floor for every animated boot/hoof sample")
     var pieces=actor.find_children("Hoof" if actor.mounted else "Boot","MeshInstance3D",true,false)
     var nearest=INF
     for piece in pieces:
      for vertex in piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:nearest=minf(nearest,contact.distance_to(piece.to_global(vertex)))
     assert(nearest<.035,"Ground contact remains on the actual sole geometry in either facing and travel direction")
     assert(actor.travel_direction.dot(-actor.global_basis.z*direction)>.999,"Dust direction follows real forward or backward movement")
     samples+=1
    var phase=actor.gait_phase;var key="HorseLeg0" if actor.mounted else "LeftLeg"
    var settled=actor.bones[key].rotation
    actor._process(3.0)
    assert(is_equal_approx(phase,actor.gait_phase) and actor.bones[key].rotation.is_equal_approx(settled),"Stationary actors cannot run in place")
  if actor.mounted:
   assert(bent.all(func(value):return value),"Both front knees and hind hocks flex through the travelled stride")
   verify_gait_entry(actor)
  else:verify_infantry_entry(actor)
  await actor.pose("windup",.001).finished
  var rotation=actor.bones.LeftLeg.rotation;actor.position.x+=.2;actor._process(.02)
  assert(actor.bones.LeftLeg.rotation.is_equal_approx(rotation),"Combat poses reclaim locomotion joints")
  if actor.mounted:
   for index in range(4):assert(actor.bones["HorseKnee"+str(index)].rotation.is_zero_approx(),"Attack preparation restores the mount's standing lower legs")
   for pose in ["idle","windup","critical_windup","strike","recover","guard","hit","critical_hit","evade","victory","down"]:
    var motion=actor.pose(pose,1)
    for sample in range(4):
     motion.custom_step(.25);actor.apply_constraints();verify_mounted_geometry(actor)
  else:
   for pose in ["idle","critical_windup","strike","recover","idle","critical_hit","hit","down","idle","evade","idle","guard","idle"]:
    var motion=actor.pose(pose,1)
    for sample in range(8):
     motion.custom_step(.125);actor.apply_constraints()
     verify_level_feet(actor)
     var height=lowest_boot(actor)
     assert(height>=-.001 and height<.018,"Actual soles stay planted throughout anticipation, contact, recoil, defeat and recovery, not just at their endpoints")
     assert(absf(actor.ground_contact_position().y-actor.global_position.y)<.0001,"The moving sole constraint follows the interpolated joints")
     for leg in ["LeftLeg","RightLeg"]:
      assert(is_equal_approx(actor.bones[leg].position.y-actor.rest[leg].position.y,actor.support_height),"Hips and upper legs retain the same support offset through each transition")
  if unit.id in ["lyra","oren","bram"]:
   for pose in ["idle","strike","critical_hit","windup"]:
    actor.pose(pose,1).custom_step(1);actor.apply_constraints();verify_knee_clearance(actor)
  actor.queue_free();await process_frame
 # Equivalent travel, subdivided into different frames, has identical stride.
 await verify_contacts(fighters,stage,game)
 var unit=game.roster[0].duplicate(true);unit.team="player"
 var one=fighters.build(stage,unit,Vector3.ZERO);var many=fighters.build(stage,unit,Vector3.ZERO)
 for actor in [one,many]:
  actor.set_process(false);await actor.pose("idle",.001).finished;await actor.pose("advance",.001).finished
 one.position.z-=.63;one._process(.1)
 for step in range(9):many.position.z-=.07;many._process(.1/9)
 assert(absf(one.gait_phase-many.gait_phase)<.00001 and one.bones.LeftLeg.rotation.distance_to(many.bones.LeftLeg.rotation)<.00001,"Stride follows distance independently of frame subdivision")
 var before=one.gait_phase;one.position.z+=.1;one._process(.01)
 assert(one.gait_phase<before,"Retreat reverses the gait while preserving opponent-facing orientation")
 assert(Fighters.Actor.approach_duration(3)>Fighters.Actor.approach_duration(.5) and Fighters.Actor.approach_duration(100)<=.65,"Longer approaches get bounded extra travel time")
 assert(game.rng.state==state,"Locomotion uses no gameplay randomness")
 stage.queue_free();await process_frame;await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-locomotion-test.json"
 root.add_child(app);await process_frame;app.game.start_battle();app.make_map();app.show_battle()
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var saved=app.game.save_data("battle").duplicate(true);var camera=app.camera.transform
 skip_approach(app)
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"hit":true,"crit":false,"damage":1,"remaining":19}],{a.id:20,b.id:20})
 var stopped=interrupted.get_ref() if interrupted!=null else null
 assert(stopped!=null and stopped.pose_name=="advance" and stopped.position.distance_to(interrupted_position)<.1,"Tab kills the actual travel tween before preparation begins")
 assert(not app.stage.visible and app.camera.transform.is_equal_approx(camera) and app.game.save_data("battle")==saved,"Interrupted approach restores the tactical view without changing campaign state")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",samples," roster travel samples, closed tapered boot geometry and exact mesh support, planted actual boot geometry through 2,184 infantry transition samples, smooth infantry entry from an active pose, articulated mounted knees with smooth entry/settling and living/defeated saddle/hoof/stirrup contact, stationary/pose isolation, reversed travel, frame-independent stride/contacts, silent stationary/hidden poses and real Tab interruption")
 quit()

func verify_infantry_entry(actor):
 actor.pose("critical_windup",1).custom_step(1);actor.gait_phase=.8
 var prior={}
 for key in ["LeftLeg","RightLeg","LeftKnee","RightKnee"]:prior[key]=actor.bones[key].rotation
 var motion=actor.pose("advance",.2);actor._process(0)
 for key in prior:assert(actor.bones[key].rotation.is_equal_approx(prior[key]),"Beginning infantry travel preserves the previous hip/knee stance without a first-frame snap")
 motion.custom_step(.05);actor._process(0)
 for key in prior:assert(actor.bones[key].rotation.distance_to(prior[key])<.14,"The first quarter of the approach eases into the returning stride")
 assert(lowest_boot(actor)>=-.001 and lowest_boot(actor)<.025,"Blend into travel keeps the actual supporting boot on the arena floor")
 motion.custom_step(.15);actor._process(0)
 assert(actor.infantry_gait_weight==1 and actor.bones.LeftLeg.rotation.distance_to(prior.LeftLeg)>.3,"The complete distance-driven stride takes ownership after preparation")
 var stopping=actor.pose("windup",.2)
 for step in range(4):
  stopping.custom_step(.05);actor.apply_constraints()
  assert(lowest_boot(actor)>=-.001 and lowest_boot(actor)<.025,"Stopping from the blended stride retains ground contact throughout the attack preparation")
 assert(actor.infantry_gait_weight==0,"Weapon preparation releases locomotion blending")

func verify_gait_entry(actor):
 actor.pose("idle",1).custom_step(1);actor.gait_phase=.8
 var motion=actor.pose("advance",.2);actor._process(0)
 for index in range(4):
  assert(actor.bones["HorseLeg"+str(index)].rotation.is_zero_approx() and actor.bones["HorseKnee"+str(index)].rotation.is_zero_approx(),"Starting travel does not snap the mount into a full stride")
 motion.custom_step(.05);actor._process(0)
 for index in range(4):assert(absf(actor.bones["HorseKnee"+str(index)].rotation.x)<.22,"Initial knee flex blends gradually into travel")
 verify_mounted_geometry(actor)
 motion.custom_step(.15);actor._process(0)
 assert(actor.mounted_gait_weight==1 and maxf(absf(actor.bones.HorseKnee0.rotation.x),absf(actor.bones.HorseKnee1.rotation.x))>.5,"The full articulated gait takes over after the entry transition")
 verify_mounted_geometry(actor)
 var stopping=actor.pose("idle",.2)
 for step in range(4):
  stopping.custom_step(.05);actor.apply_constraints();verify_mounted_geometry(actor)
 assert(actor.mounted_gait_weight==0,"Returning to idle releases travel weighting")
 for index in range(4):assert(actor.bones["HorseKnee"+str(index)].rotation.is_zero_approx(),"Stopping settles every lower leg")

func verify_contacts(fighters,stage,game):
 for job in ["Vanguard","Rider"]:
  var unit=game.roster.filter(func(entry):return entry.job==job)[0].duplicate(true);unit.team="player"
  for direction in [-1,1]:
   var totals=[];var knees=[]
   for subdivisions in [1,40]:
    var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false)
    await actor.pose("advance",.001).finished
    var contacts=[];actor.travel_contact.connect(func(index):contacts.append(index))
    var stride=Fighters.Actor.MountStride.LENGTH if actor.mounted else 1.6
    for step in range(subdivisions):
     actor.position.z-=stride*direction/subdivisions;actor._process(.016)
    assert(contacts==[0,1],"A complete forward or backward stride emits exactly two alternating contacts regardless of frame subdivision")
    if actor.mounted:
     for step in range(subdivisions):
      actor.position.z-=stride*.225*direction/subdivisions;actor._process(.016)
     knees.append([actor.bones.HorseKnee0.rotation,actor.bones.HorseKnee1.rotation,actor.bones.HorseKnee2.rotation,actor.bones.HorseKnee3.rotation])
    totals.append(actor.gait_phase)
    actor._process(1);assert(contacts.size()==2,"Stationary advance cannot play walking sounds")
    actor.hide();actor.position.z-=.9;actor._process(1);assert(contacts.size()==2,"Covered actors do not emit travel cues")
    actor.show();await actor.pose("windup",.001).finished;actor.position.z-=.9;actor._process(.02)
    assert(contacts.size()==2,"Weapon poses do not borrow locomotion contacts")
    actor.queue_free();await process_frame
   assert(absf(totals[0]-totals[1])<.0001)
   if job=="Rider":
    for index in range(4):assert(knees[0][index].distance_to(knees[1][index])<.00001,"Mounted knee flex follows travel distance independently of frame subdivision")

func mesh_vertical_span(mesh: MeshInstance3D) -> Vector2:
 var span=Vector2(INF,-INF)
 for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  var y=mesh.to_global(vertex).y;span.x=minf(span.x,y);span.y=maxf(span.y,y)
 return span

func verify_mounted_geometry(actor):
 var lowest=INF
 for hoof in actor.find_children("Hoof","MeshInstance3D",true,false):lowest=minf(lowest,mesh_vertical_span(hoof).x-actor.global_position.y)
 assert(lowest>=-.001 and lowest<.02,"Actual hoof vertices retain ground contact through the mounted stride and combat poses")
 var pelvis=actor.bones.Body.get_node("Pelvis");var saddle=actor.bones.Horse.get_node("SaddleSeat")
 var gap=mesh_vertical_span(pelvis).x-mesh_vertical_span(saddle).y
 assert(gap>=-.008 and gap<.025,"Rider pelvis stays seated on the saddle as the mount settles and the torso acts")

 for side in ["Left","Right"]:
  var boot=actor.bones[side+"Knee"].get_node("Boot");var bottom=Vector3(0,INF,0)
  for vertex in boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   var point=boot.to_global(vertex)
   if point.y<bottom.y:bottom=point
  var stirrup=actor.bones.Horse.get_node(side+"Stirrup")
  var local=stirrup.to_local(bottom);var box=stirrup.get_aabb()
  assert(absf(local.y-box.end.y)<.003 and local.x>box.position.x and local.x<box.end.x and local.z>box.position.z and local.z<box.end.z,"Actual lowest boot point rests on its stirrup through every mounted pose")

func verify_boot_mesh():
 var Boot=preload("res://scripts/infantry_boot.gd");var mesh=Boot.mesh()
 assert(mesh==Boot.mesh(),"Infantry share one cached boot shape")
 var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={};var orientations={}
 assert(indices.size()==240 and mesh.get_aabb().size.is_equal_approx(Vector3(.18,.15,.29)),"Tapered boot uses 80 triangles within the previous footwear bounds")
 for i in range(0,indices.size(),3):
  var normal=(vertices[indices[i+2]]-vertices[indices[i]]).cross(vertices[indices[i+1]]-vertices[indices[i]])
  assert(normal.length()>.000001,"Boot has no collapsed sole or ankle faces")
  for j in range(3):
   assert(normal.normalized().dot(normals[indices[i+j]])>0,"Boot lighting normals face outward, including the sole crease")
   var a=str(vertices[indices[i+j]].snapped(Vector3.ONE*.000001));var b=str(vertices[indices[i+(j+1)%3]].snapped(Vector3.ONE*.000001));var key=a+":"+b if a<b else b+":"+a
   edges[key]=edges.get(key,0)+1;orientations[key]=orientations.get(key,0)+(1 if a<b else -1)
 for key in edges:assert(edges[key]==2 and orientations[key]==0,"Boot upper, ankle and sole form a closed consistently oriented surface")
 for pitch in [-1.45,-.7,-.3,0,.3,.7,1.45]:
  for roll in [-.1,0,.1]:
   var basis=Basis.from_euler(Vector3(pitch,.4,roll));var contact=Boot.support(basis);var minimum=INF;var distance=INF
   for vertex in vertices:
    var point=basis*vertex;minimum=minf(minimum,point.y);distance=minf(distance,point.distance_to(contact))
   assert(absf(contact.y-minimum)<.000001 and distance<.000001,"Ground support follows an actual lowest shoe vertex at every pose angle")

func verify_level_feet(actor):
 for side in ["Left","Right"]:
  var foot=actor.bones[side+"Foot"]
  assert(foot.global_basis.is_equal_approx(actor.global_basis),"Articulated soles remain level as hips and knees bend")
  assert(foot.position==Vector3(0,-.38,0),"Grounding never stretches or translates an ankle")
  var sole=[]
  var boot=foot.get_node("Boot")
  for point in boot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   if is_equal_approx(point.y,-.075):sole.append(boot.to_global(point).y)
  assert(sole.size()>2 and absf(sole.max()-sole.min())<.00001,"Actual sole vertices form a level support plane")

func verify_knee_mesh():
 var Guard=preload("res://scripts/knee_guard.gd");var mesh=Guard.mesh();assert(mesh==Guard.mesh())
 var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 var edges={};var orientations={}
 assert(indices.size()==312 and mesh.get_aabb().size.x<=.2001 and mesh.get_aabb().size.y<=.2201 and mesh.get_aabb().size.z<.18,"Closed knee shell uses 104 triangles within the former spherical cover bounds")
 for i in range(0,indices.size(),3):
  var a=points[indices[i]];var b=points[indices[i+1]];var c=points[indices[i+2]];var normal=(c-a).cross(b-a)
  assert(normal.length_squared()>1e-14,"Forged shell has no collapsed faces")
  for j in range(3):
   assert(normal.normalized().dot(normals[indices[i+j]])>.99,"Every face lights from its outward normal")
   var from=str(points[indices[i+j]].snapped(Vector3.ONE*.000001));var to=str(points[indices[i+(j+1)%3]].snapped(Vector3.ONE*.000001))
   var key=from+":"+to if from<to else to+":"+from
   edges[key]=edges.get(key,0)+1;orientations[key]=orientations.get(key,0)+(1 if from<to else -1)
 for key in edges:assert(edges[key]==2 and orientations[key]==0,"Rim joins front and inner surfaces into one closed consistently oriented shell")

func nearest_hit(mesh,origin,direction):
 var inverse=mesh.global_transform.affine_inverse();var local=inverse*origin;var ray=inverse.basis*direction;var closest=INF
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays=mesh.mesh.surface_get_arrays(surface);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  if indices==null or indices.is_empty():indices=range(points.size())
  for i in range(0,indices.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(local,ray,points[indices[i]],points[indices[i+1]],points[indices[i+2]])
   if hit!=null:closest=minf(closest,origin.distance_to(mesh.to_global(hit)))
 return closest

func verify_knee_clearance(actor):
 for side in ["Left","Right"]:
  var knee=actor.bones[side+"Knee"];var guard=knee.get_node("KneeGuard")
  var surfaces=actor.bones[side+"Leg"].find_children("*","MeshInstance3D",true,false)
  for x in [-.075,-.04,0,.04,.075]:
   for y in [-.04,0,.05]:
    var origin=knee.to_global(Vector3(x,y,-.3));var direction=knee.global_basis.z.normalized()
    var front=nearest_hit(guard,origin,direction)
    assert(front<INF,"Authored knee shell covers the front sample: "+side+" "+actor.pose_name+" "+str(Vector2(x,y)))
    for surface in surfaces:
     if surface==guard:continue
     assert(nearest_hit(surface,origin,direction)>front+.001,"Trouser, collar and greave remain behind the forged front in actual posed geometry")
