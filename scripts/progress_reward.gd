extends PanelContainer
# Read-only reward presentation: resolved values arrive together; only the
# displayed numbers reveal in sequence. Node-owned tweens die on dismissal.
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const STATS=[["max_hp","HP"],["pow","Power"],["defense","Defense"],["resistance","Resistance"],["speed","Speed"]]
var leveled=false
var requested_close=false
var record: Dictionary
var rows={}
var meter: ProgressBar
var experience: Label
var motion: Tween
var host: Control
var content: Control
var close_button: Button
var maximum_level=99

func label(text: String,point: Vector2,extent: Vector2,font_size=20,color=Color("eee5cf")) -> Label:
 var node=Label.new();node.text=text;node.position=point;node.size=extent
 node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(node);return node

func configure(parent: Control,change: Dictionary,portrait: Texture2D,job: String,cap=99):
 name="ProgressReward";host=parent;record=change;maximum_level=cap
 leveled=int(change.unit.level)>int(change.before.level)
 var style=StyleBoxFlat.new();style.bg_color=Color("182d3c");style.border_color=Color("c8b07b")
 style.set_border_width_all(2);style.set_corner_radius_all(3)
 style.shadow_color=Color(0,0,0,.3);style.shadow_size=8
 add_theme_stylebox_override("panel",style)
 parent.add_child(self);z_index=22
 content=Control.new();content.custom_minimum_size=Vector2(640,356) if leveled else Vector2(510,150);add_child(content)
 var face=TextureRect.new();face.name="Portrait";face.texture=portrait
 face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 face.position=Vector2(14,62) if leveled else Vector2(12,8);face.size=Vector2(166,274) if leveled else Vector2(86,130)
 face.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(face)
 var x=194.0 if leveled else 112.0;var width=420.0 if leveled else 378.0
 var heading=label("LEVEL UP" if leveled else change.unit.name,Vector2(22,8) if leveled else Vector2(x,7),Vector2(590,42) if leveled else Vector2(width,34),32 if leveled else 27,Color("f1d795"));heading.add_theme_font_override("font",FONT)
 if leveled:
  label(change.unit.name,Vector2(x,53),Vector2(230,32),26)
  var level=label("Lv. %d → %d"%[change.before.level,change.unit.level],Vector2(x+230,56),Vector2(190,30),23,Color("f1d795"));level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  label(job,Vector2(x,86),Vector2(width,24),16,Color("b7c6c9"))
  for i in range(STATS.size()):
   var key=STATS[i][0];var y=118+i*29
   label(STATS[i][1],Vector2(x,y),Vector2(170,27),20)
   var value=label(str(int(change.before[key])),Vector2(x+190,y),Vector2(90,27),21);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
   var gain=label("+%d"%int(change.gains[key]) if change.gains[key]>0 else "—",Vector2(x+308,y),Vector2(90,27),21,Color("c4e5a3") if change.gains[key]>0 else Color("8f9d9d"))
   gain.modulate.a=0;rows[key]={"value":value,"gain":gain}
 else:
  label("Level %d  ·  %s"%[change.unit.level,job],Vector2(x,40),Vector2(width,25),17,Color("b7c6c9"))
 var y=274.0 if leveled else 73.0
 meter=ProgressBar.new();meter.name="Experience";meter.position=Vector2(x,y);meter.size=Vector2(width,14);meter.max_value=100;meter.show_percentage=false
 var fill=StyleBoxFlat.new();fill.bg_color=Color("b3c981");meter.add_theme_stylebox_override("fill",fill)
 var background=StyleBoxFlat.new();background.bg_color=Color("0b1c28");background.border_color=Color("8e8b70");background.set_border_width_all(1);meter.add_theme_stylebox_override("background",background)
 content.add_child(meter)
 experience=label("",Vector2(x,y+17),Vector2(250,24),16)
 meter.value_changed.connect(func(value):experience.text="EXP  %02d / 100"%roundi(value))
 meter.value=change.before.xp;experience.text="EXP  %02d / 100"%int(change.before.xp)
 var earned=label("+%d XP"%change.xp_gain,Vector2(x+260,y+17),Vector2(width-260,24),16,Color("f1d795"));earned.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 close_button=Button.new();close_button.text="Continue";close_button.position=Vector2(x+width-120,314 if leveled else 112);close_button.size=Vector2(120,30);close_button.add_theme_font_size_override("font_size",16)
 var button_style=StyleBoxFlat.new();button_style.bg_color=Color("293f4d");button_style.border_color=Color("a69c7e");button_style.set_border_width_all(1)
 for state in ["normal","hover","pressed","focus"]:close_button.add_theme_stylebox_override(state,button_style)
 close_button.pressed.connect(func():requested_close=true);content.add_child(close_button)
 label("Space / Enter",Vector2(x,318 if leveled else 116),Vector2(170,22),14,Color("aab9bb"))
 parent.resized.connect(arrange);arrange()

func arrange():
 size=get_combined_minimum_size()
 position=Vector2((host.size.x-size.x)*.5,(host.size.y-size.y)*.5 if leveled else host.size.y-size.y-22)

func reveal_stat(key: String):
 var row=rows[key];row.value.text=str(int(record.unit[key]))
 var accent=create_tween();accent.tween_property(row.gain,"modulate:a",1.0,.12)
 if record.gains[key]>0:
  row.value.add_theme_color_override("font_color",Color("d2eeb4"))
  row.gain.scale=Vector2.ONE*1.18;accent.parallel().tween_property(row.gain,"scale",Vector2.ONE,.18)

func begin(cue: Callable):
 motion=create_tween()
 if leveled:
  motion.tween_property(meter,"value",100.0,.25)
  motion.tween_callback(func():meter.value=0;cue.call())
 motion.tween_property(meter,"value",100.0 if record.unit.level>=maximum_level else float(record.unit.xp),.35)
 if record.unit.level>=maximum_level:motion.tween_callback(func():experience.text="LEVEL LIMIT REACHED")
 if leveled:
  for stat in STATS:
   motion.tween_callback(reveal_stat.bind(stat[0]));motion.tween_interval(.075)
