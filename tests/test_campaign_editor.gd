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

func await_phase_dialogue(app,text_value: String):
 var deadline=Time.get_ticks_msec()+3000
 while app.screen!="dialogue" and Time.get_ticks_msec()<deadline:
  if app.chapter_card_active:app.chapter_card_skip=true
  if app.phase_banner_active:app.phase_skip=true
  await process_frame
 assert(app.screen=="dialogue" and app.dialogue_label.text==text_value)

func check_document():
 var draft=Draft.new()
 assert(draft.playtest_problem().is_empty())
 var compiled=draft.compile()
 assert(compiled.content.chapters.size()==12 and compiled.content.section_starts==[0,4,8])
 assert(compiled.story.chapters==draft.base_story.chapters)
 assert(canonical(compiled.content.bonds)==canonical(Rules.new().supports.entries))
 assert(compiled.content.trial_scenes==draft.base_trial_scenes)
 var original=draft.encode()
 assert(draft.decode(original).is_empty())
 var broken=canonical(draft.data);broken.chapters[0].level.map[0]="~"
 assert(not draft.decode(JSON.stringify(broken)).is_empty())
 broken=canonical(draft.data);broken.bonds[1].members[0]="lyra"
 assert("unpaired" in draft.decode(JSON.stringify(broken)))
 broken=canonical(draft.data);broken.chapters[0].level.enemies[0].item="field_staff"
 assert("class cannot use" in draft.decode(JSON.stringify(broken)))
 broken=canonical(draft.data);broken.chapters[0].phase_scenes=[{"id":"scene_01","phase":"invalid","turn":2,"lines":[]}]
 assert("phase scene" in draft.decode(JSON.stringify(broken)))
 broken=canonical(draft.data);broken.chapters[0].level.enemies[0].arrival_turn=2
 var late_commander=Draft.new();assert(late_commander.decode(JSON.stringify(broken)).is_empty())
 assert("commander must start" in late_commander.playtest_problem())
 assert(canonical(draft.data)==JSON.parse_string(original))
 var selected=draft.insert_chapter(2,true)
 assert(selected==3 and draft.data.chapters[selected].key!="chapter_03")
 var original_first=draft.data.chapters[0].key
 var person=draft.data.recruits.filter(func(recruit):return recruit.id=="oren")[0]
 assert(person.chapter==original_first)
 assert(draft.move_chapter(0,1)==1 and draft.index_for(person.chapter)==1 and draft.data.chapters[0].section)
 var authored=draft.compile()
 assert(authored.content.roster.filter(func(recruit):return recruit.id=="oren")[0].join==1)
 assert(authored.content.bonds[0].chapters==[1,0,2])
 assert(draft.remove_chapter(1)==1 and draft.index_for(person.chapter)==1)
 assert(draft.data.bonds[0].chapters[0]==draft.data.chapters[1].key)
 assert(draft.playtest_problem().is_empty())

func check_long_campaign(path: String):
 var draft=Draft.new()
 while draft.data.chapters.size()<Draft.MAX_CHAPTERS:draft.insert_chapter(draft.data.chapters.size()-1,false)
 var finale=draft.data.chapters[-1]
 finale.level.enemies[0].position=[1,2]
 finale.level.enemy_level=4
 var bond=draft.data.bonds[0]
 bond.chapters[0]=finale.key
 assert(draft.playtest_problem().is_empty(),draft.playtest_problem())
 var content=draft.compile().content
 var game=Rules.new(content)
 game.chapter=31;game.start_battle()
 var hero=game.at(Vector2i(1,3));var enemy=game.at(Vector2i(1,2))
 assert(hero.id=="lyra" and enemy.level==4 and game.can_attack(hero,enemy))
 game.combat(hero,enemy)
 var progress=game.supports.progress(bond.id)
 assert(progress.chapter==31 and progress.points==1 and game.supports.can_read(bond.id,31),str(progress))
 assert(game.save_game(path,"battle"))
 var restored=Rules.new(content)
 var saved=restored.read_saved_data(path)
 assert(not saved.is_empty(),"The chapter 32 save failed validation")
 assert(restored.restore_save(saved)=="battle")
 assert(canonical(restored.supports.progress(bond.id))==canonical(progress))
 var malformed=saved.duplicate(true);malformed.supports[bond.id].chapter=32
 assert(not restored.valid_save(malformed) and not Rules.new().supports.valid_state(saved.supports))

func check_reinforcement_collision(path: String):
 var draft=Draft.new();draft.data=draft.new_document(false)
 var level=draft.data.chapters[0].level;level.objective="rout"
 var delayed=level.enemies[1]
 delayed.position=[0,3];delayed.arrival_turn=2
 var content=draft.compile().content
 var game=Rules.new(content)
 game.trials.flags.reset_pressure=true;game.trials.pressure=1
 game.start_battle()
 assert(game.living("enemy").size()==1 and game.enemy_waves.size()==1)
 game.living("enemy")[0].hp=0
 assert(game.result().is_empty())
 assert(game.move_unit(game.at(Vector2i(1,3)),Vector2i(0,3)))
 assert(game.save_game(path,"battle"))
 var restored=Rules.new(content)
 assert(restored.load_game(path)=="battle" and restored.enemy_waves.size()==1)
 restored.begin_enemy_phase();restored.next_player_turn()
 var arrived=restored.at(Vector2i(0,2))
 assert(arrived.id=="enemy_1" and arrived.held_tonics==1 and restored.at(Vector2i(0,3)).id=="lyra")
 assert(restored.enemy_waves.is_empty() and restored.living("enemy").size()==1)
 assert(restored.save_game(path,"battle") and restored.load_game(path)=="battle")
 restored.begin_enemy_phase();restored.next_player_turn()
 assert(restored.units.filter(func(unit):return unit.id=="enemy_1").size()==1)
 restored.at(Vector2i(0,2)).hp=0
 assert(restored.result()=="victory")

func check_shrinking_board(path: String):
 var draft=Draft.new()
 var stage=draft.insert_chapter(10,false,true)
 var content=draft.compile().content
 var game=Rules.new(content)
 game.chapter=stage;game.start_battle()
 var hero=game.living("player")[0]
 var capital=game.objective_position()
 game.at(capital).hp=0;hero.x=capital.x;hero.y=capital.y
 assert(game.result()=="victory")
 var old_battle=game.units.duplicate(true)
 game.finish_chapter()
 assert(game.chapter==stage+1 and game.info().place=="The Sun Engine" and game.units.is_empty())
 assert(game.save_game(path,"camp"))
 var restored=Rules.new(content)
 assert(restored.load_game(path)=="camp" and restored.chapter==game.chapter and restored.units.is_empty())
 var earlier_save=restored.save_data("camp").duplicate(true)
 earlier_save.units=old_battle
 assert(restored.restore_save(canonical(earlier_save))=="camp" and restored.units.is_empty())

func check_section_story():
 var draft=Draft.new()
 var edited=draft.data.chapters[4]
 edited.section_scenes.relief={"title":"Relief at the ridge","lines":[{"speaker":"lyra","text":"The ridge companies are here."}]}
 edited.section_scenes.memorial={"title":"The ridge roll","lines":[{"speaker":"lyra","text":"Open the ridge record."}]}
 assert(draft.move_chapter(4,1)==5)
 var game=Rules.new(draft.compile().content)
 assert(game.trials.scenes.has("relief_5") and not game.trials.scenes.has("relief_4"))
 game.chapter=5;game.permadeath=true;game.trials.flags.section_restarts=true
 game.trials.arrive(game)
 assert(game.trials.next_scene(game)[0].text=="The ridge companies are here.")
 assert(game.trials.scene_title("relief_5")=="Relief at the ridge")
 game.trials.losses.ivo=5;game.trials.queue_scene("memorial_5")
 var memorial=game.trials.next_scene(game)
 assert(memorial[0].text=="Open the ridge record." and "Ivo" in memorial[1].text)

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
 check_long_campaign(scratch.path_join("long-campaign.json"))
 check_reinforcement_collision(scratch.path_join("timed-reinforcement.json"))
 check_shrinking_board(scratch.path_join("smaller-finale.json"))
 check_section_story()
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
 var route_tabs=editor.find_child("CampaignEditorTabs",true,false)
 route_tabs.current_tab=route_tabs.get_tab_idx_from_control(editor.find_child("Route",true,false))
 await process_frame;await process_frame
 var route_chart=editor.find_child("EditorRouteChart",true,false)
 var pin=InputEventMouseButton.new();pin.button_index=MOUSE_BUTTON_LEFT;pin.pressed=true
 pin.position=route_chart.map_rect.position+route_chart.map_rect.size*Vector2(.21,.67)
 route_chart._gui_input(pin)
 assert(route_chart.positions[0].is_equal_approx(Vector2(.21,.67)))
 assert(editor.find_child("EditorRouteX",true,false).value==21 and editor.find_child("EditorRouteY",true,false).value==67)
 editor.find_child("EditorRouteX",true,false).value=27
 assert(route_chart.positions[0].is_equal_approx(Vector2(.27,.67)))
 route_tabs.current_tab=0
 await process_frame
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
 var book=editor.find_child("CampaignEditorTabs",true,false)
 book.current_tab=book.get_tab_idx_from_control(editor.find_child("Company",true,false))
 await process_frame
 var recruits=editor.find_child("EditorRecruit",true,false)
 recruits.select(2);recruits.item_selected.emit(2)
 await process_frame
 controls(app,"Add recruit").pressed.emit()
 await process_frame
 var custom=editor.draft.data.recruits[-1]
 assert(custom.id=="recruit_01" and custom.art_id=="sera" and custom.chapter==editor.chapter().key)
 var recruit_name=editor.find_child("EditorRecruitName",true,false)
 recruit_name.text="Linden";recruit_name.text_changed.emit(recruit_name.text)
 custom.bio="A signal scout who came down from the ridge."
 custom.ending="Linden marked the old roads for the next company."
 controls(app,"Deploy in the opening chapter").button_pressed=true
 editor.chapter().opening=[{"speaker":custom.id,"text":"We can take the upper road."}]
 assert(editor.draft.recruit_in_use(custom.id))
 book=editor.find_child("CampaignEditorTabs",true,false)
 book.current_tab=book.get_tab_idx_from_control(editor.find_child("Story",true,false))
 await process_frame
 controls(app,"Add phase scene").pressed.emit();await process_frame
 var phase_text=editor.find_child("EditorPhaseSceneLines",true,false)
 phase_text.text=custom.id+" | The signal is ours.";phase_text.text_changed.emit()
 controls(app,"Add phase scene").pressed.emit();await process_frame
 var side_picker=editor.find_child("EditorPhaseScenePhase",true,false)
 side_picker.select(1);side_picker.item_selected.emit(1)
 phase_text=editor.find_child("EditorPhaseSceneLines",true,false)
 phase_text.text="narrator | Their line is already moving.";phase_text.text_changed.emit()
 editor.draft.data.settings.action_saves=true
 assert(editor.chapter().phase_scenes.size()==2 and editor.chapter().phase_scenes[1].phase=="enemy")
 book.current_tab=book.get_tab_idx_from_control(editor.find_child("Encounters",true,false))
 await process_frame
 var first_encounter=editor.find_child("EditorEncounter",true,false)
 first_encounter.select(1);first_encounter.item_selected.emit(1)
 var arrival=editor.find_child("EditorEncounterArrivalPhase",true,false)
 arrival.select(1);arrival.item_selected.emit(1)
 assert(editor.level().enemies[1].arrival_phase=="enemy" and editor.find_child("EditorMakeCommander",true,false).disabled)
 editor.find_child("AddValleyBattle",true,false).pressed.emit()
 assert(editor.selected==1 and editor.level().map.size()==16 and editor.level().map[0].length()==24)
 var chart=editor.level()
 assert(chart.objective_position==Valley.CAPITAL and editor.draft.playtest_problem().is_empty())
 assert("~" in "".join(chart.map) and "=" in "".join(chart.map) and "h" in "".join(chart.map))
 var bonds_tabs=editor.find_child("CampaignEditorTabs",true,false)
 bonds_tabs.current_tab=bonds_tabs.get_tab_idx_from_control(editor.find_child("Bonds",true,false))
 await process_frame
 controls(app,"Add bond").pressed.emit()
 var first_bond=editor.draft.data.bonds[0]
 assert(first_bond.members==["lyra","oren"] and first_bond.chapters[0]==editor.chapter().key)
 var title=editor.find_child("EditorBondTitle0",true,false)
 title.text="Watch on the river";title.text_changed.emit(title.text)
 var lines=editor.find_child("EditorBondLines0",true,false)
 lines.text="lyra | The bridge is quiet now.";lines.text_changed.emit()
 var paired_ending=editor.find_child("EditorBondEnding",true,false)
 paired_ending.text="They returned to watch the river.";paired_ending.text_changed.emit()
 assert(first_bond.scenes[0].title==title.text and first_bond.scenes[0].lines[0].text=="The bridge is quiet now.")
 assert(first_bond.ending==paired_ending.text)
 controls(app,"Save draft").pressed.emit()
 assert(not editor.draft_key.is_empty() and app.campaign_draft_library.list_drafts().size()==1)
 var copy=Draft.new();assert(copy.decode(JSON.stringify(app.campaign_draft_library.list_drafts()[0].document,"",true,true)).is_empty())
 assert(copy.compile().content.authoring_signature==editor.draft.compile().content.authoring_signature)
 assert(Vector2(copy.data.chapters[0].level.route_position[0],copy.data.chapters[0].level.route_position[1]).is_equal_approx(Vector2(.27,.67)))
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
 var tabs=editor.find_child("CampaignEditorTabs",true,false)
 tabs.current_tab=tabs.get_tab_idx_from_control(editor.find_child("Encounters",true,false))
 await process_frame
 editor.find_child("EditorEncounterBaseLevel",true,false).value=6
 editor.find_child("EditorEncounterLevel",true,false).value=5
 var equipment=editor.find_child("EditorEncounterEquipment",true,false)
 for index in equipment.item_count:
  if equipment.get_item_metadata(index)=="javelin":equipment.select(index);equipment.item_selected.emit(index)
 var encounter=editor.find_child("EditorEncounter",true,false)
 encounter.select(1);encounter.item_selected.emit(1)
 controls(app,"Make commander").pressed.emit()
 assert(editor.level().enemies[0].name=="Capital garrison")
 encounter=editor.find_child("EditorEncounter",true,false)
 encounter.select(1);encounter.item_selected.emit(1)
 controls(app,"Make commander").pressed.emit()
 assert(editor.level().enemies[0].item=="javelin" and editor.level().enemies[0].level==5)
 encounter=editor.find_child("EditorEncounter",true,false)
 var reinforcement=encounter.item_count-1
 encounter.select(reinforcement);encounter.item_selected.emit(reinforcement)
 editor.find_child("EditorEncounterLevel",true,false).value=9
 editor.find_child("EditorEncounterArrivalTurn",true,false).value=2
 var hard=Rules.new(editor.draft.compile().content)
 hard.chapter=1;hard.trials.flags.hard_campaign=true;hard.start_battle()
 assert(hard.at(Vector2i(20,2))==null and hard.enemy_waves.size()==1)
 hard.begin_enemy_phase();hard.next_player_turn()
 assert(hard.at(Vector2i(20,2)).level==9 and hard.at(Vector2i(20,2)).job=="Warden")
 assert(editor.draft.playtest_problem().is_empty(),editor.draft.playtest_problem())
 controls(app,"Play from start").pressed.emit()
 assert(app.screen=="dialogue" and app.dialogue_name.text=="Linden" and app.dialogue_label.text=="We can take the upper road.")
 assert(app.dialogue_portrait.texture==app.portraits.get_dialogue_portrait("sera"))
 await finish_presentation(app)
 assert(app.screen=="camp" and app.game!=installed and app.game.info().title=="River Gate")
 var veteran=app.game.roster.filter(func(recruit):return recruit.id=="oren")[0]
 assert(veteran.name=="Captain Oren" and veteran.job=="Duelist" and veteran.max_hp==31 and veteran.weapon=="sword")
 var linden=app.game.roster.filter(func(recruit):return recruit.id==custom.id)[0]
 assert(linden.name=="Linden" and linden.job=="Ranger" and linden.id in app.game.deployed)
 app.show_dossier(linden);await process_frame
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return label.text==custom.bio))
 controls(app,"Return to war council").pressed.emit();await process_frame
 assert(not installed.valid_save(app.game.save_data("camp")))
 var playable_bond=app.game.supports.entry_for(first_bond.id)
 assert(playable_bond.scenes[0].title=="Watch on the river" and playable_bond.chapters==[1,1,1])
 app.preferences.values.auto_end=false
 controls(app,"Deploy company  >").pressed.emit()
 await await_phase_dialogue(app,"The signal is ours.")
 assert(app.game.turn==1 and app.game.phase=="player" and app.busy)
 var pending=app.game.pending_phase_scenes()
 var player_key=app.game.phase_scene_token(pending[0])
 var unfinished=app.game.read_saved_data(app.campaign_save_path())
 assert(player_key not in unfinished.story_seen and unfinished.stage=="battle")
 assert(unfinished.enemy_waves[0].unit.id=="enemy_1" and not app.unit_nodes.has("enemy_1"))
 await finish_presentation(app)
 assert(player_key in app.game.read_saved_data(app.campaign_save_path()).story_seen)
 assert(app.game.restore_save(unfinished)=="battle")
 app.resume_saved_battle()
 await await_phase_dialogue(app,"The signal is ours.")
 await finish_presentation(app)
 assert(app.game.pending_phase_scenes().is_empty())
 app.resume_saved_battle();await finish_presentation(app)
 assert(app.game.story_seen.count(player_key)==1 and app.screen=="battle")
 var deployed_linden=app.game.units.filter(func(unit):return unit.id==custom.id)[0]
 assert(app.unit_nodes[custom.id].visual_id=="recruit.sera")
 assert(app.unit_nodes[custom.id].marker.mesh is PlaneMesh and not app.unit_nodes[custom.id].on_war_table)
 var actor=app.make_preview_fighter(deployed_linden,Vector3(35,0,0),"revised")
 assert(actor.available and actor.actor.has_meta("source_model"))
 app.stage.remove_child(actor.actor);actor.actor.queue_free()
 var custom_save=app.game.read_saved_data(app.campaign_save_path())
 assert(custom_save.units.any(func(unit):return unit.id==custom.id and unit.art_id=="sera"))
 var edited_save=custom_save.duplicate(true)
 edited_save.roster.filter(func(unit):return unit.id==custom.id)[0].art_id="lyra"
 assert(not app.game.valid_save(edited_save))
 app.end_turn()
 await await_phase_dialogue(app,"Their line is already moving.")
 var enemy_scene=app.game.pending_phase_scenes()[0]
 var enemy_key=app.game.phase_scene_token(enemy_scene)
 assert(app.game.turn==1 and app.game.phase=="enemy" and app.game.living("enemy").all(func(enemy):return not enemy.acted))
 assert(app.game.enemy_waves.is_empty() and app.unit_nodes.has("enemy_1"))
 assert(app.game.read_saved_data(app.campaign_save_path()).units.any(func(unit):return unit.id=="enemy_1"))
 await finish_presentation(app)
 assert(app.game.turn==2 and app.game.phase=="player" and enemy_key in app.game.read_saved_data(app.campaign_save_path()).story_seen)
 await capture_tile(app,Vector2i(0,3))
 controls(app,"Continue the chronicle").pressed.emit();await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==1 and app.game.info().presentation=="valley_table")
 assert(app.game.deployed.size()==2 and app.game.read_saved_data(app.campaign_save_path()).stage=="camp")
 app.game.supports.state[first_bond.id]={"points":1,"rank":0,"chapter":0,"earned":1,"turn":1}
 app.read_support(veteran,playable_bond,0)
 assert(app.screen=="dialogue" and app.dialogue_label.text=="The bridge is quiet now.")
 app.finish_dialogue()
 assert(app.game.supports.progress(first_bond.id).rank==1 and app.game.read_saved_data(app.campaign_save_path()).supports[first_bond.id].rank==1)
 app.show_camp();await process_frame
 controls(app,"Deploy company  >").pressed.emit()
 assert(app.valley_reveal_active and app.busy and not app.ui.visible and not app.markers.visible)
 var ink=app.world.get_node("ValleyGrid").material_override
 assert(ink.get_shader_parameter("front")<0.0 and app.camera.basis.z.is_equal_approx(Vector3.UP))
 assert(app.unit_nodes.values().all(func(piece):return not piece.visible))
 var persisted=app.game.save_data("battle").duplicate(true)
 var mid_reveal=[false]
 var inspect_reveal=func():
  if not app.valley_reveal_active:return
  var visible=app.unit_nodes.values().filter(func(piece):return piece.visible)
  if not visible.is_empty() and visible.size()<app.unit_nodes.size():mid_reveal[0]=true
  var frame=app.camera.get_viewport().get_visible_rect()
  for corner in Valley.reveal_corners(app.game.board_size()):
   assert(frame.grow(1).has_point(app.camera.unproject_position(corner)))
 process_frame.connect(inspect_reveal)
 await finish_presentation(app)
 process_frame.disconnect(inspect_reveal)
 assert(mid_reveal[0] and not app.valley_reveal_active and app.ui.visible and app.markers.visible)
 assert(app.map_navigation.at_home() and app.game.save_data("battle")==persisted)
 assert(app.canvas.get_node_or_null("ValleyRevealHint")==null and ink.get_shader_parameter("front")>20.0)
 for piece in app.unit_nodes.values():assert(piece.visible and is_zero_approx(piece.position.y))
 assert(app.game.board_size()==Vector2i(24,16))
 var paper=app.world.get_node("ValleyChart")
 assert(paper.material_override.albedo_texture==Route.MAP and Valley.MAP==Route.MAP)
 assert(app.world.has_node("ValleyTable") and app.world.has_node("ValleyGrid") and app.world.has_node("ValleyStandard"))
 assert(app.world.has_node("ValleyRoomFloor"))
 var allied_counter=app.unit_nodes.lyra.marker
 var enemy_counter=app.unit_nodes.enemy_0.marker
 assert(allied_counter.name=="ValleyCounter" and enemy_counter.name=="ValleyCounter")
 assert(allied_counter.mesh==app.unit_nodes.oren.marker.mesh and allied_counter.mesh!=enemy_counter.mesh)
 assert(allied_counter.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==216)
 assert(enemy_counter.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==162)
 assert(allied_counter.mesh.get_aabb().end.y+allied_counter.position.y<app.unit_nodes.lyra.ring.position.y)
 var sample_material=allied_counter.material_override
 app.unit_nodes.oren.begin_rescue_transfer(.35)
 assert(app.unit_nodes.oren.marker.material_override!=sample_material and is_equal_approx(sample_material.albedo_color.a,1.0))
 assert(is_equal_approx(app.unit_nodes.oren.marker.material_override.albedo_color.a,.35))
 app.refresh_pieces();await process_frame
 assert(app.world.get_node("ValleyGrid").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==84)
 assert(app.map_height(Vector2i(7,5))==0 and app.game.terrain(Vector2i(7,5))=="+")
 var hero=app.game.units.filter(func(unit):return unit.id=="lyra")[0]
 assert(Tactics.new().distance_field(app.game,hero,[Vector2i(Valley.CAPITAL[0],Valley.CAPITAL[1])]).has(app.game.pos(hero)))
 var guard=app.game.at(Vector2i(3,8))
 assert(guard.team=="enemy" and guard.level==6 and app.game.can_attack(hero,guard))
 var commander=app.game.at(Vector2i(Valley.CAPITAL[0],Valley.CAPITAL[1]))
 assert(commander.boss and commander.level==5 and commander.item=="javelin" and commander.reach==2)
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
 assert(app.ui.find_child("Ending_"+custom.id,true,false).text==custom.ending)
 assert(app.ui.find_child("Ending_rhea",true,false)==null)
 var record=app.game.read_saved_data(app.campaign_save_path())
 assert(record.stage=="ending" and record.campaign_id==app.game.content.authoring_signature)
 controls(app,"Return to editor").pressed.emit();await process_frame
 assert(app.screen=="campaign_editor" and app.game==installed and app.game.save_data("battle")==original)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.campaign_editor.selected==1)
 controls(app,"Resume playtest").pressed.emit();await finish_presentation(app)
 assert(app.screen=="ending" and app.game.completed)
 app.game.supports.state[first_bond.id]={"points":6,"rank":3,"chapter":1,"earned":3,"turn":3}
 app.show_ending();await process_frame
 assert(app.ui.find_child("PairedEnding_"+first_bond.id,true,false).text==first_bond.ending)
 controls(app,"Return to editor").pressed.emit();await process_frame
 app.game.chapter=10
 app.game.permadeath=true
 app.game.trials.flags.death_legacies=true;app.game.trials.flags.reset_pressure=true;app.game.trials.flags.sacrifice_cost=true
 app.game.trials.pressure=2
 app.game.start_battle()
 var warden=app.game.units.filter(func(unit):return unit.id=="ivo")[0]
 warden.hp=0;app.game.commit_casualties()
 assert(app.game.lost_ids()==["ivo"] and "maelin" in app.game.trials.volunteers)
 app.game.trials.injuries.oren=11
 app.game.supports.state.lyra_oren={"points":3,"rank":1,"chapter":9,"earned":1,"turn":3}
 app.game.deployed=["lyra","maelin","oren","sera"]
 app.game.formation_order=["oren","maelin","lyra","sera"]
 app.show_campaign_route();await process_frame
 var route_state=app.game.save_data("camp").duplicate(true)
 app.ui.find_child("OpenValleyFront",true,false).pressed.emit()
 await finish_presentation(app)
 assert(app.screen=="camp" and app.game.info().presentation=="valley_table" and app.game.chapter==11)
 assert(app.campaign_save_path().get_file().begins_with("valley-front-"))
 assert(app.game.deployed==route_state.deployed and app.game.formation_order==route_state.formation_order)
 assert(app.game.lost_ids()==["ivo"] and app.game.trials.pressure==2 and app.game.trials.credits==1)
 assert(app.game.supports.progress("lyra_oren").rank==1 and app.game.rng.state==installed.rng.state)
 assert(app.game.read_saved_data(app.campaign_save_path()).stage=="camp")
 controls(app,"Deploy company  >").pressed.emit()
 assert(app.valley_reveal_active)
 var skip=InputEventKey.new();skip.keycode=KEY_TAB;skip.pressed=true
 app._input(skip)
 assert(app.valley_reveal_skip)
 await finish_presentation(app)
 assert(not app.valley_reveal_active and app.map_navigation.at_home() and app.ui.visible)
 assert(app.game.at(Vector2i(3,9)).id=="oren" and app.game.at(Vector2i(3,9)).potions==1)
 assert(app.game.at(Vector2i(4,9)).id=="maelin" and app.game.living("enemy").all(func(enemy):return enemy.held_tonics==0))
 var places={"Reed Crossing":[Vector2i(6,9),"BRIDGE"],"Hallow Abbey":[Vector2i(9,5),"SANCTUARY"],
  "Kingsroad":[Vector2i(12,8),"BRIDGE"],"Windscar Pass":[Vector2i(19,7),"HILL"]}
 for name in places:
  var site=places[name]
  app.click_tile(site[0]);await process_frame
  assert(app.terrain_card.place.visible and app.terrain_card.place.text==name and app.terrain_card.heading.text==site[1])
 app.click_tile(Vector2i(21,1));await process_frame
 assert(not app.terrain_card.place.visible and app.terrain_card.place.text.is_empty())
 assert(Valley.route_tile([1.0,1.0])==Vector2i(23,15))
 assert(Valley.reached_places(app.game.content.chapters,app.game.chapter).size()==11)
 app.show_battle_menu();await process_frame
 controls(app,"Return to campaign route").pressed.emit();await process_frame
 assert(app.screen=="campaign_route" and app.game==installed and app.game.save_data("camp")==route_state)
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 app.campaign_draft.data=app.campaign_draft.new_document(false)
 app.campaign_draft.data.chapters[0].level.enemies.clear()
 var ready=app.campaign_draft.insert_chapter(0,false)
 app.campaign_draft.data.chapters[ready].level.objective_position=[0,3]
 app.campaign_draft.data.settings.permadeath=true
 app.campaign_draft.data.settings.section_restarts=true
 app.show_campaign_editor("title");await process_frame
 app.campaign_editor.select_chapter(ready);await process_frame
 var section_book=app.campaign_editor.find_child("CampaignEditorTabs",true,false)
 section_book.current_tab=section_book.get_tab_idx_from_control(app.campaign_editor.find_child("Story",true,false))
 await process_frame
 controls(app,"Start a new campaign section").button_pressed=true
 var withdrawal_title=app.campaign_editor.find_child("EditorSectionTitle_retreat",true,false)
 withdrawal_title.text="Withdrawal to the ridge";withdrawal_title.text_changed.emit(withdrawal_title.text)
 var withdrawal_lines=app.campaign_editor.find_child("EditorSectionLines_retreat",true,false)
 withdrawal_lines.text="lyra | The ridge is still ours.";withdrawal_lines.text_changed.emit()
 assert(app.campaign_editor.play_buttons[0].disabled and app.campaign_editor.selected==1)
 controls(app,"Test this battle").pressed.emit();await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==1 and app.campaign_preview.return=="chapter")
 assert(app.campaign_save_path().get_file().begins_with("battle-test-1-"))
 controls(app,"Return to editor").pressed.emit();await process_frame
 controls(app,"Resume battle test").pressed.emit();await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==1)
 controls(app,"Deploy company  >").pressed.emit();await finish_presentation(app)
 assert(app.game.trials.section_starts==PackedInt32Array([0,1]) and app.game.trials.checkpoint.chapter==1)
 app.show_battle_menu();await process_frame
 controls(app,"War council (restart section)").pressed.emit()
 await await_phase_dialogue(app,"The ridge is still ours.")
 await finish_presentation(app)
 assert(app.screen=="camp" and "retreat_1" in app.game.trials.read_scenes)
 app.show_campaign_trials();await process_frame
 controls(app,"Replay · Withdrawal to the ridge").pressed.emit()
 await await_phase_dialogue(app,"The ridge is still ours.")
 await finish_presentation(app)
 controls(app,"Return to war council").pressed.emit();await finish_presentation(app)
 controls(app,"Deploy company  >").pressed.emit();await finish_presentation(app)
 await capture_tile(app,Vector2i(0,3))
 controls(app,"Return to editor").pressed.emit();await finish_presentation(app)
 assert(app.screen=="campaign_editor" and app.game==installed and app.campaign_editor.selected==1)
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app);await process_frame
 print("PASS: campaign JSON, route pins, custom recruits, phase scenes, timed reinforcements, chapter 32 saves, authored section withdrawal and memorials, Valley carryover, and single-battle tests")
 quit()
