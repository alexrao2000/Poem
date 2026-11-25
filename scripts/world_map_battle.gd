extends RefCounted
## The route illustration and tactical grid share the same normalized frame.
const MAP=preload("res://assets/art/campaign-valley-v1.png")
const GRID_INK=preload("res://assets/shaders/valley-grid.gdshader")
const REVEAL_SECONDS=1.75
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
const ROUTE_TERRAIN={"Reed Crossing":"=","Hallow Abbey":"+","Kingsroad":"=","Windscar Pass":"h"}
const LANDMARK_TERRAINS=["=","+","h","o","f"]

static func route_dialogue(route: Array) -> Array:
 var scenes={
  "Reed Crossing":{"id":"reed_crossing","lines":[
   {"speaker":"narrator","text":"The ferrymen wind the last length of chain onto the bank. From here, the next company can see your standard."}]},
  "Hallow Abbey":{"id":"hallow_abbey","refill_tonics":true,"lines":[
   {"speaker":"oren","text":"Raise the abbey lamp. The next garrison will know the river road is open.","when_absent":[
    {"speaker":"narrator","text":"The keeper raises the signal lamp. Every road out of the abbey answers."}]}]},
  "Windscar Pass":{"id":"windscar_pass","lines":[
   {"speaker":"lyra","text":"Those roofs below us belong to everyone we’ve met on the road. Leave a company on the ridge until the last banner is through."}]}}
 var events=[]
 for chapter in route:
  var place=chapter.level
  if not scenes.has(place.place):continue
  var tile=route_tile(place.route_position)
  var event=scenes[place.place]
  event.position=[tile.x,tile.y]
  event.route_key=chapter.key
  events.append(event)
 return events

static func chapter(route: Array) -> Dictionary:
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
 for location in route:
  if ROUTE_TERRAIN.has(location.place):
   var point=route_tile(location.route_position)
   cells[point.y][point.x]=ROUTE_TERRAIN[location.place]
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
  "presentation":"valley_table","map":rows,"environment":"castle","score_theme":"valley",
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
 scenery.block(parent,center+Vector3.DOWN*.95,Vector3(84,.27,84),Color("382c3b")).name="ValleyRoomFloor"
 scenery.block(parent,center+Vector3.DOWN*.43,extent+Vector3(.96,0,.96),Color("463044")).name="ValleyTable"
 scenery.block(parent,center+Vector3.DOWN*.10,Vector3(size.x+.38,.16,size.y+.38),Color("ad8555")).name="ValleyTableRim"
 var parchment=StandardMaterial3D.new()
 parchment.albedo_texture=game.content.get("route_atlas",MAP)
 parchment.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 scenery.mesh(parent,scenery.plane_shape(size),center,Vector3.ONE,parchment).name="ValleyChart"
 var grid=ImmediateMesh.new()
 var ink=ShaderMaterial.new();ink.shader=GRID_INK
 ink.set_shader_parameter("origin",Vector2(reveal_origin(game)))
 grid.surface_begin(Mesh.PRIMITIVE_LINES)
 for x in range(int(size.x)+1):
  grid.surface_add_vertex(Vector3(x-.5,.013,-.5))
  grid.surface_add_vertex(Vector3(x-.5,.013,size.y-.5))
 for y in range(int(size.y)+1):
  grid.surface_add_vertex(Vector3(-.5,.013,y-.5))
  grid.surface_add_vertex(Vector3(size.x-.5,.013,y-.5))
 grid.surface_end()
 var overlay=MeshInstance3D.new();overlay.name="ValleyGrid";overlay.mesh=grid;overlay.material_override=ink;parent.add_child(overlay)
 build_landmarks(parent,game,scenery)
 var standards=game.capture_tiles()
 for index in standards.size():
  var point=standards[index]
  var marker=Node3D.new();marker.name=standard_node_name(index);parent.add_child(marker)
  marker.position=Vector3(point.x+.30,0,point.y-.27)
  scenery.cylinder(marker,Vector3(0,.017,0),.034,.143,Color("b38b51"))
  scenery.cylinder(marker,Vector3(0,.21,0),.41,.015,Color("e2bc78"))
  var flag=preload("res://scripts/wind_cloth.gd").new()
  marker.add_child(flag);flag.position=Vector3(0,.39,0)
  flag.configure(Vector2(.26,.19),Color("ad5549"),true,1.4)

static func standard_node_name(index: int) -> String:
 return "ValleyStandard" if index==0 else "ValleyStandard%d"%(index+1)

static func build_landmarks(parent: Node3D,game,scenery):
 var group=Node3D.new();group.name="ValleyLandmarks";parent.add_child(group)
 var sites=reached_places(game.content.chapters,game.chapter)
 var objective=game.objective_position() if game.info().objective=="seize" else Vector2i(-1,-1)
 if objective.x>=0 and not sites.has(objective):sites[objective]=[]
 var brass=Color("e1c58a")
 var clay=Color("996c56")
 for tile in sites:
  var terrain="o" if tile==objective else game.terrain(tile)
  if terrain not in LANDMARK_TERRAINS:continue
  var marker=Node3D.new()
  marker.name="Landmark_%d_%d"%[tile.x,tile.y]
  marker.set_meta("tile",tile);marker.set_meta("terrain",terrain)
  marker.position=Vector3(tile.x-.375,.003,tile.y+.375);group.add_child(marker)
  scenery.block(marker,Vector3(0,.013,0),Vector3(.181,.025,.169),Color("694938")).name="Footing"
  match terrain:
   "=":
    for x in [-.057,.057]:
     scenery.block(marker,Vector3(x,.055,0),Vector3(.028,.067,.098),clay)
    scenery.block(marker,Vector3(0,.09,0),Vector3(.16,.025,.089),brass)
    for z in [-.036,.036]:
     scenery.block(marker,Vector3(0,.116,z),Vector3(.15,.033,.012),clay)
   "+":
    scenery.block(marker,Vector3(-.022,.074,0),Vector3(.091,.096,.087),clay)
    scenery.block(marker,Vector3(-.022,.137,0),Vector3(.078,.055,.10),brass).rotation.z=PI*.25
    scenery.block(marker,Vector3(.051,.098,0),Vector3(.047,.145,.046),clay)
    scenery.cylinder(marker,Vector3(.051,.194,0),.059,.033,brass,.003)
   "h","f":
    var ink=Color("a8886a") if terrain=="h" else Color("7d8966")
    scenery.cylinder(marker,Vector3(-.041,.069,.017),.087,.038,ink,.004)
    scenery.cylinder(marker,Vector3(.030,.098,-.015),.145,.051,ink,.004)
   "o":
    scenery.block(marker,Vector3(0,.072,0),Vector3(.144,.093,.127),clay)
    scenery.block(marker,Vector3(0,.135,0),Vector3(.084,.097,.078),brass)
    for x in [-.062,.062]:
     for z in [-.053,.053]:
      scenery.block(marker,Vector3(x,.102,z),Vector3(.037,.154,.037),clay)
      scenery.block(marker,Vector3(x,.19,z),Vector3(.045,.022,.045),brass)

static func reveal_origin(game) -> Vector2i:
 return game.objective_position() if game.info().objective=="seize" else Vector2i(CAPITAL[0],CAPITAL[1])

static func route_tile(pin: Array) -> Vector2i:
 return Vector2i(floori(pin[0]*WIDTH),floori(pin[1]*HEIGHT)).clamp(Vector2i.ZERO,Vector2i(WIDTH-1,HEIGHT-1))

static func reached_places(chapters: Array,chapter_index: int) -> Dictionary:
 var places={}
 for index in range(0,chapter_index):
  var chapter=chapters[index]
  if chapter.place.is_empty() or chapter.get("presentation","")=="valley_table":continue
  var tile=route_tile(chapter.route_position)
  if not places.has(tile):places[tile]=[]
  if chapter.place not in places[tile]:places[tile].append(chapter.place)
 return places

static func reveal_corners(board: Vector2i) -> Array:
 return [Vector3(-.5,0,-.5),Vector3(board.x-.5,0,-.5),
  Vector3(-.5,0,board.y-.5),Vector3(board.x-.5,0,board.y-.5)]

static func chart_view(camera: Camera3D,board: Vector2i,home: Dictionary) -> Dictionary:
 var view=home.duplicate()
 var aspect=camera.get_viewport().get_visible_rect().size.aspect()
 view.transform=Transform3D(Basis(Vector3.RIGHT,-PI*.5),Vector3((board.x-1)*.5,24,(board.y-1)*.5))
 view.size=maxf(board.y+2,(board.x+2)/aspect)
 view.h_offset=0.0;view.v_offset=0.0
 return view

static func play_reveal(navigation,game,world: Node3D,actors: Array,hint: Control,skip: Callable):
 var camera: Camera3D=navigation.camera
 var home: Dictionary=navigation.capture_view()
 var chart=chart_view(camera,game.board_size(),home)
 var origin=Vector2(reveal_origin(game))
 var radius=0.0
 for corner in reveal_corners(game.board_size()):radius=maxf(radius,origin.distance_to(Vector2(corner.x,corner.z)))
 var ink: ShaderMaterial=world.get_node("ValleyGrid").material_override
 var props=actors.duplicate()
 for index in game.capture_tiles().size():
  var standard=world.get_node_or_null(standard_node_name(index))
  if standard!=null:props.append(standard)
 var pieces_from_above=props.size()
 props.append_array(world.get_node("ValleyLandmarks").get_children())
 var resting=props.map(func(piece):return piece.position)
 var seats=resting.map(func(point):return origin.distance_to(Vector2(point.x,point.z)))
 var apply_frame=func(weight: float):
  var front=lerpf(-.85,radius+4.8,smoothstep(.10,.86,weight))
  ink.set_shader_parameter("front",front)
  navigation.apply_return(smoothstep(.07,1.0,weight),chart,home)
  for index in props.size():
   var arrival=smoothstep(seats[index]+.34,seats[index]+3.0,front)
   props[index].visible=arrival>0.0
   var offset=1.60*pow(1.0-arrival,2.0) if index<pieces_from_above else -.24*(1.0-arrival)
   props[index].position=resting[index]+Vector3.UP*offset
  hint.modulate.a=1.0-smoothstep(.88,1.0,weight)
 apply_frame.call(0.0)
 var motion=world.create_tween()
 motion.tween_method(apply_frame,0.0,1.0,REVEAL_SECONDS)
 while motion.is_running() and not skip.call():await world.get_tree().process_frame
 if motion.is_running():motion.kill()
 apply_frame.call(1.0)
