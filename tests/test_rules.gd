extends SceneTree
const Rules = preload("res://scripts/rules.gd")
var checks=0
func verify(condition,message):
	checks+=1
	if not condition:
		push_error(message)
		quit(1)
func _initialize():
	var g=Rules.new()
	verify(g.roster.size()==24,"24 characters")
	verify(g.content.chapters.size()==12,"12 chapters")
	for chapter in range(12):
		g.chapter=chapter
		g.deployed=[]
		for u in g.available().slice(0,6):g.deployed.append(u.id)
		g.start_battle()
		verify(g.living("player").size()>=4,"Deploy party")
		var positions={}
		for u in g.units:
			verify(not positions.has(g.pos(u)),"No overlapping spawns chapter "+str(chapter))
			positions[g.pos(u)]=true
			verify(g.terrain(g.pos(u)) not in ["~","#"],"Valid spawn")
		# Check terrain connectivity to every objective and spawn, ignoring occupants.
		var reached={Vector2i(1,3):true};var queue=[Vector2i(1,3)]
		while not queue.is_empty():
			var p=queue.pop_front()
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var q=p+d
				if not reached.has(q) and g.terrain(q) not in ["~","#"]:reached[q]=true;queue.append(q)
		verify(reached.has(Vector2i(12,4)),"Objective reachable")
		for u in g.units:verify(reached.has(g.pos(u)),"Unit reachable")
		for u in g.living("enemy"):u.hp=0
		if g.info().objective=="seize":g.units[0].x=12;g.units[0].y=4
		verify(g.result()=="victory","Victory for chapter "+str(chapter))
		g.finish_chapter()
	verify(g.completed,"Campaign ending")
	g.new_campaign();g.start_battle()
	var a=g.units[0];var b=g.living("enemy")[0]
	a.x=8;a.y=4;b.x=9;b.y=4
	var before=g.rng.state
	var forecast=g.forecast(a,b)
	verify(g.rng.state==before,"Forecast does not consume RNG")
	verify(g.save_game("/private/tmp/ashen-test-save.json","battle"),"Save success")
	var results=g.combat(a,b)
	verify(not results.is_empty(),"Combat generates events")
	var copy=Rules.new()
	verify(copy.load_game("/private/tmp/ashen-test-save.json")=="battle","Load stage")
	var results2=copy.combat(copy.units[0],copy.living("enemy")[0])
	verify(JSON.stringify(results)==JSON.stringify(results2),"Save preserves RNG and outcomes")
	verify(g.combat(a,b).is_empty(),"No second action")
	g.new_campaign();g.start_battle()
	for u in g.living("player"):u.hp=0
	verify(g.result()=="defeat","Defeat path")
	g.chapter=2;g.start_battle();g.turn=6
	verify(g.result()=="","Survive must finish enemy phase")
	g.next_player_turn();verify(g.result()=="victory","Survival completion")
	print("PASS: ",checks," campaign, combat, connectivity and persistence assertions")
	quit()
