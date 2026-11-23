extends RefCounted
## Windscar Pass's near rock strata, shared by the board and close-up stage.

const WIDTH=44.0
const COLUMNS=32
const DEPTHS=[0.0,1.3,2.0,3.4,4.0,6.4,8.5,10.5]
const HEIGHTS=[0.0,.46,1.41,1.74,2.94,2.45,1.12,0.0]
const PAINTS=[
 Color("757c77"),Color("687471"),Color("8a8f81"),Color("646f73"),
 Color("7c8584"),Color("707c7b"),Color("78817a"),
]
static var shared_mesh: ArrayMesh
static var shared_material: StandardMaterial3D

static func vertex(column: int,row: int) -> Vector3:
 var x=(float(column)/COLUMNS-.5)*WIDTH
 var taper=smoothstep(0.0,4.8,WIDTH*.5-absf(x))
 var relief=1.0+.18*sin(x*.34+.48)+.12*cos(x*.68+row*.61)+.08*sin(x*1.28)
 return Vector3(x,HEIGHTS[row]*relief*taper,-DEPTHS[row])

static func mesh() -> ArrayMesh:
 if shared_mesh!=null:return shared_mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(DEPTHS.size()-1):
  for column in range(COLUMNS):
   var a=vertex(column,row);var b=vertex(column+1,row)
   var c=vertex(column+1,row+1);var d=vertex(column,row+1)
   var paint=PAINTS[row].lerp(Color("adb1a1"),.15*(.5+.5*sin(column*1.67+row*.6)))
   face(tool,a,b,c,paint)
   face(tool,a,c,d,paint.darkened(.025))
 shared_mesh=tool.commit()
 return shared_mesh

static func face(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,paint: Color):
 var normal=(b-a).cross(c-a).normalized()
 for point in [a,c,b]:
  tool.set_normal(normal);tool.set_color(paint)
  tool.add_vertex(point)

static func build(parent: Node3D,origin: Vector3,size: Vector3) -> MeshInstance3D:
 if shared_material==null:
  shared_material=StandardMaterial3D.new()
  shared_material.vertex_color_use_as_albedo=true
  shared_material.vertex_color_is_srgb=true
  shared_material.roughness=.97
 var slope=MeshInstance3D.new();slope.name="PassEscarpment"
 slope.mesh=mesh();slope.material_override=shared_material
 slope.position=origin;slope.scale=size
 slope.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # The whole slope is already one surface and can keep its shared geometry.
 slope.set_meta("static_batch",true)
 parent.add_child(slope)
 return slope

static func height_at(slope: MeshInstance3D,position: Vector3) -> float:
 var local=slope.transform.affine_inverse()*position
 var column_fraction=(local.x/WIDTH+.5)*COLUMNS
 var depth=-local.z
 if column_fraction<=0 or column_fraction>=COLUMNS or depth<=0 or depth>=DEPTHS[-1]:
  return slope.position.y
 var column=floori(column_fraction)
 var row=0
 while depth>DEPTHS[row+1]:row+=1
 var u=column_fraction-column
 var v=inverse_lerp(DEPTHS[row],DEPTHS[row+1],depth)
 var a=vertex(column,row).y;var c=vertex(column+1,row+1).y
 # Use the same diagonal as the mesh so trees sit on its faces.
 var height: float
 if u>=v:height=a*(1-u)+vertex(column+1,row).y*(u-v)+c*v
 else:height=a*(1-v)+c*u+vertex(column,row+1).y*(v-u)
 return slope.position.y+height*slope.scale.y
