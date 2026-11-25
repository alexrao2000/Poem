extends VBoxContainer
signal closed
signal playtest_requested(start: int, resume: bool)
signal draft_selection_changed(key: String, chapter: int)
const Draft=preload("res://scripts/campaign_draft.gd")
const Grid=preload("res://scripts/campaign_editor_grid.gd")
const Settings=preload("res://scripts/campaign_settings.gd")
const TOOLS=["Terrain","Deployment","Enemy","Hard-mode enemy","Objective"]
const GOLD=Color("896937")
var draft: RefCounted
var library: RefCounted
var draft_key=""
var selected=0
var active_tab=0
var brush=0
var selected_person=0
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
 build_story(page(book,"Story"))
 build_company(page(book,"Company"))
 build_rules(page(book,"Rules"))
 book.current_tab=active_tab;book.tab_changed.connect(func(index):active_tab=index)
 status=heading(self,"",15);status.name="EditorStatus"
 var footer=row(self)
 play_buttons.append(action(footer,"Play from start",func():launch(0,false)))
 play_buttons.append(action(footer,"Play chapter",func():launch(selected,false)))
 play_buttons[-1].name="PlayEditedChapter"
 play_buttons.append(action(footer,"Resume playtest",func():launch(selected,true)))
 action(footer,"Return",func():closed.emit())
 validation()

func chapter() -> Dictionary:return draft.data.chapters[selected]
func level() -> Dictionary:return chapter().level

func build_battle(panel: VBoxContainer):
 var layout=level()
 var parameters=GridContainer.new();parameters.columns=2
 parameters.add_theme_constant_override("h_separation",12);parameters.add_theme_constant_override("v_separation",8);panel.add_child(parameters)
 field_label(parameters,"Objective",choice(Draft.OBJECTIVES,layout.objective,func(value):layout.objective=value;grid.queue_redraw();changed()))
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
 grid=Grid.new();grid.name="EditorGrid";panel.add_child(grid);grid.configure(layout);grid.tile_edited.connect(edit_tile)

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
  if old>=0:group[old]=enemy
  elif group.size()<24:group.append(enemy)
 else:
  layout.objective_position=position
 grid.queue_redraw()
 changed()

func same_tile(position: Array,point: Vector2i) -> bool:
 return int(position[0])==point.x and int(position[1])==point.y

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
 section.toggled.connect(func(value):record.section=value;changed())
 for field in [["intro","Briefing"],["tactical_brief","Tactical notes"],["outro","Outcome and finale text"]]:
  var key=field[0]
  heading(panel,field[1],17)
  panel.add_child(multiline(layout.get(key,""),76,func(value):layout[key]=value;changed()))
 heading(panel,"Dialogue uses one line per speaker. Enter an ID, a vertical bar, then their words.",15)
 for kind in ["opening","closing"]:
  heading(panel,kind.capitalize()+" dialogue",17)
  var text_rows=[]
  for line in record[kind]:text_rows.append(line.speaker+" | "+line.text.replace("\n"," "))
  panel.add_child(multiline("\n".join(text_rows),132,func(value):record[kind]=parse_dialogue(value);changed()))
 var route=row(panel)
 var x=spin(roundi(layout.route_position[0]*100),0,100,func(value):layout.route_position[0]=value/100.0;changed())
 var y=spin(roundi(layout.route_position[1]*100),0,100,func(value):layout.route_position[1]=value/100.0;changed())
 field_label(route,"Route pin X %",x);field_label(route,"Y %",y)

func build_company(panel: VBoxContainer):
 var company=draft.data.recruits
 var picker=choice(company.map(func(person):return person.id),company[selected_person].id,func(value):
  selected_person=company.find_custom(func(person):return person.id==value)
  rebuild())
 for index in company.size():picker.set_item_text(index,company[index].name+" · "+company[index].id)
 panel.add_child(picker)
 var person=company[selected_person]
 heading(panel,"Display name",17)
 panel.add_child(line_edit(person.name,"Recruit name",80,func(value):person.name=value;changed()))
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

func build_rules(panel: VBoxContainer):
 heading(panel,"Campaign title",17)
 panel.add_child(line_edit(draft.data.title,"Campaign title",120,func(value):draft.data.title=value;changed()))
 for setting in [{"key":"permadeath","name":"Permadeath","text":"Committed fallen allies stay lost."}]+Settings.SWITCHES:
  var key=setting.key
  var enabled=CheckButton.new();enabled.text=setting.name;enabled.button_pressed=draft.data.settings[key];panel.add_child(enabled)
  enabled.toggled.connect(func(value):draft.data.settings[key]=value;changed())
  heading(panel,setting.text,15)

func parse_dialogue(text: String) -> Array:
 var lines=[]
 for row_text in text.split("\n",false):
  var parts=row_text.split("|",true,1)
  var speaker=parts[0].strip_edges() if parts.size()==2 else "narrator"
  var words=parts[-1].strip_edges()
  if not words.is_empty():lines.append({"speaker":speaker if not speaker.is_empty() else "narrator","text":words})
 return lines

func select_chapter(index: int):
 selected=index
 draft_selection_changed.emit(draft_key,selected)
 rebuild()

func insert_chapter(copy: bool,valley=false):
 var index=draft.insert_chapter(selected,copy,valley)
 if index>=0:dirty=true;select_chapter(index)

func move_chapter(direction: int):
 dirty=true;select_chapter(draft.move_chapter(selected,direction))

func confirm_remove():
 var dialog=ConfirmationDialog.new();dialog.title="Remove chapter?"
 dialog.dialog_text="Recruit arrivals scheduled here move to the next surviving chapter."
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
 var records=library.list_drafts()
 if records.is_empty():heading(list,"Save a draft to add it here.",17)
 for record in records:
  action(list,record.document.get("title","Campaign"),func():
   if dirty and not save_draft():return
   var error=draft.decode(JSON.stringify(record.document))
   if not error.is_empty():status.text=error;return
   draft_key=record.key;dirty=false;select_chapter(0))
 action(list,"Copy Poem’s campaign",func():
  if dirty and not save_draft():return
  draft.data=draft.new_document(true);draft_key="";dirty=true;select_chapter(0))
 dialog.popup_centered(Vector2i(440,320))

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

func launch(index: int,resume: bool):
 if not draft.playtest_problem().is_empty():return
 draft_selection_changed.emit(draft_key,selected)
 playtest_requested.emit(index,resume)

func changed():
 dirty=true
 validation()

func validation():
 if not is_instance_valid(status):return
 var issue=draft.playtest_problem()
 status.text=("Unsaved draft" if dirty else "Ready to playtest") if issue.is_empty() else issue
 for button in play_buttons:button.disabled=not issue.is_empty()

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
