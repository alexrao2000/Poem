extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new();var sword=g.roster[0];var bow=g.roster[2]
 assert(g.item_for(sword).might==3 and g.attack_speed(sword)==sword.speed,"Defaults retain original combat values")
 assert(not g.equip(sword,"longbow"),"Cannot equip another weapon class")
 assert(not g.equip(sword,"tempered_sword"),"Chapter-locked item")
 assert(g.equip(sword,"dueling_sword"),"Opening alternative available")
 g.chapter=5
 assert(g.equip(sword,"tempered_sword") and g.attack_speed(sword)==sword.speed-3,"Weight affects speed")
 assert(g.equip(bow,"longbow"));g.start_battle()
 var archer=g.units.filter(func(u):return u.id==bow.id)[0];var foe=g.living("enemy")[0]
 archer.x=2;archer.y=3;foe.x=5;foe.y=3
 assert(g.can_attack(archer,foe),"Longbow reaches three tiles")
 archer.ai="guard"
 var ai=Tactics.new();assert(ai.threatened_tiles(g,archer).has(g.pos(foe)),"Threat overlay includes longbow maximum range")
 assert(g.pos(archer) in ai.attack_positions(g,archer,foe),"AI plans from longbow range")
 foe.x=3;assert(not g.can_attack(archer,foe),"Longbow retains adjacent blind spot")
 var fighter=g.units[0];fighter.x=4;fighter.y=3;foe.x=5;foe.item="iron_sword";foe.speed=fighter.speed-4
 assert(not g.forecast(fighter,foe).double,"Heavy blade loses a marginal follow-up")
 fighter.item="iron_sword";assert(g.forecast(fighter,foe).double,"Standard blade keeps follow-up")
 var healer=g.units.filter(func(u):return u.weapon=="staff")[0]
 healer.item="beacon_staff";g.normalize_equipment(healer);healer.x=2;healer.y=3;fighter.hp-=12
 assert(g.heal(healer,fighter) and fighter.hp==fighter.max_hp-2,"Beacon heals ten HP at range two")
 assert(g.save_game("/private/tmp/poem-equipment-save.json","battle"))
 var restored=Rules.new();assert(restored.load_game("/private/tmp/poem-equipment-save.json")=="battle")
 assert(restored.roster[2].item=="longbow" and restored.roster[2].reach==3,"Equipment survives save roundtrip")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test_equipment-ui-save.json";root.add_child(app);await process_frame
 app.show_equipment(app.game.roster[0]);await process_frame
 assert(app.screen=="equipment","Equipment page opens")
 app.show_dossier(app.game.roster[0]);assert(app.screen=="dossier","Return to record")
 await Shutdown.dispose(app);await process_frame
 print("PASS: loadout compatibility, chapter unlocks, weight, range, healing and save persistence")
 quit()
