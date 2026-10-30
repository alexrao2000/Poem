extends Control
# Opposing nameplates leave the arena center open. HP animation only displays
# resolved results; neither damage nor combat timing is owned by this overlay.
const DISPLAY_FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const MatchupMarker=preload("res://scripts/weapon_matchup.gd")
const Icons=preload("res://scripts/weapon_icons.gd")
var records: Dictionary={}
var order: Array=[]
var entrance=1.0:
 set(value):entrance=clampf(value,0,1);arrange()
var entrance_motion: Tween

class HealthMeter extends Control:
 signal value_changed(value: float)
 var maximum=1.0
 var value=1.0:
  set(next):
   value=next;queue_redraw();value_changed.emit(value)
 var trailing=1.0:
  set(next):trailing=next;queue_redraw()
 var accent=Color("86c9cb")
 var motion: Tween
 func segments() -> Array:
  var inside=Rect2(Vector2(1,2),(size-Vector2(2,4)).max(Vector2.ZERO));var result=[]
  if inside.size.x<=0 or inside.size.y<=0 or maximum<=0:return result
  var budget=maxi(1,floori(inside.size.x/4));var step=maxi(1,ceili(float(maximum)/budget));var start=0.0
  while start<maximum:
   var end=minf(maximum,start+step)
   if maximum-end<step*.5:end=maximum
   var width=inside.size.x*(end-start)/maximum
   var rect=Rect2(Vector2(inside.position.x+inside.size.x*start/maximum,inside.position.y),Vector2(width-(minf(1,width*.2) if end<maximum else 0),inside.size.y))
   result.append({"rect":rect,"start":start,"end":end,"fill":clampf((value-start)/(end-start),0,1),"ghost":clampf((trailing-start)/(end-start),0,1)})
   start=end
  return result
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("ad986b"),false,1)
  draw_rect(Rect2(Vector2(1,2),(size-Vector2(2,4)).max(Vector2.ZERO)),Color("18222a"))
  for segment in segments():
   var rect=segment.rect
   draw_rect(rect,Color("283c49"))
   var ghost=rect;ghost.size.x*=segment.ghost
   if ghost.size.x>0:draw_rect(ghost,Color("e3bd73"))
   var fill=rect;fill.size.x*=segment.fill
   if fill.size.x<=0:continue
   draw_rect(fill,accent)
   draw_line(fill.position+Vector2(0,1),fill.position+Vector2(fill.size.x,1),accent.lightened(.35),1)
   draw_line(Vector2(fill.position.x,fill.end.y-1),fill.end-Vector2(0,1),accent.darkened(.25),1)
 func change_to(amount: float,instant=false):
  if motion and motion.is_valid():motion.kill()
  amount=clampf(amount,0,maximum)
  if instant:value=amount;trailing=amount;return
  trailing=maxf(trailing,value)
  motion=create_tween().set_parallel(true)
  motion.tween_property(self,"value",amount,.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  motion.tween_property(self,"trailing",amount,.34).set_delay(.14)

class StatStrip extends Control:
 var data={}
 var columns=[]
 func configure(source: Dictionary):
  data=source.duplicate(true);mouse_filter=Control.MOUSE_FILTER_IGNORE
  var available=data.get("available",true)
  var values=[str(data.get("damage",0))+("×2" if data.get("double",false) else ""),str(data.get("hit",0))+"%",str(data.get("crit",0))+"%"] if available else ["—","—","—"]
  for index in range(3):
   var title=Label.new();title.text=["DMG","HIT","CRIT"][index];title.add_theme_font_size_override("font_size",12);title.add_theme_color_override("font_color",Color("685b43"));title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(title)
   var value=Label.new();value.text=values[index];value.add_theme_font_size_override("font_size",14);value.add_theme_color_override("font_color",Color("8d4942") if index==0 and available and data.get("effective",false) else Color("303c48") if available else Color("68604e"));value.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(value)
   columns.append({"title":title,"value":value})
  resized.connect(arrange);arrange()
 func arrange():
  for index in range(columns.size()):
   var column=columns[index];var width=size.x/3
   var title_width=column.title.get_theme_font("font").get_string_size(column.title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
   column.title.position=Vector2(index*width+4,2);column.title.size=Vector2(title_width,18)
   column.value.position=Vector2(index*width+title_width+8,0);column.value.size=Vector2(maxf(1,width-title_width-12),21)

 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("eee1c7"))
  draw_line(Vector2.ZERO,Vector2(size.x,0),Color("bca36a"),1)
  for index in [1,2]:draw_line(Vector2(size.x*index/3,4),Vector2(size.x*index/3,size.y-4),Color("c9b994"),1)

class Nameplate extends Control:
 const ORNAMENT=preload("res://assets/ui/river-scroll.svg")
 var enemy=false
 var mirrored=false
 var active=false
 func _init():texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
 func _draw():
  var w=size.x;var h=size.y
  var points=PackedVector2Array([Vector2(0,8),Vector2(w-22,0),Vector2(w,h-14),Vector2(18,h)])
  if mirrored:
   for i in range(points.size()):points[i].x=w-points[i].x
  draw_colored_polygon(points,Color("38252e") if enemy else Color("172c3d"))
  var uvs=PackedVector2Array()
  for point in points:uvs.append(point/96.0)
  draw_colored_polygon(points,Color(1,.9,.7,.10),uvs,ORNAMENT)
  var edge=Color("e7ce91") if active else Color("9b927a")
  var outline=points.duplicate();outline.append(points[0]);draw_polyline(outline,edge,2 if active else 1,true)
  var y=29.0;var x=12.0 if not mirrored else w-12
  draw_colored_polygon(PackedVector2Array([Vector2(x,y-5),Vector2(x+4,y),Vector2(x,y+5),Vector2(x-4,y)]),edge)

func configure(parent: Control,entries: Array):
 name="CombatHUD";mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for entry in entries:
  var unit=entry.unit
  var plate=Nameplate.new();plate.name="Side"+str(order.size());plate.enemy=unit.team=="enemy";plate.mirrored=order.size()==1
  plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(plate)
  var face=TextureRect.new();face.name="Portrait";face.texture=entry.get("portrait")
  face.flip_h=plate.mirrored
  face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  face.clip_contents=true;face.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(face)
  var heading=make_label(plate,unit.name,27,Color("fff1d5"));heading.add_theme_font_override("font",DISPLAY_FONT)
  var job=make_label(plate,entry.class_name,14,Color("c1c2bb"))
  var stats=StatStrip.new();stats.name="ExchangeStats";plate.add_child(stats)
  var forecast=entry.get("forecast",{});stats.visible=not forecast.is_empty();job.visible=forecast.is_empty()
  if stats.visible:stats.configure(forecast)
  var weapon=make_label(plate,entry.weapon,17,Color("e6d7b5"))
  weapon.tooltip_text=entry.weapon
  var icon=TextureRect.new();icon.name="WeaponIcon";icon.texture=Icons.get_icon(unit.get("weapon",""))
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(icon)
  var matchup=MatchupMarker.new();matchup.name="WeaponMatchup";matchup.advantage=int(entry.get("triangle",0));matchup.visible=matchup.advantage!=0
  matchup.tooltip_text="Weapon advantage" if matchup.advantage>0 else "Weapon disadvantage";plate.add_child(matchup)
  var hp=make_label(plate,"",24,Color("fff8e7"));hp.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  var meter=HealthMeter.new();meter.name="Health";meter.maximum=maxf(1,forecast.get("max_hp",unit.max_hp))
  meter.accent=Color("d98684") if plate.enemy else Color("8fc8b8")
  meter.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(meter)
  meter.value_changed.connect(func(amount):hp.text="%d / %d"%[ceili(amount),int(meter.maximum)])
  meter.change_to(float(entry.hp),true)
  records[unit.id]={"plate":plate,"portrait":face,"name":heading,"job":job,"stats":stats,"weapon":weapon,"icon":icon,"matchup":matchup,"hp":hp,"meter":meter}
  order.append(unit.id)
 resized.connect(arrange);arrange()

func make_label(parent: Control,text: String,font_size: int,color: Color) -> Label:
 var label=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color);label.autowrap_mode=TextServer.AUTOWRAP_OFF
 label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(label);return label

func arrange():
 var margin=clampf(size.x*.035,20,50);var gap=clampf(size.x*.13,32,200)
 var width=minf(540,(size.x-margin*2-gap)*.5)
 for i in range(order.size()):
  var r=records[order[i]];var plate=r.plate
  plate.size=Vector2(width,126);plate.position=Vector2(margin if i==0 else size.x-margin-width,size.y-150)
  plate.position.x+=(1-entrance)*36*(-1 if i==0 else 1);plate.modulate.a=entrance
  var face_x=16.0 if i==0 else width-108
  r.portrait.position=Vector2(face_x,8);r.portrait.size=Vector2(92,110)
  var text_x=120.0 if i==0 else 28.0;var text_width=width-148
  if r.portrait.texture==null:
   text_x=28.0;text_width=width-56
  r.name.position=Vector2(text_x,10);r.name.size=Vector2(text_width,34)
  r.job.position=Vector2(text_x,44);r.job.size=Vector2(text_width,21)
  r.stats.position=r.job.position;r.stats.size=r.job.size;r.stats.arrange()
  r.icon.position=Vector2(text_x-2,69);r.icon.size=Vector2(24,24)
  r.matchup.position=Vector2(text_x+26,73);r.matchup.size=Vector2(16,18);r.matchup.queue_redraw()
  var matchup_space=20.0 if r.matchup.visible else 0.0
  r.weapon.position=Vector2(text_x+26+matchup_space,69);r.weapon.size=Vector2(maxf(80,text_width-134-matchup_space),26)
  r.hp.position=Vector2(text_x+text_width-104,66);r.hp.size=Vector2(104,30)
  r.meter.position=Vector2(text_x,101);r.meter.size=Vector2(text_width,12)
  plate.queue_redraw();r.meter.queue_redraw()

func reveal(duration=.18) -> Tween:
 if entrance_motion and entrance_motion.is_valid():entrance_motion.kill()
 entrance=0
 entrance_motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 entrance_motion.tween_property(self,"entrance",1.0,duration)
 return entrance_motion

func dismiss(duration=.12) -> Tween:
 if entrance_motion and entrance_motion.is_valid():entrance_motion.kill()
 entrance_motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 entrance_motion.tween_property(self,"entrance",0.0,duration)
 return entrance_motion

func mark_actor(id: String):
 for key in records:
  records[key].plate.active=key==id;records[key].plate.queue_redraw()

func set_health(id: String,amount: int,instant=false):
 if not records.has(id):return
 var record=records[id];record.meter.change_to(amount,instant)
 record.portrait.modulate=Color("8c8790") if amount<=0 else Color.WHITE
