extends RefCounted
## The route illustration and tactical grid share the same normalized frame.
const MAP=preload("res://assets/art/campaign-valley-v1.png")
const WIDTH=24
const HEIGHT=16
const WATER=[
 [[.2,8.2],[2,8.8],[4,9.5],[6,9.1],[8,9.4],[10,9.8],[12,10.3],[15,10.7],[17,11.4],
  [17.5,12.6],[16,13.3],[14,13],[12,11.8],[9.5,10.7],[7,10.4],[5,11],[3,12.1],[2.3,11.1],[3,10],[1,9.3]],
 [[10.1,8.5],[13.7,6.5],[17,5.7],[19.1,4.4],[20,4.2],[19.6,5.4],[17.6,6.7],[14.7,7.5],[12.5,9.2],[11,9.8]],
 [[15.7,12.2],[17.2,11.5],[20.6,11.7],[22.7,12.1],[23.3,13.2],[22.1,14.4],[18.4,15.1],[15.3,14.1]]]
const HILLS=[
 [[0,1],[3,1],[7,3],[7,5],[5,5],[4,3],[1,3],[0,4]],
 [[17,6],[22,4],[24,4],[24,12],[22,11],[20,10],[18,8]],
 [[10,4],[12,2],[14,2],[15,4],[13,6],[11,6]]]
const FORESTS=[
 [[0,4],[3,3],[8,3],[8,7],[6,9],[3,9],[0,7]],
 [[5,10],[9,10],[12,12],[12,14],[4,13]],
 [[13,4],[16,1],[19,1],[18,3],[15,5]]]
const ROADS=[
 [[4,10],[6,9],[8,8],[10,7],[13,7],[15,6],[17,5],[20,4],[21,2]],
 [[4,10],[4,8],[5,6],[7,5],[10,5],[13,5],[15,6]],
 [[11,12],[12,10],[15,9],[17,8],[18,6],[20,4]]]
const CAPITAL=[21,2]

static func chapter() -> Dictionary:
 var cells=[]
 for y in HEIGHT:
  var row=[]
  for x in WIDTH:
   var center=Vector2(x+.5,y+.5)
   var symbol="."
   if covers(center,FORESTS):symbol="f"
   if covers(center,HILLS):symbol="h"
   if covers(center,WATER):symbol="~"
   row.append(symbol)
  cells.append(row)
 for road in ROADS:
  for index in range(road.size()-1):
   draw_road(cells,Vector2i(road[index][0],road[index][1]),Vector2i(road[index+1][0],road[index+1][1]))
 var allies=[[3,9],[4,9],[3,10],[4,10],[3,11],[4,11]]
 var enemies=[
  {"job":"Knight","position":CAPITAL,"ai":"guard","name":"The Ivory Marshal"},
  {"job":"Vanguard","position":[19,4],"ai":"sentry","name":"Capital garrison"},
  {"job":"Ranger","position":[16,6],"ai":"sentry","name":"Pass scouts"},
  {"job":"Rider","position":[11,7],"ai":"pursue","name":"Highland riders"},
  {"job":"Corsair","position":[8,9],"ai":"pursue","name":"River company"},
  {"job":"Arcanist","position":[15,5],"ai":"guard","name":"Northern signal corps"}]
 var reserves=[{"job":"Warden","position":[20,2],"ai":"sentry","name":"Capital surgeons"}]
 for site in allies+enemies.map(func(enemy):return enemy.position)+reserves.map(func(enemy):return enemy.position):
  if cells[site[1]][site[0]]=="~":cells[site[1]][site[0]]="="
 cells[CAPITAL[1]][CAPITAL[0]]="o"
 cells[5][7]="+";cells[7][14]="+"
 var rows=[]
 for row in cells:rows.append("".join(row))
 return {"title":"The Roads Between","place":"Valley war table","intro":"The council map shows the armies closing on the capital. Take the crossings and seize its standard.",
  "outro":"The capital opens its gates. The valley’s companies can move toward the Sun Engine together.",
  "tactical_brief":"Follow the painted roads, use the crossings, and keep the company together through the hills.",
  "presentation":"valley_table","map":rows,"environment":"castle","score_theme":"crown",
  "route_position":[.895,.15625],"objective":"seize","objective_position":CAPITAL.duplicate(),
  "turn_limit":12,"deployment_positions":allies,"enemies":enemies,"hard_enemies":reserves}

static func covers(point: Vector2,areas: Array) -> bool:
 for area in areas:
  var polygon=PackedVector2Array()
  for vertex in area:polygon.append(Vector2(vertex[0],vertex[1]))
  if Geometry2D.is_point_in_polygon(point,polygon):return true
 return false

static func draw_road(cells: Array,from: Vector2i,to: Vector2i):
 var point=from
 while point!=to:
  cells[point.y][point.x]="=" if cells[point.y][point.x] in ["~","="] else "p"
  var remaining=to-point
  if absi(remaining.x)>=absi(remaining.y):point.x+=signi(remaining.x)
  else:point.y+=signi(remaining.y)
 cells[to.y][to.x]="=" if cells[to.y][to.x] in ["~","="] else "p"

static func build(parent: Node3D,game,scenery):
 var size=Vector2(game.board_size())
 var center=Vector3(size.x*.5-.5,0,size.y*.5-.5)
 var extent=Vector3(size.x,.76,size.y)
 scenery.block(parent,center+Vector3.DOWN*.43,extent+Vector3(.96,0,.96),Color("463044")).name="ValleyTable"
 scenery.block(parent,center+Vector3.DOWN*.10,Vector3(size.x+.38,.16,size.y+.38),Color("ad8555")).name="ValleyTableRim"
 var parchment=StandardMaterial3D.new()
 parchment.albedo_texture=MAP
 parchment.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 scenery.mesh(parent,scenery.plane_shape(size),center,Vector3.ONE,parchment).name="ValleyChart"
 var grid=ImmediateMesh.new()
 var ink=StandardMaterial3D.new()
 ink.albedo_color=Color(.24,.15,.08,.30)
 ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 grid.surface_begin(Mesh.PRIMITIVE_LINES,ink)
 for x in range(int(size.x)+1):
  grid.surface_add_vertex(Vector3(x-.5,.013,-.5))
  grid.surface_add_vertex(Vector3(x-.5,.013,size.y-.5))
 for y in range(int(size.y)+1):
  grid.surface_add_vertex(Vector3(-.5,.013,y-.5))
  grid.surface_add_vertex(Vector3(size.x-.5,.013,y-.5))
 grid.surface_end()
 var overlay=MeshInstance3D.new();overlay.name="ValleyGrid";overlay.mesh=grid;parent.add_child(overlay)
 if game.info().objective=="seize":
  var point=game.objective_position()
  var marker=Node3D.new();marker.name="ValleyStandard";parent.add_child(marker)
  marker.position=Vector3(point.x+.30,0,point.y-.27)
  scenery.cylinder(marker,Vector3(0,.017,0),.034,.143,Color("b38b51"))
  scenery.cylinder(marker,Vector3(0,.21,0),.41,.015,Color("e2bc78"))
  var flag=preload("res://scripts/wind_cloth.gd").new()
  marker.add_child(flag);flag.position=Vector3(0,.39,0)
  flag.configure(Vector2(.26,.19),Color("ad5549"),true,1.4)
