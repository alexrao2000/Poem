extends RefCounted
## One small control map blends neighboring ground paintings in world space.
## Water in masonry channels has zero weight, so it cannot stain the land edge.
const PADDING=2
const NATURAL=["river","forest","mountain","road"]
const STONE=["abbey","aqueduct","observatory","furnace","castle","engine"]
const WEIGHTS=[Color(1,0,0,0),Color(0,1,0,0),Color(0,0,1,0),Color(0,0,0,1)]

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
	var control=control_image(game)
	var result=ShaderMaterial.new();result.shader=preload("res://assets/shaders/ground.gdshader")
	result.set_shader_parameter("atlas_texture",atlas)
	result.set_shader_parameter("blend_edges",true)
	result.set_shader_parameter("surface_weights",ImageTexture.create_from_image(control))
	result.set_shader_parameter("control_size",Vector2(control.get_size()))
	result.set_shader_parameter("control_padding",float(PADDING))
	return result
