extends RefCounted
## The stream keeps its authored width through town and meanders beyond the grid.

const RiverBank = preload("res://scripts/river_bank.gd")
const CHANNEL_COLUMN = 7
const ROWS = 48
const VEGETATION_EDGE = Vector2(.25,-.029)
const WET_SHORE = [Vector2(-.07,-.126), Vector2(.14,-.043), VEGETATION_EDGE]
const GRASS_SHOULDER = [VEGETATION_EDGE, Vector2(.54,-.055),
 Vector2(.84,-.108), Vector2(1.12,-.151)]
const TREE_CLEARANCE = 1.95
const ARENA_NEAR_BANK = -4.25
const ARENA_FAR_BANK = -6.85
const ARENA_WATER_LEVEL = -.12
static var cached_length = 0.0
static var meshes: Dictionary = {}

static func section(distance: float,direction: int) -> Vector2:
 var phase = .7 if direction < 0 else -.9
 var bend = sin(distance*.36+phase)*1.25+sin(distance*.15-phase)*.83
 var spread = .18+.15*sin(distance*.38+phase)
 var transition = smoothstep(0,5,distance)
 return Vector2(CHANNEL_COLUMN+bend*transition,.5+spread*transition)

static func open_end(game,direction: int) -> bool:
 var row = 0 if direction < 0 else game.board_size().y-1
 return game.terrain(Vector2i(CHANNEL_COLUMN,row)) in ["~","="]

static func edge(board: Vector2i,direction: int) -> float:
 return -.5 if direction < 0 else board.y-.5

static func shape(length: float,direction: int,shore: int,water_level: float,profile: Array = []) -> ArrayMesh:
 if length != cached_length:
  cached_length = length
  meshes.clear()
 var key = [direction,shore,water_level,profile]
 if meshes.has(key):return meshes[key]
 var points = PackedVector3Array()
 var uv = PackedVector2Array()
 for row in ROWS+1:
  var distance = length*float(row)/ROWS
  var z = direction*distance
  var cross = section(distance,direction)
  if shore == 0:
   points.append(Vector3(cross.x-cross.y,water_level,z))
   points.append(Vector3(cross.x+cross.y,water_level,z))
   uv.append(Vector2(0,distance))
   uv.append(Vector2(1,distance))
  else:
   for grade in profile:
    var y = lerpf(-.151,grade.y,smoothstep(0,1.2,distance))
    var x = cross.x+shore*(cross.y+grade.x)
    points.append(Vector3(x,y,z))
    uv.append(Vector2(x,z))
 var columns = 1 if shore == 0 else profile.size()-1
 var reverse = direction < 0 if shore == 0 else direction*shore < 0
 var result = RiverBank.grid_mesh(points,uv,columns,ROWS,reverse)
 meshes[key] = result
 return result

static func build(scenery,parent: Node3D,game,extent: float,water_level: float):
 var stream = Node3D.new()
 stream.name = "CinderfordStream"
 parent.add_child(stream)
 var board = game.board_size()
 for direction: int in [-1,1]:
  if not open_end(game,direction):continue
  var origin = Vector3(0,0,edge(board,direction))
  var water = scenery.mesh(stream,shape(extent*.53,direction,0,water_level),origin,Vector3.ONE,scenery.water_material("village"))
  water.name = "StreamReach"
  water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for shore in [-1,1]:
   var bank = scenery.mesh(stream,shape(extent*.53,direction,shore,water_level,WET_SHORE),origin,Vector3.ONE,scenery.ground_material(2))
   bank.name = "StreamBank"
   bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var shoulder = scenery.mesh(stream,shape(extent*.53,direction,shore,water_level,GRASS_SHOULDER),origin,Vector3.ONE,scenery.ground_material(0))
   shoulder.name = "StreamShoulder"
   shoulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   plant_mouth(scenery,stream,origin,extent*.53,direction,shore)

static func plant_mouth(scenery,stream: Node3D,origin: Vector3,length: float,direction: int,shore: int):
 # These roots sit between two sampled shoulder grades, on a mesh row.
 var first: Vector2 = GRASS_SHOULDER[0]
 var second: Vector2 = GRASS_SHOULDER[1]
 for row in [2,4,6,9]:
  var distance = length*float(row+(1 if shore>0 else 0))/ROWS
  var channel = section(distance,direction)
  for tuft in 2:
   var grade = first.lerp(second,.23+tuft*.37)
   var height = lerpf(-.151,grade.y,smoothstep(0,1.2,distance))-.006
   var root = origin+Vector3(channel.x+shore*(channel.y+grade.x),height,direction*distance)
   var reed = scenery.ground_cover.plant(stream,{"kind":2,"position":root,
    "height":.26+float((row*7+tuft*3)%5)*.021,"yaw":row*.91+tuft*1.7})
   reed.name = "StreamReed"

static func tree_position(game,point: Vector3) -> Vector3:
 var direction = -1 if point.z < 0 else 1
 if not open_end(game,direction):return point
 var cross = section(absf(point.z-edge(game.board_size(),direction)),direction)
 var offset = point.x-cross.x
 if absf(offset)<cross.y+TREE_CLEARANCE:
  point.x += (cross.y+TREE_CLEARANCE)*(1 if offset>=0 else -1)
 return point

static func borders_exchange(game,a: Dictionary,b: Dictionary) -> bool:
 if a.x!=b.x or a.y==b.y or absi(a.x-CHANNEL_COLUMN)!=1:return false
 for row in range(mini(a.y,b.y),maxi(a.y,b.y)+1):
  if game.terrain(Vector2i(CHANNEL_COLUMN,row))=="~":return true
 return false

static func arena(scenery,parent: Node3D,center: Vector3,paint: Material,flow_direction: int):
 var near_length = 35.0-ARENA_NEAR_BANK
 var far_length = 35.0+ARENA_FAR_BANK
 scenery.ground(parent,center+Vector3(0,0,(35+ARENA_NEAR_BANK)*.5),Vector2(70,near_length),0,paint).name="ArenaGround"
 scenery.ground(parent,center+Vector3(0,0,(ARENA_FAR_BANK-35)*.5),Vector2(70,far_length),0,paint).name="CinderfordFarBank"
 var channel = scenery.plane_shape(Vector2(70,ARENA_NEAR_BANK-ARENA_FAR_BANK))
 var midpoint = (ARENA_NEAR_BANK+ARENA_FAR_BANK)*.5
 var water = scenery.mesh(parent,channel,center+Vector3(0,ARENA_WATER_LEVEL,midpoint),Vector3.ONE,scenery.water_material("village",flow_direction))
 water.name="CinderfordArenaStream"
 water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for edge in [ARENA_NEAR_BANK,ARENA_FAR_BANK]:
  var stone=scenery.block(parent,center+Vector3(0,-.105,edge),Vector3(70,.28,.26),scenery.detail_material(3))
  stone.name="CinderfordBankStone"
 var stations = [-9.4,-5.2,-1.45,2.7,6.8,10.4]
 for side in [-1,1]:
  var bank = ARENA_NEAR_BANK if side>0 else ARENA_FAR_BANK
  for index in stations.size():
   for tuft in 2:
    var position = center+Vector3(stations[index]+tuft*.21+side*.27,0,bank+side*(.40+tuft*.23))
    var reed = scenery.ground_cover.plant(parent,{"kind":2,"position":position,
     "height":.38+float((index*7+tuft*3)%6)*.036,"yaw":index*1.43+tuft*1.1+side*.7})
    reed.name = "StreamsideReed"
