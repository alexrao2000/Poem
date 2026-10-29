extends Node3D
signal visual_cue(id: String, cue_name: String)
const Effect=preload("res://visuals/effect.gd")
const Unit = preload("res://visuals/unit_3d.gd")
const Player = preload("res://visuals/sprite_player.gd")
const JOB_VISUAL = {"Vanguard":"vanguard","Knight":"knight","Ranger":"ranger","Arcanist":"arcanist","Warden":"warden","Rider":"rider","Corsair":"corsair","Duelist":"duelist"}
const TERRAIN = {".":0,"p":1,"~":2,"=":5,"f":0,"h":0,"+":3,"o":3,"#":4}
var catalog: RefCounted
var terrain: Texture2D
var terrain_regions: Array=[]
var game: RefCounted
var actors: Dictionary = {}
var props: Array = []
var occluders: Array = []
var selected_id = ""
var reachable: Dictionary = {}
var route: Array = []
var danger: Dictionary = {}
var cursor = Vector2i(-1,-1)
var show_grid = false
var camera: Camera3D
var overlay: Node3D
var effects: CanvasLayer
var materials: Dictionary = {}

func setup(source: RefCounted, simulation: RefCounted):
	catalog=source;game=simulation;terrain=load("res://visuals/assets/terrain-v1.png")
	terrain_regions=JSON.parse_string(FileAccess.get_file_as_string("res://visuals/data/terrain.json")).regions
	var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("203d40");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("d5e5de");settings.ambient_light_energy=.45;env.environment=settings;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-58,-35,0);sun.light_color=Color("ffe7ba");sun.light_energy=.65;sun.shadow_enabled=true;add_child(sun)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11.0
	var center=Vector3(5.5,0,4.5);camera.position=center+Vector3(0,17,12);add_child(camera);camera.look_at(center);camera.current=true
	for y in game.board_size().y:
		for x in game.board_size().x:
			var cell=Vector2i(x,y);var tile=game.terrain(cell)
			var node=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2.ONE
			node.mesh=plane;node.position=cell_to_world(cell);node.material_override=tile_material(TERRAIN.get(tile,0));add_child(node)
			if tile=="~":node.position.y=-.06
			if tile=="=":
				for z in [-.43,.43]:box(Vector3(x,.17,y+z),Vector3(1,.12,.06),Color("a99468"))
			if tile=="f" and (x+y)%2==0:tree(cell,x%3==0)
			if tile=="o":prop(cell,14,1.5)
			if tile in ["h","+"]:prop(cell,15,1.0)
	house(Vector3(9.5,0,2.2),Color("697e87"));house(Vector3(2,0,7),Color("bb925a"),.72)
	for cell in [Vector2i(4,1),Vector2i(7,8),Vector2i(1,5)]:prop(cell,10,.8)
	overlay=Node3D.new();add_child(overlay);effects=CanvasLayer.new();effects.layer=3;add_child(effects);refresh()

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x,.035 if game.terrain(cell)=="=" else 0.0,cell.y)

func world_to_cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x),roundi(point.z))

func screen_to_cell(point: Vector2) -> Vector2i:
	var hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
	if hit==null:return Vector2i(-1,-1)
	var cell=world_to_cell(hit)
	return cell if cell.x>=0 and cell.y>=0 and cell.x<game.board_size().x and cell.y<game.board_size().y else Vector2i(-1,-1)

func unit_at_screen(point: Vector2) -> String:
	var found="";var front=-INF
	var density=get_viewport().size.y/camera.size/32.0
	for id in actors:
		var actor=actors[id];var foot=camera.unproject_position(actor.position+actor.sprite.position)
		var width=34.0 if actor.visual_id=="unit.rider" else 24.0
		var bounds=Rect2(foot+Vector2(-width*.5,-38)*density,Vector2(width,40)*density)
		if bounds.has_point(point) and foot.y>front:found=id;front=foot.y
	return found

func tile_material(index: int) -> ShaderMaterial:
	if materials.has(index):return materials[index]
	var shader=Shader.new();shader.code="shader_type spatial; render_mode diffuse_lambert; uniform sampler2D atlas : source_color, filter_nearest; uniform vec4 region; void fragment(){ ALBEDO=texture(atlas,region.xy+UV*region.zw).rgb; ROUGHNESS=1.0; }"
	var r=terrain_regions[index];var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("atlas",terrain);material.set_shader_parameter("region",Vector4(r[0]/terrain.get_width(),r[1]/terrain.get_height(),r[2]/terrain.get_width(),r[3]/terrain.get_height()));materials[index]=material;return material

func box(position_value: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size_value;node.mesh=mesh;node.position=position_value
	var material=StandardMaterial3D.new();material.albedo_color=color;material.roughness=1;node.material_override=material;add_child(node);return node

func house(position_value: Vector3, roof_color: Color, size_value=1.0):
	var nodes=[]
	var wall=box(position_value+Vector3(0,.43*size_value,0),Vector3(1.6,.86,1.35)*size_value,Color("dfd2aa"));wall.material_override=tile_material(3);nodes.append(wall)
	var roof=MeshInstance3D.new();var prism=PrismMesh.new();prism.size=Vector3(1.9,.9,1.65)*size_value;roof.mesh=prism;roof.position=position_value+Vector3(0,1.25*size_value,0)
	roof.material_override=tile_material(4 if roof_color.b>roof_color.r else 5);add_child(roof);nodes.append(roof)
	nodes.append(box(position_value+Vector3(0,.28*size_value,.69*size_value),Vector3(.34,.56,.025)*size_value,Color("665841")))
	for dx in [-.5,.5]:nodes.append(box(position_value+Vector3(dx*size_value,.5*size_value,.69*size_value),Vector3(.24,.24,.025)*size_value,Color("546d70")))
	for dx in [-.77,.77]:nodes.append(box(position_value+Vector3(dx*size_value,.42*size_value,.68*size_value),Vector3(.055,.84,.04)*size_value,Color("695a42")))
	nodes.append(box(position_value+Vector3(.5,1.4,-.25)*size_value,Vector3(.22,.85,.25)*size_value,Color("a9a990")))
	occluders.append({"cell":world_to_cell(position_value),"nodes":nodes})

func tree(cell: Vector2i, willow: bool):
	box(cell_to_world(cell)+Vector3(0,.45,0),Vector3(.16,.9,.16),Color("756444"))
	prop(cell,9 if willow else 8,2.2)

func prop(cell: Vector2i, index: int, height: float):
	var node=Sprite3D.new();var atlas=AtlasTexture.new();atlas.atlas=terrain;var r=terrain_regions[index];var size_value=Vector2(r[2],r[3]);atlas.region=Rect2(r[0],r[1],r[2],r[3]);atlas.filter_clip=true
	node.texture=atlas;node.pixel_size=height/size_value.y;node.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;node.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;node.shaded=true;node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.position=cell_to_world(cell)+Vector3(0,height*.375,0);node.set_meta("cell",cell);add_child(node);props.append(node)

func refresh():
	var alive={}
	for unit in game.units:
		if unit.hp<=0:continue
		alive[unit.id]=true
		if not actors.has(unit.id):
			var actor=Unit.new();actor.team=unit.team;actor.setup(catalog,"unit."+JOB_VISUAL.get(unit.job,"vanguard"));add_child(actor);actors[unit.id]=actor
			actor.player.cue.connect(func(cue_name):visual_cue.emit(str(unit.id),cue_name))
		var actor=actors[unit.id];actor.position=cell_to_world(game.pos(unit));actor.spent=unit.acted;actor.hp_ratio=float(unit.hp)/unit.max_hp;actor.selected=unit.id==selected_id;actor.refresh_health()
	for id in actors.keys():
		if not alive.has(id):actors[id].queue_free();actors.erase(id)
	for node in props:
		var obscures=false
		if actors.has(selected_id):
			var cell=node.get_meta("cell");var unit_cell=world_to_cell(actors[selected_id].position)
			obscures=absi(cell.x-unit_cell.x)<=1 and unit_cell.y<=cell.y and cell.y-unit_cell.y<=2
		node.modulate.a=.25 if obscures else 1.0
		node.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED if obscures else SpriteBase3D.ALPHA_CUT_DISCARD
	for entry in occluders:
		var obscures=false
		if actors.has(selected_id):
			var unit_cell=world_to_cell(actors[selected_id].position)
			obscures=absi(entry.cell.x-unit_cell.x)<=1 and unit_cell.y<=entry.cell.y and entry.cell.y-unit_cell.y<=2
		for node in entry.nodes:node.transparency=.72 if obscures else 0.0
	refresh_overlay()

func overlay_material(color: Color) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.no_depth_test=false;return mat

func overlay_tile(cell: Vector2i, color: Color, inset=.05):
	var node=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2.ONE*(1.0-inset);node.mesh=plane;node.position=cell_to_world(cell)+Vector3(0,.025,0);node.material_override=overlay_material(color);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;overlay.add_child(node)

func refresh_overlay():
	for node in overlay.get_children():overlay.remove_child(node);node.queue_free()
	for cell in danger:overlay_tile(cell,Color(.83,.28,.27,.30))
	for cell in reachable:overlay_tile(cell,Color(.25,.65,.80,.32))
	for cell in route:overlay_tile(cell,Color(.95,.86,.59,.75),.78)
	if cursor.x>=0:
		for delta in [Vector3(-.46,0,0),Vector3(.46,0,0),Vector3(0,0,-.46),Vector3(0,0,.46)]:
			var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(.025,.015,.94) if delta.x!=0 else Vector3(.94,.015,.025);node.mesh=mesh;node.position=cell_to_world(cursor)+delta+Vector3(0,.04,0);node.material_override=overlay_material(Color("f6df9a"));overlay.add_child(node)

func animate_route(id: String, path: Array):
	if not actors.has(id) or path.size()<2:return
	var actor=actors[id];actor.position=cell_to_world(path[0])
	for i in range(1,path.size()):
		actor.player.play("move",Player.facing_for_step(path[i]-path[i-1]))
		await create_tween().tween_property(actor,"position",cell_to_world(path[i]),.16).finished
	actor.player.play("idle")

func play_action(id: String, target_id: String, reduced=false):
	if not actors.has(id):return
	var actor=actors[id];var direction="east"
	if actors.has(target_id):direction=Player.facing_for_step(world_to_cell(actors[target_id].position)-world_to_cell(actor.position))
	actor.player.play("act",direction,true)
	if reduced:actor.player.skip();actor.player.play("idle");return
	var home=actor.position;var step=Vector3(.14 if direction=="east" else -.14 if direction=="west" else 0,0,.14 if direction=="south" else -.14 if direction=="north" else 0)
	var tween=create_tween();tween.tween_property(actor,"position",home+step,.12);tween.tween_property(actor,"position",home,.16)
	await actor.player.finished
	if tween.is_running():tween.kill()
	actor.position=home;actor.player.play("idle")

func play_hurt(id: String, defeated=false):
	if not actors.has(id):return
	actors[id].player.play("defeated" if defeated else "hurt","",true);await actors[id].player.finished
	if actors.has(id) and not defeated:actors[id].player.play("idle")

func skip_animations():
	for actor in actors.values():actor.player.skip()

func feedback(source_id: String, target_id: String, caption: String, kind: String, reduced=false):
	if not actors.has(target_id):return
	var effect=Effect.new();var destination=camera.unproject_position(actors[target_id].position+Vector3.UP*.7)
	var start=camera.unproject_position(actors[source_id].position+Vector3.UP*.7) if actors.has(source_id) else destination
	effect.setup(start,destination,caption,kind,reduced);effects.add_child(effect)
