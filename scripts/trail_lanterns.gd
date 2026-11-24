extends RefCounted
## Greywood’s roadside lantern. Shared timber and metal geometry surrounds warm paper.
const POLE=Color("594837")
const IRON=Color("474440")
const BRASS=Color("a68b5f")
const WINDOW=Vector3(.14,1.04,0)
const ROADSIDE=[
 Vector2(1.03,3.57),Vector2(2.27,5.43),Vector2(4.83,3.57),
 Vector2(6.64,5.43),Vector2(9.54,3.57),Vector2(11.68,5.43),
]
const ARENA_SITES=[
 {"position":Vector2(-8.5,-5.6),"scale":1.60},
 {"position":Vector2(-4.50,-4.7),"scale":1.46},
 {"position":Vector2(-.78,-5.1),"scale":1.36},
 {"position":Vector2(3.42,-4.6),"scale":1.49},
 {"position":Vector2(7.25,-6.0),"scale":1.68},
]
static var frame_mesh: ArrayMesh
static var paper_mesh: BoxMesh
static var frame_material: StandardMaterial3D
static var paper_material: StandardMaterial3D

static func roadside(parent: Node3D):
 for index in ROADSIDE.size():
  var site=ROADSIDE[index]
  build(parent,Vector3(site.x,0,site.y),.53,.11 if index%2==0 else PI-.11)

static func fighting_lane(parent: Node3D,center: Vector3):
 for index in ARENA_SITES.size():
  var site=ARENA_SITES[index]
  var point=center+Vector3(site.position.x,0,site.position.y)
  build(parent,point,site.scale,.12 if index%2==0 else PI-.12)

static func build(parent: Node3D,point: Vector3,scale_value: float,heading: float) -> Node3D:
 var lantern=Node3D.new()
 lantern.name="TrailLantern";lantern.position=point
 lantern.scale=Vector3.ONE*scale_value;lantern.rotation.y=heading
 parent.add_child(lantern,true)
 var frame=MeshInstance3D.new()
 frame.name="LanternFrame";frame.mesh=frame_shape();frame.material_override=paint()
 lantern.add_child(frame)
 var paper=MeshInstance3D.new()
 paper.name="LanternPaper";paper.position=WINDOW
 if paper_mesh==null:
  paper_mesh=BoxMesh.new();paper_mesh.size=Vector3(.244,.298,.244)
  paper_material=StandardMaterial3D.new()
  paper_material.albedo_color=Color("f8bf75")
  paper_material.emission_enabled=true;paper_material.emission=Color("ed9545")
  paper_material.emission_energy_multiplier=.36;paper_material.roughness=.87
 paper.mesh=paper_mesh;paper.material_override=paper_material
 paper.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 lantern.add_child(paper)
 return lantern

static func paint() -> StandardMaterial3D:
 if frame_material==null:
  frame_material=StandardMaterial3D.new()
  frame_material.vertex_color_use_as_albedo=true;frame_material.vertex_color_is_srgb=true
  frame_material.roughness=.85
 return frame_material

static func frame_shape() -> ArrayMesh:
 if frame_mesh!=null:return frame_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var box=BoxMesh.new()
 add_part(tool,box,Vector3(-.285,.055,0),Vector3(.25,.17,.25),Color("67685b"))
 add_part(tool,box,Vector3(-.285,.72,0),Vector3(.092,1.38,.10),POLE)
 add_part(tool,box,Vector3(-.073,1.38,0),Vector3(.50,.083,.09),POLE)
 add_part(tool,box,Vector3(-.191,1.271,0),Vector3(.052,.21,.055),POLE,-.64)
 add_part(tool,box,Vector3(.14,1.289,0),Vector3(.042,.14,.045),IRON)
 for side in [-1,1]:
  for z in [-.12,.12]:
   add_part(tool,box,Vector3(.14+side*.12,1.036,z),Vector3(.035,.32,.035),IRON)
  add_part(tool,box,Vector3(.14,1.034,side*.129),Vector3(.266,.021,.018),BRASS)
  add_part(tool,box,Vector3(.14+side*.129,1.034,0),Vector3(.018,.021,.266),BRASS)
 add_part(tool,box,Vector3(.14,.881,0),Vector3(.31,.042,.31),IRON)
 add_part(tool,box,Vector3(.14,.849,0),Vector3(.278,.027,.278),BRASS)
 var hood=CylinderMesh.new();hood.bottom_radius=.22;hood.top_radius=.104
 hood.height=.11;hood.radial_segments=8;hood.rings=0
 add_part(tool,hood,Vector3(.14,1.232,0),Vector3.ONE,IRON)
 frame_mesh=tool.commit()
 return frame_mesh

static func add_part(tool: SurfaceTool,shape: PrimitiveMesh,point: Vector3,dimensions: Vector3,color: Color,lean=0.0):
 var arrays=shape.surface_get_arrays(0)
 var basis=Basis(Vector3.BACK,lean)
 for index in arrays[Mesh.ARRAY_INDEX]:
  tool.set_color(color);tool.set_normal(basis*arrays[Mesh.ARRAY_NORMAL][index])
  tool.add_vertex(point+basis*(arrays[Mesh.ARRAY_VERTEX][index]*dimensions))
