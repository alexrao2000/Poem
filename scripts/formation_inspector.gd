extends VBoxContainer
# Read-only enemy preparation details use the private preview's effective stats.

const Icons=preload("res://scripts/weapon_icons.gd")
var portraits
var portrait: TextureRect
var heading: Label
var job: Label
var item: Label
var icon: TextureRect
var stats: Label
var behavior: Label

func configure(art):
 name="FormationInspector";portraits=art;add_theme_constant_override("separation",8)
 var identity=HBoxContainer.new();identity.add_theme_constant_override("separation",8);add_child(identity)
 portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(82,96);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;identity.add_child(portrait)
 var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;identity.add_child(titles)
 heading=make_label(titles,23);job=make_label(titles,16)
 var weapon=HBoxContainer.new();weapon.add_theme_constant_override("separation",8);add_child(weapon)
 icon=TextureRect.new();icon.custom_minimum_size=Vector2(28,28);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;weapon.add_child(icon)
 item=make_label(weapon,16);item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 stats=make_label(self,17);behavior=make_label(self,15)

func make_label(parent: Control,size_value: int) -> Label:
 var label=Label.new();label.add_theme_font_size_override("font_size",size_value);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label

func inspect(game,unit: Dictionary):
 portrait.texture=portraits.get_unit_portrait(unit);heading.text=unit.name;job.text=game.class_name_for(unit)+(" · Commander" if unit.get("boss",false) else "")
 var equipment=game.item_for(unit);item.text=equipment.name+" · "+game.range_text(unit)+" tiles";icon.texture=Icons.get_item_icon(equipment.id,unit.weapon)
 stats.text="HP %d/%d · %s %d\nDEF %d · RES %d · SPD %d\nMOVE %d"%[unit.hp,unit.max_hp,"HEAL" if unit.weapon=="staff" else "ATK",game.healing_power(unit) if unit.weapon=="staff" else game.attack_power(unit),unit.defense,game.resistance_for(unit),game.attack_speed(unit),game.movement_allowance(unit)]
 behavior.text="Staff support · cannot attack." if unit.weapon=="staff" else "Red tiles: attacks from this position." if unit.get("ai","")=="guard" else "Red tiles: possible attacks after moving. Other units can block the route."
