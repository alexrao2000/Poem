extends RefCounted
# The simulation has no scene, rendering, or audio dependencies.
var content: Dictionary
var equipment: Array
const DEFAULT_ITEMS={"sword":"iron_sword","lance":"iron_lance","axe":"iron_axe","bow":"scout_bow","magic":"ember","staff":"field_staff"}
var chapter: int = 0
var turn: int = 1
var phase: String = "player"
var roster: Array = []
var units: Array = []
var deployed: Array = []
var rng := RandomNumberGenerator.new()
var completed: bool = false
var story_seen: Array = []

func _init():
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	equipment = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	rng.seed = 472019
	new_campaign()

func new_campaign():
	chapter = 0
	turn = 1
	phase = "player"
	units.clear()
	completed = false
	story_seen.clear()
	rng.seed = 472019
	roster = content.roster.duplicate(true)
	for u in roster:
		u.level = 1+int(u.join)
		u.xp = 0
		u.hp += int(u.join)*2
		u.pow += int(u.join)
		u.defense += int(u.join)/2
		u.max_hp = u.hp
		normalize_equipment(u)
	deployed = ["lyra", "oren", "sera", "ivo"]

func available() -> Array:
	return roster.filter(func(u): return int(u.join) <= chapter)

func info() -> Dictionary:
	return content.chapters[chapter]

func board_size() -> Vector2i:
	return Vector2i(info().map[0].length(),info().map.size())

func objective_position() -> Vector2i:
	var point=info().get("objective_position",[12,4])
	return Vector2i(point[0],point[1])

func start_battle():
	units.clear()
	turn = 1
	phase = "player"
	var spots = info().get("deployment_positions",[[1,3],[1,4],[1,5],[2,3],[2,4],[2,5]])
	var index = 0
	for u in available():
		if u.id not in deployed or index >= int(info().deployment): continue
		var v = u.duplicate(true)
		v.x = spots[index][0]
		v.y = spots[index][1]
		v.hp = v.max_hp
		v.team = "player"
		v.acted = false
		v.moved = false
		v.potions = 2
		units.append(v)
		index += 1
	for i in range(info().enemies.size()):
		var entry=info().enemies[i]
		var job=entry.job
		var e=content.classes[job].duplicate(true)
		e.id="enemy_"+str(i)
		e.name=info().boss if i==0 else ["Ash guard","Crown scout","Sun sworn","Black pennant"][i%4]
		e.job=job;e.color="#ce7771";e.level=1+chapter;e.xp=0
		e.hp+=chapter*2;e.pow+=chapter;e.defense+=chapter/2;e.max_hp=e.hp
		e.team="enemy";e.acted=false;e.moved=false;e.boss=i==0
		e.ai=entry.get("ai","pursue");e.alerted=false
		e.x=int(entry.position[0]);e.y=int(entry.position[1])
		normalize_equipment(e)
		units.append(e)

func terrain(p: Vector2i) -> String:
	if p.x<0 or p.y<0 or p.x>=board_size().x or p.y>=board_size().y: return "#"
	return info().map[p.y][p.x]

func pos(u: Dictionary) -> Vector2i:
	return Vector2i(int(u.x),int(u.y))

func at(p: Vector2i):
	for u in units:
		if u.hp>0 and pos(u)==p: return u
	return null

func living(team: String) -> Array:
	return units.filter(func(u): return u.team==team and u.hp>0)

func distance(a: Dictionary,b: Dictionary) -> int:
	return absi(int(a.x-b.x))+absi(int(a.y-b.y))

func reachable(u: Dictionary) -> Dictionary:
	var start = pos(u)
	var costs = {start:0}
	var queue = [start]
	while not queue.is_empty():
		var p = queue.pop_front()
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var q: Vector2i = p+d
			var tile = terrain(q)
			if tile in ["#","~"]: continue
			var other = at(q)
			if other!=null and other.team!=u.team: continue
			var cost = costs[p]+(2 if tile in ["f","h"] else 1)
			if cost<=u.move and (not costs.has(q) or cost<costs[q]):
				costs[q]=cost
				queue.append(q)
	return costs

func can_act(u: Dictionary) -> bool:
	return u.hp>0 and u.team==phase and not u.acted

func move_unit(u: Dictionary,destination: Vector2i) -> bool:
	if not can_act(u) or u.get("moved",false):return false
	if destination!=pos(u) and at(destination)!=null:return false
	if not reachable(u).has(destination):return false
	u.move_origin=[u.x,u.y];u.x=destination.x;u.y=destination.y;u.moved=true
	return true

func undo_move(u: Dictionary) -> bool:
	if not can_act(u) or not u.has("move_origin"):return false
	u.x=u.move_origin[0];u.y=u.move_origin[1];u.moved=false;u.erase("move_origin")
	return true

func wait_unit(u: Dictionary) -> bool:
	if not can_act(u):return false
	u.acted=true;return true

func item_for(u: Dictionary) -> Dictionary:
	var id=u.get("item",DEFAULT_ITEMS.get(u.weapon,"iron_sword"))
	for item in equipment:
		if item.id==id and item.kind==u.weapon:return item
	for item in equipment:
		if item.id==DEFAULT_ITEMS.get(u.weapon,"iron_sword"):return item
	return equipment[0]

func normalize_equipment(u: Dictionary):
	var item=item_for(u);u.item=item.id;u.reach=int(item.max_range)

func equip(u: Dictionary,id: String) -> bool:
	if not roster.has(u) or int(u.join)>chapter:return false
	for item in equipment:
		if item.id==id and item.kind==u.weapon and int(item.unlock)<=chapter:
			u.item=id;u.reach=int(item.max_range);return true
	return false

func attack_power(u: Dictionary) -> int:
	return int(u.pow)+int(item_for(u).might)

func attack_speed(u: Dictionary) -> int:
	return maxi(0,int(u.speed)-int(item_for(u).weight))

func in_weapon_range(u: Dictionary,tiles: int) -> bool:
	var item=item_for(u)
	return tiles>=int(item.min_range) and tiles<=int(item.max_range)

func range_text(u: Dictionary) -> String:
	var item=item_for(u)
	return str(int(item.min_range)) if item.min_range==item.max_range else "%d–%d"%[item.min_range,item.max_range]

func can_heal(a: Dictionary,b: Dictionary) -> bool:
	return can_act(a) and a.weapon=="staff" and a.team==b.team and a.id!=b.id and b.hp>0 and b.hp<b.max_hp and in_weapon_range(a,distance(a,b))

func heal(a: Dictionary,b: Dictionary) -> bool:
	if not can_heal(a,b):return false
	b.hp=mini(b.max_hp,b.hp+int(item_for(a).heal));a.acted=true;award_xp(a,30)
	return true

func use_tonic(u: Dictionary) -> bool:
	if not can_act(u) or u.get("potions",0)<=0 or u.hp>=u.max_hp:return false
	u.hp=mini(u.max_hp,u.hp+12);u.potions-=1;u.acted=true
	return true

func begin_enemy_phase():
	phase="enemy"
	for u in living("enemy"):
		u.acted=false;u.moved=false;u.erase("move_origin")

func can_attack(a: Dictionary,b: Dictionary) -> bool:
	var d = distance(a,b)
	return a.hp>0 and b.hp>0 and a.team!=b.team and in_weapon_range(a,d) and a.weapon!="staff"

func forecast(a: Dictionary,b: Dictionary) -> Dictionary:
	var advantage = 0
	var beats = {"sword":"axe","axe":"lance","lance":"sword"}
	if beats.get(a.weapon,"")==b.weapon: advantage=1
	if beats.get(b.weapon,"")==a.weapon: advantage=-1
	var cover = 2 if terrain(pos(b)) in ["f","h","o"] else 0
	var defense = int(b.defense)/2 if a.weapon=="magic" else int(b.defense)
	return {"damage":maxi(1,attack_power(a)+advantage-defense-cover),"hit":clampi(85+(attack_speed(a)-attack_speed(b))*2+int(item_for(a).hit)+advantage*15-cover*5,25,100),"crit":clampi(int(a.speed)/2+int(item_for(a).crit),0,50),"double":attack_speed(a)-attack_speed(b)>=4,"counter":can_attack(b,a)}

func strike(a: Dictionary,b: Dictionary) -> Dictionary:
	var f = forecast(a,b)
	var hit = (rng.randi_range(0,99)+rng.randi_range(0,99))/2 < f.hit
	var crit = hit and rng.randi_range(0,99)<f.crit
	var damage = mini(int(b.hp),int(f.damage)*(3 if crit else 1)) if hit else 0
	b.hp -= damage
	return {"actor":a.id,"target":b.id,"damage":damage,"crit":crit,"hit":hit,"remaining":b.hp}

func combat(a: Dictionary,b: Dictionary) -> Array:
	if a.team!=phase or a.acted or not can_attack(a,b): return []
	var f = forecast(a,b)
	var result = [strike(a,b)]
	if b.hp>0 and can_attack(b,a): result.append(strike(b,a))
	if a.hp>0 and b.hp>0:
		if f.double: result.append(strike(a,b))
		elif attack_speed(b)-attack_speed(a)>=4 and can_attack(b,a): result.append(strike(b,a))
	a.acted = true
	for u in [a,b]:
		if u.team=="player" and u.hp>0:
			award_xp(u,45 if (b.hp<=0 if u==a else a.hp<=0) else 25)
	return result

func award_xp(u: Dictionary, amount: int):
	u.xp+=amount
	while u.xp>=100:
		u.xp-=100
		u.level+=1
		u.max_hp+=2
		u.hp+=2
		u.pow+=1
		u.defense+=1
		if int(u.level)%2==0:u.speed+=1

func result() -> String:
	if living("player").is_empty(): return "defeat"
	var boss_alive = units.any(func(u): return u.get("boss",false) and u.hp>0)
	match info().objective:
		"rout":
			if living("enemy").is_empty(): return "victory"
		"boss":
			if not boss_alive: return "victory"
		"survive":
			if turn>info().turn_limit or living("enemy").is_empty(): return "victory"
		"seize":
			var occupant = at(objective_position())
			if occupant!=null and occupant.team=="player": return "victory"
	return ""

func finish_chapter():
	for u in units:
		if u.team!="player": continue
		for r in roster:
			if r.id==u.id:
				for key in ["level","xp","max_hp","pow","defense","speed","item","reach"]:r[key]=u[key]
	chapter+=1
	if chapter>=content.chapters.size():
		completed=true
		chapter=content.chapters.size()-1
	for u in available():
		if deployed.size()<6 and u.id not in deployed:deployed.append(u.id)

func next_player_turn():
	turn+=1
	phase="player"
	for u in units:
		u.acted=false;u.moved=false;u.erase("move_origin")
		if u.hp>0 and terrain(pos(u)) in ["+","o"]:u.hp=mini(u.max_hp,u.hp+6)

const SAVE_VERSION=3

func layout_signature() -> String:
	return JSON.stringify([info().map,info().deployment_positions,info().enemies,info().objective_position]).sha256_text()

func save_game(path: String,stage: String) -> bool:
	var data={"version":SAVE_VERSION,"layout_signature":layout_signature(),"story_seen":story_seen,"chapter":chapter,"turn":turn,"phase":phase,"roster":roster,"units":units,"deployed":deployed,"completed":completed,"rng":str(rng.state),"stage":stage}
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(data));file.flush();file.close()
	if FileAccess.file_exists(path):DirAccess.copy_absolute(path,path+".bak")
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func valid_save(data) -> bool:
	if not data is Dictionary:return false
	for key in ["version","chapter","turn","phase","roster","units","deployed","completed","rng","stage"]:
		if not data.has(key):return false
	for key in ["version","chapter","turn"]:
		if not (data[key] is float or data[key] is int):return false
	if int(data.version) not in [1,2,SAVE_VERSION]:return false
	if int(data.chapter)<0 or int(data.chapter)>=content.chapters.size() or int(data.turn)<1:return false
	if data.phase not in ["player","enemy"] or data.stage not in ["camp","battle","ending"]:return false
	if not data.completed is bool or not data.rng is String or not data.rng.is_valid_int():return false
	if not data.roster is Array or data.roster.size()!=content.roster.size():return false
	if not data.units is Array or not data.deployed is Array or not data.get("story_seen",[]) is Array:return false
	var ids={}
	for unit in data.roster:
		if not valid_unit(unit,false) or ids.has(unit.id):return false
		if not content.roster.any(func(original):return original.id==unit.id):return false
		ids[unit.id]=true
	for id in data.deployed:
		if not id is String or not ids.has(id):return false
	if data.deployed.size()>int(content.chapters[int(data.chapter)].deployment):return false
	var combat_ids={}
	for unit in data.units:
		if not valid_unit(unit,true) or combat_ids.has(unit.id):return false
		combat_ids[unit.id]=true
		if unit.team=="player" and not ids.has(unit.id):return false
		var grid=content.chapters[int(data.chapter)].map
		if unit.x<0 or unit.y<0 or unit.x>=grid[0].length() or unit.y>=grid.size():return false
	return true

func valid_unit(unit,in_battle: bool) -> bool:
	if not unit is Dictionary:return false
	for key in ["id","name","job","weapon","color"]:
		if not unit.get(key) is String:return false
	if not content.classes.has(unit.job):return false
	if unit.weapon!=content.classes[unit.job].weapon:return false
	if unit.has("item") and (not unit.item is String or not equipment.any(func(item):return item.id==unit.item and item.kind==unit.weapon)):return false
	for key in ["hp","max_hp","pow","defense","speed","move","reach","level","xp"]:
		if not (unit.get(key) is float or unit.get(key) is int):return false
		if not is_finite(float(unit[key])) or unit[key]<0:return false
	if unit.max_hp<=0 or unit.hp>unit.max_hp or unit.move>20 or unit.reach>10:return false
	if in_battle:
		if unit.get("team") not in ["player","enemy"] or not unit.get("acted") is bool:return false
		for key in ["x","y"]:
			if not (unit.get(key) is float or unit.get(key) is int):return false
	return true

func load_game(path: String) -> String:
	var data=null
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate))!=OK:continue
		var parsed=parser.data
		if valid_save(parsed):data=parsed;break
	if data==null:return ""
	story_seen=data.get("story_seen",[])
	chapter=int(data.chapter);turn=int(data.turn);phase=data.phase;roster=data.roster;units=data.units;deployed=data.deployed;completed=data.completed;rng.state=int(data.rng)
	for unit in roster:normalize_equipment(unit)
	for unit in units:
		normalize_equipment(unit)
		unit.moved=unit.get("moved",false)
		if unit.team=="enemy":unit.ai=unit.get("ai","guard" if unit.get("boss",false) else "pursue")
	# Old layouts cannot safely resume units on redesigned walls or water.
	if data.stage=="battle" and data.get("layout_signature","")!=layout_signature():
		units.clear();phase="player";return "camp"
	return data.stage
