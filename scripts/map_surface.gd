extends RefCounted
# Presentation height is independent of movement costs and cover. Shared values
# keep raised scenery, units and tactical ink on the same walkable surface.
const BRIDGE_HEIGHT=.08
const SANCTUARY_HEIGHT=.10

static func height_for(tile: String) -> float:
 return BRIDGE_HEIGHT if tile=="=" else SANCTUARY_HEIGHT if tile=="+" else 0.0

# Test the few distinct walkable levels, choosing the first visible tile surface.
# A flat-plane projection slips across cell edges on raised bridges and shrines.
static func tile_at_ray(origin: Vector3,direction: Vector3,bounds: Vector2i,height: Callable):
 var nearest=INF
 var selected=null
 for elevation in [0.0,BRIDGE_HEIGHT,SANCTUARY_HEIGHT]:
  var point=Plane(Vector3.UP,elevation).intersects_ray(origin,direction)
  if point==null:continue
  var cell=Vector2i(floori(point.x+.5),floori(point.z+.5))
  if cell.x<0 or cell.y<0 or cell.x>=bounds.x or cell.y>=bounds.y:continue
  if not is_equal_approx(height.call(cell),elevation):continue
  var distance=origin.distance_squared_to(point)
  if distance<nearest:nearest=distance;selected=cell
 return selected

static func crossing(a: Vector3,b: Vector3) -> Vector3:
 var middle=(a+b)*.5
 middle.y=maxf(a.y,b.y)
 return middle
