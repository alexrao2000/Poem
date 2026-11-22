extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Comparison=preload("res://scripts/equipment_comparison.gd")
func _initialize():call_deferred("run")
func compare_catalog():
 var catalog=Rules.new();var count=0
 for recruit in catalog.roster:
  for path in [""]+catalog.promotion_options(recruit).map(func(entry):return entry.id):
   var game=Rules.new();game.chapter=11
   var unit=game.roster.filter(func(entry):return entry.id==recruit.id)[0]
   if not path.is_empty():game.award_xp(unit,900);assert(game.promote(unit,path))
   for item in game.equipment:
    if item.kind!=unit.weapon:continue
    var before=game.save_data("camp").duplicate(true);var rng_before=game.rng.state
    var old_power=game.healing_power(unit) if unit.weapon=="staff" else game.attack_power(unit)
    var old_speed=game.attack_speed(unit);var comparison=Comparison.preview(game,unit,item)
    assert(game.save_data("camp")==before and game.rng.state==rng_before,"Even locked-item inspection must not equip, save or roll growth")
    assert(game.equip(unit,item.id))
    var actual_power=game.healing_power(unit) if unit.weapon=="staff" else game.attack_power(unit)
    assert(comparison.power==actual_power and comparison.speed==game.attack_speed(unit))
    assert(comparison.power_change==actual_power-old_power and comparison.speed_change==game.attack_speed(unit)-old_speed)
    assert(comparison.text.contains("Healing" if unit.weapon=="staff" else "Attack") and not comparison.text.contains("(+0)"))
    count+=1
 assert(count==306,"Every compatible item across the full base and promoted roster is compared with actual equip results")
 var slow=catalog.roster.filter(func(unit):return unit.id=="oren")[0];catalog.chapter=11;assert(catalog.equip(slow,"pike"))
 var rally=catalog.equipment.filter(func(item):return item.id=="rally_lance")[0]
 assert(Comparison.preview(catalog,slow,rally).speed_change==1,"A weight change cannot imply speed below the zero floor")
func run():
 compare_catalog()
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
 assert(app.persist_campaign("camp"));var saved=FileAccess.get_file_as_string(app.save_path)
 var unchanged=app.game.save_data("camp").duplicate(true)
 for id in ["lyra","oren","ivo"]:
  var unit=app.game.roster.filter(func(entry):return entry.id==id)[0]
  app.show_equipment(unit);await process_frame;await process_frame
  for item in app.game.equipment:
   if item.kind!=unit.weapon:continue
   var label=app.ui.find_child("EquipmentComparison_"+item.id,true,false)
   if item.id==unit.item:assert(label==null)
   else:
    assert(label!=null and label.text==Comparison.preview(app.game,unit,item).text)
    var button=label.get_parent().find_children("*","Button",true,false)[0]
    if int(item.unlock)>0:assert(button.disabled,"Previewing future totals does not unlock equipment")
 assert(app.game.save_data("camp")==unchanged and FileAccess.get_file_as_string(app.save_path)==saved)
 app.show_dossier(app.game.roster[0]);assert(app.screen=="dossier","Return to record")
 await Shutdown.dispose(app);await process_frame
 print("PASS: loadout compatibility, chapter unlocks, weight, range, healing and save persistence; 306 actual base/promoted equip comparisons, zero-speed floor and read-only locked-item UI totals")
 quit()
