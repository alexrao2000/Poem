extends Control
# A brief, skippable portrait line after an already-resolved casualty. This card
# never saves, rolls dice, or decides whether a recruit survives.
static var lines=JSON.parse_string(FileAccess.get_file_as_string("res://data/casualty_lines.json"))
var dismissed=false
var motion: Tween
var face: TextureRect
var heading: Label
var line: Label
var prompt: Label

static func mode_for(game,unit: Dictionary) -> String:
 if game.DeathDoor.downed(unit):return "downed"
 return "death" if game.permadeath and unit.id!="lyra" else "retreat"

static func quote_for(game,unit: Dictionary) -> String:
 if unit.get("team","")!="player":return ""
 return lines.get(unit.get("id",""),{}).get(mode_for(game,unit),"")

func configure(parent: Control,unit: Dictionary,portrait: Texture2D,mode: String,quote: String):
 name="CasualtyCard";z_index=30;mouse_filter=Control.MOUSE_FILTER_STOP
 parent.add_child(self)
 var background=Panel.new();background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var style=StyleBoxFlat.new();style.bg_color=Color("efe7d3");style.border_color=Color("a98b58")
 style.set_border_width_all(2);background.add_theme_stylebox_override("panel",style)
 if portrait!=null:
  face=TextureRect.new();face.name="Portrait";face.texture=portrait
  face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;face.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(face)
 heading=Label.new();heading.name="Heading";heading.text=unit.name+" · "+{"downed":"NEEDS RESCUE","retreat":"WITHDRAWING","death":"LAST WORDS"}.get(mode,"")
 heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",Color("77533d"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
 line=Label.new();line.name="Quote";line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 # Establish wrapping width before text enters the tree; a zero-width initial
 # label otherwise retains its one-character-per-line minimum height.
 line.size=Vector2(minf(760,parent.size.x-370)-(158 if portrait!=null else 32),80);line.text=quote
 line.add_theme_font_size_override("font_size",24);line.add_theme_color_override("font_color",Color("343c49"));line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)
 prompt=Label.new();prompt.text="Click or Tab to skip";prompt.add_theme_font_size_override("font_size",14);prompt.add_theme_color_override("font_color",Color("736754"));prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(prompt)
 parent.resized.connect(arrange);arrange()

func arrange():
 var viewport_size=get_parent().size
 size=Vector2(minf(760,viewport_size.x-370),164)
 position=Vector2(22,viewport_size.y-size.y-82)
 var left=142.0 if face!=null else 16.0
 var width=size.x-left-16
 if face!=null:face.position=Vector2(16,16);face.size=Vector2(110,132)
 heading.position=Vector2(left,14);heading.size=Vector2(width,26)
 line.position=Vector2(left,44);line.size=Vector2(width,80)
 prompt.position=Vector2(left,132);prompt.size=Vector2(width,20)

func _gui_input(event):
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  dismissed=true;accept_event()

func play(cancelled: Callable):
 modulate.a=0
 motion=create_tween();motion.tween_property(self,"modulate:a",1.0,.12)
 motion.tween_interval(2.5);motion.tween_property(self,"modulate:a",0.0,.16)
 while motion.is_running():
  if dismissed or cancelled.call():motion.kill();break
  await get_tree().process_frame
 hide()
