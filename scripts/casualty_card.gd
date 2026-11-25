extends Control
# A brief, skippable portrait line after an already-resolved casualty. This card
# never saves, rolls dice, or decides whether a recruit survives. Outcome color
# and emblems share a parchment frame; full portrait/quote bounds stay unchanged.
# Establish wrapping width before adding quote text to avoid a narrow minimum.
static var lines=JSON.parse_string(FileAccess.get_file_as_string("res://data/casualty_lines.json"))
var dismissed=false
var motion: Tween
var face: TextureRect
var heading: Label
var line: Label
var consequences: Label
var prompt: Label
const ACCENTS={"downed":Color("725629"),"retreat":Color("3e626b"),"death":Color("8c4545")}

class CardFrame extends Control:
 const ORNAMENT=preload("res://assets/ui/river-scroll.svg")
 var accent=Color("725629")
 var mode="downed"
 var portrait_present=true
 func _init():
  mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;resized.connect(queue_redraw)
 func _draw():
  var w=size.x;var h=size.y
  if w<24 or h<24:return
  var corners=PackedVector2Array([Vector2(0,10),Vector2(10,0),Vector2(w-10,0),Vector2(w,10),Vector2(w,h-10),Vector2(w-10,h),Vector2(10,h),Vector2(0,h-10)])
  var shadow=corners.duplicate()
  for index in range(shadow.size()):shadow[index]+=Vector2(3,4)
  draw_colored_polygon(shadow,Color(.06,.10,.13,.24));draw_colored_polygon(corners,Color("efe7d3"))
  var outline=corners.duplicate();outline.append(corners[0]);draw_polyline(outline,Color("a98b58"),2,true)
  var left=142.0 if portrait_present else 16.0
  var band=PackedVector2Array([Vector2(left-8,8),Vector2(w-12,8),Vector2(w-12,42),Vector2(left-8,42)])
  var uv=PackedVector2Array()
  for point in band:uv.append(point/96.0)
  draw_colored_polygon(band,Color(accent,.10),uv,ORNAMENT)
  draw_line(Vector2(5,15),Vector2(5,h-15),accent,3,true)
  draw_line(Vector2(left,42),Vector2(w-18,42),Color("c8b999"),1,true)
  draw_line(Vector2(left,128),Vector2(w-18,128),Color("d2c5aa"),1,true)
  if portrait_present:
   draw_rect(Rect2(13,13,116,138),Color("34454b"));draw_rect(Rect2(14,14,114,136),Color("bba16b"),false,1)
  var center=Vector2(w-27,26)
  if mode=="downed":
   draw_arc(center,8,0,TAU,24,accent,1.4,true)
   draw_line(center-Vector2(4,0),center+Vector2(4,0),accent,2,true);draw_line(center-Vector2(0,4),center+Vector2(0,4),accent,2,true)
  elif mode=="death":
   draw_line(center+Vector2(-4,-8),center+Vector2(-4,8),accent,1.6,true)
   draw_colored_polygon(PackedVector2Array([center+Vector2(-3,-7),center+Vector2(7,-4),center+Vector2(4,1),center+Vector2(-3,-1)]),accent)
  else:
   draw_line(center-Vector2(7,0),center+Vector2(7,0),accent,1.6,true)
   draw_polyline(PackedVector2Array([center+Vector2(-1,-6),center-Vector2(7,0),center+Vector2(-1,6)]),accent,1.6,true)

static func mode_for(game,unit: Dictionary) -> String:
 if game.DeathDoor.downed(unit):return "downed"
 return "death" if game.permadeath and unit.id!="lyra" else "retreat"

static func quote_for(game,unit: Dictionary) -> String:
 if unit.get("team","")!="player":return ""
 return lines.get(unit.get("id",""),{}).get(mode_for(game,unit),"")

func configure(parent: Control,unit: Dictionary,portrait: Texture2D,mode: String,quote: String,effects: Dictionary={},opening_attack=2):
 name="CasualtyCard";z_index=30;mouse_filter=Control.MOUSE_FILTER_STOP
 parent.add_child(self)
 var accent=ACCENTS.get(mode,ACCENTS.retreat)
 var background=CardFrame.new();background.name="OutcomeFrame";background.accent=accent;background.mode=mode;background.portrait_present=portrait!=null
 add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 if portrait!=null:
  face=TextureRect.new();face.name="Portrait";face.texture=portrait
  face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;face.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(face)
 heading=Label.new();heading.name="Heading";heading.text=unit.name+" · "+{"downed":"NEEDS RESCUE","retreat":"WITHDRAWING","death":"LAST WORDS"}.get(mode,"")
 heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",accent);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
 line=Label.new();line.name="Quote";line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 line.size=Vector2(minf(760,parent.size.x-370)-(158 if portrait!=null else 32),80);line.text=quote
 line.add_theme_font_size_override("font_size",24);line.add_theme_color_override("font_color",Color("343c49"));line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)
 if not effects.is_empty():
  var details=[]
  if effects.get("legacy_credit",false):details.append("Legacy credit +1")
  if effects.has("volunteer"):details.append(effects.volunteer+" joins early")
  if effects.has("replacement"):details.append(effects.replacement+" joins")
  if effects.get("opening",false):details.append("Allies gain +%d attack"%opening_attack)
  if effects.get("recovering",false):details.append("Recovery on redeployment")
  consequences=Label.new();consequences.name="Consequences";consequences.text=" · ".join(details)
  consequences.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;consequences.mouse_filter=Control.MOUSE_FILTER_IGNORE
  consequences.add_theme_font_size_override("font_size",14);consequences.add_theme_color_override("font_color",accent);add_child(consequences)
 prompt=Label.new();prompt.add_theme_font_size_override("font_size",14);prompt.add_theme_color_override("font_color",Color("736754"));prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(prompt)
 parent.resized.connect(arrange);arrange()

func arrange():
 var viewport_size=get_parent().size
 var card_width=minf(760,viewport_size.x-370)
 var left=142.0 if face!=null else 16.0
 var width=card_width-left-16
 var extra_height=0.0
 if consequences!=null:
  consequences.position=Vector2(left,132);consequences.size.x=width
  var line_height=consequences.get_theme_font("font").get_height(14)+consequences.get_theme_constant("line_spacing")
  consequences.size.y=ceilf(maxi(1,consequences.get_line_count())*line_height)
  extra_height=consequences.size.y+6
 size=Vector2(card_width,164+extra_height)
 position=Vector2(22,viewport_size.y-size.y-82)
 if face!=null:face.position=Vector2(16,16);face.size=Vector2(110,132)
 heading.position=Vector2(left,14);heading.size=Vector2(width-28,26)
 line.position=Vector2(left,44);line.size=Vector2(width,80)
 var help="Click, Enter or Space to continue · Tab to skip"
 var help_width=prompt.get_theme_font("font").get_string_size(help,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
 prompt.text=help if help_width<=width else "Enter or Space · Tab to skip"
 prompt.position=Vector2(left,132+extra_height);prompt.size=Vector2(width,20)

func _gui_input(event):
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  dismissed=true;accept_event()

func _input(event):
 if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.keycode not in [KEY_ENTER,KEY_SPACE]:return
 if not event.echo:dismissed=true
 get_viewport().set_input_as_handled()

func play(cancelled: Callable):
 modulate.a=0
 motion=create_tween();motion.tween_property(self,"modulate:a",1.0,.12)
 motion.tween_interval(2.5);motion.tween_property(self,"modulate:a",0.0,.16)
 while motion.is_running():
  if dismissed or cancelled.call():motion.kill();break
  await get_tree().process_frame
 hide()
