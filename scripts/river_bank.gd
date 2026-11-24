extends RefCounted
# A continuous world-space height field slopes water cells into adjacent land.
# Including diagonal land closes corner seams; deterministic width variation
# softens the shore without changing the playable grid or consuming game RNG.
const STEPS=8
const BED_HEIGHT=-.13
const ARENA_WIDTH=60.0
const ARENA_COLUMNS=40
const ARENA_ROWS=8
const ARENA_NEAR_START=-3.0
const ARENA_FAR_START=-15.0
const ARENA_WATER_LEVEL=-.025

static var arena_strips: Dictionary={}

static func nearby_land(game,cell: Vector2i) -> Array:
 var result=[];var board=game.board_size()
 for y in range(cell.y-1,cell.y+2):
  for x in range(cell.x-1,cell.x+2):
   if x<0 or y<0 or x>=board.x or y>=board.y:continue
   var point=Vector2i(x,y)
   if game.terrain(point) not in ["~","="]:result.append(Vector2(point))
 return result

static func height_at(point: Vector2,land: Array) -> float:
 var distance=INF
 for cell in land:
  var delta=(point-cell).abs()-Vector2.ONE*.5
  distance=minf(distance,Vector2(maxf(0,delta.x),maxf(0,delta.y)).length())
 var width=.38+.035*sin(point.x*4.0+point.y*3.0)+.02*sin(point.y*7.0-point.x*2.0)
 return BED_HEIGHT*smoothstep(0,width,distance)

static func build(game,cell: Vector2i) -> ArrayMesh:
 var land=nearby_land(game,cell)
 if land.is_empty():return null
 var vertices=PackedVector3Array();var uv=PackedVector2Array()
 for y in range(STEPS+1):
  for x in range(STEPS+1):
   var local=Vector2(x,y)/STEPS-Vector2.ONE*.5
   var point=Vector2(cell)+local
   vertices.append(Vector3(local.x,height_at(point,land),local.y))
   uv.append(point)
 return grid_mesh(vertices,uv,STEPS,STEPS)

static func grid_mesh(vertices: PackedVector3Array,uv: PackedVector2Array,columns: int,rows: int,reverse=false) -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_smooth_group(0)
 var stride=columns+1
 var corners=[0,stride+1,1,0,stride,stride+1] if reverse else [0,1,stride+1,0,stride+1,stride]
 for row in range(rows):
  for column in range(columns):
   var start=row*stride+column
   for offset in corners:
    var index=start+offset
    surface.set_uv(uv[index])
    surface.add_vertex(vertices[index])
 surface.generate_normals();surface.index()
 return surface.commit()

static func arena_point(x: float,depth: float,far_bank: bool) -> Vector3:
 var start=ARENA_FAR_START if far_bank else ARENA_NEAR_START
 var phase=1.23 if far_bank else 0.0
 var meander=.83*sin(x*.31+phase)+.31*sin(x*.78-.4)
 var edge=start+(4.2 if far_bank else -3.6)+meander
 return Vector3(x,BED_HEIGHT*depth*depth,lerpf(start,edge,depth))

static func arena_strip(far_bank: bool) -> ArrayMesh:
 if arena_strips.has(far_bank):return arena_strips[far_bank]
 var vertices=PackedVector3Array();var uv=PackedVector2Array()
 for row in range(ARENA_ROWS+1):
  for column in range(ARENA_COLUMNS+1):
   var x=(float(column)/ARENA_COLUMNS-.5)*ARENA_WIDTH
   var point=arena_point(x,float(row)/ARENA_ROWS,far_bank)
   vertices.append(point)
   uv.append(Vector2(point.x,point.z))
 arena_strips[far_bank]=grid_mesh(vertices,uv,ARENA_COLUMNS,ARENA_ROWS,not far_bank)
 return arena_strips[far_bank]
