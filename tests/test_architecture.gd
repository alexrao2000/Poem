extends SceneTree
const Cloth=preload("res://scripts/wind_cloth.gd")
const Roof=preload("res://scripts/architecture.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
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
 print("PASS: three cached roofs, 204 gable intersections, ",cases," house identities, 14 pinned cloth resources, bounded motion parameters and cleanup")
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
