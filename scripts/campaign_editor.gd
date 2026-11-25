extends VBoxContainer
signal closed
signal playtest_requested(start: int, resume: bool, single_battle: bool)
signal draft_selection_changed(key: String, chapter: int)
const Draft=preload("res://scripts/campaign_draft.gd")
const Grid=preload("res://scripts/campaign_editor_grid.gd")
const Route=preload("res://scripts/campaign_route.gd")
const Settings=preload("res://scripts/campaign_settings.gd")
const Trials=preload("res://scripts/campaign_trials.gd")
const DebugSession=preload("res://scripts/debug_session.gd")
const MAX_CAMPAIGN_FILE_BYTES=4*Draft.MAX_DRAFT_LENGTH
const TOOLS=["Terrain","Deployment","Enemy","Hard-mode enemy","Objective","Move placement","Extra standard"]
const MOVE_PLACEMENT=5
const EXTRA_STANDARD=6
const GOLD=Color("896937")
var draft: RefCounted
var library: RefCounted
var playtest_setup: Dictionary
var browser_campaign_file_callback
var draft_key=""
var selected=0
var active_tab=0
var brush=0
var selected_person=0
var selected_bond=0
var selected_enemy=0
var selected_scene=0
var selected_site_scene=0
var selected_stock=0
var selected_arrival=0
var survey_chapter=""
var encounter_panel: VBoxContainer
var grid: Control
var terrain_changed=false
var fill_connected=false
var fill_terrain: CheckButton
var undo_terrain: Button
var redo_terrain: Button
var placement_hint: Label
var grid_help: Label
var status: Label
var source_chapter: OptionButton
var terrain_choice: OptionButton
var job_choice: OptionButton
var ai_choice: OptionButton
var enemy_name: LineEdit
var play_buttons=[]
var dirty: bool:
 get:return draft.dirty
 set(value):draft.dirty=value

func configure(model,storage,key: String,index: int,setup: Dictionary):
 draft=model;library=storage;draft_key=key;playtest_setup=setup
 selected=clampi(index,0,draft.data.chapters.size()-1)
 size_flags_vertical=SIZE_EXPAND_FILL
 add_theme_constant_override("separation",8)
 rebuild()

func rebuild():
 for child in get_children():remove_child(child);child.queue_free()
 play_buttons.clear()
 heading(self,"Campaign editor",34)
 var toolbar=HFlowContainer.new()
 toolbar.add_theme_constant_override("h_separation",8)
 toolbar.add_theme_constant_override("v_separation",8)
 add_child(toolbar)
 action(toolbar,"New draft",new_draft)
 action(toolbar,"Open drafts",open_library)
 action(toolbar,"Save draft",save_draft).name="SaveCampaignDraft"
 action(toolbar,"Transfer JSON",show_transfer)
 action(toolbar,"Check campaign",show_readiness).name="EditorCheckCampaign"
 var chapter_bar=row(self)
 source_chapter=OptionButton.new();source_chapter.name="EditorChapter";source_chapter.fit_to_longest_item=false;source_chapter.clip_text=true
 source_chapter.custom_minimum_size.y=42;source_chapter.size_flags_horizontal=SIZE_EXPAND_FILL;chapter_bar.add_child(source_chapter)
 for index in draft.data.chapters.size():
  var chapter=draft.data.chapters[index]
  source_chapter.add_item("%02d · %s%s"%[index+1,chapter.level.title," · Section start" if chapter.section else ""])
 source_chapter.select(selected);source_chapter.item_selected.connect(select_chapter)
 action(chapter_bar,"Move up",func():move_chapter(-1),selected==0).size_flags_horizontal=SIZE_FILL
 action(chapter_bar,"Move down",func():move_chapter(1),selected==draft.data.chapters.size()-1).size_flags_horizontal=SIZE_FILL
 var steps=row(self)
 var full=draft.data.chapters.size()>=Draft.MAX_CHAPTERS
 action(steps,"Add chapter",func():insert_chapter(false),full)
 action(steps,"Duplicate",func():insert_chapter(true),full)
 action(steps,"Add valley battle",func():insert_chapter(false,true),full).name="AddValleyBattle"
 action(steps,"Remove",confirm_remove,draft.data.chapters.size()<=1)
 var book=TabContainer.new();book.name="CampaignEditorTabs";book.size_flags_vertical=SIZE_EXPAND_FILL;add_child(book)
 build_battle(page(book,"Battle"))
 encounter_panel=page(book,"Encounters")
 build_story(page(book,"Story"))
 var route_panel=page(book,"Route")
 var refresh_route=build_route(route_panel)
 build_company(page(book,"Company"))
 build_bonds(page(book,"Bonds"))
 build_rules(page(book,"Rules"))
 var encounters_tab=book.get_tab_idx_from_control(encounter_panel.get_parent())
 var route_tab=book.get_tab_idx_from_control(route_panel.get_parent())
 book.current_tab=active_tab
 if active_tab==encounters_tab:build_encounters()
 book.tab_changed.connect(func(index):
  active_tab=index
  if index==encounters_tab:build_encounters()
  if index==route_tab:refresh_route.call())
 status=heading(self,"",15);status.name="EditorStatus"
 var footer=row(self)
 play_buttons.append(action(footer,"Play from start",func():launch(0,false)))
 play_buttons.append(action(footer,"Play chapter",func():launch(selected,false,true)))
 play_buttons[-1].name="PlayEditedChapter"
 play_buttons.append(action(footer,"Resume playtest",func():launch(selected,true,true)))
 action(footer,"Return",func():closed.emit())
 validation()

func chapter() -> Dictionary:return draft.data.chapters[selected]
func level() -> Dictionary:return chapter().level

func build_battle(panel: VBoxContainer):
 var layout=level()
 var parameters=GridContainer.new();parameters.columns=2
 parameters.add_theme_constant_override("h_separation",12);parameters.add_theme_constant_override("v_separation",8);panel.add_child(parameters)
 field_label(parameters,"Objective",choice(Draft.OBJECTIVES,layout.objective,func(value):
  layout.objective=value;grid.marks=draft.valley_marks(selected);refresh_linked_standards();show_brush_options();changed()))
 field_label(parameters,"Phase limit",spin(int(layout.turn_limit),1,99,func(value):layout.turn_limit=value;changed()))
 field_label(parameters,"Environment",choice(Draft.ENVIRONMENTS,layout.environment,func(value):layout.environment=value;changed()))
 field_label(parameters,"Score",choice(draft.music_ids,layout.score_theme,func(value):layout.score_theme=value;changed()))
 var width=spin(layout.map[0].length(),Draft.MIN_BOARD.x,Draft.MAX_BOARD.x,Callable())
 var height=spin(layout.map.size(),Draft.MIN_BOARD.y,Draft.MAX_BOARD.y,Callable())
 var fixed_chart=layout.presentation=="valley_table"
 width.editable=not fixed_chart;height.editable=not fixed_chart
 field_label(parameters,"Width",width);field_label(parameters,"Height",height)
 action(panel,"Resize map",func():
  var dimensions=Vector2i(width.value,height.value)
  if dimensions==grid.board_size():return
  draft.terrain_history.erase(chapter().key)
  draft.resize_map(layout,dimensions)
  grid.cursor=grid.cursor.clamp(Vector2i.ZERO,grid.board_size()-Vector2i.ONE)
  grid.queue_redraw();update_terrain_history();changed(),fixed_chart)
 var tools=row(panel)
 var mode=choice(TOOLS,TOOLS[brush],func(value):brush=TOOLS.find(value);show_brush_options())
 mode.name="EditorBrush";tools.add_child(mode)
 var terrains=Draft.Rules.TERRAIN_PROFILES.keys()
 terrain_choice=OptionButton.new();terrain_choice.name="EditorTerrain";terrain_choice.custom_minimum_size.y=42;tools.add_child(terrain_choice)
 for tile in terrains:
  terrain_choice.add_item(Draft.Rules.TERRAIN_PROFILES[tile].name)
  terrain_choice.set_item_metadata(terrain_choice.item_count-1,tile)
 fill_terrain=CheckButton.new();fill_terrain.name="EditorTerrainFill";fill_terrain.text="Fill connected area"
 fill_terrain.button_pressed=fill_connected;tools.add_child(fill_terrain)
 fill_terrain.toggled.connect(func(value):
  fill_connected=value
  if brush==0:
   grid.paint_on_drag=not value
   grid.connect_terrain_strokes=not value)
 job_choice=choice(draft.templates.classes.keys(),"Vanguard",Callable());tools.add_child(job_choice)
 ai_choice=choice(Draft.STRATEGIES,"pursue",Callable());tools.add_child(ai_choice)
 enemy_name=line_edit("","Enemy name",80,Callable());tools.add_child(enemy_name)
 var history=row(panel)
 undo_terrain=action(history,"Undo terrain",func():step_terrain(false));undo_terrain.name="EditorUndoTerrain"
 redo_terrain=action(history,"Redo terrain",func():step_terrain(true));redo_terrain.name="EditorRedoTerrain"
 update_terrain_history()
 grid_help=heading(panel,"",15)
 placement_hint=heading(panel,"",15);placement_hint.name="EditorMovePlacementStatus"
 grid=Grid.new();grid.name="EditorGrid";panel.add_child(grid)
 grid.configure(layout,draft.valley_marks(selected),draft.route_texture() if fixed_chart else null)
 refresh_linked_standards()
 refresh_tile_scene_markers()
 grid.stroke_started.connect(func():terrain_changed=false)
 grid.terrain_step_requested.connect(step_terrain)
 grid.placement_canceled.connect(clear_placement_selection)
 grid.tile_edited.connect(edit_tile)
 grid.terrain_segment_edited.connect(paint_terrain_segment)
 if fixed_chart:
  var inspected=heading(panel,"",15)
  inspected.name="EditorAtlasTile"
  var show_tile=func(point):
   var terrain_name=Draft.Rules.TERRAIN_PROFILES[grid.terrain_at(point)].name
   var site=grid.marks.get(point,{}).get("place","")
   inspected.text="%d, %d · %s"%[point.x,point.y,terrain_name]
   if not site.is_empty():inspected.text+=" · "+site
  grid.tile_inspected.connect(show_tile)
  show_tile.call(grid.cursor)
 show_brush_options()

func show_brush_options():
 var enemy=brush in [2,3]
 terrain_choice.visible=brush==0
 fill_terrain.visible=brush==0
 job_choice.visible=enemy;ai_choice.visible=enemy;enemy_name.visible=enemy
 placement_hint.visible=brush==MOVE_PLACEMENT
 grid_help.visible=brush!=MOVE_PLACEMENT
 grid_help.text="Click or use the arrow keys and Enter. Right-click or Backspace erases. C marks the commander."
 if brush==EXTRA_STANDARD:
  grid_help.text="Place an extra standard. Right-click or Backspace removes it." if level().objective=="seize" else "Choose the seize objective to place standards."
 grid.paint_on_drag=brush not in [MOVE_PLACEMENT,EXTRA_STANDARD] and (brush!=0 or not fill_connected)
 grid.connect_terrain_strokes=brush==0 and not fill_connected
 clear_placement_selection()

func clear_placement_selection():
 grid.marked_placement=Vector2i(-1,-1)
 placement_hint.text="Select a deployment tile or enemy to move it."
 grid.queue_redraw()

func move_placement(point: Vector2i,erase: bool):
 if erase or grid.marked_placement==point:
  clear_placement_selection();return
 if grid.marked_placement.x<0:
  if Draft.placement_at(level(),point).is_empty():return
  grid.marked_placement=point
  placement_hint.text="Choose an empty tile or a placement to swap."
  grid.queue_redraw();return
 if not draft.move_placement(selected,grid.marked_placement,point):
  placement_hint.text="Choose a passable destination."
  return
 clear_placement_selection();changed()

func update_terrain_history():
 undo_terrain.disabled=not draft.can_step_terrain(selected,false)
 redo_terrain.disabled=not draft.can_step_terrain(selected,true)

func step_terrain(redo: bool):
 if grid.stroke_active or not draft.step_terrain(selected,redo):return
 grid.queue_redraw();grid.tile_inspected.emit(grid.cursor);grid.grab_focus()
 update_terrain_history();changed()

func paint_terrain_segment(points: Array[Vector2i],erase: bool):
 var layout=level()
 var symbol="." if erase else terrain_choice.get_selected_metadata()
 var painted=false
 for point in points:
  if layout.map[point.y][point.x]==symbol:continue
  if not painted:
   if not grid.stroke_active or not terrain_changed:draft.remember_terrain(selected)
   terrain_changed=grid.stroke_active
   painted=true
  draft.paint(layout,point,symbol)
 if painted:
  grid.queue_redraw()
  update_terrain_history()
  changed()

func edit_tile(point: Vector2i,erase: bool):
 if brush==MOVE_PLACEMENT:
  move_placement(point,erase);return
 var layout=level()
 var position=[point.x,point.y]
 if brush==EXTRA_STANDARD:
  edit_extra_standard(layout,point,erase);return
 if brush==0:
  if not fill_connected:
   paint_terrain_segment([point],erase);return
  var symbol="." if erase else terrain_choice.get_selected_metadata()
  if not draft.fill_terrain(selected,point,symbol,grid.marks):return
  update_terrain_history()
 elif erase:
  layout.deployment_positions=layout.deployment_positions.filter(func(site):return not same_tile(site,point))
  for group in ["enemies","hard_enemies"]:
   layout[group]=layout[group].filter(func(enemy):return not same_tile(enemy.position,point))
 elif brush==1:
  if layout.deployment_positions.size()<6 and not layout.deployment_positions.any(func(site):return same_tile(site,point)):
   layout.deployment_positions.append(position)
 elif brush in [2,3]:
  var group=layout.enemies if brush==2 else layout.hard_enemies
  var old=group.find_custom(func(enemy):return same_tile(enemy.position,point))
  var enemy={"position":position,"job":job_choice.get_selected_metadata(),"ai":ai_choice.get_selected_metadata(),"name":enemy_name.text}
  if old>=0:
   if group[old].job!=enemy.job:group[old].erase("item")
   group[old].merge(enemy,true)
  elif group.size()<24:group.append(enemy)
 else:
  if point in grid.linked_standards:
   grid_help.text="This tile already has a standard from a route pin.";return
  var standards=layout.get("extra_standards",[])
  var overlap=standards.find_custom(func(tile):return same_tile(tile,point))
  if overlap>=0:standards[overlap]=layout.objective_position
  layout.objective_position=position
  grid.marks=draft.valley_marks(selected)
 grid.queue_redraw()
 changed()

func edit_extra_standard(layout: Dictionary,point: Vector2i,erase: bool):
 if layout.objective!="seize" or same_tile(layout.objective_position,point):return
 if point in grid.linked_standards:
  grid_help.text="Edit this standard from its pin in Route.";return
 var standards=layout.get("extra_standards",[])
 var existing=standards.find_custom(func(tile):return same_tile(tile,point))
 if erase and existing>=0:
  standards.remove_at(existing)
  if standards.is_empty():layout.erase("extra_standards")
 elif not erase and existing<0 and standards.size()+layout.get("extra_standard_pins",[]).size()<Draft.MAX_EXTRA_STANDARDS:
  standards.append([point.x,point.y]);layout.extra_standards=standards
 else:return
 grid.queue_redraw();changed()

func refresh_linked_standards():
 grid.linked_standards.assign(draft.standard_pin_tiles(selected).map(func(tile):return Vector2i(tile[0],tile[1])))

func same_tile(position: Array,point: Vector2i) -> bool:
 return int(position[0])==point.x and int(position[1])==point.y

func build_encounters():
 for child in encounter_panel.get_children():encounter_panel.remove_child(child);child.queue_free()
 var layout=level()
 var defaults=row(encounter_panel)
 var base_level=spin(int(layout.get("enemy_level",0)),0,Draft.Rules.MAX_LEVEL,func(value):
  if value==0:layout.erase("enemy_level")
  else:layout.enemy_level=int(value)
  changed())
 base_level.name="EditorEncounterBaseLevel"
 field_label(defaults,"Default enemy level",base_level)
 heading(encounter_panel,"Use 0 to scale by chapter number.",15)
 build_hard_bonuses(layout)
 action(encounter_panel,"Preview deployment",show_deployment_preview).name="EditorPreviewDeployment"
 var enemies=layout.enemies+layout.hard_enemies
 if enemies.is_empty():
  heading(encounter_panel,"Place enemies on the Battle map to edit them here.",17)
  return
 selected_enemy=clampi(selected_enemy,0,enemies.size()-1)
 var selector=OptionButton.new();selector.name="EditorEncounter"
 selector.fit_to_longest_item=false;selector.clip_text=true;selector.custom_minimum_size.y=42
 for index in enemies.size():selector.add_item(encounter_name(enemies[index],index,layout.enemies.size()))
 selector.select(selected_enemy)
 selector.item_selected.connect(func(index):selected_enemy=index;build_encounters())
 encounter_panel.add_child(selector)
 var enemy=enemies[selected_enemy]
 var enemy_index=selected_enemy
 var display=line_edit(enemy.get("name",""),"Enemy name",80,func(value):
  enemy.name=value
  selector.set_item_text(enemy_index,encounter_name(enemy,enemy_index,layout.enemies.size()))
  changed())
 field_label(row(encounter_panel),"Display name",display)
 var fields=GridContainer.new();fields.columns=2
 fields.add_theme_constant_override("h_separation",12);fields.add_theme_constant_override("v_separation",8)
 encounter_panel.add_child(fields)
 var job=choice(draft.templates.classes.keys(),enemy.job,func(value):
  if enemy.job==value:return
  enemy.job=value;enemy.erase("item");changed();build_encounters())
 field_label(fields,"Class",job)
 field_label(fields,"Strategy",choice(Draft.STRATEGIES,enemy.get("ai","pursue"),func(value):enemy.ai=value;changed()))
 var gear=draft.gear_for(enemy.job)
 var equipment_ids=[""]+gear.map(func(item):return item.id)
 var gear_choice=choice(equipment_ids,enemy.get("item",""),func(value):
  if value.is_empty():enemy.erase("item")
  else:enemy.item=value
  changed())
 gear_choice.name="EditorEncounterEquipment"
 gear_choice.set_item_text(0,"Class default")
 for index in gear.size():gear_choice.set_item_text(index+1,gear[index].name)
 field_label(fields,"Equipment",gear_choice)
 var strength=spin(int(enemy.get("level",0)),0,Draft.Rules.MAX_LEVEL,func(value):
  if value==0:enemy.erase("level")
  else:enemy.level=int(value)
  changed())
 strength.name="EditorEncounterLevel";field_label(fields,"Level override",strength)
 heading(encounter_panel,"Use 0 to inherit the chapter’s default level.",15)
 var is_commander=enemy_index==0 and not layout.enemies.is_empty()
 var turn=spin(int(enemy.get("arrival_turn",1)),1,99,func(value):
  if value==1:enemy.erase("arrival_turn")
  else:enemy.arrival_turn=int(value)
  sync_encounter_arrival(enemy,enemy_index,layout.enemies.size(),selector);changed())
 turn.name="EditorEncounterArrivalTurn";turn.editable=not is_commander;field_label(fields,"Arrival turn",turn)
 var phase=choice(["player","enemy"],enemy.get("arrival_phase","player"),func(value):
  if value=="player":enemy.erase("arrival_phase")
  else:enemy.arrival_phase=value
  sync_encounter_arrival(enemy,enemy_index,layout.enemies.size(),selector);changed())
 phase.name="EditorEncounterArrivalPhase";phase.disabled=is_commander;field_label(fields,"Arrival phase",phase)
 var default_role="class"
 if enemy.has("raider"):default_role="advance" if enemy.raider else "hold"
 var role=choice(["class","advance","hold"],default_role,func(value):
  if value=="class":enemy.erase("raider")
  else:enemy.raider=value=="advance"
  changed())
 role.name="EditorEnemyRetryRole"
 role.set_item_text(0,"Class default");role.set_item_text(1,"Advance as a raider");role.set_item_text(2,"Hold position")
 field_label(fields,"Retry deployment",role)
 action(encounter_panel,"Make commander",func():
  layout.enemies.remove_at(enemy_index);layout.enemies.push_front(enemy)
  selected_enemy=0;grid.queue_redraw();changed();build_encounters(),is_commander or enemy_index>=layout.enemies.size()).name="EditorMakeCommander"
 sync_encounter_arrival(enemy,enemy_index,layout.enemies.size(),selector)

func build_hard_bonuses(layout: Dictionary):
 var bonuses=layout.get("hard_bonuses",Trials.default_hard_bonuses(selected))
 var custom=CheckButton.new();custom.name="EditorHardBonuses";custom.text="Set Hard enemy bonuses for this chapter"
 custom.button_pressed=layout.has("hard_bonuses");encounter_panel.add_child(custom)
 var fields=GridContainer.new();fields.columns=2;fields.visible=custom.button_pressed
 fields.add_theme_constant_override("h_separation",12);fields.add_theme_constant_override("v_separation",8)
 encounter_panel.add_child(fields)
 for stat in Trials.HARD_BONUS_STATS:
  var value=spin(int(bonuses[stat]),0,Draft.Rules.STAT_CAPS[stat],func(amount):bonuses[stat]=int(amount);changed())
  value.name="EditorHardBonus_"+stat
  field_label(fields,Trials.HARD_BONUS_STATS[stat],value)
 var help=heading(encounter_panel,"Retry pressure adds to the chapter’s Hard bonuses.",15);help.visible=custom.button_pressed
 custom.toggled.connect(func(enabled):
  fields.visible=enabled;help.visible=enabled
  if enabled:layout.hard_bonuses=bonuses
  else:layout.erase("hard_bonuses")
  changed())

func show_deployment_preview():
 var dialog=AcceptDialog.new();dialog.name="EditorDeploymentPreview";dialog.title="Enemy deployment";add_child(dialog)
 dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
 var panel=VBoxContainer.new();panel.add_theme_constant_override("separation",8);dialog.add_child(panel)
 var issue=draft.playtest_problem(selected)
 if not issue.is_empty():
  heading(panel,issue,17);dialog.popup_centered(Vector2i(560,160));return
 var compiled=draft.compile()
 var index=selected
 var seed_value=int(playtest_setup.seed) if playtest_setup.fixed_seed else -1
 var start_pressure=int(playtest_setup.pressure) if compiled.settings.reset_pressure else 0
 var reference=Draft.Rules.new(compiled.content)
 Draft.prepare_playtest(reference,compiled.settings,index,seed_value,0);reference.start_battle()
 var summary=heading(panel,"",19);summary.name="EditorDeploymentSummary"
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.custom_minimum_size=Vector2(470,270);scroll.size_flags_vertical=SIZE_EXPAND_FILL
 var list=VBoxContainer.new();list.size_flags_horizontal=SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",12);scroll.add_child(list)
 var refresh=func(value):
  for item in list.get_children():list.remove_child(item);item.queue_free()
  var prepared=Draft.Rules.new(compiled.content)
  Draft.prepare_playtest(prepared,compiled.settings,index,seed_value,int(value));prepared.start_battle()
  var comparison=DebugSession.compare_deployments(reference,prepared)
  summary.text="Chapter %02d · Pressure %d → %d"%[comparison.chapter,comparison.reference_pressure,comparison.pressure]
  for enemy in comparison.enemies:
   var card=VBoxContainer.new();card.add_theme_constant_override("separation",4);list.add_child(card)
   heading(card,enemy.name+(" · Raider" if enemy.raider else ""),17)
   var placement="Tile %s · HP %s · Attack %s"%[deployment_change(enemy,"position"),deployment_change(enemy,"hp"),deployment_change(enemy,"attack")]
   heading(card,placement,15).name="EditorDeploymentPlacement_"+enemy.id
   var details="Speed %s · Defense %s · Tonics %s"%[deployment_change(enemy,"speed"),deployment_change(enemy,"defense"),deployment_change(enemy,"held_tonics")]
   heading(card,details,15).name="EditorDeploymentStats_"+enemy.id
 var pressure=spin(start_pressure,0,10,refresh);pressure.name="EditorDeploymentPressure"
 pressure.editable=compiled.settings.reset_pressure
 field_label(row(panel),"Starting retry pressure",pressure)
 panel.add_child(scroll);refresh.call(start_pressure)
 dialog.popup_centered(Vector2i(560,420))

func deployment_change(enemy: Dictionary,key: String) -> String:
 var previous=enemy.before[key];var current=enemy.after[key]
 var before="%d, %d"%previous if key=="position" else str(previous)
 var after="%d, %d"%current if key=="position" else str(current)
 return after if before==after else before+" → "+after

func sync_encounter_arrival(enemy: Dictionary,index: int,standard_count: int,selector: OptionButton):
 selector.set_item_text(index,encounter_name(enemy,index,standard_count))
 var commander=encounter_panel.get_node_or_null("EditorMakeCommander")
 if commander!=null:commander.disabled=index==0 or index>=standard_count or Draft.Rules.delayed_enemy(enemy)
 var role=encounter_panel.find_child("EditorEnemyRetryRole",true,false)
 if role!=null:role.disabled=index==0 or Draft.Rules.delayed_enemy(enemy)

func encounter_name(enemy: Dictionary,index: int,standard_count: int) -> String:
 var name=enemy.get("name","").strip_edges()
 if name.is_empty():name=enemy.job
 var role=" · Commander" if index==0 and standard_count>0 else " · Hard only" if index>=standard_count else ""
 if Draft.Rules.delayed_enemy(enemy):role+=" · Turn %d %s"%[enemy.get("arrival_turn",1),enemy.get("arrival_phase","player")]
 return "%s · %d, %d%s"%[name,enemy.position[0],enemy.position[1],role]

func build_story(panel: VBoxContainer):
 var record=chapter();var layout=level()
 for field in [["title","Chapter title"],["place","Location"]]:
  var key=field[0]
  heading(panel,field[1],17)
  panel.add_child(line_edit(layout[key],field[1],120,func(text):
   layout[key]=text
   if key=="title":source_chapter.set_item_text(selected,"%02d · %s"%[selected+1,text])
   changed()))
 var section=CheckButton.new();section.text="Start a new campaign section";section.button_pressed=record.section
 section.disabled=selected==0;panel.add_child(section)
 for field in [["intro","Briefing"],["tactical_brief","Tactical notes"],["outro","Outcome and finale text"]]:
  var key=field[0]
  heading(panel,field[1],17)
  panel.add_child(multiline(layout.get(key,""),76,func(value):layout[key]=value;changed()))
 heading(panel,"Dialogue uses one line per speaker. Enter an ID, a vertical bar, then their words.",15)
 for kind in ["opening","closing"]:
  heading(panel,kind.capitalize()+" dialogue",17)
  dialogue_editor(panel,"EditorChapterDialogue_"+kind,132,func():return record[kind],func(lines):
   record[kind]=lines;changed())
 var events=VBoxContainer.new();events.add_theme_constant_override("separation",8);panel.add_child(events)
 build_phase_scenes(events,record)
 var tile_events=VBoxContainer.new();tile_events.add_theme_constant_override("separation",8);panel.add_child(tile_events)
 build_tile_dialogue(tile_events,layout)
 var section_story=VBoxContainer.new();section_story.add_theme_constant_override("separation",8);panel.add_child(section_story)
 section_story.visible=record.section
 section.toggled.connect(func(value):record.section=value;section_story.visible=value;changed())
 if selected>0:
  var relief=VBoxContainer.new();relief.add_theme_constant_override("separation",8);section_story.add_child(relief)
  build_section_relief(relief,record)
 build_section_story(section_story,record)

func build_section_relief(panel: VBoxContainer,record: Dictionary):
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 heading(panel,"Relief company",21)
 var automatic=CheckButton.new();automatic.name="EditorSectionReliefDefault"
 automatic.text="Use scheduled relief";automatic.button_pressed=not record.has("relief_company");panel.add_child(automatic)
 automatic.toggled.connect(func(value):
  if value:record.erase("relief_company")
  else:record.relief_company=[]
  changed();build_section_relief(panel,record)
  panel.get_node("EditorSectionReliefDefault").grab_focus())
 if automatic.button_pressed:
  heading(panel,"Recruits scheduled for this chapter and the next can arrive when the section begins.",15)
  return
 heading(panel,"Choose which recruits reach this rally point under the section restart rules.",15)
 var assigned=record.relief_company
 var eligible=[]
 for person in draft.data.recruits:
  if person.id in assigned:
   var entry=row(panel)
   heading(entry,person.name,16).size_flags_horizontal=SIZE_EXPAND_FILL
   action(entry,"Remove",func():
    assigned.erase(person.id);changed();build_section_relief(panel,record)).name="EditorRemoveRelief_"+person.id
  elif person.id!="lyra" and (person.chapter.is_empty() or draft.index_for(person.chapter)>=selected):
   eligible.append(person)
 if eligible.is_empty():return
 var options=row(panel)
 var picker=choice(eligible.map(func(person):return person.id),eligible[0].id,Callable())
 picker.name="EditorReliefRecruit";picker.fit_to_longest_item=false;picker.clip_text=true;picker.size_flags_horizontal=SIZE_EXPAND_FILL
 for index in eligible.size():picker.set_item_text(index,eligible[index].name)
 options.add_child(picker)
 action(options,"Add to relief",func():
  assigned.append(picker.get_selected_metadata());changed();build_section_relief(panel,record)).name="EditorAddRelief"

func build_section_story(panel: VBoxContainer,record: Dictionary):
 heading(panel,"Section dialogue",21)
 var definitions=record.section_scenes if record.has("section_scenes") else draft.section_scene_defaults(int(record.source))
 for kind in Draft.SECTION_SCENES:
  if selected==0 and kind=="relief" and not definitions.has(kind):continue
  var scene=definitions.get(kind,{"title":"","lines":[]})
  heading(panel,Draft.SECTION_SCENES[kind],17)
  var title=line_edit(scene.title,"Scene title",100,func(value):
   scene.title=value;definitions[kind]=scene;record.section_scenes=definitions;changed())
  title.name="EditorSectionTitle_"+kind;panel.add_child(title)
  dialogue_editor(panel,"EditorSectionLines_"+kind,110,func():return scene.lines,func(lines):
   scene.lines=lines;definitions[kind]=scene;record.section_scenes=definitions;changed())

func build_route(panel: VBoxContainer) -> Callable:
 heading(panel,"Click the chart to place this chapter’s pin. Select a seal to edit its chapter.",16)
 var atlas_actions=row(panel)
 var feedback=heading(panel,"",15);feedback.name="EditorAtlasStatus"
 action(atlas_actions,"Open atlas image",func():open_route_atlas(panel,feedback)).name="EditorOpenAtlas"
 action(atlas_actions,"Restore original atlas",func():
  draft.data.erase("route_atlas");changed();rebuild(),not draft.data.has("route_atlas")).name="EditorRestoreAtlas"
 action(atlas_actions,"Add blank war table",add_blank_war_table,draft.data.chapters.size()>=Draft.MAX_CHAPTERS).name="EditorAddBlankWarTable"
 var chart=Route.new();chart.name="EditorRouteChart"
 var refresh_survey=build_route_survey(panel,chart)
 panel.add_child(chart)
 chart.configure(draft.data.chapters.map(func(record):return record.level),selected,true,PackedInt32Array(),0,draft.route_texture())
 chart.enable_pin_editor()
 chart.chapter_selected.connect(select_chapter)
 var position=level().route_position
 var coordinates=row(panel)
 var x=spin(roundi(position[0]*100),0,100,func(value):chart.place_pin(Vector2(value/100.0,chart.positions[chart.selected].y)))
 var y=spin(roundi(position[1]*100),0,100,func(value):chart.place_pin(Vector2(chart.positions[chart.selected].x,value/100.0)))
 x.name="EditorRouteX";y.name="EditorRouteY"
 field_label(coordinates,"Pin X %",x);field_label(coordinates,"Pin Y %",y)
 chart.pin_placed.connect(func(index,point):
  draft.data.chapters[index].level.route_position=[point.x,point.y]
  x.set_value_no_signal(roundi(point.x*100));y.set_value_no_signal(roundi(point.y*100))
  refresh_survey.call();changed())
 if level().presentation!="valley_table":
  var site=choice([""]+Draft.ROUTE_TERRAIN,level().get("route_terrain",""),func(value):
   if value.is_empty():level().erase("route_terrain")
   else:level().route_terrain=value
   refresh_survey.call();changed())
  site.name="EditorRouteTerrain"
  site.set_item_text(0,"Use the table’s terrain")
  for index in Draft.ROUTE_TERRAIN.size():
   site.set_item_text(index+1,Draft.Rules.TERRAIN_PROFILES[Draft.ROUTE_TERRAIN[index]].name)
  field_label(row(panel),"Terrain on later war tables",site)
 refresh_survey.call()
 return refresh_survey

func build_route_survey(panel: VBoxContainer,chart: Control) -> Callable:
 var tables=draft.data.chapters.filter(func(record):return record.level.presentation=="valley_table")
 if tables.is_empty():return func():pass
 var picker=OptionButton.new();picker.name="EditorRouteSurvey"
 picker.custom_minimum_size.y=42;picker.fit_to_longest_item=false;picker.clip_text=true
 picker.add_item("Off")
 picker.select(0)
 for record in tables:
  picker.add_item("%02d · %s"%[draft.index_for(record.key)+1,record.level.title])
  picker.set_item_metadata(picker.item_count-1,record.key)
  if record.key==survey_chapter:picker.select(picker.item_count-1)
 field_label(row(panel),"War-table overlay",picker)
 var location=heading(panel,"",15);location.name="EditorRouteSurveyTile"
 var require=CheckButton.new();require.name="EditorRequireRouteStandard";require.text="Require this pin as a standard";panel.add_child(require)
 var refresh=func():
  var key=picker.get_selected_metadata()
  var index=draft.index_for(key) if key is String else -1
  var battle=draft.battle_level(index) if index>=0 else {}
  chart.set_war_table_overlay(battle)
  location.visible=index>=0
  require.hide()
  if index>=0:
   picker.set_item_text(picker.selected,"%02d · %s"%[index+1,draft.data.chapters[index].level.title])
   var tile=chart.survey_tile(chart.positions[selected])
   var terrain=Draft.Rules.TERRAIN_PROFILES[chart.survey_terrain[tile.y][tile.x]].name
   location.text="Selected pin · %d, %d · %s"%[tile.x,tile.y,terrain]
   var authored=draft.data.chapters[index].level
   var pins=authored.get("extra_standard_pins",[])
   var pinned=chapter().key in pins
   var full=authored.get("extra_standards",[]).size()+pins.size()>=Draft.MAX_EXTRA_STANDARDS
   var eligible=index>selected and level().presentation!="valley_table" and battle.objective=="seize"
   require.visible=eligible or pinned
   require.set_pressed_no_signal(pinned)
   require.disabled=not pinned and (not eligible or tile in chart.survey_standards or full)
 picker.item_selected.connect(func(_selected):
  var key=picker.get_selected_metadata()
  survey_chapter=key if key is String else ""
  refresh.call())
 require.toggled.connect(func(enabled):
  if not require.visible or require.disabled:return
  var index=draft.index_for(picker.get_selected_metadata())
  var battle=draft.data.chapters[index].level
  var pins=battle.get("extra_standard_pins",[])
  if enabled:
   pins.append(chapter().key);battle.extra_standard_pins=pins
  else:
   pins.erase(chapter().key)
   if pins.is_empty():battle.erase("extra_standard_pins")
  refresh.call();changed())
 return refresh

func open_route_atlas(parent: Node,feedback: Label):
 var limit=Draft.Atlas.MAX_FILE_BYTES
 if OS.has_feature("web"):
  open_browser_file(parent,feedback,limit,".png,.jpg,.jpeg,image/png,image/jpeg",true,func(encoded):
   import_route_atlas(Marshalls.base64_to_raw(encoded),feedback))
  return
 var picker=campaign_file_picker(parent,false,"*.png,*.jpg,*.jpeg","Atlas images")
 picker.file_selected.connect(func(path):
  var file=FileAccess.open(path,FileAccess.READ)
  if file==null:feedback.text="Could not open the atlas image.";return
  var length=file.get_length()
  if length>limit:feedback.text="The atlas image exceeds 6 MB.";file.close();return
  var image=file.get_buffer(length);file.close()
  import_route_atlas(image,feedback))
 picker.popup_centered_ratio(.72)

func import_route_atlas(bytes: PackedByteArray,feedback: Label):
 var packed=Draft.Atlas.pack(bytes)
 if packed.has("error"):feedback.text=packed.error;return
 var candidate=draft.data.duplicate()
 candidate.route_atlas=packed.encoded
 if JSON.stringify(candidate,"  ",true,true).length()>Draft.MAX_DRAFT_LENGTH:
  feedback.text="The atlas would make the campaign file too large.";return
 draft.data.route_atlas=packed.encoded
 changed();rebuild()

func build_phase_scenes(panel: VBoxContainer,record: Dictionary):
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 heading(panel,"Battle dialogue",21)
 var scenes=record.get("phase_scenes",[])
 var actions=row(panel)
 action(actions,"Add phase scene",func():
  var ids=scenes.map(func(scene):return scene.id)
  var number=1
  while "scene_%02d"%number in ids:number+=1
  scenes.append({"id":"scene_%02d"%number,"turn":1,"phase":"player","lines":[]})
  record.phase_scenes=scenes
  selected_scene=scenes.size()-1;changed();build_phase_scenes(panel,record),scenes.size()>=Draft.MAX_PHASE_SCENES).name="EditorAddPhaseScene"
 if scenes.is_empty():return
 selected_scene=clampi(selected_scene,0,scenes.size()-1)
 var index=selected_scene
 var scene=scenes[index]
 action(actions,"Remove phase scene",func():confirm_remove_battle_scene(scenes,index,"phase",build_phase_scenes.bind(panel,record)))
 var picker=OptionButton.new();picker.name="EditorPhaseScene";picker.custom_minimum_size.y=42
 for stored in scenes:picker.add_item(phase_scene_label(stored))
 picker.select(index);picker.item_selected.connect(func(value):selected_scene=value;build_phase_scenes(panel,record));panel.add_child(picker)
 var trigger=row(panel)
 var turn=spin(int(scene.turn),1,99,func(value):
  scene.turn=int(value);picker.set_item_text(index,phase_scene_label(scene));changed())
 turn.name="EditorPhaseSceneTurn";field_label(trigger,"Turn",turn)
 var phase=choice(["player","enemy"],scene.phase,func(value):
  scene.phase=value;picker.set_item_text(index,phase_scene_label(scene));changed())
 phase.name="EditorPhaseScenePhase";field_label(trigger,"Phase",phase)
 dialogue_editor(panel,"EditorPhaseSceneLines",132,func():return scene.lines,func(lines):scene.lines=lines;changed())

func phase_scene_label(scene: Dictionary) -> String:
 return "Turn %d · %s phase"%[scene.turn,scene.phase.capitalize()]

func confirm_remove_battle_scene(scenes: Array,index: int,trigger: String,refresh: Callable):
 var dialog=ConfirmationDialog.new();dialog.title="Remove this %s scene?"%trigger
 dialog.dialog_text="This removes its dialogue and trigger."
 add_child(dialog);dialog.popup_centered()
 dialog.confirmed.connect(func():scenes.remove_at(index);refresh_tile_scene_markers();changed();refresh.call();dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free)

func build_tile_dialogue(panel: VBoxContainer,layout: Dictionary):
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 heading(panel,"Tile dialogue",21)
 var scenes=layout.get("site_scenes",[])
 var actions=row(panel)
 action(actions,"Add tile scene",func():
  var ids=scenes.map(func(scene):return scene.id)
  var number=1
  while "site_%02d"%number in ids:number+=1
  scenes.append({"id":"site_%02d"%number,"position":[grid.cursor.x,grid.cursor.y],"lines":[]})
  layout.site_scenes=scenes
  selected_site_scene=scenes.size()-1;refresh_tile_scene_markers();changed()
  build_tile_dialogue(panel,layout),scenes.size()>=Draft.MAX_SITE_SCENES).name="EditorAddTileScene"
 if scenes.is_empty():return
 heading(panel,"Plays once when a standing ally finishes an action on the tile.",15)
 selected_site_scene=clampi(selected_site_scene,0,scenes.size()-1)
 var index=selected_site_scene
 var scene=scenes[index]
 action(actions,"Remove tile scene",func():confirm_remove_battle_scene(scenes,index,"tile",build_tile_dialogue.bind(panel,layout)))
 var picker=OptionButton.new();picker.name="EditorTileScene";picker.custom_minimum_size.y=42
 for stored in scenes:picker.add_item(tile_scene_label(stored))
 picker.select(index);picker.item_selected.connect(func(value):selected_site_scene=value;build_tile_dialogue(panel,layout));panel.add_child(picker)
 if layout.presentation=="valley_table":add_site_route_picker(panel,layout,scene)
 var trigger=row(panel)
 var position=draft.site_position(selected,scene)
 for axis in 2:
  var title="X tile" if axis==0 else "Y tile"
  var bounds=Draft.MAX_BOARD.x if axis==0 else Draft.MAX_BOARD.y
  var coordinate=spin(int(position[axis]),0,bounds-1,func(value):
   scene.position[axis]=int(value);picker.set_item_text(index,tile_scene_label(scene));refresh_tile_scene_markers();changed())
  coordinate.editable=not scene.has("route_key")
  coordinate.name="EditorTileScene"+str(axis)
  field_label(trigger,title,coordinate)
 var refill=CheckButton.new();refill.name="EditorTileSceneTonics";refill.text="Refill the visiting ally’s field tonics"
 refill.button_pressed=scene.get("refill_tonics",false);panel.add_child(refill)
 refill.toggled.connect(func(value):
  if value:scene.refill_tonics=true
  else:scene.erase("refill_tonics")
  changed())
 dialogue_editor(panel,"EditorTileSceneLines",132,func():return scene.lines,func(lines):scene.lines=lines;changed())

func tile_scene_label(scene: Dictionary) -> String:
 return "Tile %d, %d"%draft.site_position(selected,scene)

func refresh_tile_scene_markers():
 grid.site_tiles=level().get("site_scenes",[]).map(func(scene):return draft.site_position(selected,scene))
 grid.queue_redraw()

func add_site_route_picker(panel: VBoxContainer,layout: Dictionary,scene: Dictionary):
 var routes={}
 for index in selected:
  var record=draft.data.chapters[index]
  var place=record.level.place if not record.level.place.is_empty() else record.level.title
  if record.level.presentation!="valley_table":routes[record.key]="%02d · %s"%[index+1,place]
 var link=scene.get("route_key","")
 if not link.is_empty() and not routes.has(link):routes[link]="Choose an earlier route pin"
 if routes.is_empty():return
 var field=choice([""]+routes.keys(),link,func(value):
  if value.is_empty():
   scene.position=draft.site_position(selected,scene)
   scene.erase("route_key")
  else:scene.route_key=value
  refresh_tile_scene_markers();changed();build_tile_dialogue(panel,layout))
 field.name="EditorTileSceneRoute";field.fit_to_longest_item=false;field.clip_text=true
 field.set_item_text(0,"Fixed tile")
 for index in routes.size():field.set_item_text(index+1,routes.values()[index])
 field_label(row(panel),"Route pin",field)

func build_company(panel: VBoxContainer):
 var company=draft.data.recruits
 selected_person=clampi(selected_person,0,company.size()-1)
 var person=company[selected_person]
 var actions=row(panel)
 action(actions,"Add recruit",func():
  selected_person=draft.add_recruit(person,chapter().key)
  changed();rebuild(),company.size()>=draft.templates.roster.size()+Draft.MAX_CUSTOM_RECRUITS).name="EditorAddRecruit"
 if person.has("art_id"):
  var used=draft.recruit_in_use(person.id)
  var remove=action(actions,"Remove recruit",func():remove_custom_recruit(),used)
  if used:remove.tooltip_text="Clear this recruit’s dialogue, bond and opening deployment first."
 var picker=choice(company.map(func(person):return person.id),company[selected_person].id,func(value):
  selected_person=company.find_custom(func(person):return person.id==value)
  rebuild())
 picker.name="EditorRecruit";picker.fit_to_longest_item=false;picker.clip_text=true
 for index in company.size():picker.set_item_text(index,company[index].name+" · "+company[index].id)
 panel.add_child(picker)
 if person.has("art_id"):
  var references=draft.templates.roster
  var appearance=choice(references.map(func(recruit):return recruit.id),person.art_id,func(value):person.art_id=value;changed())
  for index in references.size():appearance.set_item_text(index,references[index].name)
  appearance.name="EditorRecruitAppearance";field_label(row(panel),"Catalogue appearance",appearance)
 heading(panel,"Display name",17)
 var display=line_edit(person.name,"Recruit name",80,func(value):
  person.name=value;picker.set_item_text(selected_person,value+" · "+person.id);changed())
 display.name="EditorRecruitName";panel.add_child(display)
 heading(panel,"Introduction",17)
 panel.add_child(multiline(person.bio,96,func(value):person.bio=value;changed()))
 heading(panel,"Epilogue",17)
 panel.add_child(multiline(person.ending,96,func(value):person.ending=value;changed()))
 heading(panel,"Arrival",17)
 var arrivals=[""]+draft.data.chapters.map(func(record):return record.key)
 var arrival=choice(arrivals,person.chapter,func(value):
  person.chapter=value;draft.sync_opening_company();changed();rebuild())
 arrival.set_item_text(0,"Reserve · outside this campaign")
 for index in draft.data.chapters.size():
  arrival.set_item_text(index+1,"%02d · %s"%[index+1,draft.data.chapters[index].level.title])
 arrival.disabled=person.id=="lyra"
 panel.add_child(arrival)
 var deploy=CheckButton.new();deploy.text="Deploy in the opening chapter";deploy.button_pressed=person.id in draft.data.opening_company
 deploy.disabled=person.id=="lyra" or person.chapter!=draft.data.chapters[0].key
 panel.add_child(deploy)
 deploy.toggled.connect(func(value):
  if value and draft.data.opening_company.size()>=6:
   deploy.set_pressed_no_signal(false);status.text="The opening company has six members.";return
  if value:draft.data.opening_company.append(person.id)
  else:draft.data.opening_company.erase(person.id)
  changed())
 var attributes=GridContainer.new();attributes.columns=2
 attributes.add_theme_constant_override("h_separation",12);attributes.add_theme_constant_override("v_separation",8);panel.add_child(attributes)
 field_label(attributes,"Class",choice(draft.templates.classes.keys(),person.job,func(value):person.job=value;changed()))
 var stat_names={"hp":"Base HP","pow":"Power","defense":"Defense","resistance":"Resistance","speed":"Speed","move":"Movement"}
 for stat in Draft.RECRUIT_STATS:
  var limits=Draft.RECRUIT_STATS[stat]
  field_label(attributes,stat_names[stat],spin(int(person.stats[stat]),limits[0],limits[1],func(value):
   person.stats[stat]=value;changed()))

func remove_custom_recruit():
 var recruit=draft.data.recruits[selected_person]
 if not recruit.has("art_id") or draft.recruit_in_use(recruit.id):return
 var dialog=ConfirmationDialog.new();dialog.title="Remove this recruit?"
 dialog.dialog_text="This removes the recruit’s record from the draft."
 add_child(dialog);dialog.popup_centered()
 dialog.confirmed.connect(func():draft.data.recruits.remove_at(selected_person);changed();rebuild())
 dialog.canceled.connect(dialog.queue_free)

func build_rules(panel: VBoxContainer):
 heading(panel,"Campaign title",17)
 panel.add_child(line_edit(draft.data.title,"Campaign title",120,func(value):draft.data.title=value;changed()))
 var pressure_option: CheckButton
 for setting in [{"key":"permadeath","name":"Permadeath","text":"Committed fallen allies stay lost."}]+Settings.SWITCHES:
  var key=setting.key
  var enabled=CheckButton.new();enabled.text=setting.name;enabled.button_pressed=draft.data.settings[key];panel.add_child(enabled)
  enabled.name="EditorRule_"+key
  enabled.toggled.connect(func(value):draft.data.settings[key]=value;changed())
  if key=="reset_pressure":pressure_option=enabled
  heading(panel,setting.text,15)
 build_playtest_setup(panel,pressure_option)
 var stock=VBoxContainer.new();stock.add_theme_constant_override("separation",8);panel.add_child(stock)
 build_legacy_stock(stock)
 var arrivals=VBoxContainer.new();arrivals.add_theme_constant_override("separation",8);panel.add_child(arrivals)
 build_legacy_arrivals(arrivals)

func build_playtest_setup(panel: VBoxContainer,pressure_option: CheckButton):
 heading(panel,"Playtest setup",21)
 heading(panel,"Resume with the same seed and pressure to open that playtest save.",15)
 var fixed=CheckButton.new();fixed.name="EditorFixedSeed";fixed.text="Override combat seed"
 fixed.button_pressed=playtest_setup.fixed_seed;panel.add_child(fixed)
 var seed_row=row(panel);seed_row.visible=fixed.button_pressed
 var seed=spin(playtest_setup.seed,0,2147483647,func(value):playtest_setup.seed=int(value))
 seed.name="EditorPlaytestSeed";field_label(seed_row,"Combat seed",seed)
 fixed.toggled.connect(func(value):playtest_setup.fixed_seed=value;seed_row.visible=value)
 var pressure_row=row(panel);pressure_row.visible=pressure_option.button_pressed
 var pressure=spin(playtest_setup.pressure,0,10,func(value):playtest_setup.pressure=int(value))
 pressure.name="EditorPlaytestPressure";field_label(pressure_row,"Starting retry pressure",pressure)
 pressure_option.toggled.connect(func(value):pressure_row.visible=value)

func build_legacy_stock(panel: VBoxContainer):
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 heading(panel,"Legacy supplies",21)
 var catalogue=draft.legacy_items()
 var entries=draft.data.legacy_stock if draft.data.has("legacy_stock") else Trials.LEGACY_STOCK.duplicate(true)
 var listed=entries.map(func(entry):return entry.id)
 var unlisted=catalogue.filter(func(item):return item.id not in listed)
 var actions=row(panel)
 action(actions,"Add item",func():
  entries.append({"id":unlisted[0].id,"cost":1,"losses":1,"legacy_only":false})
  selected_stock=entries.size()-1;save_legacy_stock(entries);build_legacy_stock(panel),unlisted.is_empty()).name="EditorAddLegacyItem"
 if entries.is_empty():return
 selected_stock=clampi(selected_stock,0,entries.size()-1)
 var slot=selected_stock
 var stock=entries[slot]
 action(actions,"Remove item",func():
  entries.remove_at(slot);save_legacy_stock(entries);build_legacy_stock(panel))
 var picker=choice(listed,stock.id,func(value):selected_stock=listed.find(value);build_legacy_stock(panel))
 picker.name="EditorLegacyStock"
 for index in listed.size():
  var item=catalogue.filter(func(entry):return entry.id==listed[index])[0]
  picker.set_item_text(index,item.name)
 panel.add_child(picker)
 var choices=[catalogue.filter(func(item):return item.id==stock.id)[0]]+unlisted
 var gear=choice(choices.map(func(item):return item.id),stock.id,func(value):
  stock.id=value;save_legacy_stock(entries);build_legacy_stock(panel))
 gear.name="EditorLegacyItem";field_label(row(panel),"Item",gear)
 for index in choices.size():gear.set_item_text(index,choices[index].name)
 var measurements=row(panel)
 var limit=draft.data.recruits.size()+draft.templates.legacy_recruits.size()-1
 var cost=spin(int(stock.cost),1,limit,func(value):stock.cost=int(value);save_legacy_stock(entries))
 cost.name="EditorLegacyCost";field_label(measurements,"Credit cost",cost)
 var losses=spin(int(stock.losses),1,limit,func(value):stock.losses=int(value);save_legacy_stock(entries))
 losses.name="EditorLegacyLosses";field_label(measurements,"Required losses",losses)
 var exclusive=CheckButton.new();exclusive.name="EditorLegacyExclusive";exclusive.text="Legacy purchase required"
 exclusive.button_pressed=stock.get("legacy_only",false);panel.add_child(exclusive)
 exclusive.toggled.connect(func(value):stock.legacy_only=value;save_legacy_stock(entries))

func save_legacy_stock(entries: Array):
 draft.data.legacy_stock=entries
 changed()

func build_legacy_arrivals(panel: VBoxContainer):
 for child in panel.get_children():panel.remove_child(child);child.queue_free()
 heading(panel,"Legacy arrivals",21)
 heading(panel,"The first eligible recruit joins after a matching permanent loss.",15)
 var arrivals=draft.data.legacy_arrivals if draft.data.has("legacy_arrivals") else draft.default_legacy_arrivals()
 var names={}
 for person in draft.data.recruits:
  if person.id!="lyra":names[person.id]=person.name
 var listed=arrivals.map(func(arrival):return arrival.id)
 var unlisted=names.keys().filter(func(id):return id not in listed)
 var actions=row(panel)
 action(actions,"Add arrival",func():
  arrivals.append({"id":unlisted[0],"losses":1,"job":"","title":"","lines":[]})
  selected_arrival=arrivals.size()-1;save_legacy_arrivals(arrivals);build_legacy_arrivals(panel),unlisted.is_empty()).name="EditorAddLegacyArrival"
 if arrivals.is_empty():return
 selected_arrival=clampi(selected_arrival,0,arrivals.size()-1)
 var slot=selected_arrival
 var arrival=arrivals[slot]
 action(actions,"Remove arrival",func():
  arrivals.remove_at(slot);save_legacy_arrivals(arrivals);build_legacy_arrivals(panel))
 var priority=row(panel)
 action(priority,"Higher priority",func():move_legacy_arrival(panel,arrivals,slot,-1),slot==0)
 action(priority,"Lower priority",func():move_legacy_arrival(panel,arrivals,slot,1),slot==arrivals.size()-1)
 var picker=choice(listed,arrival.id,func(value):selected_arrival=listed.find(value);build_legacy_arrivals(panel))
 picker.fit_to_longest_item=false;picker.clip_text=true
 picker.name="EditorLegacyArrival"
 for index in listed.size():picker.set_item_text(index,names[listed[index]])
 panel.add_child(picker)
 var recruit_ids=[arrival.id]+unlisted
 var recruit=choice(recruit_ids,arrival.id,func(value):arrival.id=value;save_legacy_arrivals(arrivals);build_legacy_arrivals(panel))
 recruit.fit_to_longest_item=false;recruit.clip_text=true
 recruit.name="EditorLegacyArrivalRecruit"
 for index in recruit_ids.size():recruit.set_item_text(index,names[recruit_ids[index]])
 field_label(row(panel),"Recruit",recruit)
 var condition=row(panel)
 var limit=draft.data.recruits.size()+draft.templates.legacy_recruits.size()-1
 var count=spin(int(arrival.losses),1,limit,func(value):arrival.losses=int(value);save_legacy_arrivals(arrivals))
 count.name="EditorLegacyArrivalLosses";field_label(condition,"Required losses",count)
 var job=choice([""]+draft.templates.classes.keys(),arrival.job,func(value):arrival.job=value;save_legacy_arrivals(arrivals))
 job.set_item_text(0,"Any class");job.name="EditorLegacyArrivalClass";field_label(condition,"Fallen class",job)
 var title=line_edit(arrival.title,"Arrival scene title",100,func(value):arrival.title=value;save_legacy_arrivals(arrivals))
 title.name="EditorLegacyArrivalTitle";panel.add_child(title)
 heading(panel,"Enter each line as a speaker ID, a vertical bar, then their words.",15)
 dialogue_editor(panel,"EditorLegacyArrivalLines",110,func():return arrival.lines,func(lines):
  arrival.lines=lines;save_legacy_arrivals(arrivals))

func move_legacy_arrival(panel: VBoxContainer,arrivals: Array,slot: int,direction: int):
 var arrival=arrivals.pop_at(slot)
 selected_arrival=slot+direction
 arrivals.insert(selected_arrival,arrival)
 save_legacy_arrivals(arrivals);build_legacy_arrivals(panel)

func save_legacy_arrivals(arrivals: Array):
 draft.data.legacy_arrivals=arrivals
 changed()

func build_bonds(panel: VBoxContainer):
 var bonds=draft.data.bonds if draft.data.has("bonds") else draft.stock_bonds(draft.data.chapters)
 var names={}
 for person in draft.data.recruits:names[person.id]=person.name
 for legacy in draft.templates.legacy_recruits:names[legacy.unit.id]=legacy.unit.name
 var paired=[]
 for bond in bonds:paired.append_array(bond.members)
 var unpaired=draft.bond_members().filter(func(id):return id not in paired)
 var actions=row(panel)
 action(actions,"Add bond",func():
  var number=1
  var keys=bonds.map(func(bond):return bond.id)
  while "bond_%02d"%number in keys:number+=1
  var scenes=[]
  for rank in 3:scenes.append({"title":["First conversation","Second conversation","Third conversation"][rank],"lines":[]})
  var chapter_key=chapter().key
  bonds.append({"id":"bond_%02d"%number,"members":unpaired.slice(0,2),"chapters":[chapter_key,chapter_key,chapter_key],
   "points":[1,3,6],"scenes":scenes,"ending":""})
  selected_bond=bonds.size()-1
  save_bond_edits(bonds);rebuild(),unpaired.size()<2).name="EditorAddBond"
 if bonds.is_empty():
  heading(panel,"Add a bond to write conversations and a paired epilogue for two recruits.",17)
  return
 selected_bond=clampi(selected_bond,0,bonds.size()-1)
 action(actions,"Remove bond",func():
  var dialog=ConfirmationDialog.new();dialog.title="Remove this bond?"
  dialog.dialog_text="This removes its three conversations and paired epilogue."
  add_child(dialog);dialog.popup_centered()
  dialog.confirmed.connect(func():bonds.remove_at(selected_bond);save_bond_edits(bonds);rebuild())
  dialog.canceled.connect(dialog.queue_free))
 var bond=bonds[selected_bond]
 var identities=bonds.map(func(entry):return entry.id)
 var picker=choice(identities,bond.id,func(value):selected_bond=identities.find(value);rebuild());picker.name="EditorBond"
 picker.fit_to_longest_item=false;picker.clip_text=true
 for index in bonds.size():picker.set_item_text(index,"%s & %s"%[names[bonds[index].members[0]],names[bonds[index].members[1]]])
 panel.add_child(picker)
 var members=GridContainer.new();members.columns=2;members.add_theme_constant_override("h_separation",12);panel.add_child(members)
 for index in 2:
  var options=[bond.members[index]]+unpaired
  var member=choice(options,bond.members[index],func(value):bond.members[index]=value;save_bond_edits(bonds);rebuild())
  member.fit_to_longest_item=false;member.clip_text=true
  for entry in options.size():member.set_item_text(entry,names[options[entry]])
  field_label(members,"Member %d"%(index+1),member)
 heading(panel,"Paired epilogue",17)
 var ending=multiline(bond.ending,90,func(value):bond.ending=value;save_bond_edits(bonds));ending.name="EditorBondEnding"
 panel.add_child(ending)
 heading(panel,"Enter each line as a speaker ID, a vertical bar, then their words.",15)
 var chapter_keys=draft.data.chapters.map(func(record):return record.key)
 for rank in 3:
  heading(panel,"Rank "+["C","B","A"][rank],21)
  var gate=GridContainer.new();gate.columns=2;gate.add_theme_constant_override("h_separation",12);panel.add_child(gate)
  var unlock=choice(chapter_keys,bond.chapters[rank],func(value):bond.chapters[rank]=value;save_bond_edits(bonds))
  unlock.name="EditorBondChapter"+str(rank);unlock.fit_to_longest_item=false;unlock.clip_text=true
  for index in chapter_keys.size():unlock.set_item_text(index,"%02d · %s"%[index+1,draft.data.chapters[index].level.title])
  field_label(gate,"Opens in chapter",unlock)
  var points=spin(int(bond.points[rank]),1,6,func(value):bond.points[rank]=value;save_bond_edits(bonds));points.name="EditorBondPoints"+str(rank)
  field_label(gate,"Bond points",points)
  var scene=bond.scenes[rank]
  var title=line_edit(scene.title,"Conversation title",100,func(value):scene.title=value;save_bond_edits(bonds));title.name="EditorBondTitle"+str(rank)
  panel.add_child(title)
  var original_lines=scene.lines.duplicate(true)
  var lines=multiline(dialogue_text(original_lines),110,func(value):scene.lines=parse_dialogue(value,original_lines);save_bond_edits(bonds))
  lines.name="EditorBondLines"+str(rank);panel.add_child(lines)

func save_bond_edits(bonds: Array):
 draft.data.bonds=bonds
 changed()

func dialogue_editor(panel: Control,field_name: String,height: int,read: Callable,write: Callable):
 var field=multiline(dialogue_text(read.call()),height,Callable())
 field.name=field_name;panel.add_child(field)
 var options=action(panel,"Edit loss dialogue",func():show_loss_dialogue(field,read.call(),write),read.call().is_empty())
 options.name=field_name+"LossOptions"
 field.text_changed.connect(func():
  write.call(parse_dialogue(field.text,read.call()))
  options.disabled=read.call().is_empty())

func show_loss_dialogue(field: TextEdit,source: Array,write: Callable):
 var lines=source.duplicate(true)
 var dialog=AcceptDialog.new();dialog.name="EditorLossDialogue";dialog.title="Dialogue after a loss"
 dialog.ok_button_text="Apply changes";dialog.dialog_hide_on_ok=false;add_child(dialog)
 dialog.canceled.connect(dialog.queue_free)
 var panel=VBoxContainer.new();panel.add_theme_constant_override("separation",8);dialog.add_child(panel)
 var picker=OptionButton.new();picker.name="EditorLossLine";picker.fit_to_longest_item=false;picker.clip_text=true
 picker.custom_minimum_size.y=42;panel.add_child(picker)
 for index in lines.size():
  var line=lines[index]
  picker.add_item("%d · %s · %s"%[index+1,line.speaker,line.text.replace("\n"," ").left(64)])
 var words=multiline("",84,Callable());words.name="EditorLossWords";panel.add_child(words)
 heading(panel,"Also requires these recruits to survive",16)
 var needs=line_edit("","Recruit IDs separated by commas",1800,Callable());needs.name="EditorLossRequires";panel.add_child(needs)
 heading(panel,"Alternate lines if the speaker or a required recruit fell",16)
 heading(panel,"Enter a speaker ID, a vertical bar, then their words. The first surviving speaker is used.",15)
 var alternatives=multiline("",116,Callable());alternatives.name="EditorLossAlternatives";panel.add_child(alternatives)
 var error=heading(panel,"",15);error.name="EditorLossError"
 var select_line=func(index):
  var line=lines[index]
  words.text=line.text;needs.text=", ".join(line.get("requires",[]))
  alternatives.text=dialogue_text(line.get("when_absent",[]));error.text=""
 picker.item_selected.connect(select_line);picker.select(0);select_line.call(0)
 dialog.confirmed.connect(func():
  var line=lines[picker.selected]
  var required=[]
  var members=draft.bond_members()
  for entry in needs.text.split(",",false):
   var recruit=entry.strip_edges()
   if recruit.is_empty() or recruit in required:continue
   if recruit not in members:
    error.text="Unknown recruit ID · "+recruit;return
   required.append(recruit)
  var substitutions=parse_dialogue(alternatives.text,line.get("when_absent",[]))
  if substitutions.any(func(alternate):return alternate.speaker not in members and alternate.speaker!="narrator"):
   error.text="Use a recruit ID or narrator for each alternate line.";return
  line.text=words.text.strip_edges()
  if line.text.is_empty() or not Draft.dialogue_valid(substitutions) or not Draft.valid_text(line.text,1800):
   error.text="Enter dialogue with up to 1,800 characters in each line.";return
  if required.is_empty():line.erase("requires")
  else:line.requires=required
  if substitutions.is_empty():line.erase("when_absent")
  else:line.when_absent=substitutions
  write.call(lines)
  field.set_block_signals(true);field.text=dialogue_text(lines);field.set_block_signals(false)
  dialog.hide();dialog.queue_free())
 dialog.popup_centered(Vector2i(560,440))

func dialogue_text(lines: Array) -> String:
 var rows=[]
 for line in lines:rows.append(line.speaker+" | "+line.text.replace("\n"," "))
 return "\n".join(rows)

func parse_dialogue(text: String,original: Array) -> Array:
 var lines=[]
 var remaining=original.duplicate()
 for row_text in text.split("\n",false):
  var parts=row_text.split("|",true,1)
  var speaker=parts[0].strip_edges() if parts.size()==2 else "narrator"
  if speaker.is_empty():speaker="narrator"
  var words=parts[-1].strip_edges()
  if words.is_empty():continue
  var previous=remaining.find_custom(func(line):return line.speaker==speaker and line.text.replace("\n"," ")==words)
  lines.append(remaining.pop_at(previous) if previous>=0 else {"speaker":speaker,"text":words})
 return lines

func select_chapter(index: int):
 selected=index
 selected_enemy=0
 selected_scene=0
 selected_site_scene=0
 draft_selection_changed.emit(draft_key,selected)
 rebuild()

func insert_chapter(copy: bool,valley=false):
 var index=draft.insert_chapter(selected,copy,valley)
 if index>=0:dirty=true;select_chapter(index)

func add_blank_war_table():
 var index=draft.insert_blank_war_table(selected)
 if index<0:return
 dirty=true;active_tab=0;select_chapter(index)

func move_chapter(direction: int):
 dirty=true;select_chapter(draft.move_chapter(selected,direction))

func confirm_remove():
 var dialog=ConfirmationDialog.new();dialog.title="Remove chapter?"
 dialog.dialog_text="Recruit arrivals and bond conversations scheduled here move to the next surviving chapter."
 add_child(dialog);dialog.popup_centered()
 dialog.confirmed.connect(func():dirty=true;select_chapter(draft.remove_chapter(selected)))
 dialog.canceled.connect(dialog.queue_free)

func new_draft():
 if dirty and not save_draft():return
 draft.data=draft.new_document(false);draft_key="";dirty=true
 select_chapter(restore_editor_state({}))

func save_draft() -> bool:
 var issue=draft.structural_problem(draft.data)
 if not issue.is_empty():status.text=issue;return false
 var saved=library.save(draft_key,draft.data,playtest_setup,chapter().key)
 if saved.is_empty():status.text="Could not save the draft. Copy the JSON to keep it.";return false
 draft_key=saved;dirty=false;draft_selection_changed.emit(draft_key,selected);status.text="Draft saved."
 return true

func open_library():
 var dialog=AcceptDialog.new();dialog.title="Local campaign drafts";add_child(dialog)
 dialog.close_requested.connect(dialog.queue_free)
 dialog.confirmed.connect(dialog.queue_free)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(360,240);dialog.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(list)
 heading(list,"Campaign templates",21)
 action(list,"Copy Poem’s campaign",func():open_poem_template(false))
 action(list,"Copy Poem with the Valley battle",func():open_poem_template(true)).name="EditorValleyTemplate"
 heading(list,"Saved drafts",21)
 var records=library.list_drafts()
 if records.is_empty():heading(list,"Save a draft to add it here.",17)
 var feedback=heading(list,"",15)
 for record in records:
  var actions=row(list)
  var title=record.document.get("title","Campaign")
  var open=action(actions,title,func():open_saved_draft(record,false,dialog,feedback))
  open.name="EditorOpenDraft_"+record.key
  open.alignment=HORIZONTAL_ALIGNMENT_LEFT;open.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  var copy=action(actions,"Copy",func():open_saved_draft(record,true,dialog,feedback))
  copy.name="EditorCopyDraft_"+record.key;copy.size_flags_horizontal=SIZE_FILL
  var remove=action(actions,"Remove",func():confirm_remove_draft(record,dialog,feedback))
  remove.name="EditorRemoveDraft_"+record.key;remove.size_flags_horizontal=SIZE_FILL
 dialog.popup_centered(Vector2i(440,320))

func open_saved_draft(record: Dictionary,make_copy: bool,dialog: AcceptDialog,feedback: Label):
 if dirty and not save_draft():feedback.text=status.text;return
 var chapter_index=selected
 if draft_key!=record.key:
  var error=draft.decode(JSON.stringify(record.document,"",true,true))
  if not error.is_empty():feedback.text=error;return
  chapter_index=restore_editor_state(record)
 elif not make_copy:
  dialog.queue_free();return
 if make_copy:
  draft.data=draft.data.duplicate(true)
  draft.data.title=draft.data.title.left(113)+" (copy)"
  draft_key="";dirty=true
 else:
  draft_key=record.key;dirty=false
 select_chapter(chapter_index)

func restore_editor_state(record: Dictionary) -> int:
 var saved=library.editor_state(record)
 playtest_setup.clear();playtest_setup.merge(saved.setup)
 return maxi(0,draft.index_for(saved.chapter))

func confirm_remove_draft(record: Dictionary,dialog: AcceptDialog,feedback: Label):
 var confirm=ConfirmationDialog.new();confirm.name="EditorConfirmRemoveDraft"
 confirm.title="Remove saved draft?";confirm.ok_button_text="Remove"
 confirm.dialog_text="Remove the saved copy of “%s” from this device?"%record.document.get("title","Campaign")
 dialog.add_child(confirm)
 confirm.canceled.connect(confirm.queue_free)
 confirm.confirmed.connect(func():
  if not library.remove(record.key):
   feedback.text="Could not remove the saved draft.";confirm.queue_free();return
  if draft_key==record.key:
   draft_key="";draft_selection_changed.emit(draft_key,selected);validation()
  dialog.hide();dialog.queue_free();open_library())
 confirm.popup_centered()

func open_poem_template(valley: bool):
 if dirty and not save_draft():return
 draft.load_poem_template(valley);draft_key="";dirty=true;select_chapter(restore_editor_state({}))

func show_transfer():
 var dialog=AcceptDialog.new();dialog.title="Campaign JSON";add_child(dialog)
 dialog.close_requested.connect(dialog.queue_free)
 dialog.confirmed.connect(dialog.queue_free)
 var panel=VBoxContainer.new();dialog.add_child(panel)
 heading(panel,"Copy this campaign or paste another Poem campaign document.",16)
 var source=multiline(draft.encode(),230,Callable());source.name="EditorTransferText";panel.add_child(source)
 var buttons=row(panel)
 action(buttons,"Copy JSON",func():DisplayServer.clipboard_set(source.text))
 var files=row(panel)
 var feedback=heading(panel,"",15);feedback.name="EditorCampaignTransferStatus"
 action(buttons,"Import pasted JSON",func():import_campaign_text(source.text,feedback))
 action(files,"Open JSON file",func():open_campaign_file(dialog,feedback)).name="EditorOpenCampaignFile"
 action(files,"Save JSON file",func():save_campaign_file(dialog,feedback)).name="EditorSaveCampaignFile"
 dialog.popup_centered(Vector2i(560,350))

func show_readiness():
 var dialog=AcceptDialog.new();dialog.name="EditorCampaignReadiness";dialog.title="Campaign readiness";add_child(dialog)
 dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.custom_minimum_size=Vector2(452,260);dialog.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",12);scroll.add_child(list)
 var invalid=draft.structural_problem(draft.data)
 if not invalid.is_empty():
  heading(list,invalid,17)
 else:
  var company=draft.company_problem()
  if not company.is_empty():heading(list,company,17)
  for index in draft.data.chapters.size():
   var readiness=draft.battle_readiness(index)
   var section=VBoxContainer.new();section.add_theme_constant_override("separation",4);list.add_child(section)
   var outline="%02d · %s · %s"%[index+1,draft.data.chapters[index].level.title,readiness.title]
   var chapter_button=action(section,outline,func():active_tab=0;select_chapter(index))
   chapter_button.name="EditorReadinessChapter_%d"%index
   chapter_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
   chapter_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
   if not readiness.description.is_empty():
    heading(section,readiness.description,16).name="EditorReadinessNote_%d"%index
 dialog.popup_centered(Vector2i(560,420))

func import_campaign_text(raw: String,feedback: Label):
 var incoming=Draft.new()
 var issue=incoming.decode(raw)
 if not issue.is_empty():feedback.text=issue;return
 if dirty and not save_draft():feedback.text=status.text;return
 draft.data=incoming.data;draft_key="";dirty=true;select_chapter(restore_editor_state({}))

func open_campaign_file(parent: Window,feedback: Label):
 if OS.has_feature("web"):
  open_browser_file(parent,feedback,MAX_CAMPAIGN_FILE_BYTES,".json,application/json",false,func(raw):
   import_campaign_text(raw,feedback))
  return
 var picker=campaign_file_picker(parent,false)
 picker.file_selected.connect(func(path):
  var file=FileAccess.open(path,FileAccess.READ)
  if file==null:feedback.text="Could not open the campaign file.";return
  if file.get_length()>MAX_CAMPAIGN_FILE_BYTES:
   feedback.text="This campaign document is too large.";file.close();return
  var raw=file.get_as_text();file.close()
  import_campaign_text(raw,feedback))
 picker.popup_centered_ratio(.72)

func open_browser_file(parent: Node,feedback: Label,limit: int,accept: String,binary: bool,receive: Callable):
 var bridge=JavaScriptBridge.get_interface("poemCampaignFiles")
 if bridge==null:
  JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/web_campaign_files.js"),true)
  bridge=JavaScriptBridge.get_interface("poemCampaignFiles")
 if bridge==null:feedback.text="The browser file picker is unavailable.";return
 if not parent.has_meta("browser_file_picker"):
  parent.set_meta("browser_file_picker",true)
  parent.tree_exited.connect(func():bridge.cancel(),CONNECT_ONE_SHOT)
 browser_campaign_file_callback=JavaScriptBridge.create_callback(func(arguments):
  if not is_instance_valid(feedback) or arguments.size()!=2:return
  var problem=str(arguments[0])
  if not problem.is_empty():feedback.text=problem;return
  receive.call(str(arguments[1])))
 bridge.open(limit,browser_campaign_file_callback,accept,binary)

func save_campaign_file(parent: Window,feedback: Label):
 var title=draft.data.title.validate_filename().strip_edges()
 if title.is_empty():title="campaign"
 var filename=title.left(80)+".campaign.json"
 var payload=draft.encode()
 if OS.has_feature("web"):
  JavaScriptBridge.download_buffer(payload.to_utf8_buffer(),filename,"application/json")
  return
 var picker=campaign_file_picker(parent,true)
 picker.current_file=filename
 picker.file_selected.connect(func(path):
  var temporary=path+".%d-%d.tmp"%[OS.get_process_id(),Time.get_ticks_usec()]
  var file=FileAccess.open(temporary,FileAccess.WRITE)
  if file==null:feedback.text="Could not save the campaign file.";return
  file.store_string(payload);file.flush()
  var written=file.get_error()==OK
  file.close()
  if written:written=DirAccess.rename_absolute(temporary,path)==OK
  if not written:DirAccess.remove_absolute(temporary)
  feedback.text="Saved "+path.get_file()+"." if written else "Could not save the campaign file.")
 picker.popup_centered_ratio(.72)

func campaign_file_picker(parent: Node,saving: bool,extensions="*.json",description="Campaign JSON") -> FileDialog:
 var picker=FileDialog.new();picker.name="EditorCampaignFilePicker"
 picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
 picker.add_filter(extensions,description)
 parent.add_child(picker);picker.canceled.connect(picker.queue_free)
 picker.file_selected.connect(func(_path):picker.queue_free())
 return picker

func launch(index: int,resume: bool,allow_single=false):
 var single_battle=not draft.playtest_problem().is_empty()
 if single_battle and (not allow_single or not draft.playtest_problem(index).is_empty()):return
 if not draft_key.is_empty() and not dirty:library.remember_playtest(draft_key,playtest_setup,chapter().key)
 draft_selection_changed.emit(draft_key,selected)
 playtest_requested.emit(index,resume,single_battle)

func changed():
 dirty=true
 validation()

func validation():
 if not is_instance_valid(status):return
 var issue=draft.playtest_problem()
 status.text=("Unsaved draft" if dirty else "Ready to playtest") if issue.is_empty() else issue
 var selected_ready=issue.is_empty() or draft.playtest_problem(selected).is_empty()
 play_buttons[0].disabled=not issue.is_empty()
 play_buttons[1].disabled=not selected_ready
 play_buttons[2].disabled=not selected_ready
 play_buttons[1].text="Test this battle" if not issue.is_empty() and selected_ready else "Play chapter"
 play_buttons[2].text="Resume battle test" if not issue.is_empty() and selected_ready else "Resume playtest"

func page(book: TabContainer,title: String) -> VBoxContainer:
 var scroll=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;book.add_child(scroll)
 var panel=VBoxContainer.new();panel.size_flags_horizontal=SIZE_EXPAND_FILL;panel.add_theme_constant_override("separation",8)
 scroll.add_child(panel);return panel

func field_label(parent: Control,text: String,control: Control):
 var label=heading(parent,text,16)
 label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.size_flags_vertical=SIZE_SHRINK_CENTER
 control.size_flags_horizontal=SIZE_EXPAND_FILL;parent.add_child(control)

func heading(parent: Control,text: String,font_size: int) -> Label:
 var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",GOLD)
 parent.add_child(label);return label

func row(parent: Control) -> HBoxContainer:
 var result=HBoxContainer.new();result.add_theme_constant_override("separation",8);parent.add_child(result);return result

func action(parent: Control,text: String,used: Callable,disabled=false) -> Button:
 var button=Button.new();button.text=text;button.disabled=disabled
 button.custom_minimum_size.y=42;button.size_flags_horizontal=SIZE_EXPAND_FILL
 button.pressed.connect(used);parent.add_child(button);return button

func choice(choices: Array,current: String,used: Callable) -> OptionButton:
 var field=OptionButton.new();field.custom_minimum_size.y=42
 for item in choices:
  field.add_item(str(item));field.set_item_metadata(field.item_count-1,item)
 field.select(maxi(0,choices.find(current)))
 if used.is_valid():field.item_selected.connect(func(index):used.call(field.get_item_metadata(index)))
 return field

func spin(value: int,low: int,high: int,used: Callable) -> SpinBox:
 var control=SpinBox.new();control.min_value=low;control.max_value=high;control.value=value
 control.custom_minimum_size.y=42
 if used.is_valid():control.value_changed.connect(used)
 return control

func line_edit(value: String,hint: String,maximum: int,used: Callable) -> LineEdit:
 var control=LineEdit.new();control.text=value;control.placeholder_text=hint;control.max_length=maximum
 control.custom_minimum_size.y=42
 if used.is_valid():control.text_changed.connect(used)
 return control

func multiline(value: String,height: int,used: Callable) -> TextEdit:
 var control=TextEdit.new();control.text=value;control.custom_minimum_size.y=height
 control.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 if used.is_valid():control.text_changed.connect(func():used.call(control.text))
 return control
