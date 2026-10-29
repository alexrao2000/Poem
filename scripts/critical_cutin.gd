extends Control
# Original portrait accent over 3D combat; it never owns damage or turn state.
var landing=Vector2.ZERO
var slide: Tween
var accent=Color("d8bd7d")

func configure(parent: Control,unit: Dictionary,portrait: Texture2D,quote: String):
 name="CriticalCutin";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=20
 parent.add_child(self)
 size=Vector2(minf(parent.size.x*.78,1020),174)
 landing=Vector2((parent.size.x-size.x)*.5,maxf(78,parent.size.y*.23))
 position=landing
 var enemy=unit.team=="enemy"
 accent=Color("dc9684") if enemy else Color("d8bd7d")
 var text_start=42.0
 if portrait!=null:
  var crop=AtlasTexture.new();crop.atlas=portrait
  crop.region=Rect2(0,portrait.get_height()*.04,portrait.get_width(),portrait.get_height()*.58);crop.filter_clip=true
  var face=TextureRect.new();face.name="Portrait";face.texture=crop
  face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  face.position=Vector2(20,12);face.size=Vector2(270,150)
  face.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(face);text_start=312
 var heading=Label.new();heading.name="Heading";heading.text="CRITICAL  /  "+unit.name.to_upper()
 heading.position=Vector2(text_start,24);heading.size=Vector2(size.x-text_start-42,30)
 heading.add_theme_font_size_override("font_size",20);heading.add_theme_color_override("font_color",accent)
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
 var line=Label.new();line.name="Quote";line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 line.text=quote;line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 line.position=Vector2(text_start,61);line.size=Vector2(size.x-text_start-42,85)
 line.add_theme_font_size_override("font_size",32);line.add_theme_color_override("font_color",Color("fff6df"))
 line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)
 queue_redraw()

func _draw():
 var w=size.x;var h=size.y
 draw_colored_polygon(PackedVector2Array([Vector2(0,12),Vector2(w-26,0),Vector2(w,h-12),Vector2(26,h)]),Color("1d2b3d"))
 draw_polyline(PackedVector2Array([Vector2(0,12),Vector2(w-26,0),Vector2(w,h-12)]),accent,2,true)
 draw_polyline(PackedVector2Array([Vector2(0,12),Vector2(26,h),Vector2(w,h-12)]),accent,2,true)

func play(cancelled: Callable,from_right=false):
 var direction=1.0 if from_right else -1.0
 position.x=landing.x+direction*(get_parent().size.x+size.x)*.5
 slide=create_tween()
 slide.tween_property(self,"position:x",landing.x,.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 slide.tween_interval(.42)
 slide.tween_property(self,"position:x",landing.x-direction*(get_parent().size.x+size.x)*.5,.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
 while slide.is_running():
  if cancelled.call():slide.kill();break
  await get_tree().process_frame
 hide()
