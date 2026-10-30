extends Control
# The forecast compares both units over the battlefield. Values come directly
# from Rules; the card does not resolve hits, predict RNG, or own confirmation.
const Icons=preload("res://scripts/weapon_icons.gd")
const HUD=preload("res://scripts/combat_hud.gd")
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
var records=[]
var target_anchor: Callable
var target_cue: Control
var cue_clock=0.0

class TargetCue extends Control:
 func _draw():
  var edge=Color("e6ca8f")
  var frame=PackedVector2Array([Vector2(4,0),Vector2(32,0),Vector2(36,4),Vector2(36,28),Vector2(32,32),Vector2(22,32),Vector2(18,39),Vector2(14,32),Vector2(4,32),Vector2(0,28),Vector2(0,4)])
  draw_colored_polygon(frame,Color("243744"));frame.append(frame[0]);draw_polyline(frame,edge,1.5,true)
  for side in [-1,1]:
   var start=Vector2(18+side*8,24);var tip=Vector2(18-side*9,7)
   draw_line(start,tip,Color("fff3d6"),2.8,true)
   var guard=start.lerp(tip,.25);var cross=(tip-start).orthogonal().normalized()*4
   draw_line(guard-cross,guard+cross,edge,2,true)

func track_target(anchor: Callable):
 target_anchor=anchor;target_cue=TargetCue.new();target_cue.name="AttackTarget"
 target_cue.size=Vector2(36,40);target_cue.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(target_cue)
 _process(0)

func _process(dt):
 if not is_visible_in_tree() or target_cue==null or not target_anchor.is_valid():return
 cue_clock+=dt
 target_cue.position=target_anchor.call()-Vector2(18,46+sin(cue_clock*4)*1.5)
 var bounds=target_cue.get_rect()
 target_cue.visible=Rect2(Vector2(22,112),Vector2(size.x-365,size.y-222)).encloses(bounds)
 for record in records:
  if bounds.intersects(record.card.get_rect()) or bounds.intersects(record.portrait.get_rect()):target_cue.hide()


class MatchupMarker extends Control:
 var advantage=0
 func _draw():
  if advantage==0:return
  var sign_value=1.0 if advantage>0 else -1.0
  var center=size*.5
  var points=PackedVector2Array([center+Vector2(0,-7*sign_value),center+Vector2(7,5*sign_value),center+Vector2(-7,5*sign_value)])
  draw_colored_polygon(points,Color("64a174") if advantage>0 else Color("b86364"))
  points.append(points[0]);draw_polyline(points,Color("34444a"),1.2,true)

class Card extends Control:
 const ORNAMENT=preload("res://assets/ui/river-scroll.svg")
 var enemy=false
 func _draw():
  draw_style_box(background(),Rect2(Vector2.ZERO,size))
  draw_rect(Rect2(2,2,size.x-4,36),Color("773d46") if enemy else Color("304f6a"))
  draw_texture_rect(ORNAMENT,Rect2(2,2,size.x-4,36),true,Color(1,.9,.7,.12))
  draw_line(Vector2(14,158),Vector2(size.x-14,158),Color("baa779"),1)
 func background() -> StyleBoxFlat:
  var style=StyleBoxFlat.new();style.bg_color=Color(.94,.89,.78,.97);style.border_color=Color("bca36a")
  style.set_border_width_all(2);style.set_corner_radius_all(4)
  return style

func configure(parent: Control,rules,a: Dictionary,b: Dictionary,faces: Array):
 name="BattleForecast";mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var attack=rules.forecast(a,b);var counter=rules.forecast(b,a)
 for index in range(2):
  var unit=a if index==0 else b;var result=attack if index==0 else counter
  var available=index==0 or attack.counter
  var card=Card.new();card.enemy=unit.team=="enemy";card.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(card)
  var heading=label(card,unit.name,26,Color("fff2d3"));heading.add_theme_font_override("font",FONT)
  var weapon=label(card,rules.item_for(unit).name,16)
  var icon=TextureRect.new();icon.texture=Icons.get_icon(unit.weapon);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(icon)
  var matchup=MatchupMarker.new();matchup.advantage=result.triangle;matchup.visible=available and result.triangle!=0
  matchup.tooltip_text="Weapon advantage" if result.triangle>0 else "Weapon disadvantage";card.add_child(matchup)
  var portrait=TextureRect.new();portrait.texture=faces[index];portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(portrait);move_child(portrait,0)
  portrait.flip_h=index==1
  var hp=label(card,"%d / %d"%[unit.hp,unit.max_hp],29)
  var caption=label(card,"HP",13,Color("766546"))
  var meter=HUD.HealthMeter.new();meter.maximum=unit.max_hp;meter.accent=Color("b96268") if card.enemy else Color("5f9d91");card.add_child(meter);meter.change_to(unit.hp,true)
  var note=label(card,"No counter" if not available else "Effective!" if result.effective else rules.class_name_for(unit),14,Color("8d4942") if result.effective else Color("766546"))
  var stats=[]
  var values=[str(result.damage),str(result.hit)+"%",str(result.crit)+"%"] if available else ["—","—","—"]
  for i in range(3):
   var title=label(card,["DAMAGE","HIT","CRIT"][i],12,Color("766546"));title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   var value=label(card,values[i],23);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   stats.append({"title":title,"value":value})
  var repeat=PanelContainer.new();repeat.name="FollowUp";repeat.mouse_filter=Control.MOUSE_FILTER_IGNORE
  repeat.visible=available and result.double
  var repeat_style=StyleBoxFlat.new();repeat_style.bg_color=Color("427b59");repeat_style.border_color=Color("a3c58a")
  repeat_style.set_border_width_all(1);repeat_style.set_corner_radius_all(3)
  repeat_style.content_margin_left=3;repeat_style.content_margin_right=3;repeat_style.content_margin_top=1;repeat_style.content_margin_bottom=1
  repeat.add_theme_stylebox_override("panel",repeat_style);card.add_child(repeat)
  var multiplier=label(repeat,"×2",14,Color("f5f3d8"));multiplier.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  stats[0].repeat=repeat
  records.append({"unit":unit.id,"card":card,"name":heading,"weapon":weapon,"icon":icon,"matchup":matchup,"portrait":portrait,"hp":hp,"caption":caption,"meter":meter,"note":note,"stats":stats})
 resized.connect(arrange);arrange()

func label(parent: Control,text: String,font_size: int,color=Color("303c48")) -> Label:
 var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
 node.autowrap_mode=TextServer.AUTOWRAP_OFF;node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;node.tooltip_text=text;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func arrange():
 var width=(size.x-386)*.5
 for i in range(records.size()):
  var r=records[i];var card=r.card
  card.position=Vector2(22+i*(width+14),size.y-324);card.size=Vector2(width,214)
  r.name.position=Vector2(14,3);r.name.size=Vector2(width-28,34)
  r.icon.position=Vector2(14,43);r.icon.size=Vector2(24,24)
  r.weapon.position=Vector2(44,43);r.weapon.size=Vector2(width-(84 if r.matchup.visible else 58),24)
  r.matchup.position=Vector2(width-34,45);r.matchup.size=Vector2(20,20);r.matchup.queue_redraw()
  var face_width=minf(220,width*.68);var face_height=minf(260,card.position.y-112)
  r.portrait.size=Vector2(face_width,face_height)
  r.portrait.position=card.position+Vector2(0 if i==0 else width-face_width,-face_height)
  r.caption.position=Vector2(14,84);r.caption.size=Vector2(28,22)
  r.hp.position=Vector2(48,74);r.hp.size=Vector2(width-62,38)
  r.meter.position=Vector2(14,117);r.meter.size=Vector2(width-28,10)
  r.note.position=Vector2(14,132);r.note.size=Vector2(width-28,25)
  for j in range(3):
   var stat=r.stats[j];var column=(width-28)/3
   stat.title.position=Vector2(14+j*column,164);stat.title.size=Vector2(column,18)
   stat.value.position=Vector2(14+j*column,182);stat.value.size=Vector2(column,28)
   if j==0 and stat.repeat.visible:
    var number_width=stat.value.get_theme_font("font").get_string_size(stat.value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x
    var group_width=number_width+32
    stat.value.position.x+=maxf(0,(column-group_width)*.5);stat.value.size.x=number_width
    stat.repeat.position=Vector2(stat.value.position.x+number_width+4,185);stat.repeat.size=Vector2(28,22)
   elif j==0:
    stat.repeat.position=Vector2(14,185);stat.repeat.size=Vector2(28,22)
  card.queue_redraw()
