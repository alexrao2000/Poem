extends RefCounted
## A draft uses stable chapter keys. Only its compiled copy uses runtime indices.
const Rules=preload("res://scripts/rules.gd")
const Settings=preload("res://scripts/campaign_settings.gd")
const Supports=preload("res://scripts/supports.gd")
const Trials=preload("res://scripts/campaign_trials.gd")
const Valley=preload("res://scripts/world_map_battle.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Atlas=preload("res://scripts/campaign_atlas.gd")
const FORMAT="poem-campaign"
const VERSION=1
const MAX_CHAPTERS=32
const MAX_CUSTOM_RECRUITS=16
const MAX_PHASE_SCENES=8
const MAX_SITE_SCENES=8
const MAX_EXTRA_STANDARDS=5
const MAX_ENEMY_PLACEMENTS=24
const MAX_DEPLOYMENTS=6
const TERRAIN_UNDO_LIMIT=32
const SECTION_SCENES={"relief":"Relief arrivals","retreat":"Withdrawal","memorial":"Memorial"}
const MAX_DRAFT_LENGTH=1000000
const ENVIRONMENTS=["village","river","forest","abbey","road","harbor","mountain","aqueduct","observatory","furnace","castle","engine"]
const OBJECTIVES=["rout","boss","seize","survive"]
const STRATEGIES=["pursue","sentry","guard"]
const ROUTE_TERRAIN=["p","=","f","h","o","+"]
const RECRUIT_STATS={"hp":[1,900],"pow":[0,200],"defense":[0,200],"resistance":[0,200],"speed":[0,200],"move":[1,20]}
const LEVEL_FIELDS=["title","place","intro","outro","tactical_brief","map","route_position","environment","score_theme",
 "objective","objective_position","turn_limit","deployment_positions","enemies","hard_enemies","presentation","enemy_level","hard_bonuses","site_scenes","extra_standards","route_arena","hold_enemy_phase"]
const MIN_BOARD=Vector2i(6,5)
const MAX_BOARD=Vector2i(32,24)

var templates: Dictionary
var base_story: Dictionary
var base_trial_scenes: Dictionary
var base_profiles: Dictionary
var equipment: Array
var music_ids: Array
var terrain_history={}
var data: Dictionary:
 set(value):
  data=value
  terrain_history.clear()
var dirty=false
var atlas_source=""
var atlas_texture: ImageTexture

func _init():
 templates=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
 base_story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
 base_trial_scenes=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_trial_scenes.json"))
 base_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
 equipment=JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
 var themes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/themes.json"))
 music_ids=themes.profiles.map(func(profile):return profile.id)
 data=new_document(true)

func new_document(stock: bool) -> Dictionary:
 var result={"format":FORMAT,"version":VERSION,"title":"Poem" if stock else "Untitled campaign",
  "chapters":[],"recruits":[],"bonds":[],"opening_company":["lyra","oren","sera","ivo"],"settings":{"permadeath":false}}
 for setting in Settings.SWITCHES:result.settings[setting.key]=false
 if stock:
  for index in templates.chapters.size():
   var source=templates.chapters[index]
   var level={}
   for field in LEVEL_FIELDS:
    if source.has(field):level[field]=source[field]
   level=level.duplicate(true)
   level.enemies[0].name=source.boss
   level.hard_enemies=level.get("hard_enemies",[])
   level.score_theme=level.get("score_theme","standard")
   level.presentation="battlefield"
   var story=base_story.chapters[index]
   var opens_section=templates.section_starts.any(func(value):return int(value)==index)
   result.chapters.append({"key":"chapter_%02d"%(index+1),"source":index,"section":opens_section,
    "level":level,"opening":story.opening,"closing":story.closing})
   if opens_section:result.chapters[-1].section_scenes=section_scene_defaults(index)
 else:
  result.chapters.append({"key":"chapter_01","source":-1,"section":true,"level":blank_level(),"opening":[],"closing":[],"section_scenes":{}})
 if stock:result.bonds=stock_bonds(result.chapters)
 for recruit in templates.roster:
  var join=int(recruit.join)
  var chapter_key=result.chapters[join].key if join<result.chapters.size() else ""
  var stats={}
  for field in RECRUIT_STATS:stats[field]=recruit[field]
  result.recruits.append({"id":recruit.id,"name":recruit.name,"bio":recruit.bio,"chapter":chapter_key,
   "job":recruit.job,"stats":stats,"ending":base_profiles[recruit.id].get("ending",recruit.bio)})
 return result.duplicate(true)

func section_scene_defaults(source: int) -> Dictionary:
 var definitions={}
 for kind in SECTION_SCENES:
  var key=kind+"_"+str(source)
  if base_trial_scenes.has(key):
   definitions[kind]={"title":Trials.SCENE_TITLES.get(key,SECTION_SCENES[kind]),"lines":base_trial_scenes[key].duplicate(true)}
 return definitions

func stock_bonds(chapters: Array) -> Array:
 var bonds=Supports.new().entries
 for bond in bonds:
  bond.chapters=bond.chapters.map(func(index):return chapters[mini(int(index),chapters.size()-1)].key)
 return bonds

func bond_members() -> Array:
 var members=data.recruits.map(func(person):return person.id)
 members.append_array(templates.legacy_recruits.map(func(legacy):return legacy.unit.id))
 return members

func add_recruit(source: Dictionary,arrival: String) -> int:
 if data.recruits.size()>=templates.roster.size()+MAX_CUSTOM_RECRUITS:return -1
 var ids=data.recruits.map(func(person):return person.id)
 var number=1
 while "recruit_%02d"%number in ids:number+=1
 var recruit=source.duplicate(true)
 recruit.art_id=source.get("art_id",source.id)
 recruit.id="recruit_%02d"%number
 recruit.name="New recruit";recruit.bio="";recruit.ending="";recruit.chapter=arrival
 data.recruits.append(recruit)
 return data.recruits.size()-1

func recruit_in_use(id: String) -> bool:
 if id in data.opening_company:return true
 for bond in data.get("bonds",[]):
  if id in bond.members:return true
  for scene in bond.scenes:
   if dialogue_uses(scene.lines,id):return true
 for arrival in data.get("legacy_arrivals",[]):
  if arrival.id==id or dialogue_uses(arrival.lines,id):return true
 for chapter in data.chapters:
  if id in chapter.get("relief_company",[]):return true
  if dialogue_uses(chapter.opening,id) or dialogue_uses(chapter.closing,id):return true
  for scene in chapter.get("phase_scenes",[])+chapter.level.get("site_scenes",[]):
   if scene.get("recruit","")==id or dialogue_uses(scene.lines,id):return true
  for scene in chapter.get("section_scenes",{}).values():
   if dialogue_uses(scene.lines,id):return true
 return false

static func dialogue_uses(lines: Array,id: String) -> bool:
 for line in lines:
  if line.speaker==id or id in line.get("requires",[]) or dialogue_uses(line.get("when_absent",[]),id):return true
 return false

func blank_level() -> Dictionary:
 var rows=[]
 for _i in 10:rows.append("..............")
 return {"title":"New chapter","place":"The valley","intro":"","outro":"","tactical_brief":"",
  "map":rows,"route_position":[.5,.5],"environment":"road","score_theme":"standard","presentation":"battlefield",
  "objective":"seize","objective_position":[11,4],"turn_limit":6,
  "deployment_positions":[[1,3],[1,4],[1,5],[2,3],[2,4],[2,5]],
  "enemies":[{"position":[11,4],"job":"Vanguard","ai":"guard","name":"Garrison commander"},
   {"position":[9,4],"job":"Ranger","ai":"sentry","name":"Garrison scout"}],"hard_enemies":[]}

func encode() -> String:
 return JSON.stringify(data,"  ",true,true)

func decode(raw: String) -> String:
 if raw.length()>MAX_DRAFT_LENGTH:return "This campaign document is too large."
 var parser=JSON.new()
 if parser.parse(raw)!=OK:return "JSON line %d. %s"%[parser.get_error_line(),parser.get_error_message()]
 var issue=structural_problem(parser.data)
 if not issue.is_empty():return issue
 data=parser.data
 return ""

func index_for(key: String) -> int:
 return data.chapters.find_custom(func(chapter):return chapter.key==key)

func route_texture() -> Texture2D:
 if not data.has("route_atlas"):
  atlas_source="";atlas_texture=null
  return null
 if not cache_route_atlas(data.route_atlas):return null
 return atlas_texture

func cache_route_atlas(encoded) -> bool:
 if not encoded is String:return false
 if atlas_texture!=null and atlas_source==encoded:return true
 var picture=Atlas.unpack(encoded)
 if picture==null:return false
 picture.generate_mipmaps()
 atlas_texture=ImageTexture.create_from_image(picture)
 atlas_source=encoded
 return true

func insert_chapter(after: int,copy_current: bool,valley_table=false) -> int:
 if data.chapters.size()>=MAX_CHAPTERS:return -1
 var record={"source":-1,"section":false,"level":blank_level(),"opening":[],"closing":[]}
 if valley_table:
  record.level=Valley.chapter(templates.chapters)
  record.opening=[{"speaker":"lyra","text":"Pull the seals off the chart. I want to see every road into the capital."},
   {"speaker":"oren","text":"We drew those crossings at the same scale. Put a company on each road and see where they can meet."}]
  record.closing=[{"speaker":"lyra","text":"The capital’s road is open. Send word to every company still on the map."}]
  record.phase_scenes=[{"id":"capital_standard","turn":3,"phase":"player","lines":[
   {"speaker":"oren","text":"From the abbey road you can see both banks. Keep the crossings open behind us."},
   {"speaker":"lyra","text":"When we raise the standard, every company in the valley will know which road to take."}]}]
 if copy_current:
  record=data.chapters[after].duplicate(true)
  record.level.title+=" (copy)"
  record.section=false
 var number=1
 while index_for("chapter_%02d"%number)>=0:number+=1
 record.key="chapter_%02d"%number
 data.chapters.insert(after+1,record)
 return after+1

func insert_blank_war_table(after: int) -> int:
 var index=insert_chapter(after,false)
 if index<0:return index
 var level=data.chapters[index].level
 level.title="New war-table chapter"
 level.place="War table"
 level.presentation="valley_table"
 level.score_theme="valley"
 resize_map(level,Vector2i(Valley.WIDTH,Valley.HEIGHT))
 paint(level,Vector2i(level.objective_position[0],level.objective_position[1]),"o")
 return index

func load_poem_template(valley: bool):
 data=new_document(true)
 if valley:
  data.title="Poem · The Roads Between"
  var stage=insert_chapter(data.chapters.size()-2,false,true)
  data.chapters[stage].level.site_scenes=Valley.route_dialogue(data.chapters.slice(0,stage))

func load_valley_roads_trial():
 load_poem_template(true)
 data.title="Poem · Hold the Valley Roads · Permanent losses"
 var valley=data.chapters[-2].level
 valley.extra_standards=[[6,9],[9,5]]
 valley.tactical_brief="Leave companies at Reed Crossing and Hallow Abbey while a third claims the capital. Hold all three standards at once."
 for key in ["hard_campaign","reset_pressure","death_door","sacrifice_cost","permadeath","section_restarts","action_saves","death_legacies"]:
  data.settings[key]=true
 var medic=data.recruits[add_recruit(data.recruits[3],"")]
 medic.name="Merrin"
 medic.bio="A lamp keeper who brings the western hospice company to the ridge."
 medic.ending="Merrin kept the road lamps lit for travellers who arrived after dark."
 data.chapters[4].relief_company=[medic.id,"faye","cassian"]
 data.chapters[4].section_scenes.relief={"title":"Lamps from the west","lines":[
  {"speaker":medic.id,"text":"I brought oil and bandages. Tell the first company to take the sheltered road."},
  {"speaker":"lyra","text":"Keep a lamp at the rally point. We may have to come this way again."}]}
 var scout=data.recruits[add_recruit(data.recruits[2],"")]
 scout.name="Aster"
 scout.bio="A surveyor who knows the valley’s crossings by the stones below the water."
 scout.ending="Aster walked the valley roads again and marked the crossings on a chart anyone could read."
 data.legacy_arrivals=[{"id":scout.id,"losses":2,"job":"","title":"Aster’s chart","lines":[
  {"speaker":scout.id,"text":"I heard who was lost. Put your map here and I’ll show you another crossing."}]}]
 data.legacy_stock=Trials.LEGACY_STOCK.duplicate(true)
 data.legacy_stock.append({"id":"pike","cost":1,"losses":2,"legacy_only":true})

func load_valley_signals_trial(permanent=true):
 load_valley_roads_trial()
 data.title="Poem · Signals in the Valley · Permadeath "+("on" if permanent else "off")
 for key in ["permadeath","action_saves","section_restarts","death_legacies"]:data.settings[key]=permanent
 var chapter=data.chapters[-2]
 chapter.level.hold_enemy_phase=true
 chapter.phase_scenes.append({"id":"ridge_signal","turn":1,"phase":"enemy","on_defense":true,"lines":[
  {"speaker":"narrator","text":"The old abbey lamps answer one another along the ridge. A fresh column is moving down the road."},
  {"speaker":"lyra","text":"Keep the crossings open. If a standard falls, take it back together."}]})
 chapter.level.enemies.append_array([
  {"name":"Abbey reserve","job":"Ranger","position":[8,5],"level":24,"item":"longbow","ai":"pursue","arrive_on_defense":true},
  {"name":"Capital relief","job":"Rider","position":[22,2],"level":21,"item":"javelin","ai":"pursue","arrive_on_defense":true},
  {"name":"Abbey battlemage","job":"Arcanist","position":[10,5],"level":22,"item":"thunder","ai":"pursue","arrive_on_defense":true}])

func move_chapter(index: int,direction: int) -> int:
 var destination=index+direction
 if destination<0 or destination>=data.chapters.size():return index
 var record=data.chapters.pop_at(index)
 data.chapters.insert(destination,record)
 data.chapters[0].section=true
 data.recruits.filter(func(recruit):return recruit.id=="lyra")[0].chapter=data.chapters[0].key
 sync_opening_company()
 return destination

func remove_chapter(index: int) -> int:
 if data.chapters.size()==1:return index
 var removed=data.chapters.pop_at(index)
 terrain_history.erase(removed.key)
 var next=mini(index,data.chapters.size()-1)
 var tile=Valley.route_tile(removed.level.route_position)
 for chapter in data.chapters:
  for scene in chapter.level.get("site_scenes",[]):
   if scene.get("route_key","")!=removed.key:continue
   scene.position=[tile.x,tile.y]
   scene.erase("route_key")
  var pins=chapter.level.get("extra_standard_pins",[])
  if removed.key in pins:
   pins.erase(removed.key)
   if pins.is_empty():chapter.level.erase("extra_standard_pins")
   var standards=chapter.level.get("extra_standards",[])
   var position=[tile.x,tile.y]
   if position not in standards:standards.append(position)
   chapter.level.extra_standards=standards
 for recruit in data.recruits:
  if recruit.chapter==removed.key:recruit.chapter=data.chapters[next].key
 for bond in data.get("bonds",[]):
  for rank in bond.chapters.size():
   if bond.chapters[rank]==removed.key:bond.chapters[rank]=data.chapters[next].key
 data.chapters[0].section=true
 sync_opening_company()
 return next

func sync_opening_company():
 var eligible=data.recruits.filter(func(recruit):return recruit.chapter==data.chapters[0].key).map(func(recruit):return recruit.id)
 data.opening_company=data.opening_company.filter(func(id):return id in eligible)

func resize_map(level: Dictionary,dimensions: Vector2i):
 var rows=[]
 for y in dimensions.y:
  var row=level.map[y].left(dimensions.x) if y<level.map.size() else ""
  rows.append(row.rpad(dimensions.x,"."))
 level.map=rows

func paint(level: Dictionary,point: Vector2i,symbol: String):
 var row: String=level.map[point.y]
 level.map[point.y]=row.left(point.x)+symbol+row.substr(point.x+1)

func remember_terrain(index: int):
 var chapter=data.chapters[index]
 var history=terrain_history.get(chapter.key,{"undo":[],"redo":[]})
 history.undo.append(chapter.level.map.duplicate())
 if history.undo.size()>TERRAIN_UNDO_LIMIT:history.undo.pop_front()
 history.redo.clear()
 terrain_history[chapter.key]=history

func can_step_terrain(index: int,redo: bool) -> bool:
 return not terrain_history.get(data.chapters[index].key,{}).get("redo" if redo else "undo",[]).is_empty()

func step_terrain(index: int,redo: bool) -> bool:
 if not can_step_terrain(index,redo):return false
 var chapter=data.chapters[index]
 var history=terrain_history[chapter.key]
 var previous=history.redo if redo else history.undo
 var current=history.undo if redo else history.redo
 current.append(chapter.level.map.duplicate())
 chapter.level.map=previous.pop_back()
 return true

func fill_terrain(index: int,start: Vector2i,symbol: String,route_marks: Dictionary) -> bool:
 var level=data.chapters[index].level
 var bounds=Rect2i(Vector2i.ZERO,Vector2i(level.map[0].length(),level.map.size()))
 if not bounds.has_point(start) or route_marks.has(start):return false
 var original=level.map[start.y][start.x]
 if original==symbol:return false
 remember_terrain(index)
 var frontier=[start]
 while not frontier.is_empty():
  var point=frontier.pop_back()
  if not bounds.has_point(point) or route_marks.has(point) or level.map[point.y][point.x]!=original:continue
  paint(level,point,symbol)
  for direction in Tactics.DIRECTIONS:frontier.append(point+direction)
 return true

static func placement_at(level: Dictionary,point: Vector2i) -> Dictionary:
 for group in ["deployment_positions","enemies","hard_enemies"]:
  var members=level[group]
  for index in members.size():
   var location=members[index] if group=="deployment_positions" else members[index].position
   if Vector2i(location[0],location[1])==point:return {"group":group,"index":index}
 return {}

func move_placement(index: int,from: Vector2i,to: Vector2i) -> bool:
 var level=data.chapters[index].level
 var selected=placement_at(level,from)
 if selected.is_empty() or from==to:return false
 var effective=battle_level(index)
 if not walkable(effective,[to.x,to.y]):return false
 var displaced=placement_at(level,to)
 if not displaced.is_empty():
  if not walkable(effective,[from.x,from.y]):return false
  set_placement(level,displaced,from)
 set_placement(level,selected,to)
 return true

func copy_placement(index: int,from: Vector2i,to: Vector2i) -> String:
 var level=data.chapters[index].level
 var source=placement_at(level,from)
 if source.is_empty():return "Select a placement to copy."
 var position=[to.x,to.y]
 if not placement_at(level,to).is_empty() or not walkable(battle_level(index),position):
  return "Choose an empty passable tile."
 var group=level[source.group]
 var deployment=source.group=="deployment_positions"
 if group.size()>=(MAX_DEPLOYMENTS if deployment else MAX_ENEMY_PLACEMENTS):
  return "This placement group is full."
 if deployment:group.append(position)
 else:
  var copied=group[source.index].duplicate(true)
  copied.position=position
  group.append(copied)
 return ""

static func set_placement(level: Dictionary,placement: Dictionary,point: Vector2i):
 var target=[point.x,point.y]
 var group=level[placement.group]
 if placement.group=="deployment_positions":group[placement.index]=target
 else:group[placement.index].position=target

func structural_problem(document) -> String:
 if not document is Dictionary or document.get("format")!=FORMAT or document.get("version")!=VERSION:
  return "Choose a Poem campaign document with format version 1."
 if not valid_text(document.get("title"),120) or not document.get("chapters") is Array or not document.get("recruits") is Array or not document.get("settings") is Dictionary:
  return "The campaign title, chapters, company, or settings are missing."
 if document.has("route_atlas") and not cache_route_atlas(document.route_atlas):return "The campaign contains an invalid route atlas."
 if document.chapters.is_empty() or document.chapters.size()>MAX_CHAPTERS:return "A campaign needs 1–32 chapters."
 var keys={}
 for chapter in document.chapters:
  if not chapter is Dictionary or not valid_text(chapter.get("key"),64) or not chapter.key.is_valid_identifier() or keys.has(chapter.key):
   return "Every chapter needs a unique key."
  if not chapter.get("section") is bool or not chapter.get("level") is Dictionary:return "A chapter is missing its section setting or battle."
  if not integer(chapter.get("source"),-1,templates.chapters.size()-1):return "A chapter has an invalid scenery reference."
  var level_issue=map_structure_problem(chapter.level)
  if not level_issue.is_empty():return level_issue
  if not dialogue_valid(chapter.get("opening")) or not dialogue_valid(chapter.get("closing")):return "A chapter has an invalid dialogue line."
  if not phase_scenes_valid(chapter.get("phase_scenes",[])):return "A chapter has an invalid phase scene."
  var section=chapter.get("section_scenes",{})
  if not section is Dictionary:return "A chapter has invalid section dialogue."
  for kind in section:
   if not SECTION_SCENES.has(kind) or not section[kind] is Dictionary or not valid_text(section[kind].get("title"),100) or not dialogue_valid(section[kind].get("lines")):
    return "A chapter has invalid section dialogue."
  keys[chapter.key]=true
 for chapter in document.chapters:
  for scene in chapter.level.get("site_scenes",[]):
   if scene.has("route_key") and (chapter.level.presentation!="valley_table" or not keys.has(scene.route_key)):
    return "A tile dialogue link needs a campaign route pin."
  for pin in chapter.level.get("extra_standard_pins",[]):
   if not keys.has(pin):return "A required standard needs a campaign route pin."
 if not document.chapters[0].section:return "The opening chapter must start a section."
 var known=templates.roster.map(func(recruit):return recruit.id)
 var people={}
 if document.recruits.size()<known.size() or document.recruits.size()>known.size()+MAX_CUSTOM_RECRUITS:
  return "Keep the catalogue roster and up to sixteen additional recruits."
 for recruit in document.recruits:
  if not recruit is Dictionary or not valid_text(recruit.get("id"),40) or people.has(recruit.id):
   return "Each company recruit needs a unique identity."
  if recruit.id in known:
   if recruit.has("art_id"):return "Catalogue recruits retain their original appearance."
  elif not recruit.id.begins_with("recruit_") or not recruit.id.is_valid_identifier() or recruit.get("art_id") not in known:
   return "Each new recruit needs a valid identity and catalogue appearance."
  if not valid_text(recruit.get("name"),80) or not valid_text(recruit.get("bio"),800) or not recruit.get("chapter") is String:
   return "A recruit is missing a name, introduction, or arrival."
  if not valid_text(recruit.get("ending"),1200):return "A recruit has an invalid epilogue."
  if not templates.classes.has(recruit.get("job")) or not recruit.get("stats") is Dictionary:return "A recruit has an unknown class or missing stats."
  if recruit.has("item") and not gear_for(recruit.job).any(func(item):return item.id==recruit.item):
   return "A recruit has starting equipment their class cannot use."
  for field in RECRUIT_STATS:
   if not integer(recruit.stats.get(field),RECRUIT_STATS[field][0],RECRUIT_STATS[field][1]):
    return "A recruit has an invalid base stat."
  if not recruit.chapter.is_empty() and not keys.has(recruit.chapter):return "A recruit arrives in a missing chapter."
  people[recruit.id]=true
 if document.has("legacy_stock") and not valid_legacy_stock(document.legacy_stock,people.size()+templates.legacy_recruits.size()-1):
  return "Choose unique legacy items with valid loss thresholds and credit costs."
 if document.has("legacy_arrivals") and not valid_legacy_arrivals(document.legacy_arrivals,people):
  return "Choose a unique recruit, a loss threshold and a valid class for each legacy arrival."
 if not known.all(func(id):return people.has(id)):return "The company roster is incomplete."
 for chapter in document.chapters:
  for scene in chapter.level.get("site_scenes",[]):
   if scene.has("recruit") and not people.has(scene.recruit):
    return "A recruitment site needs a recruit from the company roster."
  if not chapter.has("relief_company"):continue
  var relief=chapter.relief_company
  if not relief is Array or relief.size()>=people.size():return "Choose a distinct roster member for each relief assignment."
  var seen={"lyra":true}
  for id in relief:
   if not id is String or not people.has(id) or seen.has(id):return "Choose a distinct roster member for each relief assignment."
   seen[id]=true
 if document.has("bonds"):
  var bond_people=people.duplicate()
  for legacy in templates.legacy_recruits:bond_people[legacy.unit.id]=true
  var bond_issue=bond_structure_problem(document.bonds,bond_people,keys)
  if not bond_issue.is_empty():return bond_issue
 if not document.get("opening_company") is Array or document.opening_company.is_empty() or document.opening_company.size()>6:
  return "Choose one to six opening company members."
 var deployed={}
 for id in document.opening_company:
  if not people.has(id) or deployed.has(id):return "Choose each opening recruit once."
  deployed[id]=true
 if not deployed.has("lyra"):return "The company leader must deploy in the opening chapter."
 for key in (["permadeath"]+Settings.SWITCHES.map(func(setting):return setting.key)):
  if not document.settings.get(key) is bool:return "A campaign rules switch is missing."
 return ""

func legacy_items() -> Array:
 return equipment.filter(func(item):return item.unlock>0)

func valid_legacy_stock(entries,limit: int) -> bool:
 var ids=legacy_items().map(func(item):return item.id)
 if not entries is Array or entries.size()>ids.size():return false
 for stock in entries:
  if not stock is Dictionary or stock.get("id") not in ids:return false
  if not integer(stock.get("cost"),1,limit) or not integer(stock.get("losses"),1,limit):return false
  if not stock.get("legacy_only",false) is bool:return false
  ids.erase(stock.id)
 return true

func default_legacy_arrivals() -> Array:
 var arrivals=Trials.LEGACY_ARRIVALS.duplicate(true)
 for arrival in arrivals:
  var key="volunteer_"+arrival.id
  arrival.title=Trials.SCENE_TITLES[key];arrival.lines=base_trial_scenes[key].duplicate(true)
 return arrivals

func valid_legacy_arrivals(entries,people: Dictionary) -> bool:
 if not entries is Array or entries.size()>=people.size():return false
 var used={"lyra":true}
 for arrival in entries:
  if not arrival is Dictionary or not arrival.get("id") is String or not people.has(arrival.id) or used.has(arrival.id):return false
  if not integer(arrival.get("losses"),1,people.size()+templates.legacy_recruits.size()-1):return false
  if arrival.get("job") not in ([""]+templates.classes.keys()):return false
  if not valid_text(arrival.get("title"),100) or not dialogue_valid(arrival.get("lines")):return false
  used[arrival.id]=true
 return true

func phase_scenes_valid(scenes) -> bool:
 if not scenes is Array or scenes.size()>MAX_PHASE_SCENES:return false
 var found={}
 for scene in scenes:
  if not scene is Dictionary or not valid_text(scene.get("id"),32) or not scene.id.is_valid_identifier() or found.has(scene.id):
   return false
  if not integer(scene.get("turn"),1,99) or scene.get("phase") not in ["player","enemy"] or not dialogue_valid(scene.get("lines")):
   return false
  if not scene.get("on_defense",false) is bool:return false
  found[scene.id]=true
 return true

func site_scenes_valid(scenes) -> bool:
 if not scenes is Array or scenes.size()>MAX_SITE_SCENES:return false
 var identities={}
 for scene in scenes:
  if not scene is Dictionary or not valid_text(scene.get("id"),32) or not scene.id.is_valid_identifier() or identities.has(scene.id):
   return false
  if not point_valid(scene.get("position")) or not dialogue_valid(scene.get("lines")):return false
  if not scene.get("refill_tonics",false) is bool:return false
  if scene.has("recruit") and (not valid_text(scene.recruit,40) or not scene.recruit.is_valid_identifier()):return false
  if scene.has("route_key") and (not valid_text(scene.route_key,64) or not scene.route_key.is_valid_identifier()):return false
  identities[scene.id]=true
 return true

func bond_structure_problem(bonds,people: Dictionary,chapter_keys: Dictionary) -> String:
 if not bonds is Array or bonds.size()>people.size()/2.0:return "A company member can have one authored bond."
 var identities={}
 var paired={}
 for bond in bonds:
  if not bond is Dictionary or not valid_text(bond.get("id"),64) or not bond.id.is_valid_identifier() or identities.has(bond.id):
   return "Every bond needs a unique key."
  identities[bond.id]=true
  if not bond.get("members") is Array or bond.members.size()!=2:return "A bond needs two company members."
  for member in bond.members:
   if not member is String or not people.has(member) or paired.has(member):return "Choose two unpaired company members for each bond."
   paired[member]=true
  if not valid_text(bond.get("ending"),1200):return "A bond has an invalid paired epilogue."
  for field in ["chapters","points","scenes"]:
   if not bond.get(field) is Array or bond[field].size()!=3:return "Every bond needs C, B, and A rank settings."
  var minimum=1
  for rank in 3:
   if not bond.chapters[rank] is String or not chapter_keys.has(bond.chapters[rank]):return "A bond opens in a missing chapter."
   if not integer(bond.points[rank],minimum,6):return "Bond ranks need one to six points in ascending order."
   minimum=int(bond.points[rank])
   var scene=bond.scenes[rank]
   if not scene is Dictionary or not valid_text(scene.get("title"),100) or not dialogue_valid(scene.get("lines")):
    return "A bond has an invalid conversation."
 return ""

func map_structure_problem(level: Dictionary) -> String:
 for field in ["title","place","intro","outro","tactical_brief"]:
  if not valid_text(level.get(field,""),1800):return "A chapter contains invalid text."
 if level.get("environment") not in ENVIRONMENTS or level.get("score_theme") not in music_ids:
  return "A chapter references an unknown environment or score."
 if level.get("presentation") not in ["battlefield","valley_table"] or level.get("objective") not in OBJECTIVES:
  return "A chapter references an unknown presentation or objective."
 if not level.get("hold_enemy_phase",false) is bool:return "Choose whether standards must be held through an enemy phase."
 if not integer(level.get("turn_limit"),1,99):return "A survival limit must be between 1 and 99 phases."
 if not integer(level.get("enemy_level",0),0,Rules.MAX_LEVEL):return "Set a default enemy level from 0 to 99."
 if level.has("hard_bonuses"):
  var bonuses=level.hard_bonuses
  if not bonuses is Dictionary or bonuses.size()!=Trials.HARD_BONUS_STATS.size():return "Set all four Hard enemy bonuses."
  for stat in Trials.HARD_BONUS_STATS:
   if not integer(bonuses.get(stat),0,Rules.STAT_CAPS[stat]):return "Set each Hard enemy bonus within its stat limit."
 if not level.get("route_position") is Array or level.route_position.size()!=2 or not level.route_position.all(
   func(value):return number(value) and value>=0 and value<=1):return "A route pin must stay on the map."
 if level.get("route_terrain","") not in ([""]+ROUTE_TERRAIN):return "Choose a terrain type for the route pin."
 if not level.get("route_arena",false) is bool:return "Choose whether later war tables reuse the route location’s environment."
 if not level.get("map") is Array or level.map.size()<MIN_BOARD.y or level.map.size()>MAX_BOARD.y or not level.map[0] is String:
  return "A battle needs a rectangular terrain grid."
 var width=level.map[0].length()
 if width<MIN_BOARD.x or width>MAX_BOARD.x:return "A battle grid must be 6–32 tiles wide."
 if level.presentation=="valley_table" and (width!=24 or level.map.size()!=16):
  return "The valley chart uses a 24 by 16 grid."
 for row in level.map:
  if not row is String or row.length()!=width:return "Terrain rows must have the same width."
  for symbol in row:
   if not Rules.TERRAIN_PROFILES.has(symbol):return "A battle contains an unknown terrain tile."
 if not point_valid(level.get("objective_position")):return "An objective needs a tile."
 var additional=level.get("extra_standards",[])
 if not additional is Array or additional.size()>MAX_EXTRA_STANDARDS or not additional.all(point_valid):
  return "Use up to five additional standard tiles."
 var pins=level.get("extra_standard_pins",[])
 if not pins is Array or additional.size()+pins.size()>MAX_EXTRA_STANDARDS:
  return "Use up to five additional standards, including linked route pins."
 if not pins.is_empty() and level.presentation!="valley_table":return "Only war tables can require a route pin."
 var seen={}
 for pin in pins:
  if not valid_text(pin,64) or not pin.is_valid_identifier() or seen.has(pin):return "Each linked standard needs a different route pin."
  seen[pin]=true
 if not site_scenes_valid(level.get("site_scenes",[])):return "A chapter has invalid tile dialogue."
 if not level.get("deployment_positions") is Array or level.deployment_positions.size()>MAX_DEPLOYMENTS or not level.deployment_positions.all(point_valid):
  return "A battle supports up to six deployment tiles."
 for key in ["enemies","hard_enemies"]:
  if not level.get(key) is Array or level[key].size()>MAX_ENEMY_PLACEMENTS:return "A battle supports up to 24 placements in each enemy group."
  for enemy in level[key]:
   if not enemy is Dictionary or not templates.classes.has(enemy.get("job")) or not point_valid(enemy.get("position")):
    return "An enemy needs a class and a tile."
   if enemy.get("ai","pursue") not in STRATEGIES or not valid_text(enemy.get("name",""),80):return "An enemy has an invalid strategy or name."
   if enemy.has("raider") and not enemy.raider is bool:return "Choose a valid enemy retry behavior."
   if not integer(enemy.get("level",0),0,Rules.MAX_LEVEL):return "Set an enemy level from 0 to 99."
   if not integer(enemy.get("arrival_turn",1),1,99) or enemy.get("arrival_phase","player") not in ["player","enemy"]:
    return "Set an enemy arrival to a player or enemy phase between turns 1 and 99."
   if not enemy.get("arrive_on_defense",false) is bool:return "Choose whether an enemy arrives to contest the standards."
   if enemy.has("item") and not gear_for(enemy.job).any(func(item):return item.id==enemy.item):
    return "An enemy has equipment their class cannot use."
 return ""

func gear_for(job: String) -> Array:
 var weapon=templates.classes[job].weapon
 return equipment.filter(func(item):return item.kind==weapon)

func battle_problem(level: Dictionary) -> String:
 var occupied={}
 if level.deployment_positions.is_empty():return "Place at least one deployment tile."
 if level.enemies.is_empty():return "Place at least one enemy. The first enemy is the commander."
 if Rules.delayed_enemy(level.enemies[0]):return "The commander must start on the board."
 var goals=Rules.standard_tiles(level)
 if goals.size()>level.deployment_positions.size():return "Place at least %d deployment tiles to hold every standard."%goals.size()
 var standard_tiles={}
 for goal in goals:
  if standard_tiles.has(goal):return "Put each standard on its own tile."
  if not walkable(level,[goal.x,goal.y]):return "Put the seize objective on passable terrain." if goals.size()==1 else "Put all standards on passable terrain."
  standard_tiles[goal]=true
 for scene in level.get("site_scenes",[]):
  if (not scene.lines.is_empty() or scene.get("refill_tonics",false) or scene.has("recruit")) and not walkable(level,scene.position):
   var event="recruitment site" if scene.has("recruit") else "tonic cache" if scene.lines.is_empty() else "tile dialogue"
   return "Move the %s at %d, %d to passable terrain."%[event,scene.position[0],scene.position[1]]
 var positions=level.deployment_positions+level.enemies.map(func(enemy):return enemy.position)+level.hard_enemies.map(func(enemy):return enemy.position)
 for position in positions:
  if not walkable(level,position):return "Move the placement at %d, %d to passable terrain."%position
  var point=Vector2i(position[0],position[1])
  if occupied.has(point):return "Two deployments or enemies share tile %d, %d."%position
  occupied[point]=true
 return ""

func valley_marks(index: int) -> Dictionary:
 var level=data.chapters[index].level
 if level.presentation!="valley_table":return {}
 var objective=Vector2i(level.objective_position[0],level.objective_position[1])
 var marks={}
 for prior in index:
  var route=data.chapters[prior].level
  var terrain=route.get("route_terrain","")
  if route.presentation=="valley_table" or terrain.is_empty():continue
  var tile=Valley.route_tile(route.route_position)
  if level.objective=="seize" and tile==objective:continue
  marks[tile]={"terrain":terrain,"place":route.title if route.place.is_empty() else route.place}
 return marks

func battle_level(index: int) -> Dictionary:
 var level=data.chapters[index].level
 var marks=valley_marks(index)
 var scenes=level.get("site_scenes",[])
 var linked=scenes.any(func(scene):return scene.has("route_key"))
 var linked_standards=standard_pin_tiles(index)
 if marks.is_empty() and not linked and linked_standards.is_empty():return level
 var adjusted=level.duplicate()
 if not marks.is_empty():adjusted.map=level.map.duplicate()
 for tile in marks:paint(adjusted,tile,marks[tile].terrain)
 if not linked_standards.is_empty():
  adjusted.extra_standards=level.get("extra_standards",[])+linked_standards
 if linked:
  adjusted.site_scenes=scenes.map(func(scene):
   if not scene.has("route_key"):return scene
   var resolved=scene.duplicate()
   resolved.position=site_position(index,scene)
   var anchor=earlier_route_index(index,scene.route_key)
   if anchor>=0:resolved.revisit_chapter=anchor
   resolved.erase("route_key")
   return resolved)
 return adjusted

func earlier_route_index(index: int,key: String) -> int:
 if key.is_empty():return -1
 var anchor=index_for(key)
 if anchor<0 or anchor>=index or data.chapters[anchor].level.presentation=="valley_table":return -1
 return anchor

func site_position(index: int,site: Dictionary) -> Array:
 var anchor=earlier_route_index(index,site.get("route_key",""))
 if anchor<0:return site.position
 var tile=Valley.route_tile(data.chapters[anchor].level.route_position)
 return [tile.x,tile.y]

func standard_pin_tiles(index: int) -> Array:
 var level=data.chapters[index].level
 var positions=[]
 if level.objective!="seize":return positions
 for key in level.get("extra_standard_pins",[]):
  var anchor=earlier_route_index(index,key)
  if anchor>=0:
   var tile=Valley.route_tile(data.chapters[anchor].level.route_position)
   positions.append([tile.x,tile.y])
 return positions

func route_link_problem(index: int) -> String:
 var level=data.chapters[index].level
 for scene in level.get("site_scenes",[]):
  if scene.has("route_key") and earlier_route_index(index,scene.route_key)<0:
   return "Tile dialogue must follow a route pin from an earlier chapter."
 if level.objective=="seize":
  for key in level.get("extra_standard_pins",[]):
   if earlier_route_index(index,key)<0:return "A required standard must follow a route pin from an earlier chapter."
 return ""

func battle_readiness(index: int) -> Dictionary:
 var link_issue=route_link_problem(index)
 if not link_issue.is_empty():return {"title":"Needs edits","description":link_issue}
 var level=battle_level(index)
 var issue=battle_problem(level)
 if not issue.is_empty():return {"title":"Needs edits","description":issue}
 if level.objective=="seize" and not seize_route_exists(level):
  var message="The seize tile is cut off from every deployment tile." if level.get("extra_standards",[]).is_empty() else "A required standard is cut off from every deployment tile."
  return {"title":"Check the route","description":message}
 return {"title":"Ready","description":""}

func seize_route_exists(level: Dictionary) -> bool:
 return Rules.standard_tiles(level).all(func(goal):return route_from_deployment(level,goal))

func route_from_deployment(level: Dictionary,goal: Vector2i) -> bool:
 var deployments=level.deployment_positions.map(func(point):return Vector2i(point[0],point[1]))
 var frontier=[goal]
 var visited={goal:true}
 while not frontier.is_empty():
  var point=frontier.pop_back()
  if point in deployments:return true
  for direction in Tactics.DIRECTIONS:
   var next=point+direction
   if not visited.has(next) and walkable(level,[next.x,next.y]):
    visited[next]=true;frontier.append(next)
 return false

func playtest_problem(selected=-1) -> String:
 var issue=structural_problem(data)
 if not issue.is_empty():return issue
 var indices=range(data.chapters.size()) if selected<0 else [selected]
 for index in indices:
  issue=route_link_problem(index)
  if not issue.is_empty():return "Chapter %d · %s"%[index+1,issue]
  issue=battle_problem(battle_level(index))
  if not issue.is_empty():return "Chapter %d · %s"%[index+1,issue]
 return company_problem()

func company_problem() -> String:
 var leader=data.recruits.filter(func(recruit):return recruit.id=="lyra")[0]
 if leader.chapter!=data.chapters[0].key:return "Set the company leader’s arrival to the first chapter."
 if data.opening_company.size()>data.chapters[0].level.deployment_positions.size():
  return "Add first-chapter deployment tiles for the opening company."
 var starting=data.recruits.filter(func(recruit):return recruit.chapter==data.chapters[0].key).map(func(recruit):return recruit.id)
 if not data.opening_company.all(func(id):return id in starting):return "The opening company can only use recruits who have arrived."
 return ""

func compile() -> Dictionary:
 var content=templates.duplicate(true)
 content.title=data.title
 var picture=route_texture()
 if picture!=null:content.route_atlas=picture
 content.authoring_signature=JSON.stringify(JSON.parse_string(encode()),"",true,true).sha256_text()
 content.opening_company=data.opening_company.duplicate()
 content.chapters=[]
 content.section_starts=[]
 var relief={}
 var scenes=[]
 for index in data.chapters.size():
  var chapter=data.chapters[index]
  var authored=battle_level(index)
  var level={}
  for field in LEVEL_FIELDS:
   if authored.has(field):level[field]=authored[field]
  level=level.duplicate(true)
  if chapter.has("phase_scenes"):level.phase_scenes=chapter.phase_scenes.duplicate(true)
  level.id=index
  level.boss=level.enemies[0].get("name","") if not level.enemies.is_empty() else ""
  if level.boss.is_empty():level.boss="Garrison commander"
  level.deployment=level.deployment_positions.size()
  level.enemy_count=level.enemies.size()
  if chapter.source>=0:
   var original=templates.chapters[int(chapter.source)]
   if level.map==original.map and level.environment==original.environment:
    level.landmarks=original.get("landmarks",[]).duplicate(true)
    level.lighting=original.get("lighting",{}).duplicate(true)
  if chapter.section:
   content.section_starts.append(index)
   if chapter.has("relief_company"):relief[index]=chapter.relief_company.duplicate()
  content.chapters.append(level)
  scenes.append({"opening":chapter.opening.duplicate(true),"closing":chapter.closing.duplicate(true)})
 var roster_by_id={}
 for recruit in content.roster:roster_by_id[recruit.id]=recruit
 for authored in data.recruits:
  if roster_by_id.has(authored.id):
   apply_recruit(roster_by_id[authored.id],authored)
  else:
   content.roster.append(build_recruit(authored))
 if data.has("bonds"):
  content.bonds=data.bonds.duplicate(true)
  for bond in content.bonds:bond.chapters=bond.chapters.map(index_for)
 if data.chapters.any(func(chapter):return chapter.has("section_scenes")):compile_section_scenes(content)
 if data.has("legacy_stock"):content.legacy_stock=data.legacy_stock.duplicate(true)
 if data.has("legacy_arrivals"):compile_legacy_arrivals(content)
 if not relief.is_empty():content.section_relief=relief
 return {"content":content,"story":{"chapters":scenes},"settings":data.settings.duplicate(true)}

static func prepare_playtest(game,settings: Dictionary,start: int,seed_value: int,pressure: int,deploy_company=true):
 game.new_campaign(settings.permadeath);game.chapter=start
 for setting in Settings.SWITCHES:Settings.set_enabled(game,setting.key,settings[setting.key])
 if seed_value>=0:game.rng.seed=seed_value
 game.trials.pressure=pressure
 if deploy_company and start>0:
  if game.content.get("section_relief",{}).has(start):game.trials.arrive(game)
  game.deployed=game.available().slice(0,int(game.info().deployment)).map(func(unit):return unit.id)

func compile_section_scenes(content: Dictionary):
 content.trial_scenes={}
 content.trial_titles={}
 for id in base_trial_scenes:
  if id.begins_with("volunteer_"):
   content.trial_scenes[id]=base_trial_scenes[id].duplicate(true)
   content.trial_titles[id]=Trials.SCENE_TITLES[id]
 for index in content.section_starts:
  var chapter=data.chapters[index]
  var definitions=chapter.section_scenes if chapter.has("section_scenes") else section_scene_defaults(int(chapter.source))
  for kind in definitions:
   var scene=definitions[kind]
   if scene.lines.is_empty() or (kind=="relief" and index==0):continue
   var id=kind+"_"+str(index)
   content.trial_scenes[id]=scene.lines.duplicate(true)
   content.trial_titles[id]=SECTION_SCENES[kind] if scene.title.is_empty() else scene.title

func compile_legacy_arrivals(content: Dictionary):
 if not content.has("trial_scenes"):
  content.trial_scenes=base_trial_scenes.duplicate(true)
  content.trial_titles=Trials.SCENE_TITLES.duplicate()
 content.legacy_arrivals=data.legacy_arrivals.duplicate(true)
 for arrival in content.legacy_arrivals:
  var key="volunteer_"+arrival.id
  if arrival.lines.is_empty():
   content.trial_scenes.erase(key);content.trial_titles.erase(key)
  else:
   content.trial_scenes[key]=arrival.lines
   content.trial_titles[key]="A recruit arrives" if arrival.title.is_empty() else arrival.title

func build_recruit(authored: Dictionary) -> Dictionary:
 var art_id=authored.get("art_id",authored.id)
 var recruit=templates.roster.filter(func(entry):return entry.id==art_id)[0].duplicate(true)
 if authored.has("art_id"):
  recruit.id=authored.id
  recruit.art_id=art_id
  recruit.art_job=recruit.job
 apply_recruit(recruit,authored)
 return recruit

func apply_recruit(recruit: Dictionary,authored: Dictionary):
 var arrival=index_for(authored.chapter)
 recruit.join=arrival if arrival>=0 else data.chapters.size()
 recruit.name=authored.name;recruit.bio=authored.bio
 recruit.ending=authored.ending
 if recruit.job!=authored.job:
  var job=templates.classes[authored.job]
  recruit.job=authored.job;recruit.weapon=job.weapon;recruit.reach=job.reach
  recruit.item=Rules.DEFAULT_ITEMS[recruit.weapon]
 if authored.has("item"):recruit.item=authored.item
 for field in RECRUIT_STATS:recruit[field]=authored.stats[field]

static func point_valid(value) -> bool:
 return value is Array and value.size()==2 and value.all(func(coordinate):return integer(coordinate,0,99))

static func walkable(level: Dictionary,position: Array) -> bool:
 var x=int(position[0]);var y=int(position[1])
 return y>=0 and y<level.map.size() and x>=0 and x<level.map[y].length() and level.map[y][x] not in ["#","~"]

static func number(value) -> bool:
 return (value is float or value is int) and is_finite(float(value))

static func integer(value,lower: int,upper: int) -> bool:
 return number(value) and value>=lower and value<=upper and value==int(value)

static func valid_text(value,maximum: int) -> bool:
 return value is String and value.length()<=maximum

static func dialogue_valid(lines,depth=0) -> bool:
 if not lines is Array or lines.size()>80 or depth>1:return false
 for line in lines:
  if not line is Dictionary or not valid_text(line.get("speaker"),40) or not valid_text(line.get("text"),1800):return false
  if not valid_text(line.get("expression",""),40):return false
  if not line.get("requires",[]) is Array or not line.get("requires",[]).all(func(id):return valid_text(id,40)):return false
  if line.has("when_absent") and not dialogue_valid(line.when_absent,depth+1):return false
 return true
