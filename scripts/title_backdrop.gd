extends "res://scripts/painted_backdrop.gd"
## The original dawn painting fills the title without stretching. A tiny slow
## drift stays within overscan; the covered 3D scene is hidden until departure.
const ART=preload("res://assets/art/title-dawn-v1.png")
var elapsed=0.0

func configure(host: Control,scene_nodes: Array):
 name="TitleBackdrop";super.configure(host,scene_nodes)

static func framing(dimensions: Vector2,time: float) -> Rect2:
 var source=Vector2(ART.get_width(),ART.get_height())
 var scale_value=maxf(dimensions.x/source.x,dimensions.y/source.y)*1.03
 var extent=source*scale_value
 var drift=Vector2(sin(time*.07),cos(time*.05))*dimensions*.004
 return Rect2((dimensions-extent)*.5+drift,extent)

func _process(dt):
 if not is_visible_in_tree():return
 elapsed+=dt;queue_redraw()

func _draw():draw_texture_rect(ART,framing(size,elapsed),false)
