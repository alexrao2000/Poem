extends RefCounted
## Sparse edge planting leaves movement cells and the fighting lane readable.
const THEMES=["village","river","forest","road","mountain"]
const NATURAL=["river","forest","road","mountain"]
const HEIGHTS=[.18,.15,.33,.17]
var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/ground-cover.json"))
var shapes={}
var paint: ShaderMaterial

func material() -> ShaderMaterial:
 if paint==null:
  paint=ShaderMaterial.new();paint.shader=preload("res://assets/shaders/ground_cover.gdshader")
  paint.set_shader_parameter("plant_atlas",load(catalog.texture))
 return paint

func shape(kind: int) -> ArrayMesh:
 if shapes.has(kind):return shapes[kind]
 var record=catalog.plants[kind];var rect=record.rect;var pivot=record.root
 var height=float(record.bounds[3]-record.bounds[1]);var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var pixels=[Vector2(rect[0],rect[1]+rect[3]),Vector2(rect[0]+rect[2],rect[1]+rect[3]),Vector2(rect[0]+rect[2],rect[1]),Vector2(rect[0],rect[1])]
 for angle in [0.0,PI*.5]:
  var basis=Basis(Vector3.UP,angle)
  for i in [0,2,1,0,3,2]:
   var pixel=pixels[i];var point=Vector3((pixel.x-pivot[0])/height,(pivot[1]-pixel.y)/height,0)
   surface.set_normal(basis*Vector3.BACK)
   surface.set_uv(pixel/Vector2(catalog.size[0],catalog.size[1]))
   surface.set_uv2(Vector2(0,clampf(point.y,0,1)))
   surface.add_vertex(basis*point)
 shapes[kind]=surface.commit();return shapes[kind]

func plant(parent: Node3D,entry: Dictionary) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name="GroundCover";node.mesh=shape(entry.kind);node.material_override=material()
 node.position=entry.position;node.rotation.y=entry.yaw;node.scale=Vector3.ONE*entry.height
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=.02
 node.set_meta("plant_kind",entry.kind);node.set_meta("plant_height",entry.height)
 parent.add_child(node);return node

static func map_entries(game,building_cells={}) -> Array:
 var theme=game.info().get("environment","village");var entries=[]
 if theme not in THEMES:return entries
 var rng=RandomNumberGenerator.new();rng.seed=70193+game.chapter*137
 for y in range(game.board_size().y):
  for x in range(game.board_size().x):
   var cell=Vector2i(x,y);var terrain=game.terrain(cell)
   if terrain not in [".","f","h"] or building_cells.has(cell):continue
   var shore=Vector2i.ZERO
   if theme in NATURAL:
    for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
     if game.terrain(cell+direction)=="~":shore=direction;break
   if rng.randf()>(.8 if terrain=="f" else .65 if shore!=Vector2i.ZERO else .28):continue
   var kind=2 if shore!=Vector2i.ZERO else 1 if terrain=="f" else 3 if rng.randf()<.16 else 0
   var offset=Vector2(.36 if rng.randf()>.5 else -.36,.36 if rng.randf()>.5 else -.36)
   if kind==2:
    offset=Vector2(shore)*.36+Vector2(-shore.y,shore.x)*(.26 if rng.randf()>.5 else -.26)
   if terrain=="h" and offset.distance_to(Vector2(.22,-.2))<.4:
    offset=Vector2(shore)*.72-offset if kind==2 else Vector2(-.36,offset.y)
   entries.append({"cell":cell,"kind":kind,"position":Vector3(x+offset.x,0,y+offset.y),"height":HEIGHTS[kind]*rng.randf_range(.85,1.08),"yaw":rng.randf()*TAU})
 return entries

func add_map(parent: Node3D,game,building_cells={}):
 var entries=map_entries(game,building_cells)
 for entry in entries:plant(parent,entry)
 parent.set_meta("ground_cover_count",entries.size())

func add_arena(parent: Node3D,center: Vector3,context: Dictionary):
 var theme=context.get("environment","village")
 if theme not in THEMES or context.get("terrain","")=="=":return
 var rng=RandomNumberGenerator.new();rng.seed=38611+int(context.get("chapter",0))*113
 var count=0
 for i in range(48 if theme=="forest" else 30):
  var side=i%2*2-1;var x=side*rng.randf_range(6.2,11.3)
  var z=rng.randf_range(-2.5,2.3);var level=0.0
  if theme!="river" and i%3==0:
   x=rng.randf_range(-11,11);z=rng.randf_range(-10,-4.2);level=-.06
  var kind=1 if theme=="forest" else 3 if i%9==0 else 0
  plant(parent,{"position":center+Vector3(x,level,z),"kind":kind,"height":HEIGHTS[kind]*rng.randf_range(1.5,2.2),"yaw":rng.randf()*TAU});count+=1
 parent.set_meta("ground_cover_count",count)
