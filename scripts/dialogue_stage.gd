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

func configure(next_line: Callable,skip_scene: Callable):
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(.08,.10,.13,.42)
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
	heading=Label.new();heading.add_theme_font_size_override("font_size",25)
	heading.add_theme_color_override("font_color",Color("8f6e35"));column.add_child(heading)
	speech=Label.new();speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(speech)
	var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",12);column.add_child(controls)
	hint=Label.new();hint.text="Space / Enter: continue   ·   Escape: skip"
	hint.add_theme_font_size_override("font_size",15);hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_child(hint)
	for entry in [["Skip scene",skip_scene],["Continue  >",next_line]]:
		var button=Button.new();button.text=entry[0];button.custom_minimum_size.y=42
		button.pressed.connect(entry[1]);controls.add_child(button)
	resized.connect(arrange);arrange()

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
