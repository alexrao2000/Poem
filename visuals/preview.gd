## Runs after copying only visuals/ into a clean Godot 4 project.

extends Control
const Catalog=preload("res://visuals/catalog.gd")
const Model=preload("res://visuals/preview_model.gd")
const Map2D=preload("res://visuals/map_2d.gd")
const Map3D=preload("res://visuals/map_3d.gd")
var catalog=Catalog.new()
var model=Model.new()
var viewport: SubViewport
var view: TextureRect
var renderer
var mode="2d"
var status: Label

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not catalog.open("res://visuals/units.json"):push_error(str(catalog.errors));return
	var background=ColorRect.new();background.color=Color("142a2e");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var header=HBoxContainer.new();header.position=Vector2(24,18);add_child(header)
	for value in ["2d","3d"]:
		var button=Button.new();button.text="  "+value.to_upper()+" MAP  ";button.pressed.connect(func():set_mode(value));header.add_child(button)
	for state in ["idle","move","act","hurt","defeated"]:
		var button=Button.new();button.text="  "+state.capitalize()+"  ";button.pressed.connect(func():
			for actor in renderer.actors.values():actor.player.play(state,"south",true))
		header.add_child(button)
	status=Label.new();status.position=Vector2(24,66);status.text="Eight original sprite classes · Four directions · Two map renderers\nPortable preview. Campaign rules and UI are supplied by the receiving project.";add_child(status)
	viewport=SubViewport.new();viewport.size=Vector2i(512,344);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	view=TextureRect.new();view.texture=viewport.get_texture();view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(view)
	resized.connect(layout_view);call_deferred("layout_view");set_mode("2d")

func layout_view():
	var area=size-Vector2(40,130);var factor=maxi(1,floori(minf(area.x/512,area.y/344)))
	view.size=Vector2(512,344)*factor;view.position=Vector2((size.x-view.size.x)*.5,116+(size.y-126-view.size.y)*.5).floor()

func set_mode(value: String):
	mode=value
	if renderer!=null:viewport.remove_child(renderer);renderer.queue_free()
	renderer=Map2D.new() if mode=="2d" else Map3D.new();viewport.add_child(renderer);renderer.setup(catalog,model)
	renderer.selected_id="sample_0";renderer.refresh()
