extends RefCounted
## A continuous pool joins the water tiles to gently sloped banks outside the grid.

const RiverBank = preload("res://scripts/river_bank.gd")
const WATER_LEVEL = -.085
const HALF_LENGTH = 38.0
const ROWS = 60
const MUD = [Vector2(0,-.19), Vector2(.42,-.071), Vector2(.91,.045)]
const GRASS = [Vector2(.91,.045), Vector2(2.4,.19), Vector2(4.7,.42),
 Vector2(8.2,.60), Vector2(14.0,.42), Vector2(37.0,.22)]
static var banks: Dictionary = {}

static func shore_gap(z: float,side: int) -> float:
 var phase = -.9 if side < 0 else 1.7
 return 1.93+.76*sin(z*.28+phase)+.38*sin(z*.69-phase)

static func bank_point(z: float,profile: Vector2,side: int) -> Vector3:
 var mound = pow(sin(z*.29+side*.94),2.0)*smoothstep(.91,4.7,profile.x)*.50
 return Vector3(side*(shore_gap(z,side)+profile.x),profile.y+mound,z)

static func bank_mesh(side: int,grass: bool) -> ArrayMesh:
 var key = Vector2i(side,int(grass))
 if banks.has(key):return banks[key]
 var profile = GRASS if grass else MUD
 var points = PackedVector3Array()
 var uv = PackedVector2Array()
 for row in ROWS+1:
  var z = lerpf(-HALF_LENGTH,HALF_LENGTH,float(row)/ROWS)
  for grade in profile:
   var point = bank_point(z,grade,side)
   points.append(point)
   uv.append(Vector2(point.x,point.z))
 var surface = RiverBank.grid_mesh(points,uv,profile.size()-1,ROWS,side<0)
 banks[key] = surface
 return surface

static func build(scenery,parent: Node3D,board: Vector2i,extent: float):
 var reservoir = Node3D.new()
 reservoir.name = "AqueductReservoir"
 parent.add_child(reservoir)
 var center = (Vector2(board)-Vector2.ONE)*.5
 var water = scenery.mesh(reservoir,scenery.plane_shape(Vector2.ONE*extent),
  Vector3(center.x,WATER_LEVEL,center.y),Vector3.ONE,scenery.water_material("aqueduct"))
 water.name = "ReservoirWater"
 water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var scale_value = maxf(1.0,extent/72.0)
 var scale_axes = Vector3(scale_value,1,scale_value)
 for side: int in [-1,1]:
  var origin = Vector3(-.5 if side<0 else board.x-.5,0,center.y)
  var bank = Node3D.new()
  bank.name = "WestBank" if side<0 else "EastBank"
  bank.position = origin
  reservoir.add_child(bank)
  var mud = scenery.mesh(bank,bank_mesh(side,false),Vector3.ZERO,scale_axes,scenery.ground_material(2))
  mud.name = "WetShore"
  mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var grass = scenery.mesh(bank,bank_mesh(side,true),Vector3.ZERO,scale_axes,scenery.ground_material(0))
  grass.name = "GrassyBank"
  grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var grove = [-6.5,-2.6,4.1] if side<0 else [-5.8,1.2,6.8]
  for index in grove.size():
   var point = bank_point(grove[index],GRASS[1+index%2],side)*scale_axes
   scenery.conifer(bank,point-Vector3.UP*.045,23*index+side+7,"mountain")
