extends RefCounted
## A draft uses stable chapter keys. Only its compiled copy uses runtime indices.
const Rules=preload("res://scripts/rules.gd")
const Settings=preload("res://scripts/campaign_settings.gd")
const Supports=preload("res://scripts/supports.gd")
const FORMAT="poem-campaign"
const VERSION=1
const MAX_CHAPTERS=32
const MAX_DRAFT_LENGTH=1000000
const ENVIRONMENTS=["village","river","forest","abbey","road","harbor","mountain","aqueduct","observatory","furnace","castle","engine"]
const OBJECTIVES=["rout","boss","seize","survive"]
const STRATEGIES=["pursue","sentry","guard"]
const RECRUIT_STATS={"hp":[1,900],"pow":[0,200],"defense":[0,200],"resistance":[0,200],"speed":[0,200],"move":[1,20]}
const LEVEL_FIELDS=["title","place","intro","outro","tactical_brief","map","route_position","environment","score_theme",
 "objective","objective_position","turn_limit","deployment_positions","enemies","hard_enemies","presentation"]
const MIN_BOARD=Vector2i(6,5)
const MAX_BOARD=Vector2i(32,24)

var templates: Dictionary
var base_story: Dictionary
var base_profiles: Dictionary
var music_ids: Array
var data: Dictionary
var dirty=false

func _init():
 templates=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
 base_story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
 base_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
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
 else:
  result.chapters.append({"key":"chapter_01","source":-1,"section":true,"level":blank_level(),"opening":[],"closing":[]})
 if stock:result.bonds=stock_bonds(result.chapters)
 for recruit in templates.roster:
  var join=int(recruit.join)
  var chapter_key=result.chapters[join].key if join<result.chapters.size() else ""
  var stats={}
  for field in RECRUIT_STATS:stats[field]=recruit[field]
  result.recruits.append({"id":recruit.id,"name":recruit.name,"bio":recruit.bio,"chapter":chapter_key,
   "job":recruit.job,"stats":stats,"ending":base_profiles[recruit.id].get("ending",recruit.bio)})
 return result.duplicate(true)

func stock_bonds(chapters: Array) -> Array:
 var bonds=Supports.new().entries
 for bond in bonds:
  bond.chapters=bond.chapters.map(func(index):return chapters[mini(int(index),chapters.size()-1)].key)
 return bonds

func bond_members() -> Array:
 var members=data.recruits.map(func(person):return person.id)
 members.append_array(templates.legacy_recruits.map(func(legacy):return legacy.unit.id))
 return members

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

func insert_chapter(after: int,copy_current: bool,valley_table=false) -> int:
 if data.chapters.size()>=MAX_CHAPTERS:return -1
 var record={"source":-1,"section":false,"level":blank_level(),"opening":[],"closing":[]}
 if valley_table:
  record.level=preload("res://scripts/world_map_battle.gd").chapter()
  record.opening=[{"speaker":"lyra","text":"Pull the seals off the chart. I want to see every road into the capital."},
   {"speaker":"oren","text":"We drew those crossings at the same scale. Put a company on each road and see where they can meet."}]
  record.closing=[{"speaker":"lyra","text":"The capital’s road is open. Send word to every company still on the map."}]
 if copy_current:
  record=data.chapters[after].duplicate(true)
  record.level.title+=" (copy)"
  record.section=false
 var number=1
 while index_for("chapter_%02d"%number)>=0:number+=1
 record.key="chapter_%02d"%number
 data.chapters.insert(after+1,record)
 return after+1

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
 var next=mini(index,data.chapters.size()-1)
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

func structural_problem(document) -> String:
 if not document is Dictionary or document.get("format")!=FORMAT or document.get("version")!=VERSION:
  return "Choose a Poem campaign document with format version 1."
 if not valid_text(document.get("title"),120) or not document.get("chapters") is Array or not document.get("recruits") is Array or not document.get("settings") is Dictionary:
  return "The campaign title, chapters, company, or settings are missing."
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
  keys[chapter.key]=true
 if not document.chapters[0].section:return "The opening chapter must start a section."
 var known=templates.roster.map(func(recruit):return recruit.id)
 var people={}
 if document.recruits.size()!=known.size():return "The company roster is incomplete."
 for recruit in document.recruits:
  if not recruit is Dictionary or recruit.get("id") not in known or people.has(recruit.id):return "Each company recruit needs a unique catalogue identity."
  if not valid_text(recruit.get("name"),80) or not valid_text(recruit.get("bio"),800) or not recruit.get("chapter") is String:
   return "A recruit is missing a name, introduction, or arrival."
  if not valid_text(recruit.get("ending"),1200):return "A recruit has an invalid epilogue."
  if not templates.classes.has(recruit.get("job")) or not recruit.get("stats") is Dictionary:return "A recruit has an unknown class or missing stats."
  for field in RECRUIT_STATS:
   if not integer(recruit.stats.get(field),RECRUIT_STATS[field][0],RECRUIT_STATS[field][1]):
    return "A recruit has an invalid base stat."
  if not recruit.chapter.is_empty() and not keys.has(recruit.chapter):return "A recruit arrives in a missing chapter."
  people[recruit.id]=true
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
 if not integer(level.get("turn_limit"),1,99):return "A survival limit must be between 1 and 99 phases."
 if not level.get("route_position") is Array or level.route_position.size()!=2 or not level.route_position.all(
   func(value):return number(value) and value>=0 and value<=1):return "A route pin must stay on the map."
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
 if not level.get("deployment_positions") is Array or level.deployment_positions.size()>6 or not level.deployment_positions.all(point_valid):
  return "A battle supports up to six deployment tiles."
 for key in ["enemies","hard_enemies"]:
  if not level.get(key) is Array or level[key].size()>24:return "A battle supports up to 24 placements in each enemy group."
  for enemy in level[key]:
   if not enemy is Dictionary or not templates.classes.has(enemy.get("job")) or not point_valid(enemy.get("position")):
    return "An enemy needs a class and a tile."
   if enemy.get("ai","pursue") not in STRATEGIES or not valid_text(enemy.get("name",""),80):return "An enemy has an invalid strategy or name."
   if enemy.has("item") and not valid_text(enemy.item,80):return "An enemy has an invalid equipment entry."
 return ""

func battle_problem(level: Dictionary) -> String:
 var occupied={}
 if level.deployment_positions.is_empty():return "Place at least one deployment tile."
 if level.enemies.is_empty():return "Place at least one enemy. The first enemy is the commander."
 if level.objective=="seize" and not walkable(level,level.objective_position):return "Put the seize objective on passable terrain."
 var positions=level.deployment_positions+level.enemies.map(func(enemy):return enemy.position)+level.hard_enemies.map(func(enemy):return enemy.position)
 for position in positions:
  if not walkable(level,position):return "Move the placement at %d, %d to passable terrain."%position
  var point=Vector2i(position[0],position[1])
  if occupied.has(point):return "Two deployments or enemies share tile %d, %d."%position
  occupied[point]=true
 return ""

func playtest_problem() -> String:
 var issue=structural_problem(data)
 if not issue.is_empty():return issue
 for index in data.chapters.size():
  var level=data.chapters[index].level
  issue=battle_problem(level)
  if not issue.is_empty():return "Chapter %d · %s"%[index+1,issue]
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
 content.authoring_signature=JSON.stringify(JSON.parse_string(encode()),"",true,true).sha256_text()
 content.opening_company=data.opening_company.duplicate()
 content.chapters=[]
 content.section_starts=[]
 var scenes=[]
 for index in data.chapters.size():
  var chapter=data.chapters[index]
  var level={}
  for field in LEVEL_FIELDS:
   if chapter.level.has(field):level[field]=chapter.level[field]
  level=level.duplicate(true)
  level.id=index
  level.boss=level.enemies[0].get("name","")
  if level.boss.is_empty():level.boss="Garrison commander"
  level.deployment=level.deployment_positions.size()
  level.enemy_count=level.enemies.size()
  if chapter.source>=0:
   var original=templates.chapters[int(chapter.source)]
   if level.map==original.map and level.environment==original.environment:
    level.landmarks=original.get("landmarks",[]).duplicate(true)
    level.lighting=original.get("lighting",{}).duplicate(true)
  if chapter.section:content.section_starts.append(index)
  content.chapters.append(level)
  scenes.append({"opening":chapter.opening.duplicate(true),"closing":chapter.closing.duplicate(true)})
 for recruit in content.roster:
  var authored=data.recruits.filter(func(entry):return entry.id==recruit.id)[0]
  var arrival=index_for(authored.chapter)
  recruit.join=arrival if arrival>=0 else data.chapters.size()
  recruit.name=authored.name;recruit.bio=authored.bio
  recruit.ending=authored.ending
  if recruit.job!=authored.job:
   recruit.job=authored.job
   recruit.weapon=content.classes[recruit.job].weapon
   recruit.reach=content.classes[recruit.job].reach
   recruit.item=Rules.DEFAULT_ITEMS[recruit.weapon]
  for field in RECRUIT_STATS:recruit[field]=authored.stats[field]
 if data.has("bonds"):
  content.bonds=data.bonds.duplicate(true)
  for bond in content.bonds:bond.chapters=bond.chapters.map(index_for)
 return {"content":content,"story":{"chapters":scenes},"settings":data.settings.duplicate(true)}

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
