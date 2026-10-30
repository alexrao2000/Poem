extends RefCounted
# Project equipped action range from legal stopping cells. This is a read-only
# preview: it never moves a unit or resolves an attack/heal to discover reach.
static func tiles(game,unit: Dictionary,origins: Dictionary) -> Dictionary:
 var result={}
 if unit.hp<=0:return result
 var item=game.item_for(unit);var reach=int(item.max_range);var minimum=int(item.min_range)
 for origin in origins:
  var occupied=game.at(origin)
  if occupied!=null and occupied.id!=unit.id:continue
  if game.terrain(origin) in ["#","~"]:continue
  for y in range(-reach,reach+1):
   for x in range(-reach,reach+1):
    var distance=absi(x)+absi(y)
    if distance<minimum or distance>reach:continue
    var point=origin+Vector2i(x,y)
    if game.terrain(point) not in ["#","~"]:result[point]=true
 return result
