extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new();var book=g.supports;var members=[];var lines=0
 for entry in book.entries:
  assert(entry.scenes.size()==3 and entry.chapters.size()==3 and entry.points.size()==3)
  for id in entry.members:
   assert(id not in members,"Every recruit has one authored partner");members.append(id)
  for scene in entry.scenes:
   assert(scene.lines.size()>=4)
   for line in scene.lines:
    assert(line.speaker in entry.members and not line.text.is_empty());lines+=1
 assert(members.size()==26 and book.entries.size()==13 and lines>=160)
 assert(not book.can_read("lyra_oren",0) and not book.complete_scene("lyra_oren",0))
 g.start_battle();var a=g.units[0];var b=g.units[1]
 a.x=2;a.y=3;b.x=4;b.y=3
 book.earn(g,a);assert(book.progress("lyra_oren").points==1,"Two-tile cooperation earns a point")
 book.earn(g,b);assert(book.progress("lyra_oren").points==1,"Pair cannot double dip on the same turn")
 b.x=5;g.turn=2;book.earn(g,a);assert(book.progress("lyra_oren").points==1,"Out of range earns nothing")
 b.x=4;b.hp=0;book.earn(g,a);assert(book.progress("lyra_oren").points==1,"Fallen partner earns nothing")
 b.hp=b.max_hp
 for turn in range(2,8):g.turn=turn;book.earn(g,a)
 assert(book.progress("lyra_oren").points==3,"Chapter cap prevents endless farming")
 assert(book.complete_scene("lyra_oren",0) and book.progress("lyra_oren").rank==1)
 assert(not book.complete_scene("lyra_oren",0),"Story chapter gate is respected")
 g.chapter=1;g.turn=1;book.earn(g,a)
 assert(book.progress("lyra_oren").points==4 and book.progress("lyra_oren").earned==1,"New chapter opens another bounded allowance")
 assert(book.complete_scene("lyra_oren",1))
 for turn in [2,3]:g.turn=turn;book.earn(g,a)
 assert(book.complete_scene("lyra_oren",2) and not book.complete_scene("lyra_oren",11),"A rank is the final rank")
 g.chapter=2
 var foe=g.living("enemy")[0];a.x=2;b.x=3;foe.x=4;foe.y=3
 foe.speed=a.speed+5
 var supported=g.forecast(a,foe);var enemy_supported=g.forecast(foe,a)
 b.x=9
 var unsupported=g.forecast(a,foe);var enemy_unsupported=g.forecast(foe,a)
 assert(supported.hit==unsupported.hit+15 and supported.damage==unsupported.damage+1,"Rank A applies hit and damage near partner")
 assert(enemy_supported.hit<enemy_unsupported.hit,"Rank reduces incoming hit chance")
 assert(book.nearby_rank(g,a)==0,"Leaving range immediately removes support")
 b.x=3;b.hp=0;assert(book.nearby_rank(g,a)==0,"Defeated partners grant no bonuses")
 assert(book.nearby_rank(g,foe)==0,"Enemy does not inherit player bond")
 assert(g.valid_save(g.save_data("camp")))
 var restored=Rules.new();assert(restored.import_code(g.export_code("camp"))=="camp" and restored.supports.progress("lyra_oren").rank==3)
 var data=g.save_data("camp").duplicate(true);data.erase("supports");assert(restored.restore_save(data)=="camp" and restored.supports.state.is_empty(),"Old saves migrate to empty bonds")
 data.supports={"unknown":{}};assert(not g.valid_save(data))
 data.supports=book.state.duplicate(true);data.supports.lyra_oren.rank=4;assert(not g.valid_save(data))
 data.supports.lyra_oren.rank=1;data.supports.lyra_oren.points=0;assert(not g.valid_save(data),"Rank requires its earned points")
 # Real actions feed relationship progress; invalid actions do not.
 g.new_campaign();g.start_battle();a=g.units[0];b=g.units[1];foe=g.living("enemy")[0]
 a.x=3;a.y=3;b.x=3;b.y=4;foe.x=4;foe.y=3;foe.hp=1;a.speed=30
 g.combat(a,foe);assert(g.supports.progress("lyra_oren").points==1)
 var medic=g.units[3];var scout=g.units[2];medic.x=1;medic.y=4;scout.x=1;scout.y=3;scout.hp-=8
 assert(g.heal(medic,scout) and g.supports.progress("sera_ivo").points==1)
 assert(not g.heal(medic,scout) and g.supports.progress("sera_ivo").points==1)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-support-ui.json";root.add_child(app);await process_frame
 var unit=app.game.roster[0];var entry=app.game.supports.entries[0]
 app.game.supports.state[entry.id]={"points":3,"rank":0,"chapter":0,"earned":3,"turn":3}
 app.game.chapter=1;app.show_supports(unit);await process_frame;await process_frame
 assert(app.screen=="supports")
 app.read_support(unit,entry,0);await process_frame
 assert(app.screen=="dialogue" and app.dialogue_lines.size()==4)
 app.finish_dialogue();await process_frame
 assert(app.screen=="supports" and app.game.supports.progress(entry.id).rank==1,"Completing/skipping dialogue earns rank")
 app.read_support(unit,entry,0);app.finish_dialogue();await process_frame
 assert(app.game.supports.progress(entry.id).rank==1,"Replay does not award another rank")
 var saved=Rules.new();assert(saved.load_game(app.save_path)=="camp" and saved.supports.progress(entry.id).rank==1,"Read status persists")
 app.show_dossier(unit);await process_frame;await process_frame
 for control in app.ui.find_children("*","Button",true,false):assert(control.get_global_rect().end.y<=app.ui.size.y,"Dossier buttons stay within viewport")
 await verify_reserve_bond(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: 39 support scenes / ",lines," lines, all 26 recruits, bounded progression, combat bonuses, save migration and dialogue/replay UI")
 quit()

func verify_reserve_bond(app):
 var game=app.game;game.new_campaign(true);game.action_saves=true
 game.trials.flags.death_legacies=true;game.start_battle()
 var entry=game.supports.entry_for("maelin_tovin")
 var medic=game.units.filter(func(unit):return unit.id=="ivo")[0]
 medic.hp=0;game.commit_casualties()
 var maelin=game.available().filter(func(unit):return unit.id=="maelin")[0]
 assert(not game.bond_available(entry) and not app.supports_ready(maelin))
 app.show_dossier(maelin)
 var dossier_button=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Support conversations")[0]
 dossier_button.pressed.emit()
 assert(app.screen=="supports" and app.ui.find_children("*","Label",true,false).any(func(label):return "both recruits" in label.text))
 assert(app.ui.find_children("*","Button",true,false).all(func(button):return button.text!="Read conversation"))
 var scout=game.units.filter(func(unit):return unit.id=="sera")[0]
 scout.hp=0;game.commit_casualties()
 assert(game.bond_available(entry) and game.trials.volunteers.has("tovin"))
 var warden: Dictionary;var ranger: Dictionary;var foe: Dictionary
 for rank in range(3):
  game.chapter=int(entry.chapters[rank]);game.deployed=["lyra","maelin","tovin"];game.start_battle()
  warden=game.living("player").filter(func(unit):return unit.id=="maelin")[0]
  ranger=game.living("player").filter(func(unit):return unit.id=="tovin")[0]
  foe=game.living("enemy")[0]
  warden.x=3;warden.y=3;ranger.x=4;ranger.y=3;foe.x=6;foe.y=3
  assert(not app.supports_ready(maelin))
  var needed=int(entry.points[rank])-int(game.supports.progress(entry.id).points)
  for step in range(needed):
   ranger.hp=ranger.max_hp-4
   assert(game.heal(warden,ranger),"A real staff action earns the next bond point")
   if rank==0:
    assert(not game.combat(ranger,foe).is_empty())
    assert(game.supports.progress(entry.id).points==1,"Fight and heal share the same one-point allowance")
   game.next_player_turn()
  assert(game.supports.progress(entry.id).points==entry.points[rank] and app.supports_ready(maelin))
  app.show_dossier(maelin)
  var ready=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Support conversations · Ready")
  assert(ready.size()==1);ready[0].pressed.emit()
  var read=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Read conversation")
  assert(read.size()==1 and not read[0].disabled);read[0].pressed.emit()
  assert(app.screen=="dialogue" and app.dialogue_lines==entry.scenes[rank].lines)
  for line in entry.scenes[rank].lines:
   var face=app.portraits.get_dialogue_portrait(line.speaker,line.expression)
   assert(app.dialogue_portrait.texture==face and face!=app.portraits.get_dialogue_portrait(line.speaker))
   app.dialogue_label.visible_characters=-1;app.advance_dialogue()
  var saved=Rules.new();assert(saved.load_game(app.save_path)=="camp" and saved.supports.progress(entry.id).rank==rank+1)
  assert(app.screen=="supports" and game.supports.progress(entry.id).rank==rank+1 and not app.supports_ready(maelin))
  await process_frame
 foe.speed=game.attack_speed(ranger)+int(game.item_for(foe).weight)+5;foe.defense=0
 var bonded=game.forecast(ranger,foe)
 warden.x=9
 var separate=game.forecast(ranger,foe)
 assert(bonded.hit==separate.hit+15 and bonded.damage==separate.damage+1)
 ranger.hp=0;game.commit_casualties()
 assert(not game.bond_available(entry) and not app.supports_ready(maelin))
 app.show_supports(maelin)
 var archive=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Replay conversation")
 assert(archive.size()==3);archive[0].pressed.emit()
 assert(app.dialogue_lines==entry.scenes[0].lines,"An earned memory retains the fallen partner's original lines")
 app.finish_dialogue();await process_frame
 print("PASS: reserve bond unlocks after both losses, reaches three earned ranks with original expressions, applies existing nearby bonuses, and preserves memories after loss")
