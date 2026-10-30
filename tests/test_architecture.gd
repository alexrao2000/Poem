extends SceneTree
const Cloth=preload("res://scripts/wind_cloth.gd")
const Roof=preload("res://scripts/architecture.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 await verify_gate()
 await verify_towers()
 await verify_fountain()
 await verify_cart()
 await verify_barrels()
 var colors=[]
 for variant in range(3):
  var roof=Roof.roof(variant);assert(roof==Roof.roof(variant),"Repeated houses share their immutable roof mesh")
  var arrays=roof.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
  assert(points.size()/3<600,"Tile courses stay within a small fixed triangle budget")
  assert(roof.get_aabb().size.x>1.6 and roof.get_aabb().size.z>1.25,"Both eaves overhang the existing wall footprint")
  assert(roof.get_aabb().end.y>1.7 and roof.get_aabb().end.y<1.82,"The gable peak is covered by a restrained raised ridge")
  for i in range(0,points.size(),3):
   var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
   assert(cross.length()>.000001 and cross.normalized().dot(normals[i])<-.999,"All roof and tile faces have valid clockwise winding and matching normals")
  for z in [-.63,-.1,.1,.63]:
   for step in range(-8,9):
    var x=step*.1;var underside=INF
    for i in range(0,points.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(Vector3(x,0,z),Vector3.UP,points[i],points[i+1],points[i+2])
     if hit!=null:underside=minf(underside,hit.y)
    assert(absf(underside-(1.7-absf(x)*.625))<.0001,"Actual roof underside meets the existing gable profile without a hole or protrusion")
  var palette=arrays[Mesh.ARRAY_COLOR]
  assert(not palette[0] in colors,"House roof palettes are distinct")
  colors.append(palette[0])
  var varied=false
  for color in palette:
   if not color.is_equal_approx(palette[0]):varied=true
  assert(varied,"Tile courses retain subtle individual coloration")
 assert(Roof.material().vertex_color_use_as_albedo and Roof.material().vertex_color_is_srgb,"Roof tile colors reach the shared material")
 var scenery=Scenery.new();scenery.batching_enabled=false;var game=Rules.new();var state=game.rng.state;var cases=0
 for chapter in range(12):
  game.chapter=chapter
  for item in game.info().landmarks:
   if item.kind not in ["house","warehouse"]:continue
   var p=Vector3(item.position[0],0,item.position[1]);var expected=Roof.variant_at(p)
   var world=Node3D.new();root.add_child(world);scenery.landmark(world,p,item.kind)
   var house=world.get_node("House");assert(house.get_meta("roof_variant")==expected)
   assert(house.get_node("TiledRoof").mesh==Roof.roof(expected),"Map building uses its stable position-based palette")
   var context=scenery.combat_context(game,{"x":int(p.x)-1,"y":int(p.z)},{"x":int(p.x),"y":int(p.z)})
   assert(context.landmarks[0].kind==item.kind and context.landmarks[0].roof_variant==expected,"Nearest building keeps its roof identity when remapped into the arena")
   var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
   var landmarks=arena.get_children().filter(func(node):return str(node.name).begins_with("ArenaLandmark"))
   assert(landmarks[0].get_node("House").get_meta("roof_variant")==expected,"Actual combat backdrop receives the preserved palette")
   world.queue_free();arena.queue_free();await process_frame;cases+=1
 assert(cases>0 and game.rng.state==state,"Architecture never consumes gameplay RNG")
 await verify_cloth()
 print("PASS: arched castle gate/portcullis, tiered fountain basins/jets, six shared fortified towers, battlement/deck rays, three cached roofs, 204 gable intersections, ",cases," house identities, 14 pinned cloth resources, bounded motion parameters and cleanup")
 quit()

func verify_cloth():
 var world=Node3D.new();root.add_child(world);world.position=Vector3(35,.3,-2);world.rotation.y=.3;world.scale=Vector3.ONE*2
 var previous_material: ShaderMaterial
 for standard in [true,false]:
  var cloth=Cloth.new();world.add_child(cloth);cloth.set_process(false)
  var extent=Vector2(.45,.32) if standard else Vector2(1.3,1.4)
  cloth.configure(extent,Color("a54c47") if standard else Color("dcd4b9"),standard,Cloth.PERIOD-.01)
  assert(cloth.material!=previous_material,"Each cloth owns its paused motion phase")
  previous_material=cloth.material
  var arrays=cloth.cloth.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var uv=arrays[Mesh.ARRAY_TEX_UV];var normals=arrays[Mesh.ARRAY_NORMAL]
  assert(points.size()==432 and cloth.cloth.custom_aabb.size.z>0,"Cloth uses a fixed small grid with nonzero wind culling depth")
  var pinned=0;var fork=0
  for i in range(points.size()):
   assert(cloth.cloth.custom_aabb.grow(.0001).has_point(points[i]),"Rest geometry remains in the explicit deformation bounds")
   for depth in [-extent.x*.06,extent.x*.06]:
    assert(cloth.cloth.custom_aabb.grow(.0001).has_point(points[i]+Vector3(0,-extent.y*.045,depth)),"Culling bounds cover the full documented wind and sag envelope")
   if is_zero_approx(uv[i].x):
    assert(points[i].x==0 and points[i].z==0,"The full attachment edge lies on the mast plane")
    assert(cloth.to_global(points[i]).distance_to(world.to_global(Vector3(0,points[i].y,0)))<.0001,"Attachment survives a rotated and scaled parent")
    pinned+=1
   if is_equal_approx(uv[i].x,1) and is_equal_approx(uv[i].y,.5):
    assert(is_equal_approx(points[i].x,extent.x*(.87 if standard else 1)),"Standards have a forked edge; sails remain rectangular")
    fork+=1
  assert(pinned>0 and fork>0)
  for i in range(0,points.size(),3):assert((points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized().dot(normals[i])<-.999,"Canvas has consistent front faces and normals")
  assert(cloth.material.get_shader_parameter("linen_atlas")==Cloth.LINEN and cloth.material.get_shader_parameter("dimensions")==extent,"Shared painted linen and local dimensions reach the shader")
  cloth._process(.02);assert(absf(cloth.phase-.01)<.00001,"Wind clock wraps at its common wave period")
  var phase=cloth.phase;world.hide();cloth._process(4)
  assert(cloth.phase==phase and cloth.material.get_shader_parameter("phase")==phase,"Hidden map/stage cloth stops updating")
  world.show();cloth._process(.2);assert(cloth.phase>phase)
  var batching=preload("res://scripts/static_batch.gd").new().combine(world)
  assert(batching.sources==0 and cloth.cloth.get_parent()==cloth,"Static batching preserves shader-local cloth geometry")
  cloth.queue_free();await process_frame
 world.queue_free();await process_frame
 var game=Rules.new();var scenery=Scenery.new();var flags=0;var sails=0;var state=game.rng.state
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  var pieces=world.find_children("*","Node3D",true,false).filter(func(node):return node is Cloth)
  var expected_flags=0;var expected_sails=0
  for row in game.info().map:expected_flags+=row.count("o")
  for landmark in game.info().landmarks:
   if landmark.kind=="boat":
    expected_sails+=1
    var at=landmark.position;var context=scenery.combat_context(game,{"x":int(at[0])-1,"y":int(at[1])},{"x":int(at[0]),"y":int(at[1])})
    var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
    var arena_sails=arena.find_children("*","Node3D",true,false).filter(func(node):return node is Cloth and not node.standard)
    assert(arena_sails.size()==context.landmarks.filter(func(item):return item.kind=="boat").size(),"Nearby boats keep their cloth sails in actual combat backdrops")
    arena.queue_free()
  assert(pieces.filter(func(piece):return piece.standard).size()==expected_flags and pieces.filter(func(piece):return not piece.standard).size()==expected_sails,"All objective standards and boat sails survive scene batching")
  flags+=expected_flags;sails+=expected_sails
  var references=pieces.map(func(piece):return weakref(piece));world.queue_free();await process_frame
  for reference in references:assert(reference.get_ref()==null,"Cloth resources release with their map")
 assert(flags==12 and sails==2 and game.rng.state==state,"All campaign cloth is bounded and independent of gameplay RNG")

func verify_towers():
 var masonry=preload("res://scripts/fortification.gd")
 var shape=masonry.tower();assert(shape==masonry.tower(),"Repeated towers share the same stone mesh")
 var data=shape.surface_get_arrays(0);var points=data[Mesh.ARRAY_VERTEX];var normals=data[Mesh.ARRAY_NORMAL]
 assert(points.size()/3<=2200 and shape.get_aabb().size.x<=1.401 and shape.get_aabb().end.y<=2.541,"Tower detail keeps the blocked footprint and a bounded triangle budget")
 assert(masonry.material().vertex_color_use_as_albedo and masonry.material().vertex_color_is_srgb)
 for index in range(0,points.size(),3):
  var cross=(points[index+1]-points[index]).cross(points[index+2]-points[index])
  assert(cross.length_squared()>1e-12 and cross.normalized().dot(normals[index])<-.999,"Every masonry face has nondegenerate clockwise winding and correct outward lighting")
 for sample in [[Vector2(.58,0),2.54],[Vector2(cos(PI/8+.04),sin(PI/8+.04))*.58,2.20],[Vector2(.2,.1),2.12]]:
  var highest=-INF
  for index in range(0,points.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(sample[0].x,4,sample[0].y),Vector3.DOWN,points[index],points[index+1],points[index+2])
   if hit!=null:highest=maxf(highest,hit.y)
  assert(absf(highest-sample[1])<.001,"Actual tower rays distinguish raised battlements, open gaps and the inset roof deck")
 var game=Rules.new();var scenery=Scenery.new();scenery.batching_enabled=false;var count=0
 for chapter in range(12):
  game.chapter=chapter
  for item in game.info().landmarks:
   if item.kind!="tower":continue
   var world=Node3D.new();root.add_child(world)
   var point=Vector3(item.position[0],0,item.position[1]);scenery.landmark(world,point,item.kind)
   var tower=world.get_node("FortifiedTower")
   assert(tower.mesh==shape and tower.position==point and tower.material_override==masonry.material(),"Authored towers use the shared detailed mesh at their existing positions")
   var context=scenery.combat_context(game,{"x":int(point.x)-1,"y":int(point.z)},{"x":int(point.x),"y":int(point.z)})
   var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
   var visible=arena.find_children("FortifiedTower","MeshInstance3D",true,false)
   assert(visible.size()==context.landmarks.filter(func(value):return value.kind=="tower").size(),"Nearby combat scenery keeps the same fortified identity")
   for node in visible:assert(node.mesh==shape)
   world.queue_free();arena.queue_free();await process_frame;count+=1
 assert(count==6,"Every authored castle tower is covered")

func mesh_top(shape: ArrayMesh,point: Vector2) -> float:
 var vertices=shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var highest=-INF
 for i in range(0,vertices.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(point.x,3,point.y),Vector3.DOWN,vertices[i],vertices[i+1],vertices[i+2])
  if hit!=null:highest=maxf(highest,hit.y)
 return highest

func verify_fountain():
 var fountain=preload("res://scripts/fountain.gd")
 var stone=fountain.stone();var pools=fountain.pools();var streams=fountain.flows()
 assert(stone==fountain.stone() and pools==fountain.pools() and streams==fountain.flows(),"Repeated town/combat fountains share their immutable meshes")
 var triangles=0
 for shape in [stone,pools,streams]:
  var arrays=shape.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];triangles+=vertices.size()/3
  for i in range(0,vertices.size(),3):
   var cross=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
   assert(cross.length_squared()>1e-12 and cross.normalized().dot(normals[i])<-.9999,"Basin and water faces have nondegenerate geometry and matching clockwise normals")
  for point in vertices:assert(Vector2(point.x,point.z).length()<.5 and point.y>=0 and point.y<.8,"All fountain detail remains inside its existing occupied tile")
 var tangents=pools.surface_get_arrays(0)[Mesh.ARRAY_TANGENT]
 assert(tangents!=null and tangents.size()==pools.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()*4,"Water ripples have a real tangent frame")
 for index in range(0,tangents.size(),4):assert(absf(tangents[index])>.999 and absf(tangents[index+1])+absf(tangents[index+2])<.001,"Pool UVs orient the water normal map consistently")
 assert(triangles<1200,"Small landmark stays within its fixed geometry budget")
 for point in [Vector2(.28,.01),Vector2(.14,.01)]:
  assert(mesh_top(pools,point)>mesh_top(stone,point)+.01,"Actual water disks sit above each basin floor")
 assert(mesh_top(stone,Vector2(.4,.01))>.24 and mesh_top(stone,Vector2(.22,.01))>.76,"Both basin rims remain above their water surface")
 for jet in range(4):
  var top=fountain.jet_point(0,jet*PI*.5);var bottom=fountain.jet_point(1,jet*PI*.5)
  assert(top.y>.70 and absf(bottom.y-.18)<.001 and Vector2(bottom.x,bottom.z).length()<.335,"Each narrow jet lands just above the lower pool")
 assert("fog_disabled" in fountain.stream_material().shader.code and not "depth_test_disabled" in fountain.stream_material().shader.code,"Transparent jets retain depth testing without painting fog on faded edges")
 var game=Rules.new();var scenery=Scenery.new();scenery.batching_enabled=false
 var item=game.info().landmarks.filter(func(value):return value.kind=="fountain")[0]
 var world=Node3D.new();root.add_child(world);var point=Vector3(item.position[0],0,item.position[1]);scenery.landmark(world,point,"fountain")
 var node=world.get_node("TieredFountain")
 assert(node.get_child_count()==3 and node.get_node("CarvedStone").mesh==stone and node.get_node("BasinWater").mesh==pools,"Actual town landmark uses stone, water and falling-stream meshes")
 var context=scenery.combat_context(game,{"x":int(point.x)-1,"y":int(point.z)},{"x":int(point.x),"y":int(point.z)})
 var arena=Node3D.new();root.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),context)
 var backdrop=arena.find_child("TieredFountain",true,false)
 assert(backdrop!=null and backdrop.get_node("CarvedStone").mesh==stone,"Nearby combat preserves the town fountain identity")
 world.queue_free();arena.queue_free();await process_frame

func verify_gate():
 var masonry=preload("res://scripts/fortification.gd")
 var shape=masonry.gate_wall();assert(shape==masonry.gate_wall())
 var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()/3<=240,"Gatehouse masonry has a small fixed geometry budget")
 for i in range(0,points.size(),3):
  var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(cross.length_squared()>1e-12 and cross.normalized().dot(normals[i])<-.999,"Gate masonry uses closed, outward-lit clockwise faces")
 for sample in [[Vector2(0,1),false],[Vector2(0,4.2),true],[Vector2(1,2.8),false],[Vector2(1,3.1),true],[Vector2(1.8,1),true]]:
  var blocked=false
  for i in range(0,points.size(),3):
   if Geometry3D.ray_intersects_triangle(Vector3(sample[0].x,sample[0].y,2),Vector3.FORWARD,points[i],points[i+1],points[i+2])!=null:blocked=true
  assert(blocked==sample[1],"Actual masonry leaves an arched passage below its header and between its piers")
 var scenery=Scenery.new();scenery.batching_enabled=false
 var arena=Node3D.new();root.add_child(arena)
 scenery.battle_landscape(arena,Vector3(35,0,0),{"environment":"castle"})
 var gates=arena.find_children("CastleGate","Node3D",true,false)
 assert(gates.size()==1 and gates[0].position==Vector3(35,0,-9),"Castle combat replaces the old flat wall at the same background depth")
 var gate=gates[0];assert(gate.get_node("GateMasonry").mesh==shape)
 var bars=gate.get_children().filter(func(node):return str(node.name).begins_with("PortcullisBar"))
 assert(bars.size()==11,"The gate contains a recessed open iron grille")
 for bar in bars:
  var top=(bar.transform*bar.get_aabb()).end.y
  assert(bar.position.z<0 and top<2+sqrt(1.96-bar.position.x*bar.position.x),"Portcullis bars fit below the curved stone opening")
 var supports=gate.get_children().filter(func(node):return str(node.name).begins_with("Buttress"))
 assert(supports.size()==6)
 for support in supports:assert(absf(support.position.x)>=4 and support.position.z<1,"Castle supports engage the side walls and keep the gate approach clear")
 var bounds=AABB();var first=true
 for node in gate.get_children():
  if node is MeshInstance3D:
   var box=node.transform*node.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
 assert(bounds.position.x>=-17.501 and bounds.end.x<=17.501 and bounds.end.y<=5.101,"Detailed castle wall keeps its fixed battlefield backdrop footprint")
 arena.queue_free();await process_frame

func wheel_hit(shape: Mesh,point: Vector2) -> bool:
 var points=shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for i in range(0,points.size(),3):
  if Geometry3D.ray_intersects_triangle(Vector3(point.x,-1,point.y),Vector3.UP,points[i],points[i+1],points[i+2])!=null:return true
 return false

func verify_cart():
 var wheel=preload("res://scripts/cart_wheel.gd");var shape=wheel.mesh()
 assert(shape==wheel.mesh() and wheel.material()==wheel.material(),"Road carts share wheel geometry and material")
 var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
 assert(points.size()==696,"Six spokes, wooden rim and iron tire use 232 triangles")
 for i in range(0,points.size(),3):
  var normal=(points[i+1]-points[i]).cross(points[i+2]-points[i])
  assert(normal.length()>.000001 and normal.normalized().dot(normals[i])<-.999,"All wheel faces have matching outward normals and clockwise winding")
 for i in range(6):
  var spoke=Vector2.from_angle(i*TAU/6);var gap=Vector2.from_angle((i+.5)*TAU/6)
  assert(wheel_hit(shape,spoke*.13) and wheel_hit(shape,gap*.22),"Actual rays hit every spoke and the surrounding rim")
  assert(not wheel_hit(shape,gap*.13),"Every spoke gap is physically open rather than painted on a solid disc")
 var scenery=Scenery.new();var world=Node3D.new();root.add_child(world)
 world.position=Vector3(35,.2,3);world.rotation.y=.4;world.scale=Vector3.ONE*1.7
 scenery.cart(world,Vector3.ZERO)
 var cart=world.get_node("RoadCart")
 var wheels=cart.get_children().filter(func(node):return str(node.name).begins_with("SpokedWheel"))
 var axles=cart.get_children().filter(func(node):return str(node.name).begins_with("WheelAxle"))
 var bearings=cart.get_children().filter(func(node):return str(node.name).begins_with("AxleBearing"))
 assert(wheels.size()==4 and axles.size()==2 and bearings.size()==4,"All four wheels share two supported axles")
 for node in wheels:
  var lowest=INF
  for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:lowest=minf(lowest,node.to_global(vertex).y)
  assert(absf(lowest-world.global_position.y)<.00001,"Iron tire touches the cart's ground plane under a rotated/scaled parent")
  var axle=axles.filter(func(part):return is_equal_approx(part.position.z,node.position.z))[0]
  assert(is_equal_approx(axle.position.y,node.position.y) and axle.scale.x*.5>absf(node.position.x),"Axle crosses the wheel centers and reaches their hubs")
 for bearing in bearings:
  assert(bearing.position.y-bearing.scale.y*.5<.251 and bearing.position.y+bearing.scale.y*.5>.35,"Bearings join the axle to the underside of the bed")
 world.queue_free();await process_frame

func barrel_hit(shape: Mesh,position: Vector3,direction: Vector3) -> Variant:
 var points=shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var closest=null;var distance=INF
 for i in range(0,points.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(position,direction,points[i],points[i+1],points[i+2])
  if hit!=null and position.distance_squared_to(hit)<distance:closest=hit;distance=position.distance_squared_to(hit)
 return closest

func verify_barrels():
 var barrel=preload("res://scripts/barrel_visuals.gd");var total=0
 for part in ["wood","hoops","lid_marks"]:
  var shape=barrel.mesh(part);assert(shape==barrel.mesh(part),"Repeated barrels share immutable source geometry")
  var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={}
  total+=points.size()/3
  for i in range(0,points.size(),3):
   var cross=(points[i+1]-points[i]).cross(points[i+2]-points[i])
   assert(cross.length()>.000001 and cross.normalized().dot(normals[i])<-.98,"Barrel faces remain nondegenerate with outward normals and clockwise winding")
   for j in range(3):
    var point=points[i+j]
    assert(point.y>=0 and point.y<=.40001 and Vector2(point.x,point.z).length()<=.16801,"New barrel stays inside the former body/hoop footprint")
    var a=str(point.snapped(Vector3.ONE*.000001));var b=str(points[i+(j+1)%3].snapped(Vector3.ONE*.000001))
    var edge=a+":"+b if a<b else b+":"+a;edges[edge]=edges.get(edge,0)+1
  if part=="wood":
   for count in edges.values():assert(count==2,"Bowed wooden shell, lip, recessed lid and bottom form one closed solid")
 assert(total==222,"Three barrel parts share a fixed 222-triangle budget")
 var body=barrel.mesh("wood")
 var lid=barrel_hit(body,Vector3(0,1,0),Vector3.DOWN);var lip=barrel_hit(body,Vector3(.138,1,0),Vector3.DOWN)
 assert(lid!=null and lip!=null and absf(lid.y-.392)<.00001 and absf(lip.y-.4)<.00001,"Actual rays find a recessed lid below the surrounding wooden lip")
 var middle=barrel_hit(body,Vector3(1,.2,0),Vector3.LEFT);var end=barrel_hit(body,Vector3(1,.03,0),Vector3.LEFT)
 assert(middle!=null and end!=null and middle.x>end.x+.015,"Actual side profile bows outward through the middle")
 for y in [.06,.34]:
  var wood=barrel_hit(body,Vector3(1,y,0),Vector3.LEFT);var hoop=barrel_hit(barrel.mesh("hoops"),Vector3(1,y,0),Vector3.LEFT)
  assert(wood!=null and hoop!=null and hoop.x-wood.x>.002 and hoop.x-wood.x<.003,"Both iron hoops sit just outside the curved wood")
 var scenery=Scenery.new();var world=Node3D.new();root.add_child(world);scenery.barrel(world,Vector3(3,.4,2),.75)
 var prop=world.get_node("Barrel")
 assert(prop.position==Vector3(3,.4,2) and prop.scale==Vector3.ONE*.75 and prop.get_child_count()==3,"Warehouse and cart callers retain their existing placements with three material pieces")
 world.queue_free();await process_frame
