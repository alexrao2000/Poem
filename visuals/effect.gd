## Pixel-aligned cosmetic feedback; never owns hits, HP, or turn timing.

extends Node2D
var from_position=Vector2.ZERO
var target_position=Vector2.ZERO
var text=""
var kind="impact"
var elapsed=0.0
var reduced=false
var label: Label

func setup(start: Vector2, destination: Vector2, caption: String, type: String, reduce=false):
	from_position=start.round();target_position=destination.round();text=caption;kind=type;reduced=reduce
	label=Label.new();label.text=text;label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",Color("a7e6be") if kind=="heal" else Color("fff1bd"));label.add_theme_color_override("font_outline_color",Color("152c32"));label.add_theme_constant_override("outline_size",4);label.position=target_position+Vector2(-10,-25);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label)
	z_index=100

func _process(dt):
	elapsed+=dt
	var travel=.18 if kind=="projectile" and not reduced else 0.0
	label.visible=elapsed>=travel
	label.position.y=target_position.y-25-(minf(maxf(elapsed-travel,0)*18,10) if not reduced else 0.0)
	label.modulate.a=clampf((.8+travel-elapsed)*3,0,1)
	queue_redraw()
	if elapsed>.8+travel:queue_free()

func _draw():
	var travel=.18 if kind=="projectile" and not reduced else 0.0
	if elapsed<travel:
		var point=from_position.lerp(target_position,elapsed/travel).round()
		draw_line(point-Vector2(6,0),point,Color("e7d8a3"),2);draw_rect(Rect2(point-Vector2.ONE*2,Vector2.ONE*4),Color("bcecf2"));return
	if kind=="miss":return
	var age=elapsed-travel
	if age>.28 or reduced:return
	var color=Color("a7e6be") if kind=="heal" else Color("fff1bd")
	for i in range(6):
		var angle=i*TAU/6
		var point=target_position+Vector2(cos(angle),sin(angle))*(3+age*24)
		draw_rect(Rect2(point.round()-Vector2.ONE,Vector2.ONE*2),color)
