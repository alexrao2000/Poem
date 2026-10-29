extends Node2D
const Player = preload("res://visuals/sprite_player.gd")
var player = Player.new()
var catalog: RefCounted
var visual_id = ""
var team = "player"
var hp_ratio = 1.0
var spent = false
var selected = false
var flying = false
var last_frame = -1
var sprite: Sprite2D
var clock = 0.0

func setup(value: RefCounted, id: String):
	catalog = value; visual_id = id; player.configure(catalog.assets[id])
	sprite = Sprite2D.new(); sprite.centered = false; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite); update_frame()

func update_frame():
	var frame = player.frame_index()
	if frame == last_frame: return
	last_frame = frame
	sprite.texture = catalog.frame_texture(visual_id, frame)
	var definition = player.asset.frames[frame]
	var scale_value = Vector2(player.asset.logical_frame_px[0]/float(definition.rect[2]), player.asset.logical_frame_px[1]/float(definition.rect[3]))
	sprite.scale = scale_value
	sprite.position = -Vector2(definition.pivot_px[0], definition.pivot_px[1]) * scale_value

func _process(dt):
	clock += dt; player.advance(dt); update_frame()
	sprite.modulate = Color(.70,.72,.73) if spent else Color.WHITE
	sprite.modulate.a = .25 if player.state == "defeated" and player.complete else 1.0
	sprite.position.y = -float(player.asset.frames[player.frame_index()].pivot_px[1]) * sprite.scale.y - (7.0 + sin(clock*4)*2.0 if flying else 0.0)
	queue_redraw()

func _draw():
	var color = Color("7bbbd0") if team == "player" else Color("e88577")
	draw_ellipse_shadow()
	if selected:
		draw_arc(Vector2(0,1), 12, 0, TAU, 32, Color("f2d889"), 1.5)
	if team == "player": draw_colored_polygon(PackedVector2Array([Vector2(-5,3),Vector2(0,6),Vector2(5,3),Vector2(0,0)]),color)
	else: draw_colored_polygon(PackedVector2Array([Vector2(-5,5),Vector2(5,5),Vector2(0,-1)]),color)
	if spent: draw_line(Vector2(-3,3),Vector2(0,5),Color.WHITE,1); draw_line(Vector2(0,5),Vector2(4,0),Color.WHITE,1)
	if hp_ratio < .999:
		draw_rect(Rect2(-11,9,22,3),Color("172b30"));draw_rect(Rect2(-10,10,20*maxf(hp_ratio,0),1),color)

func draw_ellipse_shadow():
	var points = PackedVector2Array()
	for i in range(20): points.append(Vector2(cos(i*TAU/20)*10,sin(i*TAU/20)*3))
	draw_colored_polygon(points, Color(0.05,.12,.12,.35))
