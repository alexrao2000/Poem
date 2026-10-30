extends SceneTree
const Cover=preload("res://scripts/ground_cover.gd")
const Rules=preload("res://scripts/rules.gd")
const Batch=preload("res://scripts/static_batch.gd")
func _initialize():call_deferred("run")
func run():
 var cover=Cover.new();var image=(load(cover.catalog.texture) as Texture2D).get_image();var cell=image.get_width()/2
 assert(image.get_width()==image.get_height() and cover.catalog.plants.size()==4)
 for index in range(4):
  var record=cover.catalog.plants[index];var coverage=0
  for y in range(cell):
   for x in range(cell):
    if image.get_pixel(x+(index%2)*cell,y+(index/2)*cell).a>.45:
     coverage+=1
     assert(x>cell*.1 and y>cell*.1 and x<cell*.9 and y<cell*.9,"All four plants have generous transparent atlas gutters")
  assert(coverage>1000 and coverage<cell*cell*.6,"Plant silhouette retains transparent gaps")
  var mesh=cover.shape(index);assert(mesh==cover.shape(index),"Repeated clumps reuse cached geometry")
  var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var uvs=arrays[Mesh.ARRAY_TEX_UV];var bends=arrays[Mesh.ARRAY_TEX_UV2]
  assert(points.size()==12,"Each plant uses only four triangles")
  for i in range(points.size()):
   assert(points[i].y>-.02 and points[i].y<1.02,"Measured opaque root sits at soil level with only a small transparent gutter below")
   assert(uvs[i].x>float(index%2)*.5 and uvs[i].x<float(index%2+1)*.5 and uvs[i].y>float(index/2)*.5 and uvs[i].y<float(index/2+1)*.5,"UVs cannot sample neighboring atlas cells")
   assert(is_equal_approx(bends[i].y,clampf(points[i].y,0,1)),"Wind weights pin the base and increase up each clump")
  for i in range(0,points.size(),3):
   var facing=(points[i+2]-points[i]).cross(points[i+1]-points[i]).normalized()
   assert(facing.dot(arrays[Mesh.ARRAY_NORMAL][i])>.999,"Clockwise triangles agree with their supplied normals")
 var game=Rules.new();var kinds={};var total=0
 var world=Node3D.new();root.add_child(world)
 for chapter in range(12):
  game.chapter=chapter;var before=game.rng.state;var entries=Cover.map_entries(game)
  assert(entries==Cover.map_entries(game),"Placement is reproducible without touching gameplay RNG")
  if game.info().environment not in Cover.THEMES:assert(entries.is_empty(),"Stone/industrial interiors do not sprout meadow plants")
  for entry in entries:
   kinds[entry.kind]=true;total+=1
   assert(game.terrain(entry.cell) in [".","f","h"],"Roads, bridges, objectives, shrines, water and walls remain clear")
   var delta=entry.position-Vector3(entry.cell.x,0,entry.cell.y)
   assert(delta.length()>.43 and delta.length()<.52 and entry.position.y==0,"Plant roots hug the cell perimeter and remain on land")
   if game.terrain(entry.cell)=="h":assert(Vector2(delta.x,delta.z).distance_to(Vector2(.22,-.2))>=.4,"Hill plants avoid the existing boulder footprint")
   if entry.kind==2:
    var water=false
    for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:water=water or game.terrain(entry.cell+direction)=="~"
    assert(water and game.info().environment in Cover.NATURAL,"Reeds occur only along natural shorelines")
   var node=cover.plant(world,entry);var bounds=node.mesh.get_aabb()
   for point in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
    var offset=node.transform*point-Vector3(entry.cell.x,0,entry.cell.y)
    assert(Vector2(offset.x,offset.z).length()>.24,"The full plant envelope leaves the unit's central standing area open")
   assert(node.extra_cull_margin>=.0199 and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Small clumps retain wind culling margin without extra shadow passes")
  assert(game.rng.state==before,"Cosmetic placement never consumes battle randomness")
 assert(total>100 and kinds.size()==4,"Campaign uses every original plant type")
 var before_wind=0.0;var vertex_count=0
 for node in world.get_children():
  for uv in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]:before_wind+=uv.y;vertex_count+=1
 var stats=Batch.new().combine(world);var after_wind=0.0;var after_count=0
 for node in world.get_children():
  assert(node.get_meta("static_batch",false) and node.extra_cull_margin>=.0199,"Static batches retain conservative wind bounds")
  for uv in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]:after_wind+=uv.y;after_count+=1
 assert(vertex_count==after_count and absf(before_wind-after_wind)<.001 and stats.batches<10,"Baking preserves plant wind weights while sharing a small number of spatial submissions")
 world.free()
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);var center=Vector3(35,.7,0)
  cover.add_arena(world,center,{"environment":game.info().environment,"chapter":chapter,"terrain":"."})
  for plant in world.get_children():
   var offset=plant.position-center
   assert(absf(offset.x)>6 or offset.z< -4,"Close-up plants leave engagement, projectiles and footwork clear")
   assert(is_equal_approx(offset.y,0 if offset.z>=-3 else -.06),"Arena roots follow the actual central or distant ground plane")
   if game.info().environment=="river":assert(offset.z>=-2.5,"River planting never floats above the water behind the fighting lane")
  world.free()
 world=Node3D.new();root.add_child(world);cover.add_arena(world,Vector3.ZERO,{"environment":"road","terrain":"="})
 assert(world.get_child_count()==0,"Wooden bridge cutaways stay free of grass")
 world.free()
 print("PASS: four original plant cards, ",total," deterministic edge placements, open unit centers, natural banks, arena footwork clearance, grounded pivots and preserved batched wind data")
 quit()
