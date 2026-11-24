extends RefCounted

static func offsets(minimum: int, maximum: int, bounds: int) -> Array[Vector2i]:
 var result: Array[Vector2i]=[]
 var extent=mini(bounds,maximum)
 for y in range(-extent,extent+1):
  for x in range(-extent,extent+1):
   var distance=absi(x)+absi(y)
   if distance>=minimum and distance<=maximum:result.append(Vector2i(x,y))
 return result

# Project equipped action range from legal stopping cells. This is a read-only
# preview: it never moves a unit or resolves an attack/heal to discover reach.
static func tiles(game,unit: Dictionary,origins: Dictionary) -> Dictionary:
 var result={}
 if unit.hp<=0:return result
 var item=game.item_for(unit);var reach=int(item.max_range)
 var steps=offsets(int(item.min_range),reach,reach)
 var occupants=game.occupied_tiles()
 for origin in origins:
  var occupied=occupants.get(origin)
  if occupied!=null and occupied.id!=unit.id:continue
  if game.terrain(origin) in ["#","~"]:continue
  for step in steps:
   var point=origin+step
   if not result.has(point) and game.terrain(point) not in ["#","~"]:result[point]=true
 return result
