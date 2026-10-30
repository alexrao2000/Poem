extends Control
# The forecast compares both units over the battlefield. Values come directly
# from Rules; the card does not resolve hits, predict RNG, or own confirmation.
const Icons=preload("res://scripts/weapon_icons.gd")
const HUD=preload("res://scripts/combat_hud.gd")
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
var records=[]

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
 var enemy=false
 func _draw():
  draw_style_box(background(),Rect2(Vector2.ZERO,size))
  draw_rect(Rect2(2,2,size.x-4,36),Color("773d46") if enemy else Color("304f6a"))
  draw_line(Vector2(14,172),Vector2(size.x-14,172),Color("baa779"),1)
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
  var portrait=TextureRect.new();portrait.texture=faces[index];portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(portrait)
  portrait.flip_h=index==1
  var hp=label(card,"%d / %d"%[unit.hp,unit.max_hp],29)
  var caption=label(card,"HP",13,Color("766546"))
  var meter=HUD.HealthMeter.new();meter.maximum=unit.max_hp;meter.accent=Color("b96268") if card.enemy else Color("5f9d91");card.add_child(meter);meter.change_to(unit.hp,true)
  var note=label(card,"No counter" if not available else "Effective!" if result.effective else rules.class_name_for(unit),14,Color("8d4942") if result.effective else Color("766546"))
  var stats=[]
  var values=[str(result.damage)+(" ×2" if result.double else ""),str(result.hit)+"%",str(result.crit)+"%"] if available else ["—","—","—"]
  for i in range(3):
   var title=label(card,["DAMAGE","HIT","CRIT"][i],12,Color("766546"));title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   var value=label(card,values[i],23);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   stats.append({"title":title,"value":value})
  records.append({"unit":unit.id,"card":card,"name":heading,"weapon":weapon,"icon":icon,"matchup":matchup,"portrait":portrait,"hp":hp,"caption":caption,"meter":meter,"note":note,"stats":stats})
 resized.connect(arrange);arrange()

func label(parent: Control,text: String,font_size: int,color=Color("303c48")) -> Label:
 var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
 node.autowrap_mode=TextServer.AUTOWRAP_OFF;node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;node.tooltip_text=text;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func arrange():
 var width=(size.x-386)*.5
 for i in range(records.size()):
  var r=records[i];var card=r.card
  card.position=Vector2(22+i*(width+14),size.y-342);card.size=Vector2(width,232)
  r.name.position=Vector2(14,3);r.name.size=Vector2(width-28,34)
  r.icon.position=Vector2(14,43);r.icon.size=Vector2(24,24)
  r.weapon.position=Vector2(44,43);r.weapon.size=Vector2(width-(84 if r.matchup.visible else 58),24)
  r.matchup.position=Vector2(width-34,45);r.matchup.size=Vector2(20,20);r.matchup.queue_redraw()
  r.portrait.position=Vector2(14 if i==0 else width-104,70);r.portrait.size=Vector2(90,100)
  var x=118.0 if i==0 else 14.0;var content_width=width-132
  r.caption.position=Vector2(x,70);r.caption.size=Vector2(content_width,20)
  r.hp.position=Vector2(x,87);r.hp.size=Vector2(content_width,38)
  r.meter.position=Vector2(x,128);r.meter.size=Vector2(content_width,10)
  r.note.position=Vector2(x,142);r.note.size=Vector2(content_width,25)
  for j in range(3):
   var stat=r.stats[j];var column=(width-28)/3
   stat.title.position=Vector2(14+j*column,177);stat.title.size=Vector2(column,18)
   stat.value.position=Vector2(14+j*column,195);stat.value.size=Vector2(column,28)
  card.queue_redraw()
