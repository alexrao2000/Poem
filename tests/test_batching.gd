extends SceneTree
const Batch=preload("res://scripts/static_batch.gd")
const Crowns=preload("res://scripts/conifer_crowns.gd")
const Scenery=preload("res://scripts/scenery.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func signature(node: Node3D) -> Dictionary:
 var batch=Batch.new();var list=[]
 # Collect baked meshes as well as original geometry for equivalence checks.
 var queue=[{"node":node,"transform":Transform3D.IDENTITY}]
 var triangles=0;var vertices=0;var totals=[0.0,0.0,0.0];var uv_totals=[0.0,0.0]
 while not queue.is_empty():
  var entry=queue.pop_back()
  for child in entry.node.get_children():
   if not child is Node3D or child.is_queued_for_deletion():continue
   var transform=entry.transform*child.transform
   if child is MeshInstance3D:
    for surface in range(child.mesh.get_surface_count()):
     var arrays=child.mesh.surface_get_arrays(surface);var points=arrays[Mesh.ARRAY_VERTEX]
     vertices+=points.size()
     triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else points.size())/3
     for point in points:
      var transformed=transform*point
      totals[0]+=float(transformed.x);totals[1]+=float(transformed.y);totals[2]+=float(transformed.z)
     if arrays[Mesh.ARRAY_TEX_UV]!=null:
      for uv in arrays[Mesh.ARRAY_TEX_UV]:uv_totals[0]+=float(uv.x);uv_totals[1]+=float(uv.y)
   queue.append({"node":child,"transform":transform})
 return {"triangles":triangles,"vertices":vertices,"sum":Vector3(totals[0],totals[1],totals[2]),"uv_sum":Vector2(uv_totals[0],uv_totals[1])}
func run():
 var foliage=(load("res://assets/art/foliage-cards-v1.png") as Texture2D).get_image()
 var cell=foliage.get_width()/2
 assert(foliage.get_width()==foliage.get_height() and cell>0)
 for tile in range(4):
  var coverage=0
  for y in range(cell):
   for x in range(cell):
    if foliage.get_pixel(x+(tile%2)*cell,y+(tile/2)*cell).a>.45:
     coverage+=1
     assert(x>cell*.07 and y>cell*.07 and x<cell*.93 and y<cell*.93,"Leaf cards retain transparent gutters")
  assert(coverage>1000 and coverage<cell*cell*.8,"Each foliage card has leaves and transparent gaps")
 verify_conifer_atlas()
 var world=Node3D.new();root.add_child(world)
 var shared=StandardMaterial3D.new();var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_normal(Vector3.ONE.normalized());surface.add_vertex(Vector3.ZERO);surface.add_vertex(Vector3.RIGHT);surface.add_vertex(Vector3.UP)
 var parent=Node3D.new();parent.position=Vector3(3,1,2);world.add_child(parent)
 var shape=surface.commit()
 for i in range(2):
  var mesh=MeshInstance3D.new();mesh.mesh=shape;mesh.material_override=shared;mesh.scale=Vector3(2,3,4);mesh.position.x=i;parent.add_child(mesh)
 var before=signature(world);var batch=Batch.new();var stats=batch.combine(world);var after=signature(world)
 assert(stats.sources==2 and stats.batches==1)
 assert(before.triangles==after.triangles and before.vertices==after.vertices and before.sum.is_equal_approx(after.sum),"Batch preserves geometry and hierarchy transforms")
 var baked=world.get_children().filter(func(child):return child is MeshInstance3D)[0]
 var normals=baked.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 assert(normals[0].distance_to(Vector3(.5,1.0/3,.25).normalized())<.0005,"Nonuniform scales use inverse-transpose normals")
 assert(baked.material_override==shared,"Material identity preserved")
 var dynamic=MeshInstance3D.new();dynamic.mesh=BoxMesh.new();dynamic.material_override=shared;dynamic.set_meta("dynamic",true);world.add_child(dynamic)
 assert(batch.combine(world).sources==0 and is_instance_valid(dynamic) and dynamic.get_parent()==world,"Explicitly dynamic and already-batched meshes are left intact")
 world.queue_free();await process_frame
 var scenery=Scenery.new();scenery.batching_enabled=false;var game=Rules.new();var total_sources=0;var total_batches=0
 verify_shared_primitives(scenery)
 world=Node3D.new();root.add_child(world)
 for dimensions in [[.5,.4,.6],[1.65,.35,.8]]:
  var arch=scenery.arch_span(world,Vector3.ZERO,dimensions[0],dimensions[1],dimensions[2])
  var arrays=arch.mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var signed_volume=0.0
  for point in points:
   var radius=Vector2(point.x,point.y).length()
   assert(point.y>=0 and radius>=dimensions[0]-.001 and radius<=dimensions[0]+dimensions[1]+.001,"Stone arch follows its curved span and leaves its underside open")
  for i in range(0,points.size(),3):signed_volume+=points[i].dot(points[i+1].cross(points[i+2]))/6.0
  var ideal=PI*.5*(pow(dimensions[0]+dimensions[1],2)-pow(dimensions[0],2))*dimensions[2]
  assert(signed_volume>ideal*.9 and signed_volume<ideal,"Closed stones have outward winding and small mortar gaps")
  for normal in arrays[Mesh.ARRAY_NORMAL]:assert(absf(normal.length()-1)<.001,"Arch surfaces have valid lighting normals")
 world.queue_free();await process_frame
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.landscape(world,game)
  verify_conifers(world,game.info().environment,false)
  before=signature(world);var began=Time.get_ticks_msec();stats=batch.combine(world);var elapsed=Time.get_ticks_msec()-began;after=signature(world)
  assert(before.vertices==after.vertices and before.triangles==after.triangles,"All chapter geometry is retained")
  assert(before.sum.distance_to(after.sum)<maxf(1,before.sum.length()*.000001),"Positions preserved within float accumulation error")
  assert(before.uv_sum.distance_to(after.uv_sum)<maxf(.1,before.uv_sum.length()*.00001),"Texture coordinates preserved")
  total_sources+=stats.sources;total_batches+=stats.batches
  print("BATCH chapter ",chapter+1,": ",stats.sources," meshes → ",stats.batches," batches / ",elapsed," ms")
  world.queue_free();await process_frame
 for chapter in range(12):
  game.chapter=chapter;world=Node3D.new();root.add_child(world);scenery.battle_landscape(world,Vector3(35,0,0),{"environment":game.info().environment})
  verify_conifers(world,game.info().environment,true)
  if game.info().environment=="harbor":verify_deck(world,Vector3(35,0,0))
  before=signature(world);stats=batch.combine(world);after=signature(world)
  assert(before.vertices==after.vertices and before.triangles==after.triangles,"Combat arenas retain all geometry")
  assert(before.sum.distance_to(after.sum)<maxf(1,before.sum.length()*.000001),"Arena transforms retained")
  world.queue_free();await process_frame
 world=Node3D.new();root.add_child(world);scenery.battle_landscape(world,Vector3(35,.7,0),{"environment":"road","terrain":"="})
 verify_deck(world,Vector3(35,.7,0));world.queue_free();await process_frame
 assert(total_batches<total_sources*.6,"Static mesh submissions reduced by at least forty percent")
 print("PASS: 12 maps and 12 arenas retain vertices, triangles, UVs and transforms; correct scaled normals, four conifer atlas regions and grounded woodland/pass trees; ",total_sources," meshes → ",total_batches," batches")
 quit()

func verify_shared_primitives(scenery):
 var host=Node3D.new();root.add_child(host)
 var wall=scenery.block(host,Vector3(4,1,2),Vector3(2,2,.6),Color.WHITE)
 var plank=scenery.block(host,Vector3(2,0,1),Vector3(.56,.09,2),Color.BROWN)
 assert(wall.mesh==plank.mesh and wall.mesh.size==Vector3.ONE,"Different props share one unit box")
 assert(wall.scale==Vector3(2,2,.6) and plank.scale==Vector3(.56,.09,2) and wall.material_override!=plank.material_override)
 var land=scenery.ground(host,Vector3.ZERO,Vector2.ONE,0)
 var water=scenery.mesh(host,scenery.plane_shape(Vector2.ONE),Vector3.DOWN*.07,Vector3.ONE,scenery.water_material())
 var clearing=scenery.ground(host,Vector3.ONE,Vector2(24,6),1)
 assert(land.mesh==water.mesh and land.material_override!=water.material_override,"Ground and water share geometry with independent paint, height and UVs")
 assert(clearing.mesh!=land.mesh and clearing.mesh.size==Vector2(24,6) and land.mesh.size==Vector2.ONE)
 assert(clearing.mesh==scenery.plane_shape(Vector2(24,6)),"The cache reuses geometry only at equal physical dimensions")
 var before=signature(host);var stats=scenery.batcher.combine(host);var after=signature(host)
 assert(before.triangles==after.triangles and before.vertices==after.vertices and before.sum.is_equal_approx(after.sum))
 assert(before.uv_sum.is_equal_approx(after.uv_sum) and stats.sources==5 and stats.batches==5)
 host.free()
 print("PASS: shared scenery box and dimension-matched planes preserve transform, paint, geometry and UVs")

func verify_conifer_atlas():
 var crowns=Crowns.new()
 var texture: Texture2D=crowns.material().get_shader_parameter("plant_atlas")
 var image=texture.get_image()
 assert(image.get_size()==Vector2i(Crowns.ATLAS),"Crown texture matches its measured crop coordinates")
 var cell=Vector2i(image.get_size()/2)
 for variant in Crowns.REGIONS.size():
  var region=Crowns.REGIONS[variant]
  var start=Vector2i(variant%2,variant/2)*cell
  var coverage=0
  for y in range(start.y,start.y+cell.y):
   for x in range(start.x,start.x+cell.x):
    if image.get_pixel(x,y).a<.45:continue
    coverage+=1
    assert(region.grow(-4).has_point(Vector2i(x,y)),"Opaque crown detail and filtering gutters fit their own crop")
  assert(coverage>50000 and coverage<cell.x*cell.y*.5,"The atlas contains four detailed cutouts with open space")
  var crown=crowns.shape(variant)
  assert(crowns.shape(variant)==crown,"Tree instances reuse the four crown meshes")
  var data=crown.surface_get_arrays(0)
  var points=data[Mesh.ARRAY_VERTEX]
  var uv=data[Mesh.ARRAY_TEX_UV]
  var wind=data[Mesh.ARRAY_TEX_UV2]
  assert(points.size()==18,"Each crown uses six triangles in three crossing planes")
  for index in points.size():
   var pixel=(uv[index]*Crowns.ATLAS).round()
   assert(pixel.x>=region.position.x and pixel.y>=region.position.y and pixel.x<=region.end.x and pixel.y<=region.end.y)
   assert(is_equal_approx(wind[index].y,1.0 if points[index].y>.99 else 0.0),"Wind pins the bottom of all three cards")

func verify_conifers(world: Node3D,theme: String,arena: bool):
 var crowns=world.find_children("ConiferCrown*","MeshInstance3D",true,false)
 if theme not in ["forest","mountain"]:
  assert(crowns.is_empty(),"Conifers are limited to Greywood and Windscar Pass")
  return
 assert(crowns.size()>=(21 if theme=="forest" else 7))
 var variants={}
 for crown in crowns:
  var trunk=crown.get_parent().get_child(crown.get_index()-1)
  var variant=crown.get_meta("conifer_variant")
  variants[variant]=true
  assert(trunk.name.begins_with("ConiferTrunk") and trunk.mesh is CylinderMesh)
  assert(is_equal_approx(trunk.global_position.y-trunk.mesh.height*.5*trunk.global_basis.y.length(),crown.global_position.y),"Trunk and crown share the same planted base")
  assert(is_equal_approx(trunk.global_position.x,crown.global_position.x) and is_equal_approx(trunk.global_position.z,crown.global_position.z))
  assert(crown.extra_cull_margin>=.01,"Culling bounds include the crest's shader motion")
  if arena:
   assert(is_equal_approx(crown.global_position.y,-.06) and crown.global_position.z<=-8,"The fighting lane stays clear and the trunks start on the arena ground")
  elif theme=="mountain":
   assert(is_equal_approx(crown.global_position.y,-.15) and crown.global_position.z<=-6,"Pass firs grow behind the tactical ridge")
  else:
   assert(is_zero_approx(crown.global_position.y) or is_equal_approx(crown.global_position.y,-.15),"Woodland trees stand on the map or extended ground")
 assert(variants.size()==2 and variants.has(0 if theme=="forest" else 2) and variants.has(1 if theme=="forest" else 3))

func verify_deck(world: Node3D,center: Vector3):
 var planks=world.find_children("ArenaDeck*","MeshInstance3D",true,false)
 assert(planks.size()==105,"Dock floor contains the full fighting lane")
 for plank in planks:
  assert(is_equal_approx(plank.position.y+plank.scale.y*plank.mesh.get_aabb().end.y,center.y),"Every deck top matches the fighters' ground plane")
 var water=world.get_node("ArenaWater")
 assert(water.position.y<center.y-.05 and water.position.z+water.mesh.size.y*.5>center.z+2.5,"Water stays below and extends beneath the entire deck")
 for mesh in world.find_children("*","MeshInstance3D",true,false):
  assert(not (mesh.mesh is PlaneMesh and mesh.mesh.size==Vector2(24,6)),"Wooden arenas do not retain a coincident central ground plane")
