extends SceneTree
# Cross-section failures retain the consequence ledger while rewinding campaign
# progress. Trials are independently selectable and old saves remain permissive.
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func fall(game,id: String):
 var unit=game.units.filter(func(u):return u.id==id)[0]
 unit.hp=0;unit.erase("downed");unit.erase("bleed_turns");game.commit_casualties()
func victory(game):
 for enemy in game.living("enemy"):enemy.hp=0
 if game.info().objective=="seize":game.units[0].x=game.objective_position().x;game.units[0].y=game.objective_position().y
 assert(game.result()=="victory");game.finish_chapter()
func rules():
 for chapter in [2,5,11]:
  for permanent in [false,true]:
   for initial_pressure in [0,9,10]:
    var g=Rules.new();g.new_campaign(permanent);g.chapter=chapter;g.trials.flags.section_restarts=true;g.trials.flags.reset_pressure=true;g.trials.flags.hard_campaign=true;g.trials.pressure=initial_pressure;g.start_battle()
    var before=g.save_data("battle").duplicate(true);var preview=g.trials.restart_preview(g)
    assert(g.save_data("battle")==before,"Viewing retreat consequences cannot save a checkpoint, roll RNG or increase pressure")
    assert(preview.chapter==(int(chapter/4)*4 if permanent else chapter) and preview.pressure==mini(10,initial_pressure+1))
    assert(g.trials.restart(g) and g.chapter==preview.chapter and g.trials.pressure==preview.pressure,"The actual retreat uses the previewed chapter and capped pressure")
    assert(g.trials.enemy_modifiers(g.chapter)==preview.enemies,"Retreat preview includes hard bonuses from the destination chapter")
 for chapter in range(12):
  var unmodified=Rules.new();unmodified.chapter=chapter;unmodified.start_battle()
  for pressure in [0,1,2,10]:
   var prepared=Rules.new();prepared.chapter=chapter;prepared.trials.pressure=pressure
   prepared.trials.flags.hard_campaign=true;prepared.trials.flags.reset_pressure=true;prepared.start_battle()
   var modifiers=prepared.trials.enemy_modifiers(chapter)
   assert(modifiers.max_hp==6+chapter+pressure*2 and modifiers.pow==2+int(chapter/2)+pressure)
   assert(modifiers.speed==1+int(chapter/4) and modifiers.defense==int(chapter/3))
   assert(modifiers.held_tonics==maxi(0,2-pressure) and modifiers.raiders_advance==(pressure>0))
   var occupied=[]
   for unit in prepared.units:
    assert(prepared.pos(unit) not in occupied,"Reset advances cannot overlap deployed units")
    occupied.append(prepared.pos(unit))
    if unit.team!="enemy":continue
    var original_unit=unmodified.units.filter(func(other):return other.id==unit.id)[0]
    for key in ["max_hp","pow","speed","defense"]:assert(unit[key]==mini(prepared.STAT_CAPS[key],original_unit[key]+modifiers[key]),"Preparation preview matches actual enemy stats")
    assert(unit.held_tonics==modifiers.held_tonics)
   assert(prepared.valid_save(prepared.save_data("battle")),"Every pressure/chapter preparation remains loadable")
 var g=Rules.new();g.new_campaign(true);g.action_saves=true
 for key in g.trials.flags:g.trials.flags[key]=true
 g.start_battle();var base=Rules.new();base.start_battle()
 assert(g.living("enemy")[0].max_hp==base.living("enemy")[0].max_hp+6 and g.living("enemy")[0].pow==base.living("enemy")[0].pow+2)
 var hp=g.roster[0].max_hp
 fall(g,"oren");assert(g.trials.credits==1 and g.trials.losses.size()==1 and "faye" in g.available().map(func(u):return u.id),"Death unlocks a legacy credit and an early volunteer")
 g.commit_casualties();assert(g.trials.credits==1,"A death grants its event only once")
 assert(g.trials.buy(g,"tempered_sword") and not g.trials.buy(g,"tempered_sword") and g.equip(g.roster[0],"tempered_sword"),"Legacy purchase spends one credit and unlocks equipment early")
 victory(g);g.start_battle();victory(g);g.start_battle()
 assert(g.chapter==2);g.units[0].xp=90;fall(g,"lyra")
 assert(g.result()=="defeat" and g.retry_battle() and g.chapter==0 and g.trials.pressure==1)
 assert(g.roster[0].xp==0 and g.roster[0].max_hp==hp and g.roster[1].fallen,"Section restart rewinds growth, preserves casualties and revives only the lord")
 assert(g.trials.credits==0 and "tempered_sword" in g.trials.purchases and "faye" in g.trials.volunteers,"Purchases and volunteers survive section restart")
 var copied=Rules.new();assert(copied.import_code(g.export_code("camp"))=="camp" and copied.trials.pressure==1)
 g.start_battle();assert(g.living("enemy")[0].held_tonics==1 and g.living("enemy")[0].pow==base.living("enemy")[0].pow+3)
 var raiders=g.units.filter(func(u):return u.get("raider",false));assert(not raiders.is_empty())
 assert(raiders.any(func(u):return g.pos(u)!=base.pos(base.units.filter(func(original):return original.id==u.id)[0])),"Raider reset advance changes position before the new attempt")
 for index in range(4):victory(g);g.start_battle()
 assert(g.chapter==4 and g.trials.checkpoint.chapter==4 and "vela" in g.trials.volunteers and "dax" in g.trials.volunteers,"Section break delivers replacement recruits and a new checkpoint")
 victory(g);g.start_battle();fall(g,"faye");fall(g,"lyra");assert(g.retry_battle() and g.chapter==4)
 assert(g.roster.filter(func(u):return u.id=="faye")[0].fallen)
 var payload=g.export_code("camp");assert(copied.import_code(payload)=="camp","Losses later than the rewound chapter remain valid")
 g.trials.flags.section_restarts=false
 assert(copied.import_code(g.export_code("camp"))=="camp","Turning section restarts off does not invalidate recorded later losses")
 var casual=Rules.new();casual.trials.flags.reset_pressure=true;casual.trials.flags.sacrifice_cost=true;casual.start_battle()
 var original_pow=casual.attack_power(casual.units[0]);fall(casual,"oren")
 assert(casual.attack_power(casual.units[0])==original_pow+2,"A sacrifice creates a bounded attack opening")
 victory(casual);casual.start_battle();var returning=casual.units.filter(func(u):return u.id=="oren")[0]
 assert(returning.hp==returning.max_hp-4 and returning.potions==1 and not casual.roster[1].fallen)
 fall(casual,"lyra");assert(casual.result()=="defeat" and casual.retry_battle() and casual.trials.pressure==1,"Lord defeat applies reset pressure with permadeath off")
 var valid=copied.save_data("camp").duplicate(true)
 for key in ["pressure","credits"]:
  var invalid=valid.duplicate(true);invalid.trials[key]=-1;assert(not copied.valid_save(invalid))
 var invalid=valid.duplicate(true);invalid.trials.checkpoint.trials={};assert(not copied.valid_save(invalid),"Nested section checkpoints cannot be imported")
 invalid=valid.duplicate(true);invalid.trials.volunteers.append("unknown");assert(not copied.valid_save(invalid))
 invalid=valid.duplicate(true);invalid.trials.flags.hard_campaign="yes";assert(not copied.valid_save(invalid))
 invalid=valid.duplicate(true);invalid.trials.credits+=1;assert(not copied.valid_save(invalid),"Credits must match recorded losses and purchases")
 invalid=valid.duplicate(true);invalid.trials.losses[invalid.trials.losses.keys()[0]]=copied.content.chapters.size()
 assert(not copied.valid_save(invalid),"A recorded loss must belong to an existing chapter")
 invalid=valid.duplicate(true);invalid.trials.injuries.oren=copied.content.chapters.size()
 assert(copied.valid_save(invalid),"Recovery through the chapter after the finale remains a valid terminal record")
 casual.start_battle();var enemy=casual.living("enemy")[0];enemy.hp=1;casual.phase="enemy"
 var planner=preload("res://scripts/tactics.gd").new();var plan=planner.plan(casual,enemy)
 assert(plan.action=="tonic");planner.apply_plan(casual,enemy,plan)
 assert(enemy.hp==13 and enemy.held_tonics==0 and enemy.acted,"Enemies actually spend remaining held tonics after reset preparation")
 for key in ["held_tonics","reset_supplies_spent","resolve_until","raider","recovering"]:
  var malformed=casual.save_data("battle").duplicate(true);malformed.units[0][key]="bad";assert(not casual.valid_save(malformed))
func inspect(app):
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for node in app.ui.find_children("*","Control",true,false):
   if not node.is_visible_in_tree():continue
   var parent=node.get_parent();var clipped=false
   while parent!=app.ui:
    if parent is ScrollContainer:clipped=true;break
    parent=parent.get_parent()
   if not clipped:assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(node.get_global_rect()),"Experiment controls fit: "+app.screen)

func run():
 rules()
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-trials-ui.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.story_seen=["opening_0"];app.show_camp();app.show_options("camp")
 for key in app.game.trials.flags:app.ui.find_child(key,true,false).button_pressed=true
 await inspect(app)
 app.close_options();app.game.start_battle();fall(app.game,"oren")
 app.show_campaign_trials();await inspect(app)
 var purchase=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("Secure · Tempered"))
 assert(purchase.size()==1 and not purchase[0].disabled);purchase[0].pressed.emit()
 var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="camp" and loaded.trials.credits==0 and "tempered_sword" in loaded.trials.purchases,"Actual legacy shop purchase saves the campaign ledger")
 app.make_map();app.show_battle();var before_retreat=app.game.save_data("battle").duplicate(true)
 app.show_battle_menu();await inspect(app)
 var preview=app.ui.find_child("RestartPreview",true,false)
 assert("Pressure 0 → 1" in preview.text and "Held tonics: 1" in preview.text and "advance before deployment" in preview.text)
 assert(app.game.save_data("battle")==before_retreat,"Opening the visible retreat preview preserves the campaign")
 app.close_battle_menu();app.restart_campaign_attempt()
 assert(app.screen=="dialogue","A retreat enters its earned company scenes")
 while app.screen=="dialogue":app.finish_dialogue()
 assert(app.screen=="camp" and app.game.trials.pressure==1 and app.game.units.is_empty(),"Player-requested restart uses the same penalty and section path as defeat")
 app.game.new_campaign(true);app.game.chapter=5
 for key in ["reset_pressure","section_restarts","hard_campaign"]:app.game.trials.flags[key]=true
 app.game.start_battle();fall(app.game,"lyra");app.make_map();assert(await app.check_result())
 await inspect(app)
 var defeat_preview=app.ui.find_child("RestartPreview",true,false)
 assert("Return to Chapter 05" in defeat_preview.text and "Pressure 0 → 1" in defeat_preview.text and "+12 HP" in defeat_preview.text,"Defeat previews the beginning of the destination section, including its hard modifiers")
 app.game.new_campaign();app.game.trials.flags.reset_pressure=true;app.game.start_battle()
 app.preferences.values.combat="map"
 var enemy=app.game.living("enemy")[0];enemy.hp=1
 for foe in app.game.living("enemy"):
  if foe!=enemy:foe.hp=0
 app.make_map();app.show_battle();app.selected=enemy;app.update_side();await process_frame
 assert(app.side.find_children("*","Label",true,false).any(func(label):return "Held tonics: 2" in label.text),"Enemy inspection exposes its remaining consumables")
 await app.end_turn()
 assert(enemy.held_tonics==1 and enemy.hp>1 and not app.busy and app.game.phase=="player","Real enemy phase resolves and presents tonic use")
 await Shutdown.dispose(app);await process_frame
 print("PASS: independent campaign trials, harder enemies, irreversible legacy rewards/purchases, volunteers, section checkpoints/restarts, replacement arrivals, reset supply loss/raider advances, casual sacrifice openings/recovery and import validation")
 quit()
