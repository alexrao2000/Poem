extends PanelContainer
## Portrait and deployment state lead; the dossier keeps detailed statistics.
signal inspect_requested
signal deployment_requested
var portrait_button: Button
var deploy_button: Button
var state_label: Label

func label_in(parent: Node,text_value: String,font_size: int,color: Color) -> Label:
 var label=Label.new();label.text=text_value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
 parent.add_child(label);return label

func configure(unit: Dictionary,class_title: String,portrait: Texture2D,weapon: Dictionary,deployed: bool,available: bool,support_ready: bool,full: bool):
 name="Company_"+unit.id;set_meta("unit_id",unit.id);size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var ink=Color("34566d") if available else Color("827c70")
 var style=StyleBoxFlat.new();style.bg_color=Color("f4efdf") if available else Color("ded8c8")
 style.border_color=Color("40667d") if deployed else Color("b8a986")
 style.set_border_width_all(2 if deployed else 1);style.content_margin_left=10;style.content_margin_right=10
 style.content_margin_top=8;style.content_margin_bottom=8;add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",6);add_child(column)
 state_label=label_in(column,"IN COMPANY" if deployed else "RESERVE" if available else "JOINS IN CHAPTER %02d"%[int(unit.join)+1],12,ink)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);column.add_child(row)
 portrait_button=Button.new();portrait_button.icon=portrait;portrait_button.expand_icon=true
 portrait_button.custom_minimum_size=Vector2(82,94);portrait_button.disabled=not available
 portrait_button.tooltip_text="Open "+unit.name+"'s dossier" if available else "Not yet recruited"
 for state in ["normal","hover","pressed","disabled"]:
  var background=StyleBoxFlat.new();background.bg_color=Color("d2dce0") if state=="hover" else Color("e0ded2")
  background.set_content_margin_all(3);portrait_button.add_theme_stylebox_override(state,background)
 portrait_button.pressed.connect(func():inspect_requested.emit());row.add_child(portrait_button)
 var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.add_theme_constant_override("separation",3);row.add_child(info)
 var heading=label_in(info,unit.name,26,ink);heading.add_theme_font_override("font",preload("res://assets/fonts/CormorantGaramond.ttf"))
 label_in(info,class_title,14,Color("645e51"));label_in(info,"Lv %d   ·   HP %d"%[unit.level,unit.max_hp],13,Color("645e51"))
 var gear=HBoxContainer.new();gear.add_theme_constant_override("separation",5);info.add_child(gear)
 var icon=TextureRect.new();icon.texture=preload("res://scripts/weapon_icons.gd").get_icon(weapon.kind)
 icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.custom_minimum_size=Vector2(20,20);gear.add_child(icon)
 var item=label_in(gear,weapon.name,12,Color("806537"));item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 item.tooltip_text=weapon.name
 label_in(column,"Support conversation ready" if support_ready else "Open portrait for dossier" if available else "The road will bring you together",12,Color("906b2e") if support_ready else Color("817b6b"))
 deploy_button=Button.new();deploy_button.text="Remove" if deployed else "Add to company" if available else "Not yet recruited"
 deploy_button.custom_minimum_size.y=36;deploy_button.disabled=not available or (full and not deployed)
 deploy_button.tooltip_text="Return "+unit.name+" to reserve" if deployed else "Choose up to six allies" if full else "Deploy "+unit.name
 deploy_button.pressed.connect(func():deployment_requested.emit());column.add_child(deploy_button)
