extends Control
## Own the temporary presentation clock only for the cinematic's lifetime.
## Audio streams keep their normal playhead and pitch while animation speeds up.
var original_scale=1.0
var active=false
var accelerated=false
var hint: Label

func configure(parent: Control):
 name="CombatPlayback";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=15
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 original_scale=Engine.time_scale;active=true
 hint=Label.new();hint.name="PlaybackHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.add_theme_font_size_override("font_size",14);hint.add_theme_color_override("font_color",Color("f4e7c6"))
 hint.add_theme_color_override("font_outline_color",Color("253342"));hint.add_theme_constant_override("outline_size",3)
 add_child(hint);hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 hint.offset_left=22;hint.offset_right=-22;hint.offset_top=-26;hint.offset_bottom=-6
 set_accelerated(Input.is_key_pressed(KEY_SHIFT))

func set_accelerated(value: bool):
 if not active:return
 accelerated=value;Engine.time_scale=original_scale*(2.0 if value else 1.0)
 hint.text="FAST ×2  ·  Release Shift: normal  ·  Tab: skip" if value else "Hold Shift: fast-forward  ·  Tab: skip"

func _input(event):
 if not active or not event is InputEventKey:return
 if event.keycode==KEY_SHIFT or event.physical_keycode==KEY_SHIFT:
  if not event.echo:set_accelerated(event.pressed)
  get_viewport().set_input_as_handled()

func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:set_accelerated(false)

func stop():
 if not active:return
 Engine.time_scale=original_scale;active=false;accelerated=false
 set_process_input(false);hide()

func _exit_tree():stop()
