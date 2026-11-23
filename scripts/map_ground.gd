extends RefCounted
## One control map blends edge-matched ground paintings in world space.
## Water in masonry channels has zero weight, so it cannot stain the land edge.
const PADDING=2
const NATURAL=["river","forest","mountain","road"]
const STONE=["abbey","aqueduct","observatory","furnace","castle","engine"]
const CONTINUOUS_ARENAS=["village","forest","mountain","road"]
const ARENA_CONTROL_RADIUS=Vector2i(16,6)
const WEIGHTS=[Color(1,0,0,0),Color(0,1,0,0),Color(0,0,1,0),Color(0,0,0,1)]
static var arena_controls: Dictionary={}

static func surface_for(symbol: String,theme: String) -> int:
	if symbol in ["~","="]:return 2 if theme in NATURAL else -1
	if symbol in ["o","+","p"]:return 3 if theme in ["observatory","engine","furnace"] else 1
	if symbol=="h":return 2
	return 3 if theme in STONE else 0

static func control_image(game) -> Image:
	var board=game.board_size();var theme=game.info().get("environment","village")
	var control=Image.create(board.x+PADDING*2,board.y+PADDING*2,false,Image.FORMAT_RGBA8)
	control.fill(WEIGHTS[0])
	for y in range(board.y):
		for x in range(board.x):
			var surface=surface_for(game.terrain(Vector2i(x,y)),theme)
			control.set_pixel(x+PADDING,y+PADDING,Color(0,0,0,0) if surface<0 else WEIGHTS[surface])
	return control

static func material(game,atlas: Texture2D) -> ShaderMaterial:
	return blended_material(atlas,ImageTexture.create_from_image(control_image(game)),float(PADDING))

static func arena_control_image(surface: int) -> Image:
	var size=ARENA_CONTROL_RADIUS*2+Vector2i.ONE
	var control=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	for row in size.y:
		for column in size.x:
			var x=float(column-ARENA_CONTROL_RADIUS.x)
			var z=float(row-ARENA_CONTROL_RADIUS.y)
			var bend=.52*sin(x*.31+.4)
			var width=2.40+.32*cos(x*.63)
			var shoulder=absf(z-bend)-width+.23*sin(x*1.37+z*.81)
			var coverage=(1-smoothstep(-.7,1.4,shoulder))*(1-smoothstep(9,15,absf(x)))
			control.set_pixel(column,row,WEIGHTS[0].lerp(WEIGHTS[surface],coverage))
	return control

static func arena_material(surface: int,center: Vector3,atlas: Texture2D) -> ShaderMaterial:
	if not arena_controls.has(surface):
		arena_controls[surface]=ImageTexture.create_from_image(arena_control_image(surface))
	var result=blended_material(atlas,arena_controls[surface],0.0)
	result.set_shader_parameter("control_origin",Vector2(center.x,center.z)-Vector2(ARENA_CONTROL_RADIUS))
	return result

static func blended_material(atlas: Texture2D,control: Texture2D,padding: float) -> ShaderMaterial:
	var result=ShaderMaterial.new();result.shader=preload("res://assets/shaders/ground.gdshader")
	result.set_shader_parameter("atlas_texture",atlas)
	result.set_shader_parameter("blend_edges",true)
	result.set_shader_parameter("wang_enabled",true)
	result.set_shader_parameter("wang_scale",float(atlas.get_width())/512.0)
	result.set_shader_parameter("wang_texture",load("res://assets/art/terrain-wang.png"))
	result.set_shader_parameter("surface_weights",control)
	result.set_shader_parameter("control_size",Vector2(control.get_size()))
	result.set_shader_parameter("control_padding",padding)
	return result
