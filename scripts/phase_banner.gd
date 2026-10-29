extends Control
# Brief original phase ribbon. The caller owns input locks and turn changes.
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
var enemy=false
var motion: Tween
var heading: Label
var detail: Label
var resting=Vector2.ZERO

func configure(parent: Control,side: String,turn: int):
 name="PhaseBanner";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=25;enemy=side=="enemy"
 parent.add_child(self);size=Vector2(parent.size.x,144);resting=Vector2(0,parent.size.y*.42-72);position=resting
 heading=Label.new();heading.text="ENEMY PHASE" if enemy else "PLAYER PHASE"
 heading.add_theme_font_override("font",FONT);heading.add_theme_font_size_override("font_size",50)
 heading.add_theme_color_override("font_color",Color("fff2d4"));heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 heading.position=Vector2(80,22);heading.size=Vector2(size.x-160,65);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
 detail=Label.new();detail.text="TURN %02d"%turn;detail.add_theme_font_size_override("font_size",18)
 detail.add_theme_color_override("font_color",Color("d9c795"));detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 detail.position=Vector2(80,94);detail.size=Vector2(size.x-160,25);detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(detail)
 queue_redraw()

func _draw():
 var w=size.x;var h=size.y
 draw_colored_polygon(PackedVector2Array([Vector2(0,10),Vector2(w,0),Vector2(w,h-10),Vector2(0,h)]),Color(.28,.12,.17,.95) if enemy else Color(.07,.20,.30,.95))
 draw_line(Vector2(0,10),Vector2(w,0),Color("bea473"),2,true)
 draw_line(Vector2(0,h),Vector2(w,h-10),Color("bea473"),2,true)
 for side in [-1,1]:
  var x=w*.5+side*235
  draw_line(Vector2(x+side*26,69),Vector2(x+side*125,69),Color("a49b80"),1,true)
  draw_polyline(PackedVector2Array([Vector2(x,48),Vector2(x+side*16,69),Vector2(x,90),Vector2(x-side*16,69),Vector2(x,48)]),Color("dcc38c"),2,true)

func play(cancelled: Callable):
 var direction=-1.0 if not enemy else 1.0
 position.x=direction*size.x
 motion=create_tween()
 motion.tween_property(self,"position:x",0.0,.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 motion.tween_interval(.36)
 motion.tween_property(self,"position:x",-direction*size.x,.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 while motion.is_running():
  if cancelled.call():motion.kill();break
  await get_tree().process_frame
 hide()
