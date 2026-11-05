extends SceneTree
# permadeath carries casualties through victory, saves and later chapters. Failed
# attempts restart at preparation; memorials retain records without living actions.

const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")

func victory(game):
 for unit in game.units:
  if unit.team=="enemy":unit.hp=0
 assert(game.result()=="victory")

func dead_recruit(game,id="oren"):
 return game.roster.filter(func(unit):return unit.id==id)[0]

func press(app,text_value: String):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text==text_value)
 assert(buttons.size()==1 and not buttons[0].disabled,"Real enabled control exists: "+text_value)
 buttons[0].pressed.emit()

func verify_rules():
 var game=Rules.new();game.new_campaign(true);game.start_battle()
 var victim=game.units.filter(func(unit):return unit.id=="oren")[0];var foe=game.living("enemy")[0]
 victim.x=1;victim.y=3;victim.hp=1;victim.defense=0;victim.speed=0
 foe.x=2;foe.y=3;foe.pow=255;foe.speed=255;game.phase="enemy"
 var events=game.combat(foe,victim)
 assert(not events.is_empty() and victim.hp==0,"A real lethal strike creates a permadeath casualty")
 var mid=Rules.new();assert(mid.import_code(game.export_code("battle"))=="battle")
 assert(mid.permadeath and mid.units.filter(func(unit):return unit.id=="oren")[0].hp==0,"Mid-battle transfer retains the fallen unit and mode")
 victory(game);game.finish_chapter()
 var lost=dead_recruit(game)
 assert(lost.fallen and lost.fallen_chapter==0 and lost.hp==0,"Winning records the recruit and chapter of death")
 assert(lost not in game.available() and lost.id not in game.deployed,"Permanent losses cannot occupy deployment slots")
 assert(not game.equip(lost,lost.item),"Fallen records cannot change equipment")
 lost.level=10
 assert(not game.can_promote(lost,game.promotion_options(lost)[0].id),"Fallen records cannot be promoted")
 var bond=game.supports.for_unit(lost.id)[0]
 assert(not game.bond_available(bond),"A lost partner cannot unlock new conversations")
 game.permadeath=false
 var off=Rules.new();assert(off.import_code(game.export_code("camp"))=="camp" and not off.permadeath and dead_recruit(off).fallen,"Turning the rule off preserves earlier casualties across saves")
 game.permadeath=true
 var data=game.save_data("camp").duplicate(true);var loaded=Rules.new()
 assert(loaded.restore_save(data)=="camp" and dead_recruit(loaded).fallen)
 loaded.start_battle()
 assert(not loaded.units.any(func(unit):return unit.id=="oren"),"A dead recruit does not respawn in later chapters")
 var leader=loaded.units.filter(func(unit):return unit.id=="lyra")[0];leader.hp=0
 assert(loaded.result()=="defeat" and not loaded.living("player").is_empty(),"Lyra falling loses permadeath even with allies standing")
 var chapter=loaded.chapter;loaded.finish_chapter();assert(loaded.chapter==chapter,"A lost chapter cannot commit its casualties or advance")
 var saved_supports=loaded.battle_supports.duplicate(true)
 loaded.supports.state[bond.id]={"points":1,"rank":0,"chapter":chapter,"earned":1,"turn":1}
 var failed=Rules.new();assert(failed.import_code(loaded.export_code("battle"))=="battle")
 assert(failed.retry_battle() and failed.supports.state==saved_supports,"Retry after save/load restores pre-battle support gains")
 failed.start_battle()
 assert(failed.living("player").any(func(unit):return unit.id=="lyra") and not failed.units.any(func(unit):return unit.id=="oren"),"Retry revives this attempt's casualties but preserves older losses")
 for mutation in ["mode","flag","chapter","deployment","revived","leader_loss"]:
  var bad=data.duplicate(true)
  match mutation:
   "mode":bad.permadeath="unknown"
   "flag":bad.roster[1].fallen="yes"
   "chapter":bad.roster[1].fallen_chapter=50
   "deployment":bad.deployed.append("oren")
   "revived":bad.roster[1].hp=1
   "leader_loss":bad.roster[0].fallen=true;bad.roster[0].fallen_chapter=0;bad.roster[0].hp=0
  var before=failed.export_code("battle")
  assert(failed.restore_save(bad)=="" and failed.export_code("battle")==before,"Malformed casualty data is rejected atomically: "+mutation)
 var counter=Rules.new();counter.new_campaign(true);counter.start_battle()
 var attacker=counter.units.filter(func(unit):return unit.id=="oren")[0];var enemy=counter.living("enemy")[0]
 attacker.hp=1;attacker.pow=1;attacker.speed=0;attacker.x=1;attacker.y=3
 enemy.defense=255;enemy.pow=255;enemy.speed=255;enemy.x=2;enemy.y=3
 var counter_events=counter.combat(attacker,enemy)
 assert(counter_events.size()==2 and counter_events[1].target==attacker.id and attacker.hp==0,"A lethal enemy counter is recorded through the same casualty path")
 victory(counter);counter.finish_chapter();assert(dead_recruit(counter).fallen)
 var casual=Rules.new();casual.start_battle();casual.units[1].hp=0;victory(casual);casual.finish_chapter();casual.start_battle()
 assert(casual.units.any(func(unit):return unit.id=="oren" and unit.hp>0),"recovery keeps next-chapter recovery")
 var legacy=Rules.new().save_data("camp").duplicate(true);legacy.version=3;legacy.erase("permadeath");legacy.erase("battle_supports")
 for unit in legacy.roster:unit.erase("fallen");unit.erase("fallen_chapter")
 assert(failed.restore_save(legacy)=="camp" and failed.permadeath==false and failed.lost_ids().is_empty(),"Existing saves migrate to recovery without inventing losses")

func inspect(app,dimensions: Vector2):
 app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
 await process_frame;await process_frame
 for node in app.ui.find_children("*","Control",true,false):
  if not node.is_visible_in_tree():continue
  var parent=node.get_parent();var clipped=false
  while parent!=app.ui:
   if parent is ScrollContainer:clipped=true;break
   parent=parent.get_parent()
  if not clipped:assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(node.get_global_rect()),"permadeath fixed controls fit: "+app.screen+" "+str(dimensions))

func run():
 verify_rules()
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-permadeath-ui.json"
 root.add_child(app);await process_frame
 press(app,"Begin the chronicle");assert(app.screen=="campaign_rules")
 app.ui.find_child("Permadeath",true,false).button_pressed=true
 press(app,"Begin the chronicle");assert(app.game.permadeath and app.screen=="dialogue")
 app.finish_dialogue();app.game.start_battle()
 app.game.units.filter(func(unit):return unit.id=="oren")[0].hp=0;victory(app.game)
 await app.check_result();await process_frame
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return "permanently lost" in label.text),"Victory names the permanent casualty")
 press(app,"Continue the chronicle")
 assert(app.dialogue_lines.all(func(line):return line.speaker!="oren"),"A fallen recruit cannot speak in the victory scene")
 app.finish_dialogue()
 if app.screen=="dialogue":app.finish_dialogue()
 assert(app.screen=="camp" and dead_recruit(app.game).fallen)
 var card=app.ui.find_child("Company_oren",true,false)
 assert(card.deploy_button.disabled and card.deploy_button.text=="Permanently lost" and not card.portrait_button.disabled,"Memorial card prevents deployment while retaining the dossier")
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.show_camp();await inspect(app,dimensions)
  app.show_dossier(dead_recruit(app.game));await inspect(app,dimensions)
  assert(app.ui.find_children("*","Button",true,false).any(func(button):return button.text=="Advanced training" and button.disabled),"Memorial training control is disabled")
  app.show_supports(dead_recruit(app.game));await inspect(app,dimensions)
  app.show_campaign_rules();await inspect(app,dimensions)
 var entry=app.game.supports.for_unit("oren")[0]
 app.game.supports.state[entry.id]={"points":6,"rank":1,"chapter":1,"earned":0,"turn":1}
 app.show_supports(dead_recruit(app.game));app.read_support(dead_recruit(app.game),entry,1)
 assert(app.screen=="supports" and not app.supports_ready(dead_recruit(app.game)),"Fallen bonds cannot open or advertise unread conversations")
 app.read_support(dead_recruit(app.game),entry,0)
 assert(app.screen=="dialogue" and app.dialogue_lines.size()==entry.scenes[0].lines.size(),"Read support scenes remain complete memories")
 app.finish_dialogue();app.show_ending()
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return "Fell in chapter 01" in label.text),"Ending honors lost recruits instead of showing a living epilogue")
 app.game.start_battle();app.game.units.filter(func(unit):return unit.id=="lyra")[0].hp=0
 await app.check_result();press(app,"Regroup and retry")
 assert(app.screen=="camp" and app.game.units.is_empty() and dead_recruit(app.game).fallen,"Real retry returns to preparation without reviving a previous chapter's casualty")
 var restored=Rules.new();assert(restored.load_game(app.save_path)=="camp" and restored.permadeath and dead_recruit(restored).fallen,"Retry autosave retains permadeath and its earlier memorials")
 app.show_campaign_rules();app.ui.find_child("Permadeath",true,false).button_pressed=false;press(app,"Begin the chronicle");assert(app.game.permadeath==false and app.game.lost_ids().is_empty(),"Starting recovery clears the previous campaign's memorials")
 await Shutdown.dispose(app);await process_frame
 print("PASS: permadeath lethal combat, victory persistence, leader defeat/retry, later deployment, saves/transfers/legacy validation, living story speakers, memorial menus, support memories and recovery with the rule off")
 quit()
