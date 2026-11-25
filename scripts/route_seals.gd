extends Control

var camera: Camera3D
var pin_positions: Dictionary
var origin: Vector2
var newest=0
var front=-.85:
 set(value):
  front=value
  queue_redraw()

func configure(view: Camera3D,game,reveal_origin: Vector2):
 name="ValleyRouteSeals"
 mouse_filter=MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 camera=view
 origin=reveal_origin
 var dimensions=Vector2(game.board_size())
 for index in game.chapter:
  var chapter=game.content.chapters[index]
  if chapter.get("presentation","")=="valley_table":continue
  var pin=Vector2(chapter.route_position[0],chapter.route_position[1])
  newest=index+1
  pin_positions[pin*dimensions-Vector2.ONE*.5]=newest

static func draw_seal(canvas: CanvasItem,center: Vector2,scale_value: float,reached: bool,current: bool,opacity: float):
 canvas.draw_circle(center+Vector2(0,2)*scale_value,15*scale_value,Color(.18,.13,.08,.35*opacity))
 var rim=Color("a8864b") if reached else Color("99927e")
 var fill=Color("354e60") if current else Color("66523b") if reached else Color("746e60")
 canvas.draw_circle(center,14*scale_value,Color(rim,opacity))
 canvas.draw_circle(center,11.5*scale_value,Color(fill,opacity))

func projected_pins() -> Array:
 var projected=[]
 for point in pin_positions:
  var distance=origin.distance_to(point)
  var opacity=1.0-smoothstep(distance-.65,distance+1.25,front)
  if opacity<=0.0:continue
  var position=Vector3(point.x,.016,point.y)
  if camera.is_position_behind(position):continue
  var center=camera.unproject_position(position)
  var scale_value=clampf(center.distance_to(camera.unproject_position(position+Vector3.RIGHT))/43.0,.48,.86)
  projected.append({"center":center,"scale":scale_value,"opacity":opacity,"chapter":pin_positions[point]})
 return projected

func _draw():
 if not is_instance_valid(camera):return
 var font=get_theme_default_font()
 for pin in projected_pins():
  draw_seal(self,pin.center,pin.scale,true,pin.chapter==newest,pin.opacity)
  var font_size=roundi(7+6*pin.scale)
  var number=str(pin.chapter)
  var width=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  var baseline=(font.get_ascent(font_size)-font.get_descent(font_size))*.5
  draw_string(font,pin.center+Vector2(-width*.5,baseline),number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(Color("fff1cc"),pin.opacity))
