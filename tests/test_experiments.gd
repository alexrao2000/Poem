extends SceneTree
# Exercise irreversible action checkpoints and rescue through the simulation and
# actual command UI, including mid-enemy-phase continuation and malformed saves.
const Rules=preload("res://scripts/rules.gd")
const Door=preload("res://scripts/death_door.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")

func casualty(game,unit):
 unit.hp=0;Door.fall(game,unit);game.commit_casualties()

func verify_rules():
 var g=Rules.new();g.new_campaign(true);g.death_door=true;g.action_saves=true;g.start_battle()
 var victim=g.units[1];var rescuer=g.units[0];var healer=g.units.filter(func(u):return u.weapon=="staff")[0]
 victim.x=3;victim.y=3;rescuer.x=2;rescuer.y=3;healer.x=4;healer.y=3
 casualty(g,victim)
 assert(Door.downed(victim) and g.at(g.pos(victim))==victim and not g.can_act(victim) and not g.roster[1].fallen)
 assert(not g.can_attack(g.living("enemy")[0],victim),"Downed units cannot be finished by an attack")
 assert(Door.can_rescue(g,rescuer,victim) and Door.rescue(g,rescuer,victim))
 assert(g.at(Vector2i(3,3))==null and g.movement_allowance(rescuer)==rescuer.move-2)
 g.begin_enemy_phase();g.next_player_turn()
 assert(victim.bleed_turns==2,"Carrying pauses bleeding")
 assert(g.move_unit(rescuer,Vector2i(3,3)) and g.pos(victim)==g.pos(rescuer))
 assert(not g.undo_move(rescuer),"Committed movement cannot be undone")
 var copy=Rules.new();assert(copy.import_code(g.export_code("battle"))=="battle")
 assert(copy.death_door and copy.action_saves and copy.units[1].carried_by==rescuer.id)
 assert(g.can_heal(healer,victim) and g.heal(healer,victim))
 assert(victim.hp>0 and not Door.downed(victim) and victim.acted and not victim.has("carried_by"),"Healing revives a carried unit into a free adjacent tile, spent")
 assert(g.at(g.pos(victim))==victim)
 victim.hp=0;Door.fall(g,victim)
 g.begin_enemy_phase();assert(victim.bleed_turns==1)
 g.next_player_turn();g.begin_enemy_phase()
 assert(not Door.downed(victim) and g.roster[1].fallen and victim.id not in g.deployed,"Bleeding out commits permanent death immediately")
 g.units[0].hp=0;g.units[0].erase("downed")
 assert(g.retry_battle());g.start_battle()
 assert(not g.units.any(func(u):return u.id==victim.id),"Lord defeat cannot erase committed deaths")
 var path="/private/tmp/poem-action-save-test.json"
 assert(g.save_game(path,"battle"));g.turn=8;assert(g.save_game(path,"battle"))
 assert(FileAccess.get_file_as_string(path)==FileAccess.get_file_as_string(path+".bak"),"Recovery copy contains the same irreversible checkpoint")
 var bad=FileAccess.open(path,FileAccess.WRITE);bad.store_string("broken");bad.close()
 assert(copy.load_game(path)=="battle" and copy.turn==8,"Recovery cannot rewind a completed action")
 var data=copy.save_data("battle").duplicate(true)
 for key in ["action_saves","death_door"]:
  var invalid=data.duplicate(true);invalid[key]="yes";assert(not copy.valid_save(invalid))
 var invalid=data.duplicate(true);invalid.units[0].downed=true;invalid.units[0].bleed_turns=2
 assert(not copy.valid_save(invalid),"Positive HP cannot be marked downed")
 invalid=data.duplicate(true);invalid.units[0].carried_by="missing"
 assert(not copy.valid_save(invalid),"Broken carrier references are rejected")
 var rescue=Rules.new();rescue.death_door=true;rescue.start_battle()
 var patient=rescue.units[1];var carrier=rescue.units[0];patient.x=3;patient.y=3;carrier.x=2;carrier.y=3
 casualty(rescue,patient);assert(Door.rescue(rescue,carrier,patient));carrier.acted=false
 assert(not Door.drop(rescue,carrier,rescue.pos(carrier)),"Cannot drop on the occupied carrier tile")
 assert(Door.drop(rescue,carrier,Vector2i(3,3)) and patient.bleed_turns==2)
 carrier.acted=false;assert(Door.rescue(rescue,carrier,patient));casualty(rescue,carrier)
 assert(not patient.has("carried_by") and rescue.pos(patient)!=rescue.pos(carrier),"A downed carrier releases their passenger onto free terrain")
 var safe=Rules.new();safe.new_campaign(true);safe.death_door=true;safe.start_battle();casualty(safe,safe.units[1])
 for enemy in safe.living("enemy"):enemy.hp=0
 assert(safe.result()=="victory");safe.finish_chapter();safe.start_battle()
 assert(safe.units.any(func(u):return u.id=="oren" and u.hp>0),"Victory evacuates downed allies before memorials are committed")

func run():
 verify_rules()
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-experiment-ui.json"
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.action_saves=true;app.game.death_door=true;app.game.start_battle()
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 app.make_map();app.show_battle()
 var ally=app.game.units[0];app.selected=ally
 var destination=Vector2i(2,2);app.click_tile(destination)
 var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle" and loaded.pos(loaded.units[0])==destination,"Movement saves before its animation finishes")
 while app.busy:await process_frame
 app.cancel_selection();assert(app.game.pos(ally)==destination,"Escape cannot rewind committed movement")
 var patient=app.game.units[1];patient.x=3;patient.y=2;casualty(app.game,patient)
 app.refresh_pieces();app.selected=ally;app.update_side();await process_frame
 assert(app.unit_nodes.has(patient.id) and app.unit_nodes[patient.id].downed,"Downed units remain visible on the tactical map")
 app.show_triage()
 var rescue=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text=="Rescue "+patient.name)
 assert(rescue.size()==1);rescue[0].pressed.emit();await process_frame
 assert(patient.carried_by==ally.id and not app.unit_nodes.has(patient.id),"Rescue command removes carried ally from the map")
 assert(loaded.load_game(app.save_path)=="battle" and loaded.units[1].carried_by==ally.id,"Rescue autosaves its carrier relation")
 app.game.begin_enemy_phase()
 for foe in app.game.living("enemy"):foe.acted=true
 app.persist_campaign("battle");var before=app.game.rng.state
 await app.load_campaign()
 assert(app.game.phase=="player" and app.game.turn==2 and app.game.rng.state==before,"Reload completes an interrupted enemy phase without repeating already resolved attacks")
 await Shutdown.dispose(app);await process_frame
 print("PASS: downed countdown, rescue/carry/drop, revival, carrier loss, evacuation, irreversible deaths and movement, current recovery saves, validation and interrupted phase continuation")
 quit()
