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

func check_legacy_catalogue():
 var draft=Draft.new()
 draft.data.legacy_stock=[{"id":"pike","cost":1,"losses":1,"legacy_only":true}]
 assert(draft.playtest_problem().is_empty())
 var content=draft.compile().content
 var game=Rules.new(content)
 game.new_campaign(true);game.chapter=4;game.trials.flags.death_legacies=true
 var oren=game.roster.filter(func(unit):return unit.id=="oren")[0]
 assert(not game.equip(oren,"pike") and not game.trials.can_buy(game,"pike"))
 game.start_battle()
 game.units.filter(func(unit):return unit.id=="ivo")[0].hp=0
 game.commit_casualties()
 assert(game.trials.credits==1 and game.trials.can_buy(game,"pike") and game.trials.buy(game,"pike"))
 assert(game.equip(oren,"pike") and game.trials.credits==0 and not game.trials.buy(game,"pike"))
 var restored=Rules.new(content)
 assert(restored.import_code(game.export_code("camp"))=="camp" and restored.trials.purchases==["pike"])

func check_legacy_arrivals():
 var draft=Draft.new()
 var reserve=draft.data.recruits[draft.add_recruit(draft.data.recruits[2],"")]
 reserve.name="Aster"
 draft.data.chapters[-1].section=true
 draft.data.legacy_arrivals=[{"id":reserve.id,"losses":2,"job":"Warden","title":"The keeper’s apprentice",
  "lines":[{"speaker":reserve.id,"text":"The lamps will stay lit."}]}]
 assert(draft.recruit_in_use(reserve.id) and draft.playtest_problem().is_empty())
 var content=draft.compile().content
 var late=Rules.new(content)
 late.new_campaign(true);late.chapter=content.chapters.size()-1;late.trials.flags.section_restarts=true
 late.trials.arrive(late)
 assert(not late.available().any(func(member):return member.id==reserve.id))
 var game=Rules.new(content)
 game.new_campaign(true);game.trials.flags.death_legacies=true;game.start_battle()
 for fallen in ["sera","ivo"]:
  game.units.filter(func(member):return member.id==fallen)[0].hp=0
  game.commit_casualties()
  assert((reserve.id in game.trials.volunteers)==(fallen=="ivo"))
 assert(game.trials.credits==2 and "maelin" in game.trials.volunteers and "tovin" in game.trials.volunteers)
 var scene="volunteer_"+reserve.id
 assert(game.trials.scene_title(scene)=="The keeper’s apprentice" and scene in game.trials.earned_scenes)
 assert(game.trials.scene_lines(game,scene)[0].text=="The lamps will stay lit.")
 var restored=Rules.new(content)
 assert(restored.import_code(game.export_code("camp"))=="camp")
 assert(restored.available().any(func(member):return member.id==reserve.id))
 assert(restored.trials.earned_scenes==game.trials.earned_scenes)

func check_war_table_sites():
 var draft=Draft.new()
 var stage=draft.insert_chapter(1,false,true)
 var table=draft.data.chapters[stage].level
 var first=draft.data.chapters[0].level
 var second=draft.data.chapters[1].level
 var base=table.map.duplicate()
 first.route_position=[.2,.2];first.route_terrain="="
 second.route_position=[.2,.2];second.route_terrain="+"
 var shared=Valley.route_tile(first.route_position)
 assert(draft.valley_marks(stage)[shared].place==second.place)
 assert(draft.battle_level(stage).map[shared.y][shared.x]=="+")
 second.route_position=[.5,.7]
 var new_tile=Valley.route_tile(second.route_position)
 assert(draft.battle_level(stage).map[shared.y][shared.x]=="=")
 assert(draft.compile().content.chapters[stage].map[new_tile.y][new_tile.x]=="+")
 assert(table.map==base)
 first.route_position=table.route_position.duplicate()
 var objective=Vector2i(table.objective_position[0],table.objective_position[1])
 assert(not draft.valley_marks(stage).has(objective))
 assert(draft.battle_level(stage).map[shared.y][shared.x]==base[shared.y][shared.x])
 assert(draft.move_chapter(1,1)==stage and draft.valley_marks(1).is_empty())

func check_authored_relief():
 var draft=Draft.new()
 var reserve=draft.data.recruits[draft.add_recruit(draft.data.recruits[3],"")]
 reserve.name="Merrin"
 var rally=draft.data.chapters[4]
 rally.relief_company=[reserve.id,reserve.id]
 assert(not draft.playtest_problem().is_empty())
 rally.relief_company=[reserve.id]
 assert(draft.recruit_in_use(reserve.id) and draft.playtest_problem().is_empty())
 var content=draft.compile().content
 var game=Rules.new(content)
 game.new_campaign(true);game.chapter=3;game.trials.flags.section_restarts=true;game.start_battle()
 for enemy in game.living("enemy"):enemy.hp=0
 if game.info().objective=="seize":
  var leader=game.living("player")[0]
  leader.x=game.objective_position().x;leader.y=game.objective_position().y
 assert(game.result()=="victory")
 game.finish_chapter()
 assert(game.chapter==4 and reserve.id in game.trials.volunteers and "vela" not in game.trials.volunteers)
 assert(game.available().any(func(member):return member.id==reserve.id))
 assert(game.trials.events[-1].contains("Merrin"))
 game.deployed[-1]=reserve.id;game.start_battle()
 assert(game.trials.checkpoint.chapter==4 and game.units.any(func(member):return member.id==reserve.id))
 game.chapter=5;game.start_battle()
 game.units.filter(func(member):return member.id=="lyra")[0].hp=0
 assert(game.retry_battle() and game.chapter==4 and reserve.id in game.trials.volunteers)
 var restored=Rules.new(content)
 assert(restored.import_code(game.export_code("camp"))=="camp")
 assert(restored.available().any(func(member):return member.id==reserve.id))
 assert(draft.move_chapter(4,1)==5 and draft.compile().content.section_relief=={5:[reserve.id]})

func check_battle_readiness():
 var draft=Draft.new()
 draft.data=draft.new_document(false)
 var level=draft.data.chapters[0].level
 assert(draft.battle_readiness(0).title=="Ready")
 for y in level.map.size():draft.paint(level,Vector2i(7,y),"~")
 assert(draft.battle_readiness(0).title=="Check the route" and draft.playtest_problem().is_empty())
 draft.paint(level,Vector2i(7,4),"=")
 assert(draft.battle_readiness(0).title=="Ready")
 level.enemies.clear()
 assert(draft.battle_readiness(0).title=="Needs edits")

func check_terrain_undo():
 var draft=Draft.new()
 draft.data=draft.new_document(false)
 var index=draft.insert_chapter(0,false)
 var point=Vector2i(6,4)
 draft.remember_terrain(index)
 draft.paint(draft.data.chapters[index].level,point,"f")
 draft.data.title="Terrain edit"
 assert(draft.move_chapter(index,-1)==0 and draft.can_step_terrain(0,false))
 assert(draft.step_terrain(0,false) and draft.data.chapters[0].level.map[4][6]==".")
 assert(draft.data.title=="Terrain edit" and draft.step_terrain(0,true))
 assert(draft.data.chapters[0].level.map[4][6]=="f")
 assert(draft.step_terrain(0,false))
 draft.remember_terrain(0);draft.paint(draft.data.chapters[0].level,point,"h")
 assert(not draft.can_step_terrain(0,true))
 assert(draft.decode(draft.encode()).is_empty() and not draft.can_step_terrain(0,false))

func check_chapter_hard_bonuses():
 var draft=Draft.new()
 var bonuses={"max_hp":3,"pow":4,"speed":-1,"defense":2}
 draft.data.chapters[0].level.hard_bonuses=bonuses
 assert(not draft.playtest_problem().is_empty())
 bonuses.speed=0;assert(draft.playtest_problem().is_empty())
 var content=draft.compile().content
 var normal=Rules.new(content);normal.start_battle()
 var hard=Rules.new(content);hard.new_campaign(true)
 hard.trials.flags.hard_campaign=true;hard.trials.flags.reset_pressure=true;hard.trials.flags.section_restarts=true
 hard.trials.pressure=1;hard.start_battle()
 var regular_enemy=normal.living("enemy")[0]
 var prepared_enemy=hard.living("enemy")[0]
 assert(prepared_enemy.max_hp==regular_enemy.max_hp+5 and prepared_enemy.pow==regular_enemy.pow+5)
 assert(prepared_enemy.speed==regular_enemy.speed and prepared_enemy.defense==regular_enemy.defense+2)
 hard.chapter=1
 var retry=hard.trials.restart_preview(hard)
 assert(retry.chapter==0 and retry.enemies.max_hp==7 and retry.enemies.pow==6 and retry.enemies.held_tonics==0)
 assert(normal.trials.enemy_modifiers(0).max_hp==0)

func check_authored_raiders():
 var draft=Draft.new()
 draft.data=draft.new_document(false)
 var level=draft.data.chapters[0].level
 level.enemies[0].raider=true
 level.enemies[1].raider=false
 level.enemies.append({"job":"Vanguard","position":[7,6],"ai":"pursue","name":"Road raider","raider":true})
 level.enemies.append({"job":"Corsair","position":[8,6],"ai":"pursue","name":"Late raider","raider":true,
  "arrival_turn":2,"arrival_phase":"player"})
 assert(draft.playtest_problem().is_empty())
 var game=Rules.new(draft.compile().content)
 game.trials.flags.reset_pressure=true;game.trials.pressure=1;game.start_battle()
 var commander=game.units.filter(func(member):return member.id=="enemy_0")[0]
 var guard=game.units.filter(func(member):return member.id=="enemy_1")[0]
 var raider=game.units.filter(func(member):return member.id=="enemy_2")[0]
 assert(commander.boss and not commander.get("raider",false) and game.pos(commander)==Vector2i(11,4))
 assert(not guard.raider and game.pos(guard)==Vector2i(9,4))
 assert(raider.job=="Vanguard" and raider.raider and game.pos(raider)!=Vector2i(7,6))
 assert(game.enemy_waves.size()==1 and game.pos(game.enemy_waves[0].unit)==Vector2i(8,6))
 var restored=Rules.new(game.content)
 assert(restored.import_code(game.export_code("battle"))=="battle")
 assert(restored.at(game.pos(raider)).id=="enemy_2" and restored.at(game.pos(guard)).id=="enemy_1")

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

func verify_landmark_footing(landmarks: Node3D):
 for marker in landmarks.get_children():
  var tile=marker.get_meta("tile")
  for mesh in marker.get_children():
   var bounds=(marker.transform*mesh.transform)*mesh.get_aabb()
   assert(bounds.position.y>0 and bounds.end.y<.25)
   assert(bounds.position.x>tile.x-.5 and bounds.end.z<tile.y+.5)
   assert(Vector2(tile.x-bounds.end.x,bounds.position.z-tile.y).length()>.39)

func verify_custom_atlas(app,scratch: String):
 var sample=Image.create_empty(180,90,false,Image.FORMAT_RGBA8)
 sample.fill(Color("a24231"))
 sample.fill_rect(Rect2i(60,0,60,90),Color("397f59"))
 var path=scratch.path_join("custom-atlas.png")
 assert(sample.save_png(path)==OK and Draft.Atlas.pack(sample.save_jpg_to_buffer()).has("encoded"))
 var editor=app.campaign_editor
 var book=editor.find_child("CampaignEditorTabs",true,false)
 book.current_tab=book.get_tab_idx_from_control(editor.find_child("Route",true,false))
 await process_frame
 var original=editor.find_child("EditorRouteChart",true,false).positions.duplicate()
 editor.find_child("EditorOpenAtlas",true,false).pressed.emit();await process_frame
 editor.find_child("EditorCampaignFilePicker",true,false).file_selected.emit(path);await process_frame
 var chart=editor.find_child("EditorRouteChart",true,false)
 var picture=chart.map_picture
 assert(picture!=Route.MAP and picture.get_size()==Vector2(1200,800) and chart.positions==original)
 var center=picture.get_image().get_pixel(600,400)
 assert(center.g>center.r+.1)
 var grid=editor.find_child("EditorGrid",true,false)
 assert(grid.atlas==picture)
 var restored=Draft.new()
 assert(restored.decode(editor.draft.encode()).is_empty())
 assert(restored.route_texture().get_image().get_pixel(600,400).is_equal_approx(center))
 var malformed=restored.data.duplicate();malformed.route_atlas="AAAAAAAA"
 assert(restored.structural_problem(malformed).contains("invalid route atlas"))
 controls(app,"Play chapter").pressed.emit();await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==11)
 controls(app,"Route").pressed.emit();await process_frame
 assert(app.ui.find_child("CampaignRoute",true,false).map_picture==picture)
 controls(app,"Return to war council").pressed.emit();await process_frame
 controls(app,"Deploy company  >").pressed.emit()
 app.valley_reveal_skip=true;await finish_presentation(app)
 assert(app.world.get_node("ValleyChart").material_override.albedo_texture==picture and app.game.board_size()==Vector2i(24,16))
 app.show_battle_menu();await process_frame
 controls(app,"Return to editor").pressed.emit();await process_frame
 app.campaign_editor.find_child("EditorRestoreAtlas",true,false).pressed.emit();await process_frame
 assert(app.campaign_editor.find_child("EditorRouteChart",true,false).map_picture==Route.MAP)

func verify_moving_placements(app):
 var editor=app.campaign_editor
 var tabs=editor.find_child("CampaignEditorTabs",true,false)
 tabs.current_tab=0;await process_frame
 var mode=editor.find_child("EditorBrush",true,false)
 mode.select(5);mode.item_selected.emit(5)
 var grid=editor.find_child("EditorGrid",true,false)
 assert(not grid.paint_on_drag)
 var level=editor.level()
 var commander=level.enemies[0]
 var reinforcement=level.hard_enemies[0]
 commander.item="javelin";commander.level=9
 reinforcement.arrival_turn=3;reinforcement.arrival_phase="enemy"
 var original_commander=commander.duplicate(true)
 var original_wave=reinforcement.duplicate(true)
 var capital=Vector2i(21,2);var reserve=Vector2i(20,2)
 grid.tile_edited.emit(capital,false)
 assert(grid.marked_placement==capital)
 grid.tile_edited.emit(reserve,false)
 original_commander.position=[reserve.x,reserve.y];original_wave.position=[capital.x,capital.y]
 assert(commander==original_commander and reinforcement==original_wave and grid.marked_placement.x<0)
 assert(editor.draft.playtest_problem().is_empty())
 var water=Vector2i(-1,-1)
 for y in level.map.size():
  var x=level.map[y].find("~")
  if x>=0:water=Vector2i(x,y);break
 grid.tile_edited.emit(reserve,false);grid.tile_edited.emit(water,false)
 assert(commander==original_commander and grid.marked_placement==reserve)
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 grid._gui_input(escape)
 assert(grid.marked_placement.x<0 and app.screen=="campaign_editor")

func run():
 check_document()
 var scratch="/private/tmp/poem-campaign-editor-%d"%OS.get_process_id()
 assert(DirAccess.make_dir_recursive_absolute(scratch)==OK)
 check_long_campaign(scratch.path_join("long-campaign.json"))
 check_reinforcement_collision(scratch.path_join("timed-reinforcement.json"))
 check_shrinking_board(scratch.path_join("smaller-finale.json"))
 check_section_story()
 check_legacy_catalogue()
 check_legacy_arrivals()
 check_war_table_sites()
 check_authored_relief()
 check_battle_readiness()
 check_terrain_undo()
 check_chapter_hard_bonuses()
 check_authored_raiders()
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
  for name in ["SaveCampaignDraft","EditorCheckCampaign","EditorChapter","AddValleyBattle","CampaignEditorTabs","PlayEditedChapter"]:
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
 var table_terrain=editor.find_child("EditorRouteTerrain",true,false)
 for index in table_terrain.item_count:
  if table_terrain.get_item_metadata(index)=="o":
   table_terrain.select(index);table_terrain.item_selected.emit(index);break
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
 var stroke=InputEventMouseMotion.new();stroke.button_mask=MOUSE_BUTTON_MASK_LEFT
 stroke.position=terrain_canvas.board_rect().position+Vector2(7.5,5.5)*cell
 terrain_canvas._gui_input(stroke)
 click.pressed=false;terrain_canvas._gui_input(click)
 assert(editor.level().map[4][6]=="f" and editor.level().map[5][7]=="f")
 controls(app,"Undo terrain").pressed.emit()
 assert(editor.level().map[4][6]=="." and editor.level().map[5][7]==".")
 var redo=InputEventKey.new();redo.keycode=KEY_Z;redo.pressed=true;redo.meta_pressed=true;redo.shift_pressed=true
 terrain_canvas._gui_input(redo)
 assert(editor.level().map[4][6]=="f" and editor.level().map[5][7]=="f")
 use_brush(editor,4,Vector2i(0,3))
 editor.chapter().opening=[{"speaker":"lyra","text":"This is a new campaign."}]
 editor.level().title="River Gate"
 editor.level().place="River Gate"
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
 var retry_role=editor.find_child("EditorEnemyRetryRole",true,false)
 assert(not retry_role.disabled);retry_role.select(1);retry_role.item_selected.emit(1)
 assert(editor.level().enemies[1].raider==true)
 var arrival=editor.find_child("EditorEncounterArrivalPhase",true,false)
 arrival.select(1);arrival.item_selected.emit(1)
 assert(editor.level().enemies[1].arrival_phase=="enemy" and editor.find_child("EditorMakeCommander",true,false).disabled)
 assert(retry_role.disabled)
 editor.find_child("AddValleyBattle",true,false).pressed.emit()
 assert(editor.selected==1 and editor.level().map.size()==16 and editor.level().map[0].length()==24)
 var chart=editor.level()
 assert(chart.objective_position==Valley.CAPITAL and editor.draft.playtest_problem().is_empty())
 assert("~" in "".join(chart.map) and "=" in "".join(chart.map) and "h" in "".join(chart.map))
 var site_tile=Valley.route_tile([.27,.67])
 var table_grid=editor.find_child("EditorGrid",true,false)
 assert(table_grid.terrain_at(site_tile)=="o" and chart.map[site_tile.y][site_tile.x]!="o")
 var table_tabs=editor.find_child("CampaignEditorTabs",true,false)
 table_tabs.current_tab=0
 await process_frame;await process_frame
 var hover=InputEventMouseMotion.new()
 hover.position=table_grid.board_rect().position+(Vector2(site_tile)+Vector2(.5,.5))*table_grid.cell_size()
 table_grid._gui_input(hover)
 assert(editor.find_child("EditorAtlasTile",true,false).text=="6, 10 · Stronghold · River Gate")
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
 var exported_path=scratch.path_join("exported.campaign.json")
 controls(app,"Save JSON file").pressed.emit();await process_frame
 var picker=editor.find_child("EditorCampaignFilePicker",true,false)
 assert(picker.file_mode==FileDialog.FILE_MODE_SAVE_FILE and picker.current_file.ends_with(".campaign.json"))
 picker.file_selected.emit(exported_path);await process_frame
 assert(FileAccess.get_file_as_string(exported_path)==editor.draft.encode())
 assert(editor.find_child("EditorCampaignTransferStatus",true,false).text.contains("exported.campaign.json"))
 var malformed=scratch.path_join("malformed.campaign.json")
 var invalid_file=FileAccess.open(malformed,FileAccess.WRITE)
 invalid_file.store_string("{invalid");invalid_file.close()
 controls(app,"Open JSON file").pressed.emit();await process_frame
 picker=editor.find_child("EditorCampaignFilePicker",true,false)
 assert(picker.file_mode==FileDialog.FILE_MODE_OPEN_FILE)
 picker.file_selected.emit(malformed);await process_frame
 assert(editor.draft.encode()==transfer.text and editor.find_child("EditorCampaignTransferStatus",true,false).text.begins_with("JSON line"))
 controls(app,"Import pasted JSON").pressed.emit();await process_frame
 assert(editor.draft_key.is_empty() and editor.draft.dirty and editor.draft.data.chapters.size()==2)
 controls(app,"Transfer JSON").pressed.emit();await process_frame
 controls(app,"Open JSON file").pressed.emit();await process_frame
 picker=editor.find_child("EditorCampaignFilePicker",true,false)
 picker.file_selected.emit(exported_path);await process_frame
 assert(editor.draft_key.is_empty() and editor.draft.dirty)
 assert(editor.draft.compile().content.authoring_signature==copy.compile().content.authoring_signature)
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
 var defaults=Rules.new(editor.draft.compile().content)
 defaults.chapter=1;defaults.trials.flags.hard_campaign=true;defaults.start_battle()
 var default_wave=defaults.enemy_waves[0].unit
 editor.find_child("EditorHardBonuses",true,false).button_pressed=true
 editor.find_child("EditorHardBonus_max_hp",true,false).value=0
 editor.find_child("EditorHardBonus_pow",true,false).value=4
 assert(editor.level().hard_bonuses=={"max_hp":0,"pow":4,"speed":1,"defense":0})
 var hard=Rules.new(editor.draft.compile().content)
 hard.chapter=1;hard.trials.flags.hard_campaign=true;hard.start_battle()
 assert(hard.at(Vector2i(20,2))==null and hard.enemy_waves.size()==1)
 assert(hard.enemy_waves[0].unit.max_hp==default_wave.max_hp-7 and hard.enemy_waves[0].unit.pow==default_wave.pow+2)
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
 var landmarks=app.world.get_node("ValleyLandmarks")
 assert(landmarks.get_child_count()==2 and landmarks.get_children().all(func(marker):return not marker.visible))
 assert(ink.get_shader_parameter("front")<0.0 and app.camera.basis.z.is_equal_approx(Vector3.UP))
 assert(app.unit_nodes.values().all(func(piece):return not piece.visible))
 var persisted=app.game.save_data("battle").duplicate(true)
 var mid_reveal=[false]
 var landmarks_rising=[false]
 var inspect_reveal=func():
  if not app.valley_reveal_active:return
  var visible=app.unit_nodes.values().filter(func(piece):return piece.visible)
  if not visible.is_empty() and visible.size()<app.unit_nodes.size():mid_reveal[0]=true
  if landmarks.get_children().any(func(piece):return piece.visible and piece.position.y<.003):landmarks_rising[0]=true
  var frame=app.camera.get_viewport().get_visible_rect()
  for corner in Valley.reveal_corners(app.game.board_size()):
   assert(frame.grow(1).has_point(app.camera.unproject_position(corner)))
 process_frame.connect(inspect_reveal)
 await finish_presentation(app)
 process_frame.disconnect(inspect_reveal)
 assert(mid_reveal[0] and landmarks_rising[0] and not app.valley_reveal_active and app.ui.visible and app.markers.visible)
 assert(app.map_navigation.at_home() and app.game.save_data("battle")==persisted)
 assert(app.canvas.get_node_or_null("ValleyRevealHint")==null and ink.get_shader_parameter("front")>20.0)
 for piece in app.unit_nodes.values():assert(piece.visible and is_zero_approx(piece.position.y))
 assert(landmarks.get_children().all(func(marker):return marker.visible and is_equal_approx(marker.position.y,.003)))
 verify_landmark_footing(landmarks)
 assert(app.game.board_size()==Vector2i(24,16))
 app.click_tile(site_tile);await process_frame
 assert(app.game.terrain(site_tile)=="o" and app.terrain_card.place.text=="River Gate")
 assert(app.terrain_card.heading.text=="STRONGHOLD")
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
 var relief_pieces=app.world.get_node("ValleyLandmarks")
 verify_landmark_footing(relief_pieces)
 for name in places:
  var site=places[name]
  var relief_piece=relief_pieces.get_node("Landmark_%d_%d"%[site[0].x,site[0].y])
  assert(relief_piece.visible and relief_piece.get_meta("terrain")==app.game.terrain(site[0]))
  app.click_tile(site[0]);await process_frame
  assert(app.terrain_card.place.visible and app.terrain_card.place.text==name and app.terrain_card.heading.text==site[1])
 var abbey_opponent=app.game.living("enemy")[0].duplicate()
 abbey_opponent.x=9;abbey_opponent.y=5
 assert(app.scenery.combat_context(app.game,app.game.living("player")[0],abbey_opponent).environment=="abbey")
 assert(relief_pieces.has_node("Landmark_21_2") and not relief_pieces.has_node("Landmark_21_1"))
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
 app.campaign_draft.data.settings.death_legacies=true
 app.show_campaign_editor("title");await process_frame
 controls(app,"Check campaign").pressed.emit();await process_frame
 var readiness=app.campaign_editor.find_child("EditorCampaignReadiness",true,false)
 var chapter_ready=readiness.find_child("EditorReadinessChapter_1",true,false)
 assert(chapter_ready.text.ends_with("Ready"))
 assert(readiness.find_child("EditorReadinessNote_0",true,false).text.begins_with("Place at least one enemy"))
 chapter_ready.pressed.emit();await process_frame
 assert(app.campaign_editor.selected==ready and app.campaign_editor.active_tab==0)
 var section_book=app.campaign_editor.find_child("CampaignEditorTabs",true,false)
 section_book.current_tab=section_book.get_tab_idx_from_control(app.campaign_editor.find_child("Story",true,false))
 await process_frame
 controls(app,"Start a new campaign section").button_pressed=true
 app.campaign_editor.find_child("EditorSectionReliefDefault",true,false).button_pressed=false
 var relief_recruit=app.campaign_editor.find_child("EditorReliefRecruit",true,false)
 for index in relief_recruit.item_count:
  if relief_recruit.get_item_metadata(index)=="nell":relief_recruit.select(index);break
 controls(app,"Add to relief").pressed.emit()
 assert(app.campaign_editor.chapter().relief_company==["nell"])
 var withdrawal_title=app.campaign_editor.find_child("EditorSectionTitle_retreat",true,false)
 withdrawal_title.text="Withdrawal to the ridge";withdrawal_title.text_changed.emit(withdrawal_title.text)
 var withdrawal_lines=app.campaign_editor.find_child("EditorSectionLines_retreat",true,false)
 withdrawal_lines.text="lyra | The ridge is still ours.";withdrawal_lines.text_changed.emit()
 section_book.current_tab=section_book.get_tab_idx_from_control(app.campaign_editor.find_child("Rules",true,false))
 await process_frame
 controls(app,"Add item").pressed.emit()
 var added_stock=app.campaign_editor.draft.data.legacy_stock[-1]
 assert(added_stock.id=="pike" and added_stock.cost==1 and added_stock.losses==1)
 app.campaign_editor.find_child("EditorLegacyExclusive",true,false).button_pressed=true
 assert(added_stock.legacy_only)
 controls(app,"Add arrival").pressed.emit()
 var recruit_choice=app.campaign_editor.find_child("EditorLegacyArrivalRecruit",true,false)
 for index in recruit_choice.item_count:
  if recruit_choice.get_item_metadata(index)=="rook":
   recruit_choice.select(index);recruit_choice.item_selected.emit(index);break
 var arrival_class=app.campaign_editor.find_child("EditorLegacyArrivalClass",true,false)
 for index in arrival_class.item_count:
  if arrival_class.get_item_metadata(index)=="Ranger":
   arrival_class.select(index);arrival_class.item_selected.emit(index);break
 var arrival_title=app.campaign_editor.find_child("EditorLegacyArrivalTitle",true,false)
 arrival_title.text="Rook at the ridge";arrival_title.text_changed.emit(arrival_title.text)
 var arrival_lines=app.campaign_editor.find_child("EditorLegacyArrivalLines",true,false)
 arrival_lines.text="rook | I found the signal fire.";arrival_lines.text_changed.emit()
 controls(app,"Higher priority").pressed.emit()
 controls(app,"Higher priority").pressed.emit()
 assert(app.campaign_editor.draft.data.legacy_arrivals[0].id=="rook")
 assert(app.campaign_editor.play_buttons[0].disabled and app.campaign_editor.selected==1)
 controls(app,"Test this battle").pressed.emit();await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==1 and app.campaign_preview.return=="chapter")
 assert("nell" in app.game.trials.volunteers and "nell" in app.game.deployed)
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
 assert("nell" in app.game.trials.volunteers)
 app.show_campaign_trials();await process_frame
 controls(app,"Replay · Withdrawal to the ridge").pressed.emit()
 await await_phase_dialogue(app,"The ridge is still ours.")
 await finish_presentation(app)
 controls(app,"Return to war council").pressed.emit();await finish_presentation(app)
 controls(app,"Deploy company  >").pressed.emit();await finish_presentation(app)
 app.game.units.filter(func(unit):return unit.id=="sera")[0].hp=0
 app.game.commit_casualties();app.show_camp();await finish_presentation(app)
 assert("rook" in app.game.trials.volunteers and "volunteer_rook" in app.game.trials.read_scenes)
 assert(app.game.trials.scene_title("volunteer_rook")=="Rook at the ridge")
 app.show_campaign_trials();await process_frame
 controls(app,"Secure · Gatekeeper pike · 1 credit").pressed.emit();await process_frame
 assert(app.game.trials.purchases==["pike"] and app.game.trials.credits==0)
 assert(app.game.read_saved_data(app.campaign_save_path()).trials.purchases==["pike"])
 controls(app,"Return to war council").pressed.emit();await finish_presentation(app)
 controls(app,"Deploy company  >").pressed.emit();await finish_presentation(app)
 await capture_tile(app,Vector2i(0,3))
 controls(app,"Return to editor").pressed.emit();await finish_presentation(app)
 assert(app.screen=="campaign_editor" and app.game==installed and app.campaign_editor.selected==1)
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 controls(app,"Open drafts").pressed.emit();await process_frame
 app.campaign_editor.find_child("EditorValleyTemplate",true,false).pressed.emit();await process_frame
 var template=app.campaign_editor.draft
 assert(template.data.chapters.size()==13 and template.playtest_problem().is_empty())
 assert(template.data.chapters[10].level.place=="Crown Approach" and template.data.chapters[12].level.place=="The Sun Engine")
 assert(template.data.chapters[11].level.presentation=="valley_table" and template.data.chapters[11].phase_scenes.size()==1)
 var chapters=app.campaign_editor.find_child("EditorChapter",true,false)
 chapters.select(11);chapters.item_selected.emit(11)
 var editor_tabs=app.campaign_editor.find_child("CampaignEditorTabs",true,false)
 editor_tabs.current_tab=editor_tabs.get_tab_idx_from_control(app.campaign_editor.find_child("Story",true,false))
 await process_frame
 app.campaign_editor.find_child("EditorChapterDialogue_openingLossOptions",true,false).pressed.emit();await process_frame
 var loss_dialog=app.campaign_editor.find_child("EditorLossDialogue",true,false)
 var required=loss_dialog.find_child("EditorLossRequires",true,false)
 required.text="unknown_recruit";loss_dialog.confirmed.emit()
 assert(loss_dialog.visible and loss_dialog.find_child("EditorLossError",true,false).text.contains("unknown_recruit"))
 required.text="ivo"
 loss_dialog.find_child("EditorLossAlternatives",true,false).text="ivo | I can still see the ford.\nlyra | Leave Ivo’s lamp at the crossing."
 loss_dialog.confirmed.emit();await process_frame
 var opening_text=app.campaign_editor.find_child("EditorChapterDialogue_opening",true,false)
 opening_text.text+="\nnarrator | The companies look down at the roads.";opening_text.text_changed.emit()
 var opening=template.data.chapters[11].opening
 assert(opening[0].requires==["ivo"] and opening[0].when_absent.size()==2 and opening.size()==3)
 var exported=Draft.new()
 assert(exported.decode(template.encode()).is_empty() and exported.data.chapters[11].opening==opening)
 template.data.settings.permadeath=true;template.data.settings.action_saves=true
 template.data.settings.reset_pressure=true
 controls(app,"Play chapter").pressed.emit()
 await await_phase_dialogue(app,"Pull the seals off the chart. I want to see every road into the capital.")
 await finish_presentation(app)
 assert(app.screen=="camp" and app.game.chapter==11 and app.game.info().title=="The Roads Between")
 var ordinary_playtest=app.campaign_save_path()
 controls(app,"Deploy company  >").pressed.emit()
 app.valley_reveal_skip=true;await finish_presentation(app)
 var fallen_ivo=app.game.units.filter(func(member):return member.id=="ivo")[0]
 fallen_ivo.hp=0;app.game.commit_casualties()
 assert("ivo" in app.game.lost_ids())
 app.game.story_seen.erase("opening_11");app.show_camp()
 await await_phase_dialogue(app,"Leave Ivo’s lamp at the crossing.")
 await finish_presentation(app)
 controls(app,"Return to editor").pressed.emit();await process_frame
 assert(app.screen=="campaign_editor" and app.game==installed and app.campaign_editor.selected==11)
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 var ordinary_position=FileAccess.get_file_as_string(ordinary_playtest)
 var setup_tabs=app.campaign_editor.find_child("CampaignEditorTabs",true,false)
 setup_tabs.current_tab=setup_tabs.get_tab_idx_from_control(app.campaign_editor.find_child("Rules",true,false))
 await process_frame
 controls(app,"Save draft").pressed.emit();await process_frame
 var authored=template.encode()
 app.campaign_editor.find_child("EditorFixedSeed",true,false).button_pressed=true
 var seed=app.campaign_editor.find_child("EditorPlaytestSeed",true,false)
 var pressure=app.campaign_editor.find_child("EditorPlaytestPressure",true,false)
 assert(seed.is_visible_in_tree() and seed.value==Rules.DEFAULT_COMBAT_SEED and pressure.is_visible_in_tree())
 seed.value=267;pressure.value=2
 assert(template.encode()==authored)
 controls(app,"Play chapter").pressed.emit();await finish_presentation(app)
 var expected_rng=RandomNumberGenerator.new();expected_rng.seed=267
 assert(app.game.trials.pressure==2 and app.game.rng.state==expected_rng.state)
 var experiment_path=app.campaign_save_path()
 assert(experiment_path.ends_with("-seed-267-pressure-2.json") and ordinary_playtest!=experiment_path)
 controls(app,"Deploy company  >").pressed.emit()
 app.valley_reveal_skip=true;await finish_presentation(app)
 assert(app.game.living("enemy").all(func(member):return member.held_tonics==0))
 var experiment_snapshot=app.game.save_data("battle").duplicate(true)
 var legacy_layout=experiment_snapshot.duplicate(true)
 legacy_layout.layout_signature=JSON.stringify(app.game.layout_data()).sha256_text()
 assert(legacy_layout.layout_signature!=experiment_snapshot.layout_signature)
 var same_draft=Rules.new(app.game.content)
 assert(same_draft.restore_save(canonical(legacy_layout))=="battle")
 app.show_battle_menu();await process_frame
 controls(app,"Return to editor").pressed.emit();await process_frame
 controls(app,"Resume playtest").pressed.emit();await finish_presentation(app)
 assert(app.campaign_save_path()==experiment_path and app.screen=="battle")
 var resumed=canonical(app.game.save_data("battle"))
 var expected=canonical(experiment_snapshot)
 for key in expected:assert(resumed[key]==expected[key],"Resumed playtest differs in "+key)
 assert(FileAccess.get_file_as_string(ordinary_playtest)==ordinary_position)
 app.show_battle_menu();await process_frame
 controls(app,"Return to editor").pressed.emit();await process_frame
 assert(app.game==installed and FileAccess.get_file_as_string(app.save_path)==disk)
 var authoring_entry=app.campaign_draft_library.list_drafts()[0]
 var authoring_state=app.campaign_draft_library.editor_state(authoring_entry)
 assert(authoring_state.setup=={"fixed_seed":true,"seed":267,"pressure":2})
 assert(authoring_state.chapter==template.data.chapters[11].key and not JSON.parse_string(authored).has("editor"))
 controls(app,"Save draft").pressed.emit();await process_frame
 var saved_key=app.campaign_editor.draft_key
 var saved_title=app.campaign_editor.draft.data.title
 assert(not saved_key.is_empty())
 controls(app,"Open drafts").pressed.emit();await process_frame
 app.campaign_editor.find_child("EditorCopyDraft_"+saved_key,true,false).pressed.emit();await process_frame
 assert(app.campaign_editor.draft_key.is_empty() and app.campaign_editor.dirty)
 assert(app.campaign_editor.draft.data.title==saved_title+" (copy)")
 controls(app,"Save draft").pressed.emit();await process_frame
 var copy_key=app.campaign_editor.draft_key
 assert(not copy_key.is_empty() and copy_key!=saved_key)
 controls(app,"Open drafts").pressed.emit();await process_frame
 app.campaign_editor.find_child("EditorRemoveDraft_"+copy_key,true,false).pressed.emit();await process_frame
 var remove_draft=app.campaign_editor.find_child("EditorConfirmRemoveDraft",true,false)
 remove_draft.canceled.emit();await process_frame
 assert(app.campaign_draft_library.list_drafts().any(func(entry):return entry.key==copy_key))
 app.campaign_editor.find_child("EditorRemoveDraft_"+copy_key,true,false).pressed.emit();await process_frame
 remove_draft=app.campaign_editor.find_child("EditorConfirmRemoveDraft",true,false)
 remove_draft.confirmed.emit();await process_frame
 var remaining=app.campaign_draft_library.list_drafts()
 assert(remaining.any(func(entry):return entry.key==saved_key and entry.document.title==saved_title))
 assert(not remaining.any(func(entry):return entry.key==copy_key))
 assert(app.campaign_editor.draft_key.is_empty() and FileAccess.file_exists(experiment_path))
 app.campaign_editor.find_child("EditorOpenDraft_"+saved_key,true,false).pressed.emit();await process_frame
 assert(app.campaign_editor.draft_key==saved_key and app.campaign_editor.draft.data.title==saved_title and app.campaign_editor.selected==11)
 var preview_tabs=app.campaign_editor.find_child("CampaignEditorTabs",true,false)
 preview_tabs.current_tab=preview_tabs.get_tab_idx_from_control(app.campaign_editor.find_child("Encounters",true,false))
 await process_frame
 var draft_before_preview=app.campaign_editor.draft.encode()
 controls(app,"Preview deployment").pressed.emit();await process_frame
 var deployment=app.campaign_editor.find_child("EditorDeploymentPreview",true,false)
 assert(deployment.find_child("EditorDeploymentSummary",true,false).text=="Chapter 12 · Pressure 0 → 2")
 assert(deployment.find_child("EditorDeploymentStats_enemy_0",true,false).text.ends_with("Tonics 2 → 0"))
 for enemy in experiment_snapshot.units.filter(func(unit):return unit.team=="enemy"):
  var placement=deployment.find_child("EditorDeploymentPlacement_"+enemy.id,true,false).text
  assert(placement.get_slice(" · ",0).ends_with("%d, %d"%[enemy.x,enemy.y]))
  assert(placement.get_slice(" · ",1).ends_with(" "+str(int(enemy.hp))))
 deployment.find_child("EditorDeploymentPressure",true,false).value=1;await process_frame
 assert(deployment.find_child("EditorDeploymentStats_enemy_0",true,false).text.ends_with("Tonics 2 → 1"))
 assert(app.campaign_playtest_setup.pressure==2 and app.campaign_editor.draft.encode()==draft_before_preview)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.game==installed)
 deployment.confirmed.emit();await process_frame
 var reopened=load("res://main.tscn").instantiate();reopened.settings_path="";reopened.save_path=app.save_path
 reopened.campaign_draft_library.path=app.campaign_draft_library.path;reopened.campaign_playtest_directory=scratch
 root.add_child(reopened);await process_frame
 reopened.ui.find_child("OpenCampaignEditor",true,false).pressed.emit();await process_frame
 assert(reopened.campaign_editor.draft_key==saved_key and reopened.campaign_editor.selected==11)
 assert(reopened.campaign_playtest_setup=={"fixed_seed":true,"seed":267,"pressure":2})
 assert(reopened.campaign_draft.compile().content.authoring_signature==template.compile().content.authoring_signature)
 var probe=Rules.new(reopened.campaign_draft.compile().content)
 var replay_position=probe.read_saved_data(experiment_path)
 assert(not replay_position.is_empty(),"Reopened draft could not validate its earlier battle save")
 assert(probe.restore_save(replay_position)=="battle","Reopened draft produced a different battle layout signature")
 controls(reopened,"Resume playtest").pressed.emit();await finish_presentation(reopened)
 assert(reopened.screen=="battle" and reopened.campaign_save_path()==experiment_path,
  "Reopened test reached %s via %s instead of %s"%[reopened.screen,reopened.campaign_save_path(),experiment_path])
 assert(canonical(reopened.game.save_data("battle"))==expected)
 assert(FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(reopened);await process_frame
 await verify_custom_atlas(app,scratch)
 await verify_moving_placements(app)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and app.game==installed)
 await Shutdown.dispose(app);await process_frame
 print("PASS: campaign JSON file transfer, draft library management, remembered playtest setup, campaign readiness, authored Hard bonuses, authored retry raiders, deployment comparison, custom campaign atlas, terrain stroke undo, placement moves and swaps, route pins, war-table site terrain, rising Valley landmarks, custom recruits, phase scenes, timed reinforcements, chapter 32 saves, section dialogue, authored section relief, authored legacy stock and purchase persistence, authored loss recruits, authored loss dialogue, reproducible playtest setup, Valley carryover, thirteen-chapter Valley template, and single-battle tests")
 quit()
