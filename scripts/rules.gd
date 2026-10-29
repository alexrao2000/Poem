extends RefCounted
# The simulation has no scene, rendering, or audio dependencies.
var content: Dictionary
var chapter: int = 0
var turn: int = 1
var phase: String = "player"
var roster: Array = []
var units: Array = []
var deployed: Array = []
var rng := RandomNumberGenerator.new()
var completed: bool = false

func _init():
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	rng.seed = 472019
	new_campaign()

func new_campaign():
	chapter = 0
	completed = false
	roster = content.roster.duplicate(true)
	for u in roster:
		u.level = 1+int(u.join)
		u.xp = 0
		u.hp += int(u.join)*2
		u.pow += int(u.join)
		u.defense += int(u.join)/2
		u.max_hp = u.hp
	deployed = ["lyra", "oren", "sera", "ivo"]

func available() -> Array:
	return roster.filter(func(u): return int(u.join) <= chapter)

func info() -> Dictionary:
	return content.chapters[chapter]

func start_battle():
	units.clear()
	turn = 1
	phase = "player"
	var spots = [Vector2i(1,3),Vector2i(1,4),Vector2i(1,5),Vector2i(2,3),Vector2i(2,4),Vector2i(2,5)]
	var index = 0
	for u in available():
		if u.id not in deployed or index >= 6: continue
		var v = u.duplicate(true)
		v.x = spots[index].x
		v.y = spots[index].y
		v.hp = v.max_hp
		v.team = "player"
		v.acted = false
		v.potions = 2
		units.append(v)
		index += 1
	var positions = [Vector2i(9,3),Vector2i(10,6),Vector2i(8,8),Vector2i(11,1),Vector2i(12,7),Vector2i(8,4),Vector2i(10,8),Vector2i(9,6),Vector2i(11,3),Vector2i(12,4)]
	var jobs = ["Vanguard","Corsair","Ranger","Knight","Arcanist"]
	for i in range(int(info().enemy_count)):
		var job = jobs[(i+chapter)%jobs.size()]
		var e = content.classes[job].duplicate(true)
		e.id = "enemy_"+str(i)
		e.name = info().boss if i==0 else ["Ash guard","Crown scout","Sun sworn","Black pennant"][i%4]
		e.job = job
		e.color = "#ce7771"
		e.level = 1+chapter
		e.xp = 0
		e.hp += chapter*2
		e.pow += chapter
		e.defense += chapter/2
		e.max_hp = e.hp
		e.team = "enemy"
		e.acted = false
		e.boss = i==0
		var p = Vector2i(12,4) if i==0 else positions[i-1]
		while terrain(p) in ["#","~"] or at(p)!=null:
			p.x -= 1
		e.x = p.x
		e.y = p.y
		units.append(e)

func terrain(p: Vector2i) -> String:
	if p.x<0 or p.y<0 or p.x>=14 or p.y>=10: return "#"
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

func can_attack(a: Dictionary,b: Dictionary) -> bool:
	var d = distance(a,b)
	return a.hp>0 and b.hp>0 and a.team!=b.team and d<=a.reach and d>0 and (a.weapon!="bow" or d==2) and a.weapon!="staff"

func forecast(a: Dictionary,b: Dictionary) -> Dictionary:
	var advantage = 0
	var beats = {"sword":"axe","axe":"lance","lance":"sword"}
	if beats.get(a.weapon,"")==b.weapon: advantage=1
	if beats.get(b.weapon,"")==a.weapon: advantage=-1
	var cover = 2 if terrain(pos(b)) in ["f","h","o"] else 0
	var defense = int(b.defense)/2 if a.weapon=="magic" else int(b.defense)
	return {"damage":maxi(1,int(a.pow)+3+advantage-defense-cover),"hit":clampi(85+int(a.speed-b.speed)*2+advantage*15-cover*5,25,100),"crit":clampi(int(a.speed)/2,0,20),"double":a.speed-b.speed>=4,"counter":can_attack(b,a)}

func strike(a: Dictionary,b: Dictionary) -> Dictionary:
	var f = forecast(a,b)
	var hit = (rng.randi_range(0,99)+rng.randi_range(0,99))/2 < f.hit
	var crit = hit and rng.randi_range(0,99)<f.crit
	var damage = mini(int(b.hp),int(f.damage)*(3 if crit else 1)) if hit else 0
	b.hp -= damage
	return {"actor":a.id,"target":b.id,"damage":damage,"crit":crit,"hit":hit,"remaining":b.hp}

func combat(a: Dictionary,b: Dictionary) -> Array:
	if phase not in ["player","enemy"] or a.acted or not can_attack(a,b): return []
	var f = forecast(a,b)
	var result = [strike(a,b)]
	if b.hp>0 and can_attack(b,a): result.append(strike(b,a))
	if a.hp>0 and b.hp>0:
		if f.double: result.append(strike(a,b))
		elif b.speed-a.speed>=4 and can_attack(b,a): result.append(strike(b,a))
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
			var occupant = at(Vector2i(12,4))
			if occupant!=null and occupant.team=="player": return "victory"
	return ""

func finish_chapter():
	for u in units:
		if u.team!="player": continue
		for r in roster:
			if r.id==u.id:
				for key in ["level","xp","max_hp","pow","defense","speed"]:r[key]=u[key]
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
		u.acted=false
		if u.hp>0 and terrain(pos(u)) in ["+","o"]:u.hp=mini(u.max_hp,u.hp+6)

func save_game(path: String,stage: String):
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"version":1,"chapter":chapter,"turn":turn,"phase":phase,"roster":roster,"units":units,"deployed":deployed,"completed":completed,"rng":str(rng.state),"stage":stage}))
	return true

func load_game(path: String) -> String:
	if not FileAccess.file_exists(path):return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or d.get("version")!=1:return ""
	chapter=int(d.chapter);turn=int(d.turn);phase=d.phase;roster=d.roster;units=d.units;deployed=d.deployed;completed=d.completed;rng.state=int(d.rng)
	return d.stage
