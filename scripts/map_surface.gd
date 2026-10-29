extends RefCounted
# Presentation height is independent of movement costs and cover. Shared values
# keep raised scenery, units and tactical ink on the same walkable surface.
const BRIDGE_HEIGHT=.08
const SANCTUARY_HEIGHT=.10

static func height_for(tile: String) -> float:
 return BRIDGE_HEIGHT if tile=="=" else SANCTUARY_HEIGHT if tile=="+" else 0.0

static func crossing(a: Vector3,b: Vector3) -> Vector3:
 var middle=(a+b)*.5
 middle.y=maxf(a.y,b.y)
 return middle
