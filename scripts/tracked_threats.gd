extends RefCounted
## Session-only map annotations. References distinguish fresh attempts even
## when a new battle reuses exactly the same enemy IDs and statistics.
var units: Array=[]

func contains(unit) -> bool:
 return unit!=null and units.any(func(entry):return is_same(entry,unit))

func prune(game):
 var living=game.living("enemy")
 units=units.filter(func(entry):return living.any(func(unit):return is_same(entry,unit)))

func toggle(game,unit) -> bool:
 prune(game)
 if unit==null or not game.living("enemy").any(func(entry):return is_same(entry,unit)):return false
 if contains(unit):units=units.filter(func(entry):return not is_same(entry,unit))
 else:units.append(unit)
 return true

func tiles(game,tactics) -> Dictionary:
 prune(game)
 var result={}
 for unit in units:result.merge(tactics.threatened_tiles(game,unit))
 return result
