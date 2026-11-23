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

static func scene_for_recruit(roster: Array,recruit_id: String) -> Dictionary:
 var recruits=roster.filter(func(unit):return unit.id==recruit_id)
 if recruits.is_empty():return {}
 for scene in SCENES:
  var template=roster.filter(func(unit):return unit.id==scene.unit)
  if not template.is_empty() and template[0].job==recruits[0].job:return scene
 return {}

static func available_chapters(game,recruit_id: String,item_id="") -> Array:
 var recruits=game.content.roster.filter(func(unit):return unit.id==recruit_id)
 if recruits.is_empty():return []
 var first=int(recruits[0].join)
 if not item_id.is_empty():
  var items=game.equipment.filter(func(item):return item.id==item_id and item.kind==recruits[0].weapon)
  if items.is_empty():return []
  first=maxi(first,int(items[0].unlock))
 return range(first,game.content.chapters.size())

static func start_recruit(game,recruit_id: String,promotion_id: String,seed_value: int,item_id="",chapter=-1,commander=false) -> Dictionary:
 var scene=scene_for_recruit(game.content.roster,recruit_id)
 if scene.is_empty():return {}
 return start(game,scene.id,seed_value,recruit_id,promotion_id,item_id,chapter,commander)

static func start(game,id: String,seed_value: int,recruit_id="",promotion_id="",item_id="",chapter=-1,commander=false) -> Dictionary:
 var matches=SCENES.filter(func(scene):return scene.id==id)
 if matches.is_empty():return {}
 var scene=matches[0];var staged=Rules.new()
 if recruit_id.is_empty():recruit_id=scene.unit
 var actors=staged.roster.filter(func(unit):return unit.id==recruit_id)
 if actors.is_empty() or scene_for_recruit(staged.roster,recruit_id).get("id","")!=scene.id:return {}
 var recruit=actors[0]
 if commander and recruit.weapon=="staff":return {}
 if not promotion_id.is_empty() and not staged.promotion_options(recruit).any(func(path):return path.id==promotion_id):return {}
 var chapters=available_chapters(staged,recruit_id,item_id)
 if chapters.is_empty() or chapter<-1 or (chapter!=-1 and chapter not in chapters):return {}
 staged.chapter=maxi(scene.chapter,chapters[0]) if chapter==-1 else chapter
 staged.action_saves=true;staged.story_seen=["opening_"+str(staged.chapter)]
 staged.rng.seed=seed_value
 for unit in staged.available():
  var level=maxi(3,staged.chapter+1)
  if unit.id==recruit_id and not promotion_id.is_empty():level=maxi(level,10)
  if unit.level<level:staged.award_xp(unit,(level-int(unit.level))*100-int(unit.xp))
 if not promotion_id.is_empty() and not staged.promote(recruit,promotion_id):return {}
 if not item_id.is_empty() and not staged.equip(recruit,item_id):return {}
 staged.deployed=[recruit_id]
 for unit in staged.available():
  if unit.id!=recruit_id and staged.deployed.size()<6:staged.deployed.append(unit.id)
 staged.rng.seed=seed_value;staged.start_battle()
 var actor=staged.units.filter(func(unit):return unit.id==recruit_id)[0]
 var healing=actor.weapon=="staff"
 var recipient=staged.living("player").filter(func(unit):return unit.id!=actor.id)[0] if healing else staged.living("enemy")[0 if commander else 1]
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
 if not item_id.is_empty():reach=int(staged.item_for(actor).max_range)
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
