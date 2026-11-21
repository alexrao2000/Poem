extends Control
## Ephemeral transcript of text already revealed in the current conversation.
signal closed
var entries: Array=[]
var frame: PanelContainer
var scroll: ScrollContainer
var return_button: Button

func configure(lines: Array):
	entries=lines.duplicate(true)
	name="DialogueHistory"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new();shade.color=Color(.06,.09,.13,.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	frame=PanelContainer.new();add_child(frame)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);frame.add_child(column)
	var title=Label.new();title.text="Conversation history";title.add_theme_font_size_override("font_size",30)
	title.add_theme_font_override("font",preload("res://assets/fonts/CormorantGaramond.ttf"));column.add_child(title)
	var hint=Label.new();hint.text="Revealed lines from this conversation · H / Escape: return"
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_font_size_override("font_size",16);column.add_child(hint)
	scroll=ScrollContainer.new();scroll.name="HistoryScroll";scroll.focus_mode=Control.FOCUS_ALL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var transcript=VBoxContainer.new();transcript.name="Transcript";transcript.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	transcript.add_theme_constant_override("separation",18);scroll.add_child(transcript)
	if entries.is_empty():
		var empty=Label.new();empty.text="No lines have been revealed yet.";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;transcript.add_child(empty)
	for line in entries:
		var entry=VBoxContainer.new();entry.add_theme_constant_override("separation",4);transcript.add_child(entry)
		var speaker=Label.new();speaker.text=line.speaker;speaker.add_theme_font_size_override("font_size",20)
		speaker.add_theme_color_override("font_color",Color("36566e"));entry.add_child(speaker)
		var speech=Label.new();speech.text=line.text;speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		speech.add_theme_font_size_override("font_size",20);entry.add_child(speech)
	return_button=Button.new();return_button.text="Return to conversation";return_button.custom_minimum_size.y=42
	return_button.pressed.connect(func():closed.emit());column.add_child(return_button)
	scroll.focus_next=scroll.get_path_to(return_button);scroll.focus_previous=scroll.focus_next
	return_button.focus_next=return_button.get_path_to(scroll);return_button.focus_previous=return_button.focus_next
	resized.connect(arrange);frame.minimum_size_changed.connect(arrange);arrange()
	var owner_ref=weakref(self);var tree=get_tree()
	(func():
		await tree.process_frame;await tree.process_frame
		var owner=owner_ref.get_ref()
		if owner==null or not owner.is_inside_tree():return
		owner.scroll.scroll_vertical=int(owner.scroll.get_v_scroll_bar().max_value)
		owner.return_button.grab_focus()).call_deferred()

func arrange():
	if not is_instance_valid(frame):return
	frame.size=Vector2(minf(1040,size.x-64),minf(720,size.y-64))
	frame.position=(size-frame.size)*.5

func navigate(code: int):
	match code:
		KEY_UP:scroll.scroll_vertical-=44
		KEY_DOWN:scroll.scroll_vertical+=44
		KEY_PAGEUP:scroll.scroll_vertical-=int(scroll.size.y*.8)
		KEY_PAGEDOWN:scroll.scroll_vertical+=int(scroll.size.y*.8)
		KEY_HOME:scroll.scroll_vertical=0
		KEY_END:scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
