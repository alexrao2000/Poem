extends Control
# The forecast compares both units over the battlefield. Values come directly
# from Rules; the card does not resolve hits, predict RNG, or own confirmation.
# The fall warning assumes ordinary hits land in the displayed strike order.
const MatchupMarker=preload("res://scripts/weapon_matchup.gd")
const Icons=preload("res://scripts/weapon_icons.gd")
const HUD=preload("res://scripts/combat_hud.gd")
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const FALL_LABEL_WIDTH=144.0
const COMPACT_WIDTH=960.0
const ORDER_RESERVE=372.0
var records=[]
var strike_order: OrderStrip
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


# This is a conditional plan, never a rolled outcome. A fallen combatant can
# end the exchange before the later steps; misses still occupy their step.
class OrderStrip extends Control:
 var order: Array[String]=[]
 var chips: Array[Label]=[]
 var arrows: Array[Label]=[]
 var caption: Label
 var condition: Label
 func text_node(text: String,color: Color) -> Label:
  var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",13)
  node.add_theme_color_override("font_color",color);node.mouse_filter=Control.MOUSE_FILTER_IGNORE
  node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;add_child(node);return node
 func configure(a: Dictionary,b: Dictionary,attack: Dictionary,counter: Dictionary):
  name="StrikeOrder";mouse_filter=Control.MOUSE_FILTER_IGNORE
  caption=text_node("ORDER",Color("685b43"))
  var planned=[a]
  if attack.counter:planned.append(b)
  if attack.double:planned.append(a)
  elif attack.counter and counter.double:planned.append(b)
  condition=text_node("If both survive" if planned.size()>1 else "No counter",Color("685b43"))
  for i in range(planned.size()):
   var unit=planned[i];order.append(unit.id)
   var chip=text_node("%d · %s"%[i+1,unit.name],Color("fff2d3"))
   chip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   chip.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
   var style=StyleBoxFlat.new();style.bg_color=Color("773d46") if unit.team=="enemy" else Color("304f6a")
   style.set_corner_radius_all(3);style.content_margin_left=7;style.content_margin_right=7
   chip.add_theme_stylebox_override("normal",style);chips.append(chip)
   if i<planned.size()-1:
    var arrow=text_node("→",Color("685b43"));arrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;arrows.append(arrow)
  resized.connect(arrange);arrange()
 func ordinary_hit_fall(a: Dictionary,b: Dictionary,attack: Dictionary,counter: Dictionary) -> String:
  var hp={a.id:int(a.hp),b.id:int(b.hp)}
  for actor in order:
   var target=b.id if actor==a.id else a.id
   hp[target]-=int(attack.damage if actor==a.id else counter.damage)
   if hp[target]<=0:return target
  return ""
 func arrange():
  if caption==null:return
  var compact=size.x<COMPACT_WIDTH-ORDER_RESERVE
  caption.visible=not compact
  caption.position=Vector2(9,3);caption.size=Vector2(50,26)
  var condition_width=94.0 if compact else 108.0
  condition.position=Vector2(size.x-condition_width,3);condition.size=Vector2(condition_width-6,26)
  var left=8.0 if compact else 62.0
  var gap=16.0 if compact else 22.0
  var available=maxf(1,size.x-left-condition_width-10)
  var width=minf(145,(available-(chips.size()-1)*gap)/maxi(1,chips.size()))
  var extent=width*chips.size()+gap*(chips.size()-1)
  var start=left+(available-extent)*.5
  for i in range(chips.size()):
   chips[i].add_theme_font_size_override("font_size",12 if compact else 13)
   chips[i].position=Vector2(start+i*(width+gap),4);chips[i].size=Vector2(width,24)
   if i<arrows.size():arrows[i].position=Vector2(chips[i].get_rect().end.x,4);arrows[i].size=Vector2(gap,24)
  queue_redraw()
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color(.94,.89,.78,.97))
  draw_line(Vector2.ZERO,Vector2(size.x,0),Color("bca36a"),1)

class Card extends Control:
 const ORNAMENT=preload("res://assets/ui/river-scroll.svg")
 var enemy=false
 func _draw():
  draw_style_box(background(),Rect2(Vector2.ZERO,size))
  draw_rect(Rect2(2,2,size.x-4,36),Color("773d46") if enemy else Color("304f6a"))
  draw_texture_rect(ORNAMENT,Rect2(2,2,size.x-4,36),true,Color(1,.9,.7,.12))
  draw_line(Vector2(14,size.y-56),Vector2(size.x-14,size.y-56),Color("baa779"),1)
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
  var icon=TextureRect.new();icon.name="WeaponIcon";icon.texture=Icons.get_item_icon(rules.item_for(unit).id,unit.weapon);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(icon)
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
  stats[0].repeat=repeat;stats[0].multiplier=multiplier
  records.append({"unit":unit.id,"card":card,"name":heading,"weapon":weapon,"icon":icon,"matchup":matchup,"portrait":portrait,"hp":hp,"caption":caption,"meter":meter,"note":note,"fall":null,"stats":stats})
 strike_order=OrderStrip.new();add_child(strike_order)
 strike_order.configure(a,b,attack,counter);strike_order.visible=rules.can_attack(a,b)
 if strike_order.visible:
  var fallen=strike_order.ordinary_hit_fall(a,b,attack,counter)
  for record in records:
   if record.unit==fallen:
    var notice="Downed if hits land" if rules.death_door and not record.card.enemy else "Falls if hits land"
    record.fall=label(record.card,notice,14,Color("8b3a40"))
    record.fall.name="FallForecast"
    record.fall.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 resized.connect(arrange);arrange()

func label(parent: Control,text: String,font_size: int,color=Color("303c48")) -> Label:
 var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
 node.autowrap_mode=TextServer.AUTOWRAP_OFF;node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;node.tooltip_text=text;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func arrange():
 if strike_order!=null:
  strike_order.position=Vector2(22,size.y-104);strike_order.size=Vector2(size.x-ORDER_RESERVE,32)
 var width=(size.x-386)*.5
 var compact=size.x<COMPACT_WIDTH
 var inset=10.0 if compact else 14.0
 var height=234.0 if compact else 214.0
 var content_width=width-inset*2
 var number_size=19 if compact else 23
 for i in range(records.size()):
  var r=records[i];var card=r.card
  card.position=Vector2(22+i*(width+14),size.y-110-height);card.size=Vector2(width,height)
  r.name.add_theme_font_size_override("font_size",22 if compact else 26)
  r.name.position=Vector2(inset,3);r.name.size=Vector2(content_width,34)
  r.icon.position=Vector2(inset,49 if compact else 43);r.icon.size=Vector2(24,24)
  r.weapon.add_theme_font_size_override("font_size",14 if compact else 16)
  r.weapon.max_lines_visible=2 if compact else 1
  r.weapon.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
  r.weapon.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING if compact else TextServer.OVERRUN_TRIM_ELLIPSIS
  r.weapon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER if compact else VERTICAL_ALIGNMENT_TOP
  r.weapon.position=Vector2(inset+30,41 if compact else 43)
  r.weapon.size=Vector2(content_width-(56 if r.matchup.visible else 30),40 if compact else 24)
  r.matchup.position=Vector2(width-inset-20,51 if compact else 45);r.matchup.size=Vector2(20,20);r.matchup.queue_redraw()
  var face_width=minf(220,width*.68);var face_height=minf(260,card.position.y-112)
  r.portrait.size=Vector2(face_width,face_height)
  r.portrait.position=card.position+Vector2(0 if i==0 else width-face_width,-face_height)
  r.caption.position=Vector2(inset,88 if compact else 84);r.caption.size=Vector2(28,22)
  r.hp.add_theme_font_size_override("font_size",22 if compact else 29)
  r.hp.position=Vector2(inset+34,85 if compact else 74);r.hp.size=Vector2(content_width-34,38)
  r.meter.position=Vector2(inset,127 if compact else 117);r.meter.size=Vector2(content_width,8 if compact else 10)
  r.note.position=Vector2(inset,136 if compact else 132);r.note.size=Vector2(content_width,20 if compact else 25)
  if r.fall!=null:
   r.fall.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT
   if compact:
    r.fall.position=Vector2(inset,157);r.fall.size=Vector2(content_width,20)
   else:
    r.note.size.x-=FALL_LABEL_WIDTH+8
    r.fall.position=Vector2(width-inset-FALL_LABEL_WIDTH,132);r.fall.size=Vector2(FALL_LABEL_WIDTH,25)
  for j in range(3):
   var stat=r.stats[j];var column=content_width/3
   stat.title.add_theme_font_size_override("font_size",11 if compact else 12)
   stat.value.add_theme_font_size_override("font_size",number_size)
   stat.title.position=Vector2(inset+j*column,height-50);stat.title.size=Vector2(column,18)
   stat.value.position=Vector2(inset+j*column,height-32);stat.value.size=Vector2(column,28)
   if j==0:arrange_follow_up(stat,column,compact,number_size)
  card.queue_redraw()

func arrange_follow_up(stat: Dictionary,column: float,compact: bool,number_size: int):
 var badge_width=24 if compact else 28
 var gap=3 if compact else 4
 stat.multiplier.add_theme_font_size_override("font_size",12 if compact else 14)
 if stat.repeat.visible:
  var font=stat.value.get_theme_font("font")
  var number_width=font.get_string_size(stat.value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x
  var available=maxf(1,column-badge_width-gap)
  if compact and number_width>available:
   number_size=maxi(12,floori(number_size*available/number_width))
   stat.value.add_theme_font_size_override("font_size",number_size)
   number_width=font.get_string_size(stat.value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x
  var group_width=number_width+badge_width+gap
  stat.value.position.x+=maxf(0,(column-group_width)*.5);stat.value.size.x=number_width
  stat.repeat.position=stat.value.position+Vector2(number_width+gap,3)
 else:
  stat.repeat.position=stat.value.position+Vector2(0,3)
 stat.repeat.size=Vector2(badge_width,22)
