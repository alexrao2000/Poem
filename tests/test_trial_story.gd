extends SceneTree
# Earned scenes survive section rewinds. They are read once during camp arrival,
# can be replayed as memories, and remain isolated with the debug save state.
const Rules=preload("res://scripts/rules.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func inspect_fixed(app):
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for node in app.ui.find_children("*","Control",true,false):
   if not node.is_visible_in_tree():continue
   var parent=node.get_parent();var clipped=false
   while parent!=app.ui:
    if parent is ScrollContainer:clipped=true;break
    parent=parent.get_parent()
   if not clipped:assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(node.get_global_rect()),"Epilogue and archive controls fit: "+app.screen)

func run():
 var game=Rules.new();var count=0;var ids=game.recruit_templates.keys()
 for scene in game.trials.scenes.values():
  for line in scene:
   assert(line.speaker in ids and line.text.length()>20 and line.text.length()<500);count+=1
 assert(count==39)
 game.trials.queue_scene("relief_4");game.trials.queue_scene("relief_4")
 assert(game.trials.earned_scenes.size()==1 and game.trials.next_scene(game).size()==5)
 assert(game.trials.next_scene(game).is_empty())
 var loaded=Rules.new();assert(loaded.import_code(game.export_code("camp"))=="camp" and loaded.trials.next_scene(loaded).is_empty(),"Read scenes survive save transfer")
 var malformed=game.save_data("camp").duplicate(true);malformed.trials.read_scenes.append("retreat_0")
 assert(not game.valid_save(malformed),"A scene cannot be read without being earned")
 game.trials.queue_scene("volunteer_faye");var faye=game.roster.filter(func(unit):return unit.id=="faye")[0];faye.fallen=true;faye.fallen_chapter=4;faye.hp=0
 assert(game.trials.next_scene(game).is_empty(),"An arrival scene cannot introduce a volunteer who has since died")
 for chapter in [0,4,8]:
  var mourning=Rules.new();mourning.new_campaign(true);mourning.chapter=chapter; mourning.trials.flags.death_legacies=true; mourning.trials.flags.section_restarts=true; mourning.death_door=true; mourning.start_battle()
  var patient=mourning.units[1];patient.hp=0; mourning.DeathDoor.fall(mourning,patient); mourning.commit_casualties()
  assert(mourning.trials.earned_scenes.is_empty(),"Downed allies are not memorialized while they can still be rescued")
  mourning.begin_enemy_phase();mourning.next_player_turn();mourning.begin_enemy_phase()
  var memorial="memorial_"+str(chapter)
  assert(memorial in mourning.trials.earned_scenes,"Terminal legacy loss earns the memorial for its section")
  var next=mourning.trials.next_scene(mourning)
  assert(next.size()==4 and next.all(func(line):return line.speaker=="lyra"),"Memorial precedes volunteer arrival and uses a surviving speaker")
  assert(patient.name in next[1].text and next[1].expression=="concerned")
  var other=mourning.units[2];other.hp=0;mourning.commit_casualties()
  assert(mourning.trials.earned_scenes.count(memorial)==1,"Later losses cannot repeat a section memorial")
  assert(mourning.trials.restart(mourning))
  var restored=Rules.new();assert(restored.import_code(mourning.export_code("camp"))=="camp")
  assert(memorial in restored.trials.read_scenes and restored.trials.earned_scenes.count(memorial)==1,"Memorial read state survives retreat and save transfer")
  var replay=restored.trials.scene_lines(restored,memorial)
  assert(replay.size()==4 and patient.name in replay[1].text and other.name in replay[1].text,
   "The section record includes later committed losses without queuing a second scene")
 var returning=Rules.new();returning.trials.flags.death_legacies=true;returning.start_battle();returning.units[1].hp=0;returning.commit_casualties()
 assert(returning.trials.earned_scenes.is_empty(),"Returning casualties do not trigger permanent-loss memorials")
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-trial-story-ui.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.chapter=4;app.game.story_seen=["opening_4"];app.game.trials.flags.section_restarts=true;app.game.trials.arrive(app.game)
 app.show_camp();assert(app.screen=="dialogue" and app.dialogue_lines.size()==5 and "abbey" in app.dialogue_lines[0].text)
 assert(loaded.load_game(app.save_path)=="camp" and "relief_4" in loaded.trials.read_scenes,"Camp arrival checkpoints the scene before playback")
 app.finish_dialogue();assert(app.screen=="camp")
 app.show_camp();assert(app.screen=="camp","Returning to camp does not replay the relief scene")
 app.show_campaign_trials()
 var replay=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Replay · Relief at the abbey")
 assert(replay.size()==1);replay[0].pressed.emit();assert(app.screen=="dialogue")
 app.finish_dialogue();assert(app.screen=="campaign_trials","Memory replay returns to the campaign ledger")
 app.game.trials.queue_scene("retreat_4");var saved=app.game.export_code("camp")
 app.debug_session.begin(app.game,"camp");app.game.trials.next_scene(app.game);app.debug_session.end(app.game)
 assert(app.game.export_code("camp")==saved,"Debug playback cannot consume a scene in the normal campaign")
 app.game.new_campaign(true);app.game.chapter=11;app.game.trials.flags.death_legacies=true;app.game.start_battle()
 app.game.units[1].hp=0;app.game.commit_casualties()
 for enemy in app.game.living("enemy"):enemy.hp=0
 assert(app.game.result()=="victory");app.game.finish_chapter();app.make_map();app.show_ending()
 assert(app.screen=="dialogue" and app.dialogue_lines.size()==4 and "monastery bell" in app.dialogue_lines[0].text,"A final-battle memorial is presented before the epilogue")
 var memorial_name=app.game.units[1].name
 assert(memorial_name in app.dialogue_lines[1].text and app.dialogue_lines[1].expression=="concerned")
 assert(loaded.load_game(app.save_path)=="ending" and "memorial_8" in loaded.trials.read_scenes,"Final memorial read state is saved as a completed campaign")
 app.finish_dialogue();assert(app.screen=="ending");await inspect_fixed(app)
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Company memories")[0].pressed.emit()
 assert(app.screen=="campaign_trials" and not app.ui.find_children("*","Button",true,false).any(func(button):return button.text.begins_with("Secure ·")),"Completed archives do not reopen the legacy shop")
 await inspect_fixed(app)
 var replay_memorial=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Replay · The monastery bell")[0]
 var completed=app.game.save_data("ending").duplicate(true);replay_memorial.pressed.emit()
 assert(app.screen=="dialogue" and memorial_name in app.dialogue_lines[1].text)
 app.finish_dialogue()
 assert(app.screen=="campaign_trials" and app.game.save_data("ending")==completed,"Archived memorial replay leaves the completed campaign unchanged")
 var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;app._unhandled_input(escape)
 assert(app.screen=="ending" and app.game.completed,"Escape from the completed archive returns to the epilogue, not deployment")
 app.show_campaign_trials();app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to epilogue")[0].pressed.emit()
 assert(app.screen=="ending","The archive return button also preserves the completed route")
 await verify_section_roll(app)
 await verify_legacy_warden(app)
 await verify_legacy_ranger(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: 39 original trial-story lines, section memorial roll of names, live and archive playback, one-time arrivals, saved read state, deceased volunteer guard and debug restoration")
 quit()

func verify_section_roll(app):
 var sample=Rules.new();sample.new_campaign(true);sample.chapter=8
 sample.trials.flags.death_legacies=true
 var ids=["oren","sera","ivo","mara","tarin","nell","faye"]
 for id in ids:sample.trials.losses[id]=8
 sample.trials.losses.bram=5
 sample.trials.injuries.esme=9
 var before=sample.save_data("camp").duplicate(true)
 var lines=sample.trials.scene_lines(sample,"memorial_8")
 assert(lines.size()==5 and "Oren, Sera, Ivo and Mara" in lines[1].text and "Tarin, Nell and Faye" in lines[2].text)
 assert(not lines.any(func(line):return "Bram" in line.text or "Esme" in line.text),"Only committed names in this section enter the roll")
 assert(sample.save_data("camp")==before and sample.trials.scenes.memorial_8.size()==3)
 var projected=app.game.save_data("ending").duplicate(true)
 app.show_dialogue(lines,app.show_ending,"support",8)
 for size in [Vector2(720,640),Vector2(720,900),Vector2(1024,640),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size
  for index in [1,2]:
   app.dialogue_index=index;app.refresh_dialogue();app.dialogue_stage.arrange()
   app.dialogue_stage.speech.visible_characters=-1;app.dialogue_stage.refresh_prompt()
   await process_frame;await process_frame
   var panel=app.dialogue_stage.panel
   var speech=app.dialogue_stage.speech
   assert(Rect2(Vector2.ZERO,size).grow(1).encloses(panel.get_global_rect()) and speech.get_line_count()<=speech.get_visible_line_count())
   var hint=app.dialogue_stage.hint
   assert(hint.get_line_count()<=hint.get_visible_line_count())
   assert(app.dialogue_portrait.texture==app.portraits.get_dialogue_portrait("lyra","concerned"))
 app.finish_dialogue()
 assert(app.game.save_data("ending")==projected)

func verify_legacy_warden(app):
 var game=app.game
 for flags in [[false,true],[true,false]]:
  game.new_campaign(flags[0]);game.trials.flags.death_legacies=flags[1]
  game.start_battle();game.units[3].hp=0;game.commit_casualties()
  assert(game.roster.size()==24 and "maelin" not in game.trials.volunteers)
 game.new_campaign(true)
 game.story_seen=["opening_0"]
 game.trials.flags.death_legacies=true;game.trials.flags.section_restarts=true
 game.action_saves=true;game.death_door=true;game.start_battle()
 var warden=game.units[3];assert(warden.id=="ivo")
 warden.hp=0;game.DeathDoor.fall(game,warden);game.commit_casualties()
 assert(game.roster.size()==24 and game.trials.losses.is_empty())
 game.begin_enemy_phase();game.next_player_turn();game.begin_enemy_phase()
 assert(game.lost_ids()==["ivo"] and game.trials.credits==1 and "maelin" in game.trials.volunteers)
 assert(game.units.all(func(unit):return unit.id!="maelin"),"The volunteer joins for the next deployment")
 var shifted=game.save_data("battle").duplicate(true)
 assert(app.persist_campaign("battle"))
 var resumed=Rules.new();assert(resumed.load_game(app.save_path)=="battle" and resumed.import_code(game.export_code("battle"))=="battle")
 assert(resumed.trials.volunteers==game.trials.volunteers)
 assert(JSON.parse_string(JSON.stringify(resumed.roster))==JSON.parse_string(JSON.stringify(game.roster)),
  "Every saved role, statistic and identity survives transfer")
 var forged=shifted.duplicate(true);forged.trials.volunteers.erase("maelin")
 assert(not resumed.valid_save(forged),"An optional recruit and its enlistment must agree")
 forged=shifted.duplicate(true);forged.trials.losses={"oren":0}
 assert(not resumed.valid_save(forged),"An unrelated loss cannot justify this Warden")
 assert(game.trials.restart(game) and game.roster.size()==25 and "maelin" in game.trials.volunteers)
 var recruit=game.available().filter(func(record):return record.id=="maelin")[0]
 assert(recruit.name=="Maelin" and recruit.job=="Warden" and recruit.item=="field_staff")
 assert(game.trials.earned_scenes.count("volunteer_maelin")==1)
 game.trials.flags.death_legacies=false
 assert(game.available().has(recruit),"Enlistment persists when the experiment is disabled")
 game.story_seen=["opening_0"];app.show_camp()
 for _index in 3:
  if app.dialogue_lines[0].speaker=="maelin":break
  app.finish_dialogue()
 assert(app.screen=="dialogue" and app.dialogue_lines[0].speaker=="maelin")
 assert(app.dialogue_speaker_name("maelin")=="Maelin")
 assert(resumed.load_game(app.save_path)=="camp" and "volunteer_maelin" in resumed.trials.read_scenes)
 await verify_legacy_expressions(app,"maelin","concerned")
 while app.screen=="dialogue":app.finish_dialogue()
 assert(app.screen=="camp" and app.ui.find_child("Company_maelin",true,false)!=null)
 game.deployed=["lyra","maelin"];game.start_battle();app.make_map();app.show_battle()
 var medic=game.living("player").filter(func(record):return record.id=="maelin")[0]
 var patient=game.living("player").filter(func(record):return record.id=="lyra")[0]
 medic.x=4;medic.y=3;patient.x=5;patient.y=3;patient.hp-=6
 app.refresh_pieces()
 var saw_model={"seen":false}
 var inspect=func():
  if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  if not app.stage.visible:return
  for node in app.stage.get_children():
   if node is Imported and node.model.get_meta("character_identity","")=="maelin":saw_model.seen=true
 process_frame.connect(inspect)
 assert(game.can_heal(medic,patient))
 app.preferences.values.auto_end=false;app.preferences.values.combat="all"
 app.click_tile(game.pos(medic));app.click_tile(game.pos(patient))
 var deadline=Time.get_ticks_msec()+12000
 while app.busy and Time.get_ticks_msec()<deadline:await process_frame
 process_frame.disconnect(inspect)
 assert(not app.busy and saw_model.seen and app.unit_nodes.has("maelin") and patient.hp==patient.max_hp and medic.acted)
 game.chapter=4;game.award_xp(recruit,123);game.start_battle()
 assert(game.trials.checkpoint.roster.any(func(record):return record.id=="maelin" and record.level==4))
 assert(resumed.import_code(game.export_code("battle"))=="battle" and resumed.trials.restart(resumed))
 assert(resumed.roster.filter(func(record):return record.id=="maelin" and record.level==4).size()==1,
  "A later section preserves her training at its checkpoint")
 medic=game.living("player").filter(func(record):return record.id=="maelin")[0]
 game.trials.flags.death_legacies=true;game.death_door=false
 medic.hp=0;game.commit_casualties()
 assert(game.lost_ids()==["ivo","maelin"] and game.trials.credits==2)
 assert(game.trials.restart(game) and game.roster.size()==25 and game.trials.earned_scenes.count("volunteer_maelin")==1)
 assert(game.available().all(func(record):return record.id!="maelin"))
 assert(resumed.import_code(game.export_code("camp"))=="camp" and "maelin" in resumed.lost_ids(),
  "Her eventual permanent loss also survives a rewind")
 print("PASS: permanent Warden loss alone enlists Maelin exactly once, preserves the recruit across disk, transfer and section rewind, and deploys her with a portrait and revised staff model")

func verify_legacy_ranger(app):
 var game=app.game;game.new_campaign(true)
 game.story_seen=["opening_0"];game.action_saves=true
 game.trials.flags.death_legacies=true;game.trials.flags.section_restarts=true
 game.start_battle()
 var fallen=game.units[2];assert(fallen.id=="sera")
 fallen.hp=0;game.commit_casualties()
 assert(game.lost_ids()==["sera"] and game.trials.volunteers==["faye","tovin"])
 assert(game.trials.restart(game) and game.chapter==0 and game.roster.size()==25)
 app.show_camp()
 for _index in 3:
  if app.dialogue_lines[0].speaker=="tovin":break
  app.finish_dialogue()
 assert(app.screen=="dialogue" and app.dialogue_lines[0].speaker=="tovin")
 await verify_legacy_expressions(app,"tovin","somber")
 while app.screen=="dialogue":app.finish_dialogue()
 assert(app.screen=="camp" and app.ui.find_child("Company_tovin",true,false)!=null)
 game.deployed=["lyra","tovin"];game.start_battle()
 var ranger=game.living("player").filter(func(unit):return unit.id=="tovin")[0]
 var guard=game.at(Vector2i(9,4))
 ranger.x=7;ranger.y=4
 app.make_map();app.show_battle()
 assert(app.unit_nodes.tovin.visual_id=="recruit.tovin" and ranger.item=="scout_bow")
 var scene={"model":false,"arrow":false}
 var inspect=func():
  if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  if not app.stage.visible:return
  for node in app.stage.get_children():
   if node is Imported and node.model.get_meta("character_identity","")=="tovin":scene.model=true
   if node.name=="CombatProjectile" and node.kind=="bow":scene.arrow=true
 process_frame.connect(inspect)
 assert(game.can_attack(ranger,guard))
 app.click_tile(game.pos(ranger));app.click_tile(game.pos(guard))
 assert(app.selected==ranger and app.target==guard)
 app.player_attack()
 var deadline=Time.get_ticks_msec()+12000
 while app.busy and Time.get_ticks_msec()<deadline:await process_frame
 process_frame.disconnect(inspect)
 assert(not app.busy and scene.model and scene.arrow and ranger.acted,
  "Expected revised bow playback, got %s with busy=%s and acted=%s"%[scene,app.busy,ranger.acted])
 var restored=Rules.new();assert(restored.load_game(app.save_path)=="battle")
 assert(restored.units.any(func(unit):return unit.id=="tovin" and unit.acted) and restored.lost_ids()==["sera"])
 print("PASS: permanent Ranger loss enlists Tovin with his own portrait and tactical sprite, survives the section rewind, and plays a saved revised 3D bow attack")

func verify_legacy_expressions(app,id: String,first: String):
 var neutral=app.portraits.get_dialogue_portrait(id)
 var packed_path=app.portraits.dialogue_expressions[id][first].path
 var declared=app.dialogue_lines.map(func(line):return line.expression)
 assert(declared==[first,"concerned","resolute","resolute"])
 var before=app.game.save_data("camp").duplicate(true)
 var issued=[]
 for line in app.dialogue_lines.duplicate(true):
  var portrait=app.dialogue_portrait
  assert(portrait.texture==app.portraits.get_dialogue_portrait(line.speaker,line.expression))
  if line.speaker==id:
   assert(portrait.texture!=neutral)
   issued.append(portrait.texture.get_instance_id())
  app.dialogue_label.visible_characters=-1
  app.dialogue_stage.next_button.pressed.emit()
 assert(issued.size()==2 and issued[0]!=issued[1])
 await process_frame;await process_frame
 var after=app.game.save_data("camp").duplicate(true)
 if app.screen=="dialogue":
  assert(after.trials.read_scenes.pop_back()=="retreat_0","The queued retreat scene follows the arrival")
 else:assert(app.screen=="camp")
 assert(after==before,"Expressions leave the campaign unchanged while the next earned scene opens normally")
 assert(not ResourceLoader.has_cached(packed_path),"The arrival sheet is released with its conversation")
 print("PASS: actual earned arrival expressions for ",id," advance smoothly and release the sheet")
