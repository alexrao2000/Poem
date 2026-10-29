extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
func _initialize():
 var g=Rules.new();var seen={};var count=0
 for chapter in range(12):
  g.chapter=chapter;g.start_battle()
  for i in range(g.info().enemies.size()):
   var entry=g.info().enemies[i];var unit=g.units.filter(func(u):return u.id=="enemy_"+str(i))[0]
   assert(unit.item==entry.item and g.item_for(unit).kind==unit.weapon,"Authored item is compatible and survives spawn")
   assert(unit.reach==g.item_for(unit).max_range)
   seen[unit.item]=true;count+=1
  var restored=Rules.new();assert(restored.import_code(g.export_code("battle"))=="battle")
  for i in range(g.units.size()):assert(restored.units[i].item==g.units[i].item,"Enemy equipment survives transfers")
 assert(seen.has("javelin") and seen.has("longbow") and seen.has("war_hammer") and seen.has("thunder"))
 g.chapter=5;g.start_battle();var bow=g.units.filter(func(u):return u.item=="longbow")[0]
 var hero=g.living("player")[0];hero.x=bow.x+3;hero.y=bow.y
 assert(g.can_attack(bow,hero) and Tactics.new().threatened_tiles(g,bow).has(g.pos(hero)),"Enemy bow extends actual threat to three tiles")
 hero.x=bow.x-1;assert(not g.can_attack(bow,hero),"Enemy bow retains adjacent blind spot")
 g.chapter=7;g.start_battle();var hammer=g.units.filter(func(u):return u.item=="war_hammer")[0]
 var knight=g.units.filter(func(u):return u.team=="player" and u.job=="Knight")[0]
 assert(g.forecast(hammer,knight).effective,"Enemy anti-armor weapon reaches forecast")
 # A gear-only content update must not discard an existing battle checkpoint.
 var old=Rules.new();old.chapter=7
 for entry in old.info().enemies:entry.erase("item")
 old.start_battle();old.turn=4
 var loaded=Rules.new();assert(loaded.import_code(old.export_code("battle"))=="battle" and loaded.turn==4)
 assert(loaded.living("enemy")[0].item=="iron_lance","Existing battle preserves its saved gear")
 # Old/custom formations that omit gear still use their class default.
 g.content.chapters[0].enemies[0].erase("item");g.chapter=0;g.start_battle()
 assert(g.living("enemy")[0].item=="iron_sword")
 print("PASS: ",count," authored enemy loadouts, threat ranges, effectiveness, save transfer and legacy defaults")
 quit()
