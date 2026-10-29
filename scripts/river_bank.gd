extends RefCounted
# A continuous world-space height field slopes water cells into adjacent land.
# Including diagonal land closes corner seams; deterministic width variation
# softens the shore without changing the playable grid or consuming game RNG.
const STEPS=8
const BED_HEIGHT=-.13

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
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_smooth_group(0)
 for y in range(STEPS):
  for x in range(STEPS):
   for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
    var local=Vector2(x+corner.x,y+corner.y)/STEPS-Vector2.ONE*.5
    var point=Vector2(cell)+local
    surface.set_uv(point)
    surface.add_vertex(Vector3(local.x,height_at(point,land),local.y))
 surface.generate_normals();surface.index()
 return surface.commit()
