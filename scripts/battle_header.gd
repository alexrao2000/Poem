extends Control
## Chapter and turn information stay at the edges of the tactical view.

const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const CHAPTER_COLOR=Color("1a303d")
const PLAYER_COLOR=Color("213b48")
const ENEMY_COLOR=Color("462a35")
const INK=Color("f9e9c8")
const WIDTH=530.0
const PHASE_WIDTH=248.0
const HEIGHT=82.0

class Plate extends PanelContainer:
 const ORNAMENT=preload("res://assets/ui/river-scroll.svg")
 var fill=CHAPTER_COLOR
 var mirrored=false

 func _init():
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
  var inset=StyleBoxEmpty.new()
  inset.content_margin_left=20;inset.content_margin_right=20
  inset.content_margin_top=10;inset.content_margin_bottom=10
  add_theme_stylebox_override("panel",inset)
  resized.connect(queue_redraw)

 func outline() -> PackedVector2Array:
  var w=size.x;var h=size.y
  var points=PackedVector2Array([
   Vector2(8,0),Vector2(w-18,0),Vector2(w,18),
   Vector2(w,h-7),Vector2(w-7,h),Vector2(0,h),Vector2(0,8),
  ])
  if mirrored:
   for i in points.size():points[i].x=w-points[i].x
  return points

 func _draw():
  var points=outline()
  var shadow=PackedVector2Array();var uv=PackedVector2Array()
  for point in points:
   shadow.append(point+Vector2(0,4))
   uv.append(point/114.0)
  draw_colored_polygon(shadow,Color(0.05,0.05,0.06,.27))
  draw_colored_polygon(points,fill)
  draw_colored_polygon(points,Color(1,.88,.64,.09),uv,ORNAMENT)
  points.append(points[0])
  draw_polyline(points,Color("c7ad75"),1.5,true)
  draw_line(Vector2(12,size.y-5),Vector2(size.x-12,size.y-5),Color(0.8,.68,.46,.42),1)

var chapter_plate: Plate
var phase_plate: Plate
var heading: Label
var objective: Label
var status: Label

func configure(parent: Control,title: String,instruction: String,tooltip: String):
 name="BattleHeader";mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 offset_left=22;offset_right=-22;offset_top=18;offset_bottom=18+HEIGHT
 chapter_plate=Plate.new();chapter_plate.name="ChapterPlate";add_child(chapter_plate)
 phase_plate=Plate.new();phase_plate.name="PhasePlate";phase_plate.mirrored=true;add_child(phase_plate)
 var titles=VBoxContainer.new()
 titles.mouse_filter=Control.MOUSE_FILTER_IGNORE
 titles.add_theme_constant_override("separation",1)
 chapter_plate.add_child(titles)
 heading=Label.new();heading.text=title;heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 heading.add_theme_font_override("font",FONT)
 heading.add_theme_font_size_override("font_size",29)
 heading.add_theme_color_override("font_color",INK)
 heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
 titles.add_child(heading)
 objective=Label.new();objective.name="BattleObjective";objective.text=instruction
 objective.tooltip_text=tooltip;objective.mouse_filter=Control.MOUSE_FILTER_PASS
 objective.text_overrun_behavior=TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
 objective.add_theme_font_size_override("font_size",15)
 objective.add_theme_color_override("font_color",Color("e2d5b6"))
 titles.add_child(objective)
 status=Label.new();status.name="PhaseStatus";status.mouse_filter=Control.MOUSE_FILTER_IGNORE
 status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 status.add_theme_font_size_override("font_size",17)
 phase_plate.add_child(status)
 resized.connect(arrange)
 phase_plate.minimum_size_changed.connect(arrange)
 arrange()

func arrange():
 var phase_width=maxf(phase_plate.get_combined_minimum_size().x,clampf(size.x*.29,204,PHASE_WIDTH))
 chapter_plate.size=Vector2(minf(WIDTH,maxf(180,size.x-phase_width-40)),HEIGHT)
 phase_plate.position=Vector2(size.x-phase_width,0)
 phase_plate.size=Vector2(phase_width,HEIGHT)

func set_phase(text_value: String,enemy: bool,save_failed: bool):
 status.text=text_value
 status.add_theme_color_override("font_color",Color("ffd4a3") if save_failed else Color("f5c0b2") if enemy else Color("c5e0e0"))
 phase_plate.fill=ENEMY_COLOR if enemy else PLAYER_COLOR
 phase_plate.queue_redraw()
