extends Control
# Shared directional weapon advantage marker for forecast and combat HUD.
# Values are supplied by the rules; this control only draws their sign.

var advantage=0
func _draw():
 if advantage==0:return
 var sign_value=1.0 if advantage>0 else -1.0
 var center=size*.5
 var points=PackedVector2Array([center+Vector2(0,-7*sign_value),center+Vector2(7,5*sign_value),center+Vector2(-7,5*sign_value)])
 draw_colored_polygon(points,Color("64a174") if advantage>0 else Color("b86364"))
 points.append(points[0]);draw_polyline(points,Color("34444a"),1.2,true)
