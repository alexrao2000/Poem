extends RefCounted
# A downed recruit occupies a tile but cannot act, counter or be attacked.
# Two player-phase endings remain to reach them. Carrying pauses the countdown;
# staff healing revives them spent, and dropping requires a free adjacent tile.

static func downed(unit: Dictionary) -> bool:
 return unit.get("downed",false)

static func fall(game,unit: Dictionary):
 if unit.team!="player":return
 release_passenger(game,unit)
 if not game.death_door:return
 unit.downed=true;unit.bleed_turns=2;unit.acted=true

static func passenger(game,carrier: Dictionary):
 for unit in game.units:
  if unit.get("carried_by","")==carrier.id:return unit
 return null

static func release_passenger(game,carrier: Dictionary):
 var unit=passenger(game,carrier)
 if unit!=null:
  unit.erase("carried_by");unit.x=carrier.x;unit.y=carrier.y
  var free=drop_positions(game,carrier)
  if not free.is_empty():unit.x=free[0].x;unit.y=free[0].y

static func can_rescue(game,carrier: Dictionary,unit: Dictionary) -> bool:
 return game.can_act(carrier) and carrier.team=="player" and downed(unit) and unit.get("carried_by","").is_empty() and carrier.id!=unit.id and game.distance(carrier,unit)<=1 and passenger(game,carrier)==null

static func rescue(game,carrier: Dictionary,unit: Dictionary) -> bool:
 if not can_rescue(game,carrier,unit):return false
 unit.carried_by=carrier.id;unit.x=carrier.x;unit.y=carrier.y;carrier.acted=true
 return true

static func drop_positions(game,carrier: Dictionary) -> Array:
 var positions=[]
 for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  var tile=game.pos(carrier)+direction
  if game.terrain(tile) not in ["#","~"] and game.at(tile)==null:positions.append(tile)
 return positions

static func drop(game,carrier: Dictionary,tile: Vector2i) -> bool:
 var unit=passenger(game,carrier)
 if not game.can_act(carrier) or unit==null or tile not in drop_positions(game,carrier):return false
 unit.erase("carried_by");unit.x=tile.x;unit.y=tile.y;carrier.acted=true
 return true

static func synchronize(game,carrier: Dictionary):
 var unit=passenger(game,carrier)
 if unit!=null:unit.x=carrier.x;unit.y=carrier.y

static func revival_position(game,unit: Dictionary):
 var occupied=game.units.any(func(other):return other.id!=unit.id and other.hp>0 and other.get("carried_by","").is_empty() and game.pos(other)==game.pos(unit))
 if not occupied:return game.pos(unit)
 var free=drop_positions(game,unit)
 return null if free.is_empty() else free[0]

static func can_recover(game,unit: Dictionary) -> bool:
 return not downed(unit) or not unit.get("carried_by","").is_empty() or revival_position(game,unit)!=null

static func recover(game,unit: Dictionary):
 if not downed(unit):return
 var standing=revival_position(game,unit)
 if unit.get("carried_by","").is_empty():
  if standing==null:return
  unit.x=standing.x;unit.y=standing.y
 unit.erase("downed");unit.erase("bleed_turns");unit.acted=true
 if not unit.get("carried_by","").is_empty():
  var free=drop_positions(game,unit)
  if not free.is_empty():unit.x=free[0].x;unit.y=free[0].y;unit.erase("carried_by")

static func end_player_phase(game):
 for unit in game.units:
  if not downed(unit) or not unit.get("carried_by","").is_empty():continue
  unit.bleed_turns-=1
  if unit.bleed_turns<=0:unit.erase("downed");unit.erase("bleed_turns")

static func valid(unit: Dictionary) -> bool:
 if unit.has("downed") and not unit.downed is bool:return false
 if unit.has("carried_by") and (not unit.carried_by is String or unit.carried_by.is_empty()):return false
 if downed(unit):
  var turns=unit.get("bleed_turns",0)
  if not (turns is int or turns is float) or turns!=int(turns) or turns<1 or turns>2:return false
  if unit.get("hp",-1)!=0 or unit.get("team","")!="player" or not unit.get("acted",false):return false
 elif unit.has("bleed_turns"):return false
 return true
