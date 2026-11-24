extends Control

const SpritePlayer = preload("res://visuals/sprite_player.gd")

var player = SpritePlayer.new()
var catalog: RefCounted
var visual_id: String
var frame_bounds: Rect2

func configure(source: RefCounted, unit: Dictionary):
	catalog = source
	visual_id = catalog.asset_id_for(unit)
	player.configure(catalog.assets[visual_id])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(80, 80)
	if unit.team == "enemy" and not visual_id.begins_with("enemy."):
		self_modulate = Color(1, .72, .68)
	var frames: Array = player.clip().frames
	frame_bounds = frame_rect(int(frames[0]))
	for index in frames:
		frame_bounds = frame_bounds.merge(frame_rect(int(index)))

func frame_rect(index: int) -> Rect2:
	var frame: Dictionary = player.asset.frames[index]
	var pixels = Vector2(frame.rect[2], frame.rect[3])
	var pixel_scale = catalog.frame_scale(player.asset, frame)
	return Rect2(-Vector2(frame.pivot_px[0], frame.pivot_px[1]) * pixel_scale, pixels * pixel_scale)

func _process(delta: float):
	var previous = player.frame_index()
	player.advance(delta)
	if player.frame_index() != previous:
		queue_redraw()

func display_frame_rect(frame: int) -> Rect2:
	var available = size - Vector2(8, 8)
	var ratio = minf(available.x / frame_bounds.size.x, available.y / frame_bounds.size.y)
	var origin = size * .5 - frame_bounds.get_center() * ratio
	var rect = frame_rect(frame)
	return Rect2(origin + rect.position * ratio, rect.size * ratio)

func _draw():
	var frame = player.frame_index()
	draw_texture_rect(catalog.frame_texture(visual_id, frame), display_frame_rect(frame), false)
