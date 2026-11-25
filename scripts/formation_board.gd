extends Control
# A preparation-only map uses copied chapter data and a private slot draft.
# Numbered buttons swap occupied or empty starting tiles; only Apply commits it.

signal changed
const Icons=preload("res://scripts/terrain_icons.gd")
const COLORS={".":"aeb58f","p":"cab58d","=":"ad9371","f":"758d70","h":"a19a79","o":"9b9c8c","+":"b7c5aa","#":"6e7471","~":"799da7"}
var chapter={}
var draft=[]
var defaults=[]
var units={}
var map_sprites: RefCounted
var preview_rules
var preview_order=[]
var enemy_markers=[]
var foes: Array[Button]=[]
var inspected_id=""
var danger={}
var show_all_reach=false
var all_danger={}
var tactics=preload("res://scripts/tactics.gd").new()
var slots: Array[Button]=[]
var selected=-1
var map_rect=Rect2()
var cell_size=0.0

func configure(game,catalog: RefCounted):
 name="FormationBoard";chapter=game.info().duplicate(true);map_sprites=catalog
 draft=game.deployment_slots();defaults=game.deployment_slots(false)
 preview_rules=game.get_script().new(game.content)
 if preview_rules.restore_save(game.save_data("camp"))!="camp":
  push_error("Formation preview could not restore the preparation state");return
 for unit in game.deployment_units():units[unit.id]=unit.duplicate(true)
 mouse_filter=Control.MOUSE_FILTER_IGNORE;size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
 custom_minimum_size=Vector2(360,300)
 for index in range(draft.size()):
  var button=Button.new();button.name="StartingSlot"+str(index+1);button.z_index=1;button.toggle_mode=true;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  for state in ["normal","hover","pressed","focus"]:
   var style=StyleBoxFlat.new();style.bg_color=Color("284b61");style.bg_color.a=.84 if state=="normal" else .96
   style.border_color=Color("f0ce7c") if state in ["pressed","focus"] else Color("a7d0dc");style.set_border_width_all(2);style.set_corner_radius_all(3)
   button.add_theme_stylebox_override(state,style)
  var sprite=TextureRect.new();sprite.name="AllySprite";sprite.mouse_filter=Control.MOUSE_FILTER_IGNORE;sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  button.add_child(sprite);sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);sprite.offset_left=5;sprite.offset_right=-2;sprite.offset_top=2;sprite.offset_bottom=-2
  var number=Label.new();number.text=str(index+1);number.mouse_filter=Control.MOUSE_FILTER_IGNORE;number.position=Vector2(2,0);number.add_theme_font_size_override("font_size",12);number.add_theme_color_override("font_color",Color("fff0c4"));number.add_theme_color_override("font_outline_color",Color("233643"));number.add_theme_constant_override("outline_size",3);button.add_child(number)
  var warning=Label.new();warning.name="ThreatBadge";warning.text="!";warning.mouse_filter=Control.MOUSE_FILTER_IGNORE;warning.add_theme_font_size_override("font_size",16);warning.add_theme_color_override("font_color",Color("fff0c4"));warning.add_theme_color_override("font_outline_color",Color("8c263b"));warning.add_theme_constant_override("outline_size",4);button.add_child(warning)
  button.pressed.connect(func():choose(index));add_child(button);slots.append(button)
 resized.connect(arrange);refresh();arrange()

func choose(index: int):
 if index<0 or index>=draft.size():return
 inspected_id="";danger.clear()
 if selected<0:selected=index
 elif selected==index:selected=-1
 else:
  var previous=draft[selected];draft[selected]=draft[index];draft[index]=previous;selected=-1
 refresh();changed.emit()

func restore_defaults():
 draft=defaults.duplicate();selected=-1;inspected_id="";danger.clear();refresh();changed.emit()

func inspected_unit() -> Dictionary:
 for unit in preview_rules.living("enemy"):
  if unit.id==inspected_id:return unit
 return {}

func inspect_enemy(id: String):
 inspected_id=id;selected=-1
 refresh();changed.emit()

func set_all_reach(enabled: bool):
 show_all_reach=enabled;all_danger.clear();refresh();changed.emit()

func prepare_enemy_buttons():
 if not foes.is_empty():return
 for unit in preview_rules.living("enemy"):
  var id=unit.id;var button=Button.new();button.name="PlanEnemy_"+id;button.toggle_mode=true;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  for state in ["normal","hover","pressed","focus"]:
   var style=StyleBoxFlat.new();style.bg_color=Color(0,0,0,0);style.border_color=Color("f5d386") if state in ["pressed","focus"] else Color("ca8580");style.set_border_width_all(0 if state=="normal" else 2);style.set_corner_radius_all(3);button.add_theme_stylebox_override(state,style)
  button.pressed.connect(func():inspect_enemy(id));add_child(button);foes.append(button)

func refresh():
 var positions_changed=draft!=preview_order
 if positions_changed:
  if not preview_rules.set_formation_order(draft):return
  preview_rules.start_battle();preview_order=draft.duplicate()
  enemy_markers=preview_rules.living("enemy").map(func(unit):return {"position":[unit.x,unit.y],"name":unit.name,"job":unit.job})
 prepare_enemy_buttons()
 var enemies=preview_rules.living("enemy")
 for index in range(foes.size()):
  foes[index].tooltip_text=enemies[index].name+" · "+preview_rules.class_name_for(enemies[index]);foes[index].set_pressed_no_signal(enemies[index].id==inspected_id)
 if not show_all_reach:all_danger.clear()
 elif positions_changed or all_danger.is_empty():
  all_danger.clear()
  for enemy in enemies:all_danger.merge(tactics.threatened_tiles(preview_rules,enemy))
 var inspected=inspected_unit()
 danger=tactics.threatened_tiles(preview_rules,inspected) if not inspected.is_empty() else {}
 for index in range(slots.size()):
  var unit=units.get(draft[index],{})
  slots[index].set_pressed_no_signal(index==selected)
  var tile=chapter.deployment_positions[index];var threatened=danger.has(Vector2i(tile[0],tile[1])) or all_danger.has(Vector2i(tile[0],tile[1]))
  slots[index].get_node("ThreatBadge").visible=threatened
  slots[index].tooltip_text="Slot %d · %s"%[index+1,unit.get("name","Empty")]+("\nInside possible enemy attack reach" if threatened else "")
  slots[index].get_node("AllySprite").texture=map_sprites.preview_sprite(unit) if not unit.is_empty() else null
 arrange()

func arrange():
 if chapter.is_empty():return
 var dimensions=Vector2(chapter.map[0].length(),chapter.map.size())
 var compact=size.x<420.0
 var inset=4.0 if compact else 12.0
 var gutter=.5 if compact else 1.0
 cell_size=minf((size.x-2*inset)/dimensions.x,(size.y-2*inset)/dimensions.y)
 map_rect=Rect2((size-dimensions*cell_size)*.5,dimensions*cell_size)
 for index in range(slots.size()):
  var point=chapter.deployment_positions[index]
  slots[index].position=map_rect.position+Vector2(point[0],point[1])*cell_size+Vector2.ONE*gutter
  slots[index].size=Vector2.ONE*(cell_size-2*gutter)
  var warning=slots[index].get_node("ThreatBadge");warning.position=Vector2(maxf(0,slots[index].size.x-warning.get_minimum_size().x-2),0)
 for index in range(foes.size()):
  var point=enemy_markers[index].position
  foes[index].position=map_rect.position+Vector2(point[0],point[1])*cell_size+Vector2.ONE*gutter
  foes[index].size=Vector2.ONE*(cell_size-2*gutter)
 queue_redraw()

func _draw():
 if chapter.is_empty() or cell_size<=0:return
 draw_rect(map_rect.grow(4),Color("78684b"))
 for y in range(chapter.map.size()):
  for x in range(chapter.map[y].length()):
   var symbol=chapter.map[y][x];var rect=Rect2(map_rect.position+Vector2(x,y)*cell_size,Vector2.ONE*cell_size)
   draw_rect(rect,Color(COLORS.get(symbol,"aeb58f")));draw_rect(rect,Color(1,1,.9,.10),false,1)
   if symbol not in [".","p"]:draw_texture_rect(Icons.get_icon(symbol),rect.grow(-cell_size*.14),false,Color(1,1,1,.6))
 for point in all_danger:
  if not danger.has(point):draw_rect(Rect2(map_rect.position+Vector2(point)*cell_size,Vector2.ONE*cell_size).grow(-1),Color(.65,.12,.19,.18))
 for point in danger:
  draw_rect(Rect2(map_rect.position+Vector2(point)*cell_size,Vector2.ONE*cell_size).grow(-1),Color(.65,.12,.19,.34))
 for enemy in enemy_markers:
  var point=map_rect.position+(Vector2(enemy.position[0],enemy.position[1])+Vector2.ONE*.5)*cell_size
  draw_circle(point,cell_size*.15,Color("8c3c3e"));draw_arc(point,cell_size*.15,0,TAU,16,Color("f2c9a4"),1,true)
 var objective=chapter.objective_position
 var center=map_rect.position+(Vector2(objective[0],objective[1])+Vector2.ONE*.5)*cell_size
 if chapter.objective=="seize":
  var radius=cell_size*.30
  draw_colored_polygon(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)]),Color("f0d180"))
