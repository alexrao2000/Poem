extends Control
## Two recurring speakers share a stage; a third replaces the silent speaker.
var portraits: Array[TextureRect]=[]
var identities: Array[String]=["", ""]
var entrances: Array[Tween]=[null,null]
var active=0
var panel: PanelContainer
var heading: Label
var speech: Label
var hint: Label
var next_button: Button
var ready_indicator: Control
var ready_to_continue=false
var ready_clock=0.0

class ReadyIndicator extends Control:
	func _draw():
		var center=size*.5
		var diamond=PackedVector2Array([center+Vector2(0,-7),center+Vector2(7,0),center+Vector2(0,7),center+Vector2(-7,0)])
		draw_colored_polygon(diamond,Color("9b773c"))
		draw_line(center+Vector2(-3,-2),center+Vector2(1,0),Color("fff1cc"),1.3,true)
		draw_line(center+Vector2(1,0),center+Vector2(-3,2),Color("fff1cc"),1.3,true)


func configure(next_line: Callable,skip_scene: Callable):
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(.08,.10,.13,.20)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	for index in range(2):
		var portrait=TextureRect.new();portrait.name="Speaker"+str(index)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.flip_h=index==1;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var material=ShaderMaterial.new();material.shader=preload("res://assets/shaders/dialogue-cutout.gdshader")
		portrait.material=material;add_child(portrait);portraits.append(portrait)
	panel=PanelContainer.new();add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var nameplate=PanelContainer.new();nameplate.custom_minimum_size.x=150;header.add_child(nameplate)
	var plate=StyleBoxFlat.new();plate.bg_color=Color("304f6a");plate.border_color=Color("bba371");plate.set_border_width_all(1)
	plate.content_margin_left=10;plate.content_margin_right=10;plate.content_margin_top=0;plate.content_margin_bottom=0
	nameplate.add_theme_stylebox_override("panel",plate)
	heading=Label.new();heading.add_theme_font_size_override("font_size",25)
	heading.add_theme_font_override("font",preload("res://assets/fonts/CormorantGaramond.ttf"))
	heading.add_theme_color_override("font_color",Color("fff2d5"));nameplate.add_child(heading)
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(spacer)
	ready_indicator=ReadyIndicator.new();ready_indicator.name="LineReady";ready_indicator.custom_minimum_size=Vector2(24,24)
	ready_indicator.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(ready_indicator)
	speech=Label.new();speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(speech)
	var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",12);column.add_child(controls)
	hint=Label.new();hint.text="Space / Enter: continue   ·   Escape: skip"
	hint.add_theme_font_size_override("font_size",15);hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_child(hint)
	for entry in [["Skip scene",skip_scene],["Continue  >",next_line]]:
		var button=Button.new();button.text=entry[0];button.custom_minimum_size.y=42
		button.pressed.connect(entry[1]);controls.add_child(button)
		if entry[0]=="Continue  >":next_button=button;button.custom_minimum_size.x=140
	resized.connect(arrange);arrange();refresh_prompt()

func refresh_prompt():
	if speech==null or next_button==null:return
	ready_to_continue=speech.visible_characters<0 or speech.visible_characters>=speech.text.length()
	ready_indicator.visible=ready_to_continue
	next_button.text="Continue  >" if ready_to_continue else "Reveal text"
	next_button.tooltip_text="Go to the next line" if ready_to_continue else "Show the rest of this line"
	hint.text="Space / Enter: continue   ·   Escape: skip" if ready_to_continue else "Space / Enter: reveal   ·   Escape: skip"
	if not ready_to_continue:ready_clock=0;ready_indicator.modulate.a=1

func _process(delta):
	if not is_visible_in_tree():return
	refresh_prompt()
	if ready_to_continue:
		ready_clock+=delta;ready_indicator.modulate.a=.65+sin(ready_clock*4)*.25

func arrange():
	if not is_instance_valid(panel):return
	var compact=size.y<760
	var margin=32.0 if compact else 56.0
	var height=240.0 if compact else 230.0
	panel.position=Vector2(margin,size.y-height-24)
	panel.size=Vector2(size.x-margin*2,height)
	speech.add_theme_font_size_override("font_size",22 if compact else 25)
	var extent=minf(470.0,minf(size.x*.38,panel.position.y+12))
	for index in range(2):
		if entrances[index]!=null:entrances[index].kill();entrances[index]=null
		portraits[index].size=Vector2.ONE*extent
		portraits[index].position=Vector2(margin if index==0 else size.x-margin-extent,panel.position.y+20-extent)

func show_speaker(id: String,display_name: String,texture: Texture2D) -> TextureRect:
	var index=identities.find(id)
	var entering=index<0
	if entering:
		index=0 if identities[0].is_empty() else 1-active
		identities[index]=id;portraits[index].texture=texture
	active=index;heading.text=display_name
	for slot in range(2):
		portraits[slot].modulate=Color.WHITE if slot==active else Color(.66,.69,.73,.88)
	if entering:
		arrange()
		var destination=portraits[index].position
		portraits[index].position.x+=-24 if index==0 else 24
		entrances[index]=create_tween()
		entrances[index].tween_property(portraits[index],"position",destination,.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return portraits[index]
