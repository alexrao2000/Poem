extends Node2D
signal visual_cue(id: String, cue_name: String)
const Effect=preload("res://visuals/effect.gd")
const Unit = preload("res://visuals/unit_2d.gd")
const Player = preload("res://visuals/sprite_player.gd")
const TILE = 32
const OFFSET = Vector2(64, 23)
const TERRAIN = {".":0,"p":1,"~":2,"=":5,"f":0,"h":0,"+":3,"o":3,"#":4}
const JOB_VISUAL = {"Vanguard":"vanguard","Knight":"knight","Ranger":"ranger","Arcanist":"arcanist","Warden":"warden","Rider":"rider","Corsair":"corsair","Duelist":"duelist"}
var catalog: RefCounted
var terrain: Texture2D
var terrain_regions: Array=[]
var game: RefCounted
var actors: Dictionary = {}
var props: Array = []
var selected_id = ""
var reachable: Dictionary = {}
var route: Array = []
var danger: Dictionary = {}
var cursor = Vector2i(-1,-1)
var show_grid = false
var clock = 0.0

func setup(source: RefCounted, simulation: RefCounted):
	catalog=source;game=simulation;y_sort_enabled=true
	terrain=load("res://visuals/assets/terrain-v1.png")
	terrain_regions=JSON.parse_string(FileAccess.get_file_as_string("res://visuals/data/terrain.json")).regions
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	build_props();refresh()

func cell_to_world(cell: Vector2i) -> Vector2:
	return OFFSET+Vector2(cell)*TILE+Vector2.ONE*TILE*.5

func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x-OFFSET.x)/TILE),floori((point.y-OFFSET.y)/TILE))

func screen_to_cell(point: Vector2) -> Vector2i:
	var cell=world_to_cell(point)
	return cell if cell.x>=0 and cell.y>=0 and cell.x<game.board_size().x and cell.y<game.board_size().y else Vector2i(-1,-1)

func unit_at_screen(point: Vector2) -> String:
	var found="";var front=-INF
	for id in actors:
		var actor=actors[id];var width=34.0 if actor.visual_id=="unit.rider" else 24.0
		var bounds=Rect2(actor.position+Vector2(-width*.5,-38),Vector2(width,40))
		if bounds.has_point(point) and actor.position.y>front:found=id;front=actor.position.y
	return found

func asset_region(index: int) -> Rect2:
	var r=terrain_regions[index]
	return Rect2(r[0],r[1],r[2],r[3])

func prop(cell: Vector2i, index: int, size: Vector2):
	var node=Sprite2D.new();node.texture=terrain;node.region_enabled=true;node.region_rect=asset_region(index)
	node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;node.centered=false
	node.position=cell_to_world(cell);node.offset=Vector2(-node.region_rect.size.x*.5,-node.region_rect.size.y*.875)
	node.scale=size/node.region_rect.size;node.set_meta("cell",cell)
	add_child(node);props.append(node)

func build_props():
	for y in game.board_size().y:
		for x in game.board_size().x:
			var cell=Vector2i(x,y);var tile=game.terrain(cell)
			if tile=="f" and (x+y)%2==0:prop(cell,8 if x%3 else 9,Vector2(60,68))
			if tile=="h" or tile=="+":prop(cell,15,Vector2(32,32))
			if tile=="o":prop(cell,14,Vector2(38,48))
	prop(Vector2i(9,2),12,Vector2(76,76));prop(Vector2i(2,7),13,Vector2(58,58))
	for cell in [Vector2i(4,1),Vector2i(7,8),Vector2i(1,5)]:prop(cell,10,Vector2(28,26))

func refresh():
	var alive={}
	for unit in game.units:
		if unit.hp<=0:continue
		alive[unit.id]=true
		if not actors.has(unit.id):
			var actor=Unit.new();actor.team=unit.team;actor.setup(catalog,"unit."+JOB_VISUAL.get(unit.job,"vanguard"));add_child(actor);actors[unit.id]=actor
			actor.player.cue.connect(func(cue_name):visual_cue.emit(str(unit.id),cue_name))
		var actor=actors[unit.id]
		actor.position=cell_to_world(game.pos(unit));actor.spent=unit.acted;actor.hp_ratio=float(unit.hp)/unit.max_hp;actor.selected=unit.id==selected_id
	for id in actors.keys():
		if not alive.has(id):actors[id].queue_free();actors.erase(id)
	for node in props:
		var obscures=false
		if actors.has(selected_id):
			var delta=actors[selected_id].position-node.position
			obscures=absf(delta.x)<22 and delta.y<3 and delta.y> -44
		node.modulate.a=.3 if obscures else 1.0
	queue_redraw()

func _process(dt):
	clock+=dt;queue_redraw()

func _draw():
	if game==null or terrain==null:return
	draw_rect(Rect2(0,0,512,344),Color("203d40"))
	draw_rect(Rect2(OFFSET-Vector2(3,3),Vector2(game.board_size())*TILE+Vector2(6,6)),Color("233f3f"))
	for y in game.board_size().y:
		for x in game.board_size().x:
			var cell=Vector2i(x,y);var tile=game.terrain(cell);var rect=Rect2(OFFSET+Vector2(cell)*TILE,Vector2.ONE*TILE)
			draw_texture_rect_region(terrain,rect,asset_region(TERRAIN.get(tile,0)))
			if tile=="~":
				var shift=sin(clock*1.5+x*.7+y)*3
				draw_line(rect.position+Vector2(7+shift,12),rect.position+Vector2(15+shift,12),Color(.60,.86,.80,.25),1)
			if tile!="~" and x in [4,7] and game.terrain(Vector2i(5,y))=="~":
				draw_texture_rect_region(terrain,rect,asset_region(6 if x==4 else 7))
			if show_grid:draw_rect(rect,Color(.1,.25,.26,.15),false,1)
			if danger.has(cell):
				draw_rect(rect.grow(-1),Color(.83,.28,.27,.20));draw_line(rect.position+Vector2(3,29),rect.position+Vector2(29,3),Color(.90,.46,.40,.4),1)
			if reachable.has(cell):draw_rect(rect.grow(-1),Color(.25,.65,.80,.26));draw_rect(rect.grow(-1),Color(.64,.86,.90,.5),false,1)
	for i in range(1,route.size()):draw_line(cell_to_world(route[i-1]),cell_to_world(route[i]),Color("f3df9b"),2)
	if route.size()>1:draw_circle(cell_to_world(route[-1]),3,Color("f3df9b"))
	if cursor.x>=0:
		var rect=Rect2(OFFSET+Vector2(cursor)*TILE,Vector2.ONE*TILE).grow(-1)
		draw_rect(rect,Color("f6df9a"),false,1.5)

func animate_route(id: String, path: Array):
	if not actors.has(id) or path.size()<2:return
	var actor=actors[id]
	actor.position=cell_to_world(path[0])
	for i in range(1,path.size()):
		actor.player.play("move",Player.facing_for_step(path[i]-path[i-1]))
		await create_tween().tween_property(actor,"position",cell_to_world(path[i]),.16).finished
	actor.player.play("idle")

func play_action(id: String, target_id: String, reduced=false):
	if not actors.has(id):return
	var actor=actors[id]
	var direction="east"
	if actors.has(target_id):direction=Player.facing_for_step(world_to_cell(actors[target_id].position)-world_to_cell(actor.position))
	actor.player.play("act",direction,true)
	if reduced:actor.player.skip();actor.player.play("idle");return
	var home=actor.position;var offset=Vector2(5 if direction=="east" else -5 if direction=="west" else 0,5 if direction=="south" else -5 if direction=="north" else 0)
	var tween=create_tween();tween.tween_property(actor,"position",home+offset,.12);tween.tween_property(actor,"position",home,.16)
	await actor.player.finished
	if tween.is_running():tween.kill()
	actor.position=home
	actor.player.play("idle")

func play_hurt(id: String, defeated=false):
	if not actors.has(id):return
	actors[id].player.play("defeated" if defeated else "hurt","",true)
	await actors[id].player.finished
	if actors.has(id) and not defeated:actors[id].player.play("idle")

func skip_animations():
	for actor in actors.values():actor.player.skip()

func feedback(source_id: String, target_id: String, caption: String, kind: String, reduced=false):
	if not actors.has(target_id):return
	var effect=Effect.new();var destination=actors[target_id].position-Vector2(0,20)
	var start=actors[source_id].position-Vector2(0,20) if actors.has(source_id) else destination
	effect.setup(start,destination,caption,kind,reduced);add_child(effect)
