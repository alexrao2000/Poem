extends Control
# Opposing nameplates leave the arena center open. HP animation only displays
# resolved results; neither damage nor combat timing is owned by this overlay.
const DISPLAY_FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const Icons=preload("res://scripts/weapon_icons.gd")
var records: Dictionary={}
var order: Array=[]

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
 func _draw():
  var inside=Rect2(Vector2(1,2),size-Vector2(2,4))
  draw_rect(Rect2(Vector2.ZERO,size),Color("ad986b"),false,1)
  draw_rect(inside,Color("18222a"))
  var ghost=inside;ghost.size.x*=clampf(trailing/maximum,0,1);draw_rect(ghost,Color("e3bd73"))
  var fill=inside;fill.size.x*=clampf(value/maximum,0,1);draw_rect(fill,accent)
  if fill.size.x>0:draw_line(fill.position+Vector2(0,2),fill.position+Vector2(fill.size.x,2),accent.lightened(.3),2)
  var divisions=clampi(ceili(maximum/5.0),1,16)
  for i in range(1,divisions):
   var x=inside.position.x+inside.size.x*i/divisions
   draw_line(Vector2(x,inside.position.y),Vector2(x,inside.end.y),Color(0.08,.12,.16,.55),1)
 func change_to(amount: float,instant=false):
  if motion and motion.is_valid():motion.kill()
  amount=clampf(amount,0,maximum)
  if instant:value=amount;trailing=amount;return
  trailing=maxf(trailing,value)
  motion=create_tween().set_parallel(true)
  motion.tween_property(self,"value",amount,.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  motion.tween_property(self,"trailing",amount,.34).set_delay(.14)

class Nameplate extends Control:
 var enemy=false
 var mirrored=false
 var active=false
 func _draw():
  var w=size.x;var h=size.y
  var points=PackedVector2Array([Vector2(0,8),Vector2(w-22,0),Vector2(w,h-14),Vector2(18,h)])
  if mirrored:
   for i in range(points.size()):points[i].x=w-points[i].x
  draw_colored_polygon(points,Color("38252e") if enemy else Color("172c3d"))
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
  var weapon=make_label(plate,entry.weapon,17,Color("e6d7b5"))
  weapon.tooltip_text=entry.weapon
  var icon=TextureRect.new();icon.name="WeaponIcon";icon.texture=Icons.get_icon(unit.get("weapon",""))
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(icon)
  var hp=make_label(plate,"",24,Color("fff8e7"));hp.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  var meter=HealthMeter.new();meter.name="Health";meter.maximum=maxf(1,unit.max_hp)
  meter.accent=Color("d98684") if plate.enemy else Color("8fc8b8")
  meter.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(meter)
  meter.value_changed.connect(func(amount):hp.text="%d / %d"%[ceili(amount),int(meter.maximum)])
  meter.change_to(float(entry.hp),true)
  records[unit.id]={"plate":plate,"portrait":face,"name":heading,"job":job,"weapon":weapon,"icon":icon,"hp":hp,"meter":meter}
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
  var face_x=16.0 if i==0 else width-108
  r.portrait.position=Vector2(face_x,8);r.portrait.size=Vector2(92,110)
  var text_x=120.0 if i==0 else 28.0;var text_width=width-148
  if r.portrait.texture==null:
   text_x=28.0;text_width=width-56
  r.name.position=Vector2(text_x,10);r.name.size=Vector2(text_width,34)
  r.job.position=Vector2(text_x,44);r.job.size=Vector2(text_width,21)
  r.icon.position=Vector2(text_x-2,69);r.icon.size=Vector2(24,24)
  r.weapon.position=Vector2(text_x+26,69);r.weapon.size=Vector2(maxf(80,text_width-134),26)
  r.hp.position=Vector2(text_x+text_width-104,66);r.hp.size=Vector2(104,30)
  r.meter.position=Vector2(text_x,101);r.meter.size=Vector2(text_width,12)
  plate.queue_redraw();r.meter.queue_redraw()

func mark_actor(id: String):
 for key in records:
  records[key].plate.active=key==id;records[key].plate.queue_redraw()

func set_health(id: String,amount: int,instant=false):
 if not records.has(id):return
 var record=records[id];record.meter.change_to(amount,instant)
 record.portrait.modulate=Color("8c8790") if amount<=0 else Color.WHITE
