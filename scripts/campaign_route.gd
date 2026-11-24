extends Control
## Read-only campaign geography. Buttons review reached chapters; selecting a
## marker never changes campaign state or reveals an unreached briefing.
signal chapter_selected(index: int)
const MAP=preload("res://assets/art/campaign-valley-v1.png")
const POINTS=[Vector2(.18,.64),Vector2(.25,.61),Vector2(.23,.38),Vector2(.40,.32),Vector2(.52,.53),Vector2(.74,.73),Vector2(.83,.49),Vector2(.71,.31),Vector2(.55,.14),Vector2(.73,.20),Vector2(.82,.22),Vector2(.90,.10)]
const SEAL_SIZE=36.0
var markers: Array[Button]=[]
var current=0
var selected=0
var complete=false
var section_starts=false
var clock=0.0
var map_rect=Rect2()
var seal_scale=1.0

func configure(chapters: Array,index: int,finished=false,show_sections=false):
 current=clampi(index,0,POINTS.size()-1);selected=current;complete=finished;section_starts=show_sections
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
 custom_minimum_size=Vector2(350,240)
 for i in range(POINTS.size()):
  var marker=Button.new();marker.name="Chapter"+str(i+1);marker.text=str(i+1)
  marker.tooltip_text=chapters[i].place+" · "+chapters[i].title if i<=current or complete else "Unreached destination"
  if section_starts and i%4==0 and (i<=current or complete):marker.tooltip_text+="\nSection %d start%s"%[int(i/4)+1," · Current retreat point" if i==int(current/4)*4 and not complete else ""]
  marker.disabled=i>current and not complete;marker.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  for state in ["normal","hover","pressed","disabled"]:marker.add_theme_stylebox_override(state,StyleBoxEmpty.new())
  var focus=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.set_border_width_all(2);focus.border_color=Color("fff0b0");focus.set_corner_radius_all(18)
  marker.add_theme_stylebox_override("focus",focus)
  marker.add_theme_font_size_override("font_size",14)
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:marker.add_theme_color_override(state,Color("fff1cc"))
  marker.add_theme_color_override("font_disabled_color",Color("b4ad99"))
  marker.pressed.connect(func():select_chapter(i));add_child(marker);markers.append(marker)
 resized.connect(arrange);arrange()

func select_chapter(index: int):
 if index<0 or index>=POINTS.size() or (index>current and not complete):return
 selected=index;queue_redraw();chapter_selected.emit(index)

func arrange():
 var available=(size-Vector2(32 if size.x<500 else 48,64)).max(Vector2.ONE)
 var scale_value=minf(available.x/MAP.get_width(),available.y/MAP.get_height())
 var extent=MAP.get_size()*scale_value;map_rect=Rect2((size-extent)*.5,extent)
 var clearance=SEAL_SIZE+1
 for i in range(markers.size()):
  for previous in range(i):
   var gap=(point(i)-point(previous)).abs()
   clearance=minf(clearance,maxf(gap.x,gap.y))
 var hit_size=clampf(floorf(clearance-1),24,SEAL_SIZE)
 var target=Vector2.ONE*hit_size
 seal_scale=hit_size/SEAL_SIZE
 var font_size=roundi(8+6*seal_scale)
 for i in range(markers.size()):
  markers[i].add_theme_font_size_override("font_size",font_size)
  markers[i].position=point(i)-target*.5
  markers[i].size=target
 queue_redraw()

func point(index: int) -> Vector2:
 return map_rect.position+POINTS[index]*map_rect.size

func _process(dt):
 clock+=dt;queue_redraw()

func _draw():
 if map_rect.size.x<=0:return
 draw_texture_rect(MAP,map_rect,false)
 for i in range(POINTS.size()-1):
  var a=point(i);var b=point(i+1);var delta=b-a
  var side=Vector2(-delta.y,delta.x).normalized()*minf(18,delta.length()*.1)
  var reached=i<current or complete
  var color=Color("786344") if reached else Color("8c826b")
  color.a=.9 if reached else .43
  var samples=maxi(2,int(delta.length()/8))
  for step in range(1,samples):
   var t=float(step)/samples
   var pos=a.lerp(b,t)+side*sin(t*PI)
   draw_circle(pos,2.0 if reached else 1.1,color)
 for i in range(markers.size()):
  draw_set_transform(point(i),0,Vector2.ONE*seal_scale)
  var reached=i<=current or complete
  if section_starts and i%4==0 and reached:
   var corners=PackedVector2Array([Vector2(0,-20),Vector2(20,0),Vector2(0,20),Vector2(-20,0),Vector2(0,-20)])
   draw_polyline(corners,Color("f5dc94") if i==int(current/4)*4 and not complete else Color("a88b55"),2,true)
  draw_circle(Vector2(0,2),15,Color(0.18,.13,.08,.35))
  draw_circle(Vector2.ZERO,14,Color("a8864b") if reached else Color("99927e"))
  draw_circle(Vector2.ZERO,11.5,Color("354e60") if i==current else Color("66523b") if reached else Color("746e60"))
  if i==selected:draw_arc(Vector2.ZERO,17,0,TAU,40,Color("f5dc94"),2,true)
  if i==current and not complete:
   var pulse=Color("f5dc94");pulse.a=.35+.22*sin(clock*2.2)
   draw_arc(Vector2.ZERO,20,0,TAU,48,pulse,2,true)
   var pole=Vector2(0,-17)
   draw_line(pole,pole+Vector2(0,-24),Color("51412c"),2,true)
   draw_colored_polygon(PackedVector2Array([pole+Vector2(0,-24),pole+Vector2(16,-21),pole+Vector2(12,-13),pole+Vector2(0,-15)]),Color("f1dfb5"))
 draw_set_transform(Vector2.ZERO)
