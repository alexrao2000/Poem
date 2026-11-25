extends PanelContainer
# A compact map readout uses the same terrain profile as movement and combat.
const Icons=preload("res://scripts/terrain_icons.gd")
const FONT=preload("res://assets/fonts/CormorantGaramond.ttf")
const Valley=preload("res://scripts/world_map_battle.gd")
const STANDARD_STATUS={"player":"Standard held by your company","enemy":"Standard occupied by enemy","unheld":"Standard unheld"}
var heading: Label
var icon: TextureRect
var values: Label
var detail: Label
var place: Label
var standard: Label
var dialogue: Label
var survey: Label
var show_survey=false
var places: Dictionary={}
var tile=Vector2i(-1,-1)

func configure(parent: Control):
 name="TerrainCard";mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(self)
 position=Vector2(22,118);custom_minimum_size=Vector2(238,80)
 var column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_theme_constant_override("separation",2);add_child(column)
 var identity=HBoxContainer.new();identity.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity.add_theme_constant_override("separation",8);column.add_child(identity)
 icon=TextureRect.new();icon.name="TerrainIcon";icon.custom_minimum_size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity.add_child(icon)
 heading=Label.new();heading.add_theme_font_override("font",FONT);heading.add_theme_font_size_override("font_size",22)
 heading.add_theme_color_override("font_color",Color("63543a"));heading.size_flags_vertical=Control.SIZE_SHRINK_CENTER;identity.add_child(heading)
 heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 survey=Label.new();survey.name="TerrainSurveyMark";survey.hide()
 survey.add_theme_font_size_override("font_size",13);survey.add_theme_color_override("font_color",Color("63543a"))
 survey.size_flags_vertical=Control.SIZE_SHRINK_CENTER;identity.add_child(survey)
 values=Label.new();values.add_theme_font_size_override("font_size",14);column.add_child(values)
 detail=Label.new();detail.add_theme_font_size_override("font_size",13);detail.add_theme_color_override("font_color",Color("777163"));column.add_child(detail)
 place=Label.new();place.name="TerrainLocation";place.hide()
 place.add_theme_font_override("font",FONT);place.add_theme_font_size_override("font_size",17)
 place.add_theme_color_override("font_color",Color("63543a"));place.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 column.add_child(place)
 standard=Label.new();standard.name="TerrainStandard";standard.hide()
 standard.add_theme_font_size_override("font_size",13);standard.add_theme_color_override("font_color",Color("63543a"))
 column.add_child(standard)
 dialogue=Label.new();dialogue.name="TerrainDialogue";dialogue.hide()
 dialogue.add_theme_font_size_override("font_size",13);dialogue.add_theme_color_override("font_color",Color("35655b"))
 column.add_child(dialogue)
 for label in [heading,values,detail,place,standard,dialogue,survey]:label.mouse_filter=Control.MOUSE_FILTER_IGNORE

func inspect(game,point: Vector2i):
 tile=point
 var bounds=game.board_size();visible=point.x>=0 and point.y>=0 and point.x<bounds.x and point.y<bounds.y
 if not visible:return
 var terrain=game.terrain_profile(point)
 icon.texture=Icons.get_icon(game.terrain(point))
 heading.text=terrain.name.to_upper()
 survey.visible=show_survey
 if show_survey:survey.text=Valley.survey_mark(point)
 values.text="Move %d   Cover %d   Avoid +%d"%[terrain.move,terrain.cover,terrain.avoid] if terrain.move>0 else "Cannot enter"
 detail.text="Restores %d HP each turn"%terrain.heal if terrain.heal>0 else "Slows movement" if terrain.move>1 else "Passable ground" if terrain.move>0 else "Find a route around"
 var had_place=place.visible
 var had_standard=standard.visible
 var had_dialogue=dialogue.visible
 place.text=" · ".join(places.get(point,[]))
 place.visible=not place.text.is_empty()
 standard.visible=show_survey and point in game.capture_tiles()
 if standard.visible:standard.text=STANDARD_STATUS[Valley.standard_claim(game.at(point))]
 var events=game.site_events_at(point)
 var can_refill=events.any(func(scene):return scene.get("refill_tonics",false))
 var has_dialogue=events.any(func(scene):return not scene.lines.is_empty())
 var can_recruit=events.any(func(scene):return not game.site_recruit(scene).is_empty())
 dialogue.text="Dialogue · Tonic refill" if has_dialogue and can_refill else "Dialogue on action" if has_dialogue else "Field tonic refill"
 if can_recruit:
  var benefits=PackedStringArray(["Recruit"])
  if has_dialogue:benefits.append("Dialogue")
  if can_refill:benefits.append("Tonic refill")
  dialogue.text=" · ".join(benefits) if benefits.size()>1 else "Recruit on action"
 dialogue.visible=not events.is_empty()
 if had_place!=place.visible or had_standard!=standard.visible or had_dialogue!=dialogue.visible:reset_size()
