extends RefCounted
## Playable scene starters use ordinary growth, equipment and combat rolls.
## Build separately so an invalid request cannot disturb the current sandbox.
const Rules=preload("res://scripts/rules.gd")
const SCENES=[
 {"id":"sword","unit":"lyra","chapter":0,"title":"Lyra · Sword at the river village"},
 {"id":"lance","unit":"oren","chapter":3,"title":"Oren · Lance at the abbey"},
 {"id":"bow","unit":"sera","chapter":5,"title":"Sera · Bow at the harbor"},
 {"id":"healing","unit":"esme","chapter":3,"title":"Esme · Healing at the abbey"},
 {"id":"axe","unit":"mara","chapter":1,"title":"Mara · Axe at the broken toll"},
 {"id":"magic","unit":"noor","chapter":8,"title":"Noor · Magic at the observatory"},
 {"id":"duel","unit":"yuna","chapter":9,"title":"Yuna · Duel beneath the furnace"},
 {"id":"mounted","unit":"una","chapter":6,"title":"Una · Mounted lance in the mountains"}
]

static func start(game,id: String,seed_value: int) -> Dictionary:
 var matches=SCENES.filter(func(scene):return scene.id==id)
 if matches.is_empty():return {}
 var scene=matches[0];var staged=Rules.new();staged.chapter=scene.chapter
 staged.action_saves=true;staged.story_seen=["opening_"+str(staged.chapter)]
 staged.rng.seed=seed_value
 for unit in staged.available():
  var level=maxi(3,staged.chapter+1)
  if unit.level<level:staged.award_xp(unit,(level-int(unit.level))*100-int(unit.xp))
 staged.deployed=[scene.unit]
 for unit in staged.available():
  if unit.id!=scene.unit and staged.deployed.size()<6:staged.deployed.append(unit.id)
 staged.rng.seed=seed_value;staged.start_battle()
 var actor=staged.units.filter(func(unit):return unit.id==scene.unit)[0]
 var healing=actor.weapon=="staff"
 var recipient=staged.living("player").filter(func(unit):return unit.id!=actor.id)[0] if healing else staged.living("enemy")[1]
 var tiles=[];var center=Vector2(staged.board_size())*.5
 for y in range(staged.board_size().y):
  for x in range(staged.board_size().x):
   var tile=Vector2i(x,y);var occupant=staged.at(tile)
   if staged.terrain(tile) in ["#","~"] or tile==staged.objective_position():continue
   if occupant==null or occupant.id in [actor.id,recipient.id]:tiles.append(tile)
 tiles.sort_custom(func(a,b):
  var da=Vector2(a).distance_squared_to(center);var db=Vector2(b).distance_squared_to(center)
  return (a.y<b.y or (a.y==b.y and a.x<b.x)) if is_equal_approx(da,db) else da<db)
 var reach=2 if actor.weapon in ["bow","magic"] else 1
 for tile in tiles:
  for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
   var other=tile+direction*reach
   if other not in tiles or not staged.in_weapon_range(actor,reach):continue
   actor.x=tile.x;actor.y=tile.y;recipient.x=other.x;recipient.y=other.y
   if healing:recipient.hp=maxi(1,recipient.max_hp-12)
   if not (staged.can_heal(actor,recipient) if healing else staged.can_attack(actor,recipient)):continue
   if game.restore_save(staged.save_data("battle"))!="battle":return {}
   return {"actor":actor.id,"target":recipient.id,"healing":healing}
 return {}
