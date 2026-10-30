extends RefCounted
## Short windows keep navigation visible; only reading areas need to scroll.
static func configure(ui: Control):
	if ui.has_meta("menu_layout"):return
	ui.set_meta("menu_layout",true)
	ui.resized.connect(func():apply(ui))
	apply.bind(ui).call_deferred()

static func apply(ui: Control):
	if not is_instance_valid(ui) or ui.is_queued_for_deletion():return
	var compact=ui.size.y<760
	for state in ["normal","hover","pressed","disabled"]:
		var style=ui.theme.get_stylebox(state,"Button").duplicate()
		style.content_margin_top=6 if compact else 12;style.content_margin_bottom=style.content_margin_top
		ui.theme.set_stylebox(state,"Button",style)
	for button in ui.find_children("*","Button",true,false):
		if not button.has_meta("menu_height"):button.set_meta("menu_height",button.custom_minimum_size.y)
		button.custom_minimum_size.y=minf(34,button.get_meta("menu_height")) if compact else button.get_meta("menu_height")
	for column in ui.find_children("*","VBoxContainer",true,false):
		if not column.has_meta("menu_gap"):column.set_meta("menu_gap",column.get_theme_constant("separation"))
		column.add_theme_constant_override("separation",mini(6,column.get_meta("menu_gap")) if compact else column.get_meta("menu_gap"))
	for scroll in ui.find_children("*","ScrollContainer",true,false):
		# OptionButton popups own internal scrolling; leave those controls alone.
		if scroll.get_child_count()==0:continue
		scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
