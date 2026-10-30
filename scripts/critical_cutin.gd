extends Control
# A fast eye-level portrait slash leaves the arena and HP visible. Streaks and
# crops use fixed authored values; this accent never owns combat outcomes.
var landing=Vector2.ZERO
var slide: Tween
var accent=Color("d8bd7d")
var streaks: Control

class StreakLayer extends Control:
 var accent=Color("d8bd7d")
 var direction=1.0
 var phase=0.0:
  set(value):phase=value;queue_redraw()
 func _draw():
  for i in range(22):
   var y=12+fposmod(i*23.17,size.y-24)
   var x=fposmod(i*137.3+phase*direction*size.x*.8,size.x+240)-120
   var length=65+(i%5)*29
   var color=accent;color.a=.08+(i%3)*.035
   draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+length,y-2),Vector2(x+length+28,y+1),Vector2(x+18,y+2)]),color)

func configure(parent: Control,unit: Dictionary,portrait: Texture2D,quote: String):
 name="CriticalCutin";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=20
 parent.add_child(self)
 size=Vector2(parent.size.x,156)
 landing=Vector2(0,maxf(78,parent.size.y*.23));position=landing;clip_contents=true
 var enemy=unit.team=="enemy"
 accent=Color("dc9684") if enemy else Color("d8bd7d")
 streaks=StreakLayer.new();streaks.name="Streaks";streaks.size=size;streaks.accent=accent;streaks.direction=-1.0 if enemy else 1.0
 streaks.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(streaks)
 var text_start=42.0;var text_width=size.x-84
 if portrait!=null:
  var face=TextureRect.new();face.name="Portrait";face.texture=portrait;face.flip_h=enemy
  face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  var width=minf(650,size.x*.52)
  face.position=Vector2(size.x-width-16 if enemy else 16.0,8);face.size=Vector2(width,140)
  face.material=ShaderMaterial.new();face.material.shader=preload("res://assets/shaders/critical-portrait.gdshader");face.material.set_shader_parameter("panel_size",face.size)
  face.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(face)
  text_start=32.0 if enemy else width+36;text_width=size.x-width-68
 var heading=Label.new();heading.name="Heading";heading.text="CRITICAL  /  "+unit.name.to_upper()
 heading.position=Vector2(text_start,22);heading.size=Vector2(text_width,28)
 heading.add_theme_font_size_override("font_size",20);heading.add_theme_color_override("font_color",accent)
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
 var line=Label.new();line.name="Quote";line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 line.text=quote;line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 line.position=Vector2(text_start,55);line.size=Vector2(text_width,80)
 line.add_theme_font_size_override("font_size",30);line.add_theme_color_override("font_color",Color("fff6df"))
 line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)
 queue_redraw()

func _draw():
 var w=size.x;var h=size.y
 draw_colored_polygon(PackedVector2Array([Vector2(0,8),Vector2(w-26,0),Vector2(w,h-8),Vector2(26,h)]),Color("182638"))
 draw_line(Vector2(0,8),Vector2(w-26,0),accent,2,true)
 draw_line(Vector2(26,h),Vector2(w,h-8),accent,2,true)

func play(cancelled: Callable,from_right=false):
 var direction=1.0 if from_right else -1.0
 position.x=landing.x+direction*(get_parent().size.x+size.x)*.5
 slide=create_tween()
 slide.tween_property(self,"position:x",landing.x,.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 slide.parallel().tween_property(streaks,"phase",.15,.09)
 slide.tween_property(streaks,"phase",.70,.34)
 slide.tween_property(self,"position:x",landing.x-direction*(get_parent().size.x+size.x)*.5,.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
 slide.parallel().tween_property(streaks,"phase",1.0,.10)
 while slide.is_running():
  if cancelled.call():slide.kill();break
  await get_tree().process_frame
 hide()
