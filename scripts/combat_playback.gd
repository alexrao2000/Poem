extends Control
## Own the temporary presentation clock only for the cinematic's lifetime.
## Audio streams keep their normal playhead and pitch at every playback speed.
var original_scale=1.0
var active=false
var accelerated=false
var hint: Label
signal skip_requested
var fast_button: Button
var skip_button: Button
var pointer_fast=false
var keyboard_fast=false
var slow_available=false
var keyboard_slow=false
var slowed=false
var skip_sent=false

func configure(parent: Control,debug_slow=false):
 name="CombatPlayback";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=15
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 original_scale=Engine.time_scale;active=true;slow_available=debug_slow
 hint=Label.new();hint.name="PlaybackHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.add_theme_font_size_override("font_size",14);hint.add_theme_color_override("font_color",Color("f4e7c6"))
 hint.add_theme_color_override("font_outline_color",Color("253342"));hint.add_theme_constant_override("outline_size",3)
 add_child(hint);hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 hint.offset_left=22;hint.offset_right=-22;hint.offset_top=-26;hint.offset_bottom=-6
 fast_button=make_button("Fast ×2","FastForward",-134)
 fast_button.toggle_mode=true
 fast_button.tooltip_text="Toggle fast-forward. You can also hold Shift."
 fast_button.toggled.connect(func(value):pointer_fast=value;refresh_speed())
 skip_button=make_button("Skip","SkipCombat",-82)
 skip_button.tooltip_text="Skip this exchange. You can also press Tab."
 skip_button.pressed.connect(request_skip)
 resized.connect(arrange_buttons);arrange_buttons()
 keyboard_fast=Input.is_key_pressed(KEY_SHIFT)
 keyboard_slow=slow_available and Input.is_key_pressed(KEY_Z)
 refresh_speed()

func make_button(text: String,node_name: String,top: float) -> Button:
 var button=Button.new();button.name=node_name;button.text=text
 button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 button.add_theme_font_size_override("font_size",15)
 for state in ["normal","hover","pressed","disabled"]:
  var style=StyleBoxFlat.new();style.bg_color=Color("344c5b") if state=="hover" else Color("4c6370") if state=="pressed" else Color("172c3de6")
  style.border_color=Color("e7ce91") if state in ["hover","pressed"] else Color("9b927a")
  style.set_border_width_all(1);style.set_corner_radius_all(3);button.add_theme_stylebox_override(state,style)
 var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("f4d489");focus.set_border_width_all(2);focus.set_corner_radius_all(3)
 button.add_theme_stylebox_override("focus",focus)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("fff1d5"))
 add_child(button);button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 button.offset_top=top;button.offset_bottom=top+44
 return button

func arrange_buttons():
 var half_width=clampf(size.x*.055,41,56)
 for button in [fast_button,skip_button]:
  button.offset_left=-half_width;button.offset_right=half_width

func refresh_speed():
 if not active:return
 var fast_requested=pointer_fast or keyboard_fast
 slowed=slow_available and keyboard_slow
 accelerated=fast_requested and not slowed
 Engine.time_scale=original_scale*(.5 if slowed else 2.0 if accelerated else 1.0)
 if is_instance_valid(fast_button):fast_button.set_pressed_no_signal(fast_requested)
 var state="HALF SPEED  ·  " if slowed else "FAST ×2  ·  " if accelerated else ""
 var controls="Hold Shift to fast-forward  ·  "
 if slow_available:controls+="Hold Z for half speed  ·  "
 hint.text=state+controls+"Tab to skip"

func request_skip():
 if not active or skip_sent:return
 skip_sent=true;skip_button.disabled=true;skip_requested.emit()

func _input(event):
 if not active or not event is InputEventKey:return
 var fast_key=event.keycode==KEY_SHIFT or event.physical_keycode==KEY_SHIFT
 var slow_key=slow_available and (event.keycode==KEY_Z or event.physical_keycode==KEY_Z)
 if not fast_key and not slow_key:return
 if not event.echo:
  if fast_key:keyboard_fast=event.pressed
  else:keyboard_slow=event.pressed
  refresh_speed()
 get_viewport().set_input_as_handled()

func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  pointer_fast=false;keyboard_fast=false;keyboard_slow=false;refresh_speed()

func stop():
 if not active:return
 Engine.time_scale=original_scale;active=false;accelerated=false;slowed=false
 pointer_fast=false;keyboard_fast=false;keyboard_slow=false
 if is_instance_valid(fast_button):fast_button.disabled=true;fast_button.set_pressed_no_signal(false)
 if is_instance_valid(skip_button):skip_button.disabled=true
 set_process_input(false);hide()

func _exit_tree():stop()
