extends Label
# A short line of dialogue or a recovery status above the action.
const DISPLAY_FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const PALETTES={
 "finish":{"background":Color("192c3aed"),"border":Color("ab986f"),"ink":Color("f7ebd5")},
 "rescue":{"background":Color("3b2c2ced"),"border":Color("c09167"),"ink":Color("ffe3bd")},
 "revival":{"background":Color("233b38ed"),"border":Color("87aa82"),"ink":Color("e2f5d5")},
}
var plate=StyleBoxFlat.new()

func configure(parent: Control):
 name="CombatCaption";mouse_filter=Control.MOUSE_FILTER_IGNORE
 horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 add_theme_font_override("font",DISPLAY_FONT)
 plate.set_border_width_all(1);plate.set_corner_radius_all(4)
 plate.content_margin_left=18;plate.content_margin_right=18
 plate.content_margin_top=6;plate.content_margin_bottom=6
 add_theme_stylebox_override("normal",plate)
 hide();parent.add_child(self)
 parent.resized.connect(arrange)

func show_line(line: String,kind: String):
 var tone=PALETTES[kind]
 plate.bg_color=tone.background;plate.border_color=tone.border
 add_theme_color_override("font_color",tone.ink)
 text=line
 arrange();show()

func arrange():
 var width=get_parent().size.x
 var budget=maxf(1,width-44)
 var font_size=26
 var padding=plate.get_minimum_size()
 var measured=DISPLAY_FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_CENTER,-1,font_size).x
 while measured+padding.x>budget and font_size>18:
  font_size-=1
  measured=DISPLAY_FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_CENTER,-1,font_size).x
 add_theme_font_size_override("font_size",font_size)
 var height=ceili(DISPLAY_FONT.get_height(font_size)+padding.y)
 size=Vector2(minf(budget,ceili(measured+padding.x)),height)
 position=Vector2((width-size.x)*.5,34)
