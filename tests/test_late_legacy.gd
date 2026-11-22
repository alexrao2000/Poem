extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const NEW_STOCK=["rally_lance","vigil_staff"]
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func recruit(game,id):return game.roster.filter(func(u):return u.id==id)[0]
func fixture():
 var game=Rules.new();game.new_campaign(true);game.chapter=7;game.action_saves=true;game.trials.flags.death_legacies=true;game.trials.flags.section_restarts=true;game.deployed=["lyra","oren","ivo","sera","mara","tarin"];game.start_battle()
 for id in ["sera","mara","tarin"]:game.units.filter(func(u):return u.id==id)[0].hp=0
 game.commit_casualties();assert(game.trials.credits==3)
 return game
func run():
 for item_id in NEW_STOCK:
  var game=fixture();var target=recruit(game,"oren" if item_id=="rally_lance" else "ivo")
  assert(not game.equip(target,item_id) and game.trials.can_buy(game,item_id))
  assert(game.trials.buy(game,item_id) and game.trials.credits==1 and game.equip(target,item_id))
  assert(not game.trials.buy(game,item_id) and game.trials.credits==1)
  var transfer=game.export_code("battle");var copied=Rules.new();assert(copied.import_code(transfer)=="battle" and item_id in copied.trials.purchases)
  assert(game.trials.restart(game) and game.chapter==4 and game.trials.credits==1 and item_id in game.trials.purchases)
  assert(game.equip(recruit(game,target.id),item_id),"Purchased late supplies stay usable after a section rewind")
  assert(game.lost_ids().size()==3 and game.valid_save(game.save_data("camp")))
  game.trials.flags.death_legacies=false;assert(game.equip(recruit(game,target.id),item_id),"Disabling the experiment retains an earlier purchase")
  var fresh=Rules.new();var item=fresh.equipment.filter(func(entry):return entry.id==item_id)[0]
  fresh.chapter=int(item.unlock)-1;assert(not fresh.equip(recruit(fresh,target.id),item_id))
  fresh.chapter=int(item.unlock);assert(fresh.equip(recruit(fresh,target.id),item_id),"Ordinary campaigns unlock late supplies without requiring a death")
 var rules=Rules.new();rules.chapter=11;var lancer=recruit(rules,"oren");var healer=recruit(rules,"ivo")
 assert(rules.equip(lancer,"pike"));var pike_speed=rules.attack_speed(lancer);var pike_power=rules.attack_power(lancer);var pike_hit=rules.item_for(lancer).hit
 assert(rules.equip(lancer,"rally_lance") and rules.attack_speed(lancer)==pike_speed+1 and rules.attack_power(lancer)==pike_power-1 and rules.item_for(lancer).hit==pike_hit+15)
 lancer.speed=8;assert(rules.equip(lancer,"pike"));pike_speed=rules.attack_speed(lancer)
 assert(rules.equip(lancer,"rally_lance") and rules.attack_speed(lancer)==pike_speed+2,"Weight advantage respects the zero-speed floor for slow recruits")
 assert(rules.equip(healer,"beacon_staff"));var beacon_speed=rules.attack_speed(healer);var beacon_heal=rules.healing_power(healer)
 assert(rules.equip(healer,"vigil_staff") and rules.healing_power(healer)==beacon_heal+6 and rules.attack_speed(healer)==beacon_speed-3 and rules.range_text(healer)=="1–2")
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-late-legacy-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 for item_id in NEW_STOCK:
  var game=fixture();game.units.clear();game.story_seen=["opening_7"];game.trials.read_scenes=game.trials.earned_scenes.duplicate()
  assert(app.game.restore_save(game.save_data("camp"))=="camp");app.show_camp();assert(app.persist_campaign("camp"));app.show_campaign_trials()
  var disk=FileAccess.get_file_as_string(app.save_path);var before=canonical(app.game.save_data("camp"))
  for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size;await process_frame;await process_frame
   for stock in app.game.trials.LEGACY_STOCK:
    var entry=app.ui.find_child("LegacyStock_"+stock.id,true,false)
    assert(entry.icon.resource_path=="res://assets/ui/items/"+stock.id+".svg" and entry.size.x>=entry.get_minimum_size().x,"Available and future stock retain their named item art without clipping the button")
   for id in NEW_STOCK:
    var button=app.ui.find_child("LegacyStock_"+id,true,false);assert(not button.disabled and button.text.begins_with("Secure · "))
    var scroll=button.get_parent().get_parent();scroll.ensure_control_visible(button);await process_frame;await process_frame
    assert(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()) and button.size.x>=button.get_minimum_size().x)
  assert(canonical(app.game.save_data("camp"))==before and FileAccess.get_file_as_string(app.save_path)==disk)
  app.ui.find_child("LegacyStock_"+item_id,true,false).pressed.emit();await process_frame;await process_frame
  var bought=app.ui.find_child("LegacyStock_"+item_id,true,false);assert(bought.disabled and bought.text.begins_with("Secured · ") and app.game.trials.credits==1)
  assert(bought.icon.resource_path=="res://assets/ui/items/"+item_id+".svg","Secured stock retains its identity after the purchase rebuild")
  var saved=Rules.new();assert(saved.load_game(app.save_path)=="camp" and saved.trials.purchases==[item_id] and saved.trials.credits==1)
  var target=recruit(app.game,"oren" if item_id=="rally_lance" else "ivo");app.show_equipment(target);await process_frame;await process_frame
  var item=app.game.equipment.filter(func(entry):return entry.id==item_id)[0]
  var title=app.ui.find_children("*","Label",true,false).filter(func(label):return label.text==item.name)[0]
  var details=title.get_parent().get_parent();var equip=details.find_children("*","Button",true,false)[0]
  assert(equip.text=="Equip" and not equip.disabled);equip.pressed.emit();await process_frame;await process_frame
  assert(target.item==item_id and saved.load_game(app.save_path)=="camp" and recruit(saved,target.id).item==item_id)
  if item_id=="vigil_staff":assert(app.ui.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Healing 16   Speed ")),"Equipped staff summary presents healing instead of an unusable attack stat")
 app.preferences.values.character_models="revised";var before=canonical(app.game.save_data("camp"));var disk=FileAccess.get_file_as_string(app.save_path);var count=0
 var catalog=Rules.new()
 for unit in catalog.roster:
  if unit.weapon not in ["staff","lance"]:continue
  for path in [""]+catalog.promotion_options(unit).map(func(entry):return entry.id):
   var equipped=unit.duplicate(true);equipped.team="player";equipped.item="vigil_staff" if unit.weapon=="staff" else "rally_lance"
   if not path.is_empty():equipped.promotion=path
   var actor=app.make_fighter(equipped,Vector3.ZERO)
   assert(actor is Imported and actor.model.get_meta("character_identity")==unit.id,"New gear keeps the chosen revised recruit body")
   assert(actor.find_children("*","Node3D",true,false).any(func(node):return node.get_meta("equipment","")==equipped.item),"Fitted rig carries the actual new item")
   actor.queue_free();await process_frame;count+=1
 catalog.start_battle()
 for job in ["Knight","Rider","Warden"]:
  var enemy=catalog.living("enemy")[0].duplicate(true);enemy.team="enemy";enemy.boss=false;enemy.job=job;enemy.weapon="staff" if job=="Warden" else "lance";enemy.item="vigil_staff" if job=="Warden" else "rally_lance"
  var actor=app.make_fighter(enemy,Vector3.ZERO);assert(actor is Imported and actor.model.has_meta("enemy_appearance"))
  assert(actor.find_children("*","Node3D",true,false).any(func(node):return node.get_meta("equipment","")==enemy.item))
  actor.queue_free();await process_frame
 assert(count==27 and canonical(app.game.save_data("camp"))==before and FileAccess.get_file_as_string(app.save_path)==disk)
 await Shutdown.dispose(app);await process_frame
 print("PASS: late legacy purchase/equip/duplicate/rewind/ordinary unlock rules, quantified weapon tradeoffs, three-size actual shop and saved arsenal choices, healing summary, all27 revised base/promoted outfits and three enemy classes without fallback")
 quit()
