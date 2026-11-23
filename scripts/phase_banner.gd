extends Control
# Brief original phase ribbon with feathered edges. The caller owns input
# locks and turn changes; a shared alpha mask keeps the heading region opaque.
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
static var edge_mask: GradientTexture2D
var enemy=false
var motion: Tween
var heading: Label
var detail: Label
var resting=Vector2.ZERO
var slide_offset=0.0:
 set(value):slide_offset=value;place()

func configure(parent: Control,side: String,turn: int):
 name="PhaseBanner";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=25;enemy=side=="enemy"
 parent.add_child(self)
 heading=Label.new();heading.text="ENEMY PHASE" if enemy else "PLAYER PHASE"
 heading.add_theme_font_override("font",FONT);heading.add_theme_font_size_override("font_size",50)
 heading.add_theme_color_override("font_color",Color("fff2d4"));heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
 detail=Label.new();detail.text="TURN %02d"%turn;detail.add_theme_font_size_override("font_size",18)
 detail.add_theme_color_override("font_color",Color("d9c795"));detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(detail)
 parent.resized.connect(arrange);arrange()

func arrange():
 if get_parent()==null:return
 size=Vector2(get_parent().size.x,144);resting=Vector2(0,get_parent().size.y*.42-72)
 heading.position=Vector2(80,22);heading.size=Vector2(size.x-160,65)
 detail.position=Vector2(80,94);detail.size=Vector2(size.x-160,25)
 place();queue_redraw()

func place():position=resting+Vector2(slide_offset*size.x,0)

static func ribbon_mask() -> GradientTexture2D:
 if edge_mask!=null:return edge_mask
 var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.18,.82,1])
 gradient.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)])
 edge_mask=GradientTexture2D.new();edge_mask.width=512;edge_mask.height=1;edge_mask.gradient=gradient
 edge_mask.fill_from=Vector2.ZERO;edge_mask.fill_to=Vector2.RIGHT
 return edge_mask

func _draw():
 var w=size.x;var h=size.y
 var uv=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
 draw_colored_polygon(PackedVector2Array([Vector2(0,10),Vector2(w,0),Vector2(w,h-10),Vector2(0,h)]),Color(.28,.12,.17,.95) if enemy else Color(.07,.20,.30,.95),uv,ribbon_mask())
 draw_colored_polygon(PackedVector2Array([Vector2(0,10),Vector2(w,0),Vector2(w,2),Vector2(0,12)]),Color("bea473"),uv,ribbon_mask())
 draw_colored_polygon(PackedVector2Array([Vector2(0,h-2),Vector2(w,h-12),Vector2(w,h-10),Vector2(0,h)]),Color("bea473"),uv,ribbon_mask())
 for side in [-1,1]:
  var x=w*.5+side*235
  draw_line(Vector2(x+side*26,69),Vector2(x+side*125,69),Color("a49b80"),1,true)
  draw_polyline(PackedVector2Array([Vector2(x,48),Vector2(x+side*16,69),Vector2(x,90),Vector2(x-side*16,69),Vector2(x,48)]),Color("dcc38c"),2,true)

func play(cancelled: Callable):
 var direction=-1.0 if not enemy else 1.0
 slide_offset=direction
 motion=create_tween()
 motion.tween_property(self,"slide_offset",0.0,.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 motion.tween_interval(.36)
 motion.tween_property(self,"slide_offset",-direction,.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 while motion.is_running():
  if cancelled.call():motion.kill();break
  await get_tree().process_frame
 hide()
