extends SceneTree
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
 assert(members.size()==24 and book.entries.size()==12 and lines>=144)
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
 var app=load("res://main.tscn").instantiate();app.save_path="/private/tmp/ashen-support-ui.json";root.add_child(app);await process_frame
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
 app.queue_free();await process_frame
 print("PASS: 36 support scenes / ",lines," lines, all 24 recruits, bounded progression, combat bonuses, save migration and dialogue/replay UI")
 quit()
