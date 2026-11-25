extends SceneTree
const Draft=preload("res://scripts/campaign_draft.gd")
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Valley=preload("res://scripts/world_map_battle.gd")
const Route=preload("res://scripts/campaign_route.gd")
const Shutdown=preload("helpers/game_shutdown.gd")

func _initialize():call_deferred("run")

func canonical(data):return JSON.parse_string(JSON.stringify(data))

func controls(app,text_value: String) -> Button:
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text==text_value and button.is_visible_in_tree() and not button.disabled)
 assert(buttons.size()==1,text_value)
 return buttons[0]

func finish_presentation(app):
 var deadline=Time.get_ticks_msec()+20000
 while (app.busy or app.screen=="dialogue") and Time.get_ticks_msec()<deadline:
  await process_frame
  if app.screen=="dialogue":app.finish_dialogue()
  if app.chapter_card_active:app.chapter_card_skip=true
  if app.phase_banner_active:app.phase_skip=true
  if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
 assert(not app.busy and app.screen!="dialogue")

func check_document():
 var draft=Draft.new()
 assert(draft.playtest_problem().is_empty())
 var compiled=draft.compile()
 assert(compiled.content.chapters.size()==12 and compiled.content.section_starts==[0,4,8])
 assert(compiled.story.chapters==draft.base_story.chapters)
 var original=draft.encode()
 assert(draft.decode(original).is_empty())
 var broken=canonical(draft.data);broken.chapters[0].level.map[0]="~"
 assert(not draft.decode(JSON.stringify(broken)).is_empty())
 assert(canonical(draft.data)==JSON.parse_string(original))
 var selected=draft.insert_chapter(2,true)
 assert(selected==3 and draft.data.chapters[selected].key!="chapter_03")
 var original_first=draft.data.chapters[0].key
 var person=draft.data.recruits.filter(func(recruit):return recruit.id=="oren")[0]
 assert(person.chapter==original_first)
 assert(draft.move_chapter(0,1)==1 and draft.index_for(person.chapter)==1 and draft.data.chapters[0].section)
 var authored=draft.compile()
 assert(authored.content.roster.filter(func(recruit):return recruit.id=="oren")[0].join==1)
 assert(draft.remove_chapter(1)==1 and draft.index_for(person.chapter)==1)
 assert(draft.playtest_problem().is_empty())

func use_brush(editor,index: int,point: Vector2i,erase=false):
 var mode=editor.find_child("EditorBrush",true,false)
 mode.select(index);mode.item_selected.emit(index)
 var grid=editor.get_node(editor.get_path_to(editor.find_child("EditorGrid",true,false)))
 grid.tile_edited.emit(point,erase)

func capture_tile(app,point: Vector2i):
 var hero=app.game.units.filter(func(unit):return unit.id=="lyra")[0]
 assert(app.game.can_act(hero) and app.game.reachable(hero).has(point))
 app.click_tile(app.game.pos(hero),hero.id);app.click_tile(point)
 await finish_presentation(app)
 if app.screen=="battle":
  assert(app.game.pos(hero)==point)
  app.wait_action();await finish_presentation(app)
 assert(app.screen=="result" and app.game.result()=="victory")

func run():
 check_document()
 var scratch="/private/tmp/poem-campaign-editor-%d"%OS.get_process_id()
 assert(DirAccess.make_dir_recursive_absolute(scratch)==OK)
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path=scratch.path_join("normal.json")
 app.campaign_draft_library.path=scratch.path_join("drafts.json")
 app.campaign_playtest_directory=scratch
 root.add_child(app);await process_frame
 app.game.story_seen=["opening_0"]
 assert(app.persist_campaign("battle"))
 var installed=app.game
 var disk=FileAccess.get_file_as_string(app.save_path)
 app.game.roster[0].xp=17
 var original=app.game.save_data("battle").duplicate(true)
 app.ui.find_child("OpenCampaignEditor",true,false).pressed.emit()
 await process_frame
 assert(app.screen=="campaign_editor" and app.campaign_editor.draft.data.chapters.size()==12)
 var editor=app.campaign_editor
 for dimensions in [Vector2(720,640),Vector2(1024,640),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for name in ["SaveCampaignDraft","EditorChapter","AddValleyBattle","CampaignEditorTabs","PlayEditedChapter"]:
   var control=editor.find_child(name,true,false)
   assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"Editor layout %s, %s, %s"%[dimensions,name,control.get_global_rect()])
 controls(app,"New draft").pressed.emit()
 var selection=editor.find_child("EditorTerrain",true,false)
 for index in selection.item_count:
  if selection.get_item_metadata(index)=="f":selection.select(index)
 var terrain_canvas=editor.find_child("EditorGrid",true,false)
 await process_frame;await process_frame
 var cell=terrain_canvas.cell_size()
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 click.position=terrain_canvas.board_rect().position+Vector2(6.5,4.5)*cell
 terrain_canvas._gui_input(click)
 assert(editor.level().map[4][6]=="f")
 use_brush(editor,4,Vector2i(0,3))
 editor.chapter().opening=[{"speaker":"lyra","text":"This is a new campaign."}]
 editor.level().title="River Gate"
 editor.draft.data.title="The Editor Chronicle"
 var renamed=editor.draft.data.recruits.filter(func(recruit):return recruit.id=="oren")[0]
 renamed.name="Captain Oren";renamed.job="Duelist";renamed.stats.hp=31
 renamed.ending="Oren led the next company across the gate."
 editor.changed()
 editor.find_child("AddValleyBattle",true,false).pressed.emit()
 assert(editor.selected==1 and editor.level().map.size()==16 and editor.level().map[0].length()==24)
 var chart=editor.level()
 assert(chart.objective_position==Valley.CAPITAL and editor.draft.playtest_problem().is_empty())
 assert("~" in "".join(chart.map) and "=" in "".join(chart.map) and "h" in "".join(chart.map))
 controls(app,"Save draft").pressed.emit()
 assert(not editor.draft_key.is_empty() and app.campaign_draft_library.list_drafts().size()==1)
 var copy=Draft.new();assert(copy.decode(JSON.stringify(app.campaign_draft_library.list_drafts()[0].document)).is_empty())
 assert(copy.compile().content.authoring_signature==editor.draft.compile().content.authoring_signature)
 controls(app,"Transfer JSON").pressed.emit();await process_frame
 var transfer=editor.find_child("EditorTransferText",true,false)
 assert(transfer!=null and JSON.parse_string(transfer.text).title=="The Editor Chronicle")
 controls(app,"Import pasted JSON").pressed.emit();await process_frame
 assert(editor.draft_key.is_empty() and editor.draft.dirty and editor.draft.data.chapters.size()==2)
 editor.select_chapter(1)
 use_brush(editor,0,Vector2i(2,9),true)
 use_brush(editor,4,Vector2i(2,9))
 var paint=editor.find_child("EditorTerrain",true,false)
 for index in paint.item_count:
  if paint.get_item_metadata(index)=="f":paint.select(index)
 use_brush(editor,0,Vector2i(3,8))
 use_brush(editor,2,Vector2i(3,8))
 editor.level().deployment_positions.resize(2)
 assert(editor.draft.playtest_problem().is_empty(),editor.draft.playtest_problem())
 controls(app,"Play from start").pressed.emit()
 await finish_presentation(app)
 assert(app.screen=="camp" and app.game!=installed and app.game.info().title=="River Gate")
 var veteran=app.game.roster.filter(func(recruit):return recruit.id=="oren")[0]
 assert(veteran.name=="Captain Oren" and veteran.job=="Duelist" and veteran.max_hp==31 and veteran.weapon=="sword")
 assert(not installed.valid_save(app.game.save_data("camp")))
 app.preferences.values.auto_end=false
 controls(app,"Deploy company  >").pressed.emit();await finish_presentation(app)
 await capture_tile(app,Vector2i(0,3))
 controls(app,"Continue the chronicle").pressed.emit();await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==1 and app.game.info().presentation=="valley_table")
 assert(app.game.deployed.size()==2 and app.game.read_saved_data(app.campaign_save_path()).stage=="camp")
 controls(app,"Deploy company  >").pressed.emit();await finish_presentation(app)
 assert(app.game.board_size()==Vector2i(24,16))
 var paper=app.world.get_node("ValleyChart")
 assert(paper.material_override.albedo_texture==Route.MAP and Valley.MAP==Route.MAP)
 assert(app.world.has_node("ValleyTable") and app.world.has_node("ValleyGrid") and app.world.has_node("ValleyStandard"))
 assert(app.world.get_node("ValleyGrid").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==84)
 assert(app.map_height(Vector2i(7,5))==0 and app.game.terrain(Vector2i(7,5))=="+")
 var hero=app.game.units.filter(func(unit):return unit.id=="lyra")[0]
 assert(Tactics.new().distance_field(app.game,hero,[Vector2i(Valley.CAPITAL[0],Valley.CAPITAL[1])]).has(app.game.pos(hero)))
 var guard=app.game.at(Vector2i(3,8))
 assert(guard.team=="enemy" and app.game.can_attack(hero,guard))
 var before=app.game.save_data("battle").duplicate(true)
 var independently=Rules.new(app.game.content)
 assert(independently.restore_save(canonical(before))=="battle")
 var exchange=independently.combat(independently.at(app.game.pos(hero)),independently.at(Vector2i(3,8)))
 var witnessed=[false]
 var watch=func():
  if app.stage.visible:
   assert(app.stage.get_meta("environment")=="forest")
   witnessed[0]=true
 process_frame.connect(watch)
 await app.cinematic(hero,guard,exchange,{hero.id:hero.hp,guard.id:guard.hp})
 process_frame.disconnect(watch)
 assert(witnessed[0] and app.game.save_data("battle")==before and app.world.has_node("ValleyChart"))
 await capture_tile(app,Vector2i(2,9))
 controls(app,"Continue the chronicle").pressed.emit();await finish_presentation(app)
 assert(app.screen=="ending" and app.game.completed)
 assert(app.ui.find_child("Ending_oren",true,false).text==renamed.ending)
 var record=app.game.read_saved_data(app.campaign_save_path())
 assert(record.stage=="ending" and record.campaign_id==app.game.content.authoring_signature)
 controls(app,"Return to editor").pressed.emit();await process_frame
 assert(app.screen=="campaign_editor" and app.game==installed and app.game.save_data("battle")==original)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.campaign_editor.selected==1)
 controls(app,"Resume playtest").pressed.emit();await finish_presentation(app)
 assert(app.screen=="ending" and app.game.completed)
 controls(app,"Return to editor").pressed.emit();await process_frame
 app.game.chapter=10
 app.show_campaign_route();await process_frame
 var route_state=app.game.save_data("camp").duplicate(true)
 app.ui.find_child("OpenValleyFront",true,false).pressed.emit()
 await finish_presentation(app)
 assert(app.screen=="camp" and app.game.info().presentation=="valley_table" and app.game.chapter==11)
 controls(app,"Return to campaign route").pressed.emit();await process_frame
 assert(app.screen=="campaign_route" and app.game==installed and app.game.save_data("camp")==route_state)
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app);await process_frame
 print("PASS: campaign JSON and chapter order, three editor sizes, pointer terrain editing, saved draft, two complete authored chapters, valley geography, isolated resume and late route entrance")
 quit()
