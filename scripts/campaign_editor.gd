extends VBoxContainer
signal closed
signal playtest_requested(start: int, resume: bool, single_battle: bool)
signal draft_selection_changed(key: String, chapter: int)
const Draft=preload("res://scripts/campaign_draft.gd")
const Grid=preload("res://scripts/campaign_editor_grid.gd")
const Route=preload("res://scripts/campaign_route.gd")
const Settings=preload("res://scripts/campaign_settings.gd")
const Trials=preload("res://scripts/campaign_trials.gd")
const TOOLS=["Terrain","Deployment","Enemy","Hard-mode enemy","Objective"]
const GOLD=Color("896937")
var draft: RefCounted
var library: RefCounted
var draft_key=""
var selected=0
var active_tab=0
var brush=0
var selected_person=0
var selected_bond=0
var selected_enemy=0
var selected_scene=0
var selected_stock=0
var selected_arrival=0
var encounter_panel: VBoxContainer
var grid: Control
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

func configure(model,storage,key: String,index: int):
 draft=model;library=storage;draft_key=key
 selected=clampi(index,0,draft.data.chapters.size()-1)
 size_flags_vertical=SIZE_EXPAND_FILL
 add_theme_constant_override("separation",8)
 rebuild()

func rebuild():
 for child in get_children():remove_child(child);child.queue_free()
 play_buttons.clear()
 heading(self,"Campaign editor",34)
 var toolbar=row(self)
 action(toolbar,"New draft",new_draft)
 action(toolbar,"Open drafts",open_library)
 action(toolbar,"Save draft",save_draft).name="SaveCampaignDraft"
 action(toolbar,"Transfer JSON",show_transfer)
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
 build_route(page(book,"Route"))
 build_company(page(book,"Company"))
 build_bonds(page(book,"Bonds"))
 build_rules(page(book,"Rules"))
 var encounters_tab=book.get_tab_idx_from_control(encounter_panel.get_parent())
 book.current_tab=active_tab
 if active_tab==encounters_tab:build_encounters()
 book.tab_changed.connect(func(index):
  active_tab=index
  if index==encounters_tab:build_encounters())
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
  layout.objective=value;grid.marks=draft.valley_marks(selected);grid.queue_redraw();changed()))
 field_label(parameters,"Phase limit",spin(int(layout.turn_limit),1,99,func(value):layout.turn_limit=value;changed()))
 field_label(parameters,"Environment",choice(Draft.ENVIRONMENTS,layout.environment,func(value):layout.environment=value;changed()))
 field_label(parameters,"Score",choice(draft.music_ids,layout.score_theme,func(value):layout.score_theme=value;changed()))
 var width=spin(layout.map[0].length(),Draft.MIN_BOARD.x,Draft.MAX_BOARD.x,Callable())
 var height=spin(layout.map.size(),Draft.MIN_BOARD.y,Draft.MAX_BOARD.y,Callable())
 var fixed_chart=layout.presentation=="valley_table"
 width.editable=not fixed_chart;height.editable=not fixed_chart
 field_label(parameters,"Width",width);field_label(parameters,"Height",height)
 action(panel,"Resize map",func():
  draft.resize_map(layout,Vector2i(width.value,height.value))
  grid.cursor=grid.cursor.clamp(Vector2i.ZERO,grid.board_size()-Vector2i.ONE)
  grid.queue_redraw();changed(),fixed_chart)
 var tools=row(panel)
 var mode=choice(TOOLS,TOOLS[brush],func(value):brush=TOOLS.find(value);show_brush_options())
 mode.name="EditorBrush";tools.add_child(mode)
 var terrains=Draft.Rules.TERRAIN_PROFILES.keys()
 terrain_choice=OptionButton.new();terrain_choice.name="EditorTerrain";terrain_choice.custom_minimum_size.y=42;tools.add_child(terrain_choice)
 for tile in terrains:
  terrain_choice.add_item(Draft.Rules.TERRAIN_PROFILES[tile].name)
  terrain_choice.set_item_metadata(terrain_choice.item_count-1,tile)
 job_choice=choice(draft.templates.classes.keys(),"Vanguard",Callable());tools.add_child(job_choice)
 ai_choice=choice(Draft.STRATEGIES,"pursue",Callable());tools.add_child(ai_choice)
 enemy_name=line_edit("","Enemy name",80,Callable());tools.add_child(enemy_name)
 show_brush_options()
 heading(panel,"Click or use the arrow keys and Enter. Right-click or Backspace erases. C marks the commander.",15)
 grid=Grid.new();grid.name="EditorGrid";panel.add_child(grid);grid.configure(layout,draft.valley_marks(selected));grid.tile_edited.connect(edit_tile)
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

func show_brush_options():
 var enemy=brush in [2,3]
 terrain_choice.visible=brush==0
 job_choice.visible=enemy;ai_choice.visible=enemy;enemy_name.visible=enemy

func edit_tile(point: Vector2i,erase: bool):
 var layout=level()
 var position=[point.x,point.y]
 if brush==0:
  draft.paint(layout,point,"." if erase else terrain_choice.get_selected_metadata())
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
  layout.objective_position=position
  grid.marks=draft.valley_marks(selected)
 grid.queue_redraw()
 changed()

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
 action(encounter_panel,"Make commander",func():
  layout.enemies.remove_at(enemy_index);layout.enemies.push_front(enemy)
  selected_enemy=0;grid.queue_redraw();changed();build_encounters(),is_commander or enemy_index>=layout.enemies.size()).name="EditorMakeCommander"
 sync_encounter_arrival(enemy,enemy_index,layout.enemies.size(),selector)

func sync_encounter_arrival(enemy: Dictionary,index: int,standard_count: int,selector: OptionButton):
 selector.set_item_text(index,encounter_name(enemy,index,standard_count))
 var commander=encounter_panel.get_node_or_null("EditorMakeCommander")
 if commander!=null:commander.disabled=index==0 or index>=standard_count or Draft.Rules.delayed_enemy(enemy)

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
  var original_lines=record[kind].duplicate(true)
  panel.add_child(multiline(dialogue_text(original_lines),132,func(value):record[kind]=parse_dialogue(value,original_lines);changed()))
 var events=VBoxContainer.new();events.add_theme_constant_override("separation",8);panel.add_child(events)
 build_phase_scenes(events,record)
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
  var original_lines=scene.lines.duplicate(true)
  var lines=multiline(dialogue_text(original_lines),110,func(value):
   scene.lines=parse_dialogue(value,original_lines);definitions[kind]=scene;record.section_scenes=definitions;changed())
  lines.name="EditorSectionLines_"+kind;panel.add_child(lines)

func build_route(panel: VBoxContainer):
 heading(panel,"Click the chart to place this chapter’s pin. Select a seal to edit its chapter.",16)
 var chart=Route.new();chart.name="EditorRouteChart";panel.add_child(chart)
 chart.configure(draft.data.chapters.map(func(record):return record.level),selected,true)
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
  x.set_value_no_signal(roundi(point.x*100));y.set_value_no_signal(roundi(point.y*100));changed())
 if level().presentation!="valley_table":
  var site=choice([""]+Draft.ROUTE_TERRAIN,level().get("route_terrain",""),func(value):
   if value.is_empty():level().erase("route_terrain")
   else:level().route_terrain=value
   changed())
  site.name="EditorRouteTerrain"
  site.set_item_text(0,"Use the table’s terrain")
  for index in Draft.ROUTE_TERRAIN.size():
   site.set_item_text(index+1,Draft.Rules.TERRAIN_PROFILES[Draft.ROUTE_TERRAIN[index]].name)
  field_label(row(panel),"Terrain on later war tables",site)

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
 action(actions,"Remove phase scene",func():confirm_remove_phase_scene(scenes,index,build_phase_scenes.bind(panel,record)))
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
 var original_lines=scene.lines.duplicate(true)
 var lines=multiline(dialogue_text(original_lines),132,func(value):scene.lines=parse_dialogue(value,original_lines);changed())
 lines.name="EditorPhaseSceneLines";panel.add_child(lines)

func phase_scene_label(scene: Dictionary) -> String:
 return "Turn %d · %s phase"%[scene.turn,scene.phase.capitalize()]

func confirm_remove_phase_scene(scenes: Array,index: int,refresh: Callable):
 var dialog=ConfirmationDialog.new();dialog.title="Remove this phase scene?"
 dialog.dialog_text="This removes its dialogue and phase trigger."
 add_child(dialog);dialog.popup_centered()
 dialog.confirmed.connect(func():scenes.remove_at(index);changed();refresh.call();dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free)

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
 for setting in [{"key":"permadeath","name":"Permadeath","text":"Committed fallen allies stay lost."}]+Settings.SWITCHES:
  var key=setting.key
  var enabled=CheckButton.new();enabled.text=setting.name;enabled.button_pressed=draft.data.settings[key];panel.add_child(enabled)
  enabled.toggled.connect(func(value):draft.data.settings[key]=value;changed())
  heading(panel,setting.text,15)
 var stock=VBoxContainer.new();stock.add_theme_constant_override("separation",8);panel.add_child(stock)
 build_legacy_stock(stock)
 var arrivals=VBoxContainer.new();arrivals.add_theme_constant_override("separation",8);panel.add_child(arrivals)
 build_legacy_arrivals(arrivals)

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
 var original_lines=arrival.lines.duplicate(true)
 var lines=multiline(dialogue_text(original_lines),110,func(value):arrival.lines=parse_dialogue(value,original_lines);save_legacy_arrivals(arrivals))
 lines.name="EditorLegacyArrivalLines";panel.add_child(lines)

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
 draft_selection_changed.emit(draft_key,selected)
 rebuild()

func insert_chapter(copy: bool,valley=false):
 var index=draft.insert_chapter(selected,copy,valley)
 if index>=0:dirty=true;select_chapter(index)

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
 select_chapter(0)

func save_draft() -> bool:
 var issue=draft.structural_problem(draft.data)
 if not issue.is_empty():status.text=issue;return false
 var saved=library.save(draft_key,draft.data)
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
 for record in records:
  action(list,record.document.get("title","Campaign"),func():
   if dirty and not save_draft():return
   if draft_key==record.key:dialog.queue_free();return
   var error=draft.decode(JSON.stringify(record.document,"",true,true))
   if not error.is_empty():status.text=error;return
   draft_key=record.key;dirty=false;select_chapter(0))
 dialog.popup_centered(Vector2i(440,320))

func open_poem_template(valley: bool):
 if dirty and not save_draft():return
 draft.load_poem_template(valley);draft_key="";dirty=true;select_chapter(0)

func show_transfer():
 var dialog=AcceptDialog.new();dialog.title="Campaign JSON";add_child(dialog)
 dialog.close_requested.connect(dialog.queue_free)
 dialog.confirmed.connect(dialog.queue_free)
 var panel=VBoxContainer.new();dialog.add_child(panel)
 heading(panel,"Copy this campaign or paste another Poem campaign document.",16)
 var source=multiline(draft.encode(),230,Callable());source.name="EditorTransferText";panel.add_child(source)
 var buttons=row(panel)
 action(buttons,"Copy JSON",func():DisplayServer.clipboard_set(source.text))
 action(buttons,"Import pasted JSON",func():
  var raw=source.text
  if dirty and not save_draft():return
  var issue=draft.decode(raw)
  if not issue.is_empty():status.text=issue;return
  draft_key="";dirty=true;select_chapter(0))
 dialog.popup_centered(Vector2i(560,350))

func launch(index: int,resume: bool,allow_single=false):
 var single_battle=not draft.playtest_problem().is_empty()
 if single_battle and (not allow_single or not draft.playtest_problem(index).is_empty()):return
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
