extends Control
## A brief chapter heading over the actual battlefield. Presentation never
## owns campaign state; the caller locks commands and starts the player phase.
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
var motion: Tween
var heading: Label
var title: Label
var place: Label
var hint: Label
var skip_requested=false

func label(text: String,font_size: int,color: Color) -> Label:
 var result=Label.new();result.text=text;result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 result.add_theme_font_override("font",FONT);result.add_theme_font_size_override("font_size",font_size)
 result.add_theme_color_override("font_color",color);result.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(result)
 return result

func configure(host: Control,chapter: int,chapter_title: String,location: String):
 name="ChapterCard";z_index=26;mouse_filter=Control.MOUSE_FILTER_STOP
 host.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 heading=label("CHAPTER %02d"%[chapter+1],19,Color("d8c18c"))
 title=label(chapter_title,46,Color("fff3d8"));title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 place=label(location,24,Color("d6dbe0"))
 hint=label("Click or press Tab to continue",16,Color("e8dfc6"))
 gui_input.connect(func(event):
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   skip_requested=true;accept_event())
 resized.connect(arrange);arrange()

func arrange():
 if heading==null:return
 var center=size.y*.45;var width=minf(900,size.x-112)
 for entry in [[heading,-82,28],[title,-43,76],[place,49,33],[hint,136,26]]:
  entry[0].position=Vector2((size.x-width)*.5,center+entry[1]);entry[0].size=Vector2(width,entry[2])
 queue_redraw()

func _draw():
 var center=size.y*.45;var gold=Color("bca371")
 draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.04,.06,.18))
 draw_rect(Rect2(0,center-116,size.x,230),Color(.065,.12,.18,.94))
 for y in [center-116,center+114]:draw_line(Vector2(0,y),Vector2(size.x,y),gold,1.5,true)
 for side in [-1,1]:
  var x=size.x*.5+side*minf(290,size.x*.31)
  draw_line(Vector2(x,center-67),Vector2(x+side*100,center-67),Color("8f8c78"),1,true)
  draw_polyline(PackedVector2Array([Vector2(x-side*12,center-67),Vector2(x-side*22,center-74),Vector2(x-side*32,center-67),Vector2(x-side*22,center-60),Vector2(x-side*12,center-67)]),gold,1.5,true)

func play(cancelled: Callable):
 modulate.a=0
 motion=create_tween();motion.tween_property(self,"modulate:a",1.0,.20)
 motion.tween_interval(.8);motion.tween_property(self,"modulate:a",0.0,.20)
 while motion.is_running():
  if skip_requested or cancelled.call():motion.kill();break
  await get_tree().process_frame
 hide()
