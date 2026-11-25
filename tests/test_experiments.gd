extends SceneTree
# Exercise irreversible action checkpoints and rescue through the simulation and
# actual command UI, including mid-enemy-phase continuation and malformed saves.
const Rules=preload("res://scripts/rules.gd")
const Door=preload("res://scripts/death_door.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Draft=preload("res://scripts/campaign_draft.gd")
func _initialize():call_deferred("run")

func casualty(game,unit):
 unit.hp=0;Door.fall(game,unit);game.commit_casualties()

func verify_authored_sacrifice():
 var draft=Draft.new();draft.data=draft.new_document(false)
 draft.data.settings.sacrifice_cost=true
 for tuning in [{"attack":5,"hp_penalty":8,"tonics":0},{"attack":0,"hp_penalty":20,"tonics":1},{"attack":4,"hp_penalty":0,"tonics":2}]:
  draft.data.sacrifice_tuning=tuning
  var imported=Draft.new();assert(imported.decode(draft.encode()).is_empty())
  var compiled=imported.compile()
  var game=Rules.new(compiled.content)
  Draft.prepare_playtest(game,compiled.settings,0,17,0)
  game.start_battle()
  var ally=game.units.filter(func(unit):return unit.id=="lyra")[0]
  var victim=game.units.filter(func(unit):return unit.id=="oren")[0]
  var base_attack=game.attack_power(ally)
  victim.hp=0
  var effects=game.commit_casualties()[victim.id]
  var recovering=tuning.hp_penalty>0 or tuning.tonics<2
  assert(effects=={"opening":tuning.attack>0,"recovering":recovering})
  assert(game.attack_power(ally)==base_attack+tuning.attack)
  assert(ally.has("resolve_until")== (tuning.attack>0))
  var copy=Rules.new(compiled.content)
  assert(copy.import_code(game.export_code("battle"))=="battle")
  assert(copy.trials.sacrifice_tuning==tuning)
  assert(copy.trials.restart(copy));copy.start_battle()
  var returned=copy.units.filter(func(unit):return unit.id=="oren")[0]
  assert(returned.hp==maxi(1,int(returned.max_hp)-tuning.hp_penalty) and returned.potions==tuning.tonics)
  assert(returned.get("recovering",false)==recovering)
 var malformed=draft.data.duplicate(true)
 for invalid in [{"attack":5},{"attack":5,"hp_penalty":8,"tonics":3},{"attack":-1,"hp_penalty":8,"tonics":0}]:
  malformed.sacrifice_tuning=invalid
  assert("sacrifice values" in draft.structural_problem(malformed))
 print("PASS: authored opening and recovery values work together or independently, persist through a retry and reject invalid data")

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
 var path="/private/tmp/poem-action-save-test-%d.json"%OS.get_process_id()
 assert(g.save_game(path,"battle"));g.turn=8;assert(g.save_game(path,"battle"))
 assert(FileAccess.get_file_as_string(path)==FileAccess.get_file_as_string(path+".bak"),"Recovery copy contains the same irreversible checkpoint")
 var bad=FileAccess.open(path,FileAccess.WRITE);bad.store_string("broken");bad.close()
 assert(copy.load_game(path)=="battle" and copy.turn==8,"Recovery cannot rewind a completed action")
 var stale=copy.read_saved_data(path).duplicate(true);stale.turn=7;stale.save_sequence-=1
 var stale_file=FileAccess.open(path,FileAccess.WRITE);stale_file.store_string(JSON.stringify(stale));stale_file.close()
 assert(copy.load_game(path)=="battle" and copy.turn==8,"A newer recovery checkpoint wins if interrupted before replacing the primary")
 var pending=copy.read_saved_data(path).duplicate(true);pending.turn=9;pending.save_sequence+=1
 var pending_file=FileAccess.open(path+".tmp",FileAccess.WRITE);pending_file.store_string(JSON.stringify(pending));pending_file.close()
 assert(copy.load_game(path)=="battle" and copy.turn==9,"A fully written pending checkpoint survives interruption before rotation")
 DirAccess.remove_absolute(path+".tmp")
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
 var self_heal=Rules.new();self_heal.death_door=true;self_heal.start_battle()
 var staff=self_heal.units.filter(func(u):return u.weapon=="staff")[0];var passenger=self_heal.units[1]
 staff.x=2;staff.y=3;passenger.x=3;passenger.y=3;casualty(self_heal,passenger)
 assert(Door.rescue(self_heal,staff,passenger));self_heal.begin_enemy_phase();self_heal.next_player_turn()
 assert(self_heal.can_heal(staff,passenger) and self_heal.heal(staff,passenger) and passenger.hp>0,"A healer can treat their own carried ally on their next action")
 var safe=Rules.new();safe.new_campaign(true);safe.death_door=true;safe.start_battle();casualty(safe,safe.units[1])
 for enemy in safe.living("enemy"):enemy.hp=0
 assert(safe.result()=="victory");safe.finish_chapter();safe.start_battle()
 assert(safe.units.any(func(u):return u.id=="oren" and u.hp>0),"Victory evacuates downed allies before memorials are committed")

func verify_downed_objectives():
 for chapter in [1,4,7,10]:
  for permanent in [false,true]:
   var g=Rules.new();g.new_campaign(permanent);g.death_door=true;g.chapter=chapter;g.start_battle()
   var objective=g.objective_position();var blocker=g.at(objective)
   if blocker!=null:blocker.hp=0
   var medic=g.units.filter(func(unit):return unit.team=="player" and unit.weapon=="staff")[0]
   var patient=g.units[1];patient.x=objective.x;patient.y=objective.y;casualty(g,patient)
   var adjacent=Door.drop_positions(g,patient)[0];medic.x=adjacent.x;medic.y=adjacent.y
   assert(Door.rescue(g,medic,patient));g.begin_enemy_phase();g.next_player_turn()
   assert(Door.drop(g,medic,objective))
   assert(g.result()=="","A downed passenger cannot seize an objective after being dropped")
   var copy=Rules.new();assert(copy.import_code(g.export_code("battle"))=="battle" and copy.result()=="","Reloading a downed objective occupant cannot award victory")
   g.begin_enemy_phase();g.next_player_turn();assert(g.heal(medic,patient))
   assert(g.result()=="victory" and patient.acted,"A living recovered ally can secure the objective even with their action spent")

func verify_phase_aid_choices():
 var game=Rules.new();game.death_door=true;game.start_battle()
 var leader=game.units[0];var patient=game.units[1];var ally=game.units[2];var medic=game.units[3]
 var enemy=game.living("enemy")[0]
 leader.x=5;leader.y=3;leader.acted=true
 patient.x=5;patient.y=3;casualty(game,patient);patient.bleed_turns=1
 ally.x=4;ally.y=3;ally.acted=true
 medic.x=6;medic.y=4
 enemy.x=5;enemy.y=4
 var tactics=Tactics.new()
 var before=game.export_code("battle")
 var choices=tactics.phase_aid_choices(game,[patient])[patient.id]
 assert(choices.size()==1 and choices[0].action=="rescue" and choices[0].tile==Vector2i(6,3),"Moving into the only vacant adjacent square leaves no space to revive a shared patient")
 assert(game.export_code("battle")==before)
 enemy.x=12;enemy.y=4
 before=game.export_code("battle")
 choices=tactics.phase_aid_choices(game,[patient])[patient.id]
 assert(choices.size()==2 and choices[0].action=="revive" and choices[0].tile==Vector2i(6,3) and choices[0].cost==1)
 assert(game.export_code("battle")==before and game.move_unit(medic,choices[0].tile))
 assert(game.heal(medic,patient) and game.pos(patient)==Vector2i(5,4),"The planned staff action works from the suggested tile")
 print("PASS: phase aid respects movement, spent allies and the real revival square after a proposed move")

func verify_bleed_warning(app):
 app.game.new_campaign(true);app.game.death_door=true;app.game.start_battle()
 var carrier=app.game.units[0];var first=app.game.units[1];var second=app.game.units[2];var medic=app.game.units.filter(func(unit):return unit.weapon=="staff")[0]
 carrier.x=2;carrier.y=3;first.x=3;first.y=3;second.x=3;second.y=4;medic.x=2;medic.y=4
 casualty(app.game,first);casualty(app.game,second);first.bleed_turns=1
 app.make_map();app.show_battle();app.selected=medic;app.update_side()
 var warning=app.side.get_node("EndPlayerPhase")
 assert(warning.text=="End phase · 1 will fall" and first.name in warning.tooltip_text and not second.name in warning.tooltip_text,"Only patients at their last phase ending appear in the warning")
 second.bleed_turns=1;app.update_side();warning=app.side.get_node("EndPlayerPhase")
 assert(warning.text=="End phase · 2 will fall" and first.name in warning.tooltip_text and second.name in warning.tooltip_text)
 app.game.trials.flags.death_legacies=true
 var before=app.game.save_data("battle").duplicate(true)
 var review=app.side.get_node("ReviewPhaseLosses")
 review.pressed.emit();await process_frame
 assert(app.screen=="phase_losses" and app.selected==medic)
 for patient in [first,second]:
  var fate=app.ui.find_child("PhaseLoss_"+patient.id,true,false)
  assert(fate.text=="Permanent loss, recorded this phase. Legacy supply credit +1.")
 assert(app.ui.find_child("PhaseLossOpening",true,false)==null)
 close_loss_review(app)
 assert(app.game.save_data("battle")==before and app.selected==medic)
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;app.arrange_battle_side()
  await process_frame;await process_frame
  for control in app.side.get_children():assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"Urgent phase controls fit the tactical panel")
 assert(app.game.save_data("battle")==before,"Warning display never advances the countdown")
 assert(Door.rescue(app.game,carrier,first));app.refresh_pieces();app.update_side();warning=app.side.get_node("EndPlayerPhase")
 assert(warning.text=="End phase · 1 will fall" and second.name in warning.tooltip_text and not first.name in warning.tooltip_text,"Carried patients no longer face bleed-out")
 assert(app.game.heal(medic,second));app.refresh_pieces();app.update_side()
 assert(app.side.get_node("EndPlayerPhase").text=="End player phase","Healing the last urgent patient clears the warning")
 assert(not app.side.has_node("ReviewPhaseLosses"))

func close_loss_review(app):
 var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;root.push_input(event,true)
 assert(app.screen=="battle" and app.side.get_node("ReviewPhaseLosses").has_focus())

func verify_authored_sacrifice_feedback(app):
 var draft=Draft.new();draft.data=draft.new_document(false)
 draft.data.settings.death_door=true
 draft.data.settings.sacrifice_cost=true
 draft.data.sacrifice_tuning={"attack":5,"hp_penalty":8,"tonics":0}
 var compiled=draft.compile()
 var game=Rules.new(compiled.content)
 Draft.prepare_playtest(game,compiled.settings,0,17,0)
 game.start_battle();app.game=game
 var oren=game.units.filter(func(unit):return unit.id=="oren")[0]
 var lyra=game.units.filter(func(unit):return unit.id=="lyra")[0]
 casualty(game,oren);oren.bleed_turns=1
 var base_attack=game.attack_power(lyra)
 app.make_map();app.show_battle()
 app.show_options("battle")
 var descriptions=app.ui.find_children("*","Label",true,false)
 assert(descriptions.any(func(label):return "8 HP down, with no tonics" in label.text and "+5 attack" in label.text))
 app.close_options()
 app.side.get_node("ReviewPhaseLosses").pressed.emit()
 assert(app.ui.find_child("PhaseLossOpening",true,false).text=="Surviving allies gain +5 attack through player turn 2.")
 assert("24/32 HP with no field tonics" in app.ui.find_child("PhaseLoss_oren",true,false).text)
 close_loss_review(app)
 app.side.get_node("EndPlayerPhase").pressed.emit()
 var card=app.ui.get_node_or_null("CasualtyCard")
 var deadline=Time.get_ticks_msec()+6000
 while card==null and app.busy and Time.get_ticks_msec()<deadline:
  await process_frame
  card=app.ui.get_node_or_null("CasualtyCard")
 assert(card!=null and "Allies gain +5 attack" in card.consequences.text)
 assert(game.attack_power(lyra)==base_attack+5 and oren.hp==0 and not Door.downed(oren))
 card.dismissed=true
 while app.busy:await process_frame
 app.debug_session.begin(game,"battle",false)
 var report=app.debug_session.report(game)
 assert(report.sacrifice_tuning==draft.data.sacrifice_tuning)
 assert(report.combatants.filter(func(unit):return unit.id=="lyra")[0].attack==base_attack+5)
 app.debug_session.end(game)
 print("PASS: the authored phase review predicts Oren at 24/32 HP with no tonic, and the casualty card and Debug report show the actual +5 attack")

func verify_authored_rescue_window(app):
 var draft=Draft.new();draft.data=draft.new_document(false)
 draft.data.settings.death_door=true
 draft.data.settings.permadeath=true
 draft.data.settings.action_saves=true
 for invalid in [0,5,1.5,"four"]:
  draft.data.rescue_window=invalid
  assert("rescue window" in draft.structural_problem(draft.data))
 for phases in [1,4]:
  draft.data.rescue_window=phases
  var incoming=Draft.new();assert(incoming.decode(draft.encode()).is_empty())
  var compiled=incoming.compile()
  var game=Rules.new(compiled.content)
  Draft.prepare_playtest(game,compiled.settings,0,17,0)
  game.start_battle()
  var oren=game.units.filter(func(unit):return unit.id=="oren")[0]
  casualty(game,oren)
  assert(Door.downed(oren) and oren.bleed_turns==phases)
  var copy=Rules.new(compiled.content)
  assert(copy.import_code(game.export_code("battle"))=="battle")
  var saved=copy.save_data("battle").duplicate(true)
  assert(copy.valid_save(saved))
  var invalid_patient=saved.units.filter(func(unit):return unit.id=="oren")[0]
  invalid_patient.bleed_turns=phases+1
  assert(not copy.valid_save(saved))
  if phases==1:
   game.begin_enemy_phase()
   assert(not Door.downed(oren) and game.lost_ids()==["oren"])
   continue
  var carrier=copy.units.filter(func(unit):return unit.id=="lyra")[0]
  var patient=copy.units.filter(func(unit):return unit.id=="oren")[0]
  carrier.x=2;carrier.y=3;patient.x=3;patient.y=3
  assert(Door.rescue(copy,carrier,patient))
  copy.begin_enemy_phase();copy.next_player_turn()
  assert(patient.bleed_turns==4 and Door.drop(copy,carrier,Vector2i(3,3)))
  copy.begin_enemy_phase()
  assert(patient.bleed_turns==3)
  app.game=game;app.make_map();app.show_battle()
  assert(app.unit_nodes.oren.rescue_marker.texture.resource_path.ends_with("rescue-four.png"))
  assert(app.side.get_node("EndPlayerPhase").text=="End player phase")
  assert(app.persist_campaign("battle"))
  var ordinary=FileAccess.get_file_as_string(app.save_path)
  app.show_options("battle")
  assert(app.ui.find_children("*","Label",true,false).any(func(label):return "4 player phases for rescue or staff healing" in label.text))
  app.ui.find_child("DebugMode",true,false).button_pressed=true
  app.show_debug_tools("battle")
  var countdown=app.ui.find_child("DebugBleedTurns",true,false)
  assert(countdown.max_value==4);countdown.value=3
  var set_countdown=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Set rescue countdown")[0]
  set_countdown.pressed.emit()
  assert(app.screen=="battle" and oren.bleed_turns==3)
  assert(app.unit_nodes.oren.rescue_marker.texture.resource_path.ends_with("rescue-three.png"))
  assert(copy.load_game(app.save_path+".debug")=="battle" and app.debug_session.report(game).rescue_window==4)
  app.show_options("battle")
  app.ui.find_child("DebugMode",true,false).button_pressed=false
  assert(game.units.filter(func(unit):return unit.id=="oren")[0].bleed_turns==4)
  assert(FileAccess.get_file_as_string(app.save_path)==ordinary)
 print("PASS: one- and four-phase rescue windows drive actual loss timing, badges, portable saves and an isolated Debug countdown")

func observe_rescue_feedback(app,patient,skip=false):
 assert(app.busy and app.screen=="battle","Rescue feedback locks commands on the tactical field")
 var checkpoint=app.game.save_data("battle").duplicate(true);var visual=app.unit_nodes[patient.id]
 var start=visual.position;var saw_motion=false;var saw_fade=false;var saw_cue=false
 while app.busy:
  if is_instance_valid(visual):
   saw_motion=saw_motion or visual.position.distance_to(start)>.01
   if visual.rescue_opacity>.05 and visual.rescue_opacity<.95:
    saw_fade=true
    assert(is_equal_approx(visual.sprite.modulate.a,visual.rescue_opacity) and is_equal_approx(visual.health.modulate.a,visual.rescue_opacity))
    if visual.rescue_marker!=null:assert(is_equal_approx(visual.rescue_marker.modulate.a,visual.rescue_opacity),"The countdown badge travels and fades with its patient")
   assert(visual.marker.material_override!=app.unit_nodes[app.selected.id].marker.material_override,"Rescue opacity owns its shadow material")
  var cue=app.ui.get_node_or_null("RescueCue")
  saw_cue=saw_cue or cue!=null
  if cue!=null and cue.size.x>0:
   assert(Rect2(Vector2.ZERO,app.ui.size).encloses(cue.get_global_rect()),"Rescue feedback stays within the viewport")
   assert(not cue.get_global_rect().intersects(app.side.get_parent().get_global_rect()),"Rescue feedback stays clear of the tactical sidebar")
  if skip and saw_motion and saw_fade:
   var tab=InputEventKey.new();tab.pressed=true;tab.keycode=KEY_TAB;app._unhandled_input(tab)
  await process_frame
 assert(saw_motion and saw_fade and saw_cue,"A rescue action presents travel, translucent coverage and its short cue")
 assert(app.game.save_data("battle")==checkpoint,"Rescue animation and skipping preserve the resolved checkpoint and RNG")
 await process_frame
 assert(app.ui.get_node_or_null("RescueCue")==null,"The rescue cue is removed on completion or skip")

func verify_rescue_selection(app):
 app.game.new_campaign(true);app.game.death_door=true;app.game.start_battle();app.preferences.values.auto_end=false
 var rescuer=app.game.units[0];var patient=app.game.units[1]
 rescuer.x=2;rescuer.y=3;patient.x=4;patient.y=3;casualty(app.game,patient)
 app.make_map();app.show_battle();app.selected=rescuer;app.click_tile(Vector2i(3,3))
 while app.busy:await process_frame
 var rescue_targets=app.markers.get_node("RescueTargets");var covered={}
 for vertex in rescue_targets.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:covered[Vector2i(roundi(vertex.x),roundi(vertex.z))]=true
 assert(covered.size()==1 and covered.has(app.game.pos(patient)) and "Gold: rescue" in app.battle_hint.text,"Gold rescue coverage and the hint identify the actual adjacent patient")
 var snapshot=app.game.save_data("battle").duplicate(true)
 app.click_tile(app.game.pos(patient));await process_frame
 assert(app.screen=="triage" and app.selected==rescuer and app.origin==Vector2i(2,3),"Clicking an adjacent patient keeps the rescuer and uncommitted move")
 assert(app.game.save_data("battle")==snapshot,"Opening rescue choices consumes no action, movement or random roll")
 var choices=app.ui.find_children("*","Button",true,false)
 assert(choices.filter(func(button):return button.text.begins_with("Rescue ")).size()==1)
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return patient.name in label.text and "2 player-phase ending(s)" in label.text),"Focused rescue shows the patient's deadline")
 choices.filter(func(button):return button.text=="Return to battle")[0].pressed.emit()
 assert(app.screen=="battle" and app.selected==rescuer and app.origin==Vector2i(2,3) and app.game.save_data("battle")==snapshot)
 app.click_tile(app.game.pos(patient))
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Rescue "+patient.name)[0].pressed.emit()
 await observe_rescue_feedback(app,patient,true)
 var badge=app.unit_nodes[rescuer.id].carry_marker
 assert(badge!=null and badge.get_meta("passenger")==patient.name and badge.texture.get_size()==Vector2(64,36),"A carrier has a persistent passenger badge after the rescue transition")
 var point=app.camera.unproject_position(badge.global_position)
 assert(app.pick_map_unit(point)==rescuer and app.unit_nodes[rescuer.id].screen_bounds(app.camera).has_point(point),"The carrier badge is part of the unit’s clickable bounds")
 assert(app.markers.get_node_or_null("RescueTargets")==null,"Rescue targets clear once the action is spent")
 assert(patient.carried_by==rescuer.id and rescuer.acted and app.game.pos(rescuer)==Vector2i(3,3),"Confirming rescue uses the moved position and spends the action")

func verify_drop_controls(app):
 app.game.new_campaign(true);app.game.death_door=true;app.game.start_battle();app.preferences.values.auto_end=false
 var carrier=app.game.units.filter(func(unit):return unit.weapon=="staff")[0];var patient=app.game.units[1]
 carrier.x=2;carrier.y=3;patient.x=3;patient.y=3;casualty(app.game,patient)
 assert(Door.rescue(app.game,carrier,patient));app.game.begin_enemy_phase();app.game.next_player_turn()
 app.make_map();app.show_battle();app.selected=carrier;app.click_tile(Vector2i(3,3))
 while app.busy:await process_frame
 assert(app.game.pos(carrier)==Vector2i(3,3) and app.origin==Vector2i(2,3))
 var snapshot=app.game.save_data("battle").duplicate(true)
 app.show_triage()
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Choose drop tile")[0].pressed.emit()
 assert(app.screen=="battle" and app.drop_mode and app.markers.get_node_or_null("MovementRange")==null and app.markers.get_node_or_null("HealingReach")==null)
 var drops=app.markers.get_node("DropTargets");var tiles={}
 for vertex in drops.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:tiles[Vector2i(roundi(vertex.x),roundi(vertex.z))]=true
 var legal=Door.drop_positions(app.game,carrier)
 assert(tiles.size()==legal.size() and legal.all(func(tile):return tiles.has(tile)),"Gold target geometry covers exactly the free legal drop tiles")
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;app.arrange_battle_side()
  await process_frame;await process_frame
  for control in app.side.get_children():assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"Drop guidance and cancellation fit the tactical panel")
  assert(app.battle_hint.get_line_count()==1,"Drop guidance fits the narrow command strip")
 app.preview_route(legal[0]);assert(app.route_preview==null,"Drop selection does not imply carrier movement")
 app.click_tile(app.game.pos(carrier));app.wait_action()
 assert(app.drop_mode and app.game.save_data("battle")==snapshot,"Invalid drop targets and the wait shortcut cannot spend the action")
 var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;app._unhandled_input(escape)
 assert(not app.drop_mode and app.selected==carrier and app.origin==Vector2i(2,3) and app.game.save_data("battle")==snapshot,"Cancelling drop preserves the carrier's uncommitted movement")
 app.begin_drop();var right=InputEventMouseButton.new();right.pressed=true;right.button_index=MOUSE_BUTTON_RIGHT;app._unhandled_input(right)
 assert(not app.drop_mode and app.game.save_data("battle")==snapshot,"Right-click also cancels only the drop choice")
 app.game.action_saves=true;app.begin_drop();var destination=app.cursor_tile;var rng=app.game.rng.state
 var enter=InputEventKey.new();enter.pressed=true;enter.keycode=KEY_ENTER;app._unhandled_input(enter);await process_frame
 var immediate=Rules.new();assert(immediate.load_game(app.save_path)=="battle" and immediate.units.filter(func(unit):return unit.id==patient.id)[0].get("carried_by","").is_empty(),"Drop is saved before the transition finishes")
 await observe_rescue_feedback(app,patient)
 assert(not app.drop_mode and carrier.acted and patient.get("carried_by","").is_empty() and app.game.pos(patient)==destination and app.game.rng.state==rng)
 var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle")
 var saved_patient=loaded.units.filter(func(unit):return unit.id==patient.id)[0]
 assert(saved_patient.get("carried_by","").is_empty() and loaded.pos(saved_patient)==destination,"Keyboard drop commits the exact passenger destination")
 assert(app.unit_nodes[carrier.id].carry_marker==null,"Dropping removes the carrier badge")
 assert(app.unit_nodes.has(patient.id) and app.markers.get_node_or_null("DropTargets")==null,"A dropped ally returns to the map and clears target highlights")
 carrier.acted=false;assert(Door.rescue(app.game,carrier,patient));carrier.acted=false
 var blockers=app.game.units.filter(func(unit):return unit.id not in [carrier.id,patient.id])
 var directions=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
 for index in range(4):
  var tile=app.game.pos(carrier)+directions[index];blockers[index].x=tile.x;blockers[index].y=tile.y
 app.selected=carrier;app.show_triage()
 var choice=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Choose drop tile")[0]
 assert(choice.disabled and app.ui.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("No adjacent tile is free")))
 app.begin_drop();assert(app.screen=="triage" and not app.drop_mode and not carrier.acted,"A surrounded carrier cannot enter an empty drop selection")

func run():
 verify_rules()
 verify_authored_sacrifice()
 verify_downed_objectives()
 verify_phase_aid_choices()
 root.size=Vector2i(1440,900)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-experiment-ui-%d.json"%OS.get_process_id()
 root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.action_saves=true;app.game.death_door=true;app.game.start_battle()
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 app.make_map();app.show_battle()
 var ally=app.game.units[0];app.selected=ally
 var destination=Vector2i(2,2);app.click_tile(destination)
 var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle" and loaded.pos(loaded.units[0])==destination,"Movement saves before its animation finishes")
 while app.busy:await process_frame
 var figures=app.unit_nodes.duplicate()
 var committed=FileAccess.get_file_as_string(app.save_path)
 app.cancel_selection();assert(app.game.pos(ally)==destination and app.unit_nodes==figures,"Deselecting a committed move preserves its endpoint and figures")
 app.click_tile(destination)
 var blue=app.markers.get_node("MovementRange").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assert(blue.size()==30 and not app.selection_can_move(),"Reselecting a moved ally shows range from its saved endpoint")
 var next=Vector2i(3,2)
 assert(app.game.at(next)==null and app.game.reachable(ally).has(next),"The test tile would be within ordinary movement range")
 app.preview_route(next);app.click_tile(next)
 assert(app.route_preview==null and app.origin==null and app.game.pos(ally)==destination and FileAccess.get_file_as_string(app.save_path)==committed,"A committed move has no additional route, movement or write")
 var patient=app.game.units[1];patient.x=3;patient.y=2;casualty(app.game,patient)
 app.refresh_pieces();app.selected=ally;app.update_side();await process_frame
 assert(app.unit_nodes.has(patient.id) and app.unit_nodes[patient.id].downed,"Downed units remain visible on the tactical map")
 var downed_actor=app.unit_nodes[patient.id];var badge=downed_actor.rescue_marker
 assert(downed_actor.player.state=="hurt" and downed_actor.player.complete and downed_actor.sprite.modulate.a==1,"The actual casualty holds its visible wounded pose instead of breathing in idle")
 assert(badge.get_meta("turns")==2 and badge.texture.get_size()==Vector2(64,36),"The tactical rescue badge shows the actual remaining phase endings")
 var point=app.camera.unproject_position(badge.global_position)
 assert(downed_actor.screen_bounds(app.camera).has_point(point) and app.pick_map_unit(point)==patient,"Clicking the rescue badge inspects its downed ally")
 app.selected=patient;app.update_side()
 assert("2 phases left" in app.side.find_child("UnitConditions",true,false).text,"Inspection describes the same phase-ending deadline as the badge")
 assert("Rescue & triage" in app.battle_hint.text and not "Blue: move" in app.battle_hint.text,"Downed inspection explains how to help instead of offering impossible movement")
 var field_medic=app.game.units.filter(func(unit):return unit.weapon=="staff")[0]
 field_medic.x=3;field_medic.y=3;app.selected=field_medic;app.refresh_pieces();app.highlight();app.update_side()
 var healing_targets=app.markers.get_node_or_null("HealingTargets")
 assert(healing_targets!=null,"Downed allies receive the same green target highlight as injured allies")
 var vertices=healing_targets.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assert(Array(vertices).any(func(vertex):return Vector2(vertex.x,vertex.z).distance_to(Vector2(app.game.pos(patient)))<.61),"The healing target mesh covers the actual downed tile")
 for foe in app.game.living("enemy"):foe.ai="guard"
 app.end_turn()
 assert(app.unit_nodes[patient.id].rescue_marker.get_meta("turns")==1,"The rescue badge updates before the enemy-phase announcement")
 while app.busy:await process_frame
 assert(app.unit_nodes[patient.id].rescue_marker.texture.resource_path.ends_with("rescue-one.svg"),"The last opportunity uses the urgent one-turn badge")
 assert(app.unit_nodes[patient.id].player.state=="hurt" and app.unit_nodes[patient.id].player.complete,"Refreshing the rescue countdown retains the wounded pose")
 app.selected=ally;app.update_side()
 app.show_triage()
 var rescue=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text=="Rescue "+patient.name)
 assert(rescue.size()==1);rescue[0].pressed.emit();await process_frame
 assert(loaded.load_game(app.save_path)=="battle" and loaded.units[1].carried_by==ally.id,"Rescue is saved before the transition finishes")
 await observe_rescue_feedback(app,patient)
 assert(patient.carried_by==ally.id and not app.unit_nodes.has(patient.id),"Rescue command removes carried ally from the map")
 assert(loaded.load_game(app.save_path)=="battle" and loaded.units[1].carried_by==ally.id,"Rescue autosaves its carrier relation")
 app.game.begin_enemy_phase()
 for foe in app.game.living("enemy"):foe.acted=true
 app.persist_campaign("battle");var before=app.game.rng.state;var next_turn=app.game.turn+1
 await app.load_campaign()
 assert(app.game.phase=="player" and app.game.turn==next_turn and app.game.rng.state==before,"Reload completes an interrupted enemy phase without repeating already resolved attacks")
 app.game.new_campaign(true);app.game.death_door=true;app.game.action_saves=true;app.game.start_battle()
 var medic=app.game.units.filter(func(unit):return unit.weapon=="staff")[0];patient=app.game.units[1]
 medic.x=2;medic.y=3;patient.x=3;patient.y=3;casualty(app.game,patient);assert(Door.rescue(app.game,medic,patient))
 app.game.begin_enemy_phase();app.game.next_player_turn();app.make_map();app.show_battle();app.selected=medic
 medic.resolve_until=app.game.turn+1;medic.recovering=true;app.update_side()
 var conditions=app.side.find_child("UnitConditions",true,false)
 assert("Carrying "+patient.name in conditions.text and "ATK +2" in conditions.text and "Recovering" in conditions.text)
 assert("movement %d"%app.game.movement_allowance(medic) in conditions.tooltip_text)
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;app.arrange_battle_side()
  await process_frame;await process_frame
  assert(conditions.get_line_count()==1,"Combined conditions remain one compact status line")
  for control in app.side.get_children():assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(control.get_global_rect()),"Rescue and condition controls fit the tactical panel")
 app.show_triage()
 var healing_button=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Heal carried "+patient.name)
 assert(healing_button.size()==1);healing_button[0].pressed.emit()
 assert(app.busy and app.screen=="battle" and patient.hp>0,"Carried-ally treatment routes into real healing feedback after resolving health")
 while app.busy:await process_frame
 assert(medic.acted and patient.acted and app.unit_nodes.has(patient.id) and not app.unit_nodes[patient.id].downed and app.unit_nodes[patient.id].rescue_marker==null,"Healing returns both units to the tactical map with spent actions")
 assert(app.unit_nodes[patient.id].player.state=="idle" and not app.unit_nodes[patient.id].player.complete,"A healed ally resumes the ordinary idle animation")
 root.size=Vector2i(1024,640);await process_frame
 await verify_rescue_selection(app)
 root.size=Vector2i(1440,900);await process_frame
 await verify_drop_controls(app)
 await verify_bleed_warning(app)
 app.game.new_campaign(true);app.game.death_door=true;app.game.action_saves=true;app.game.start_battle()
 var leader=app.game.units[0];casualty(app.game,leader);leader.bleed_turns=1
 var companion=app.game.units.filter(func(unit):return unit.id=="sera")[0]
 casualty(app.game,companion);companion.bleed_turns=1
 app.make_map();app.show_battle();var state=app.game.rng.state
 var health=app.game.living("player").map(func(unit):return unit.hp)
 await app.end_turn()
 assert(app.screen=="result" and app.game.result()=="defeat" and app.game.rng.state==state,"Lord bleed-out ends the attempt before any enemy action or roll")
 assert(app.game.living("player").map(func(unit):return unit.hp)==health and not app.busy)
 assert(loaded.load_game(app.save_path)=="battle" and loaded.result()=="defeat","The phase-boundary defeat is checkpointed")
 var lost=app.ui.find_child("DefeatCommittedLosses",true,false)
 assert(lost.text=="Permanent losses on this attempt · Sera" and loaded.lost_ids()==["sera"],"The result names the companion who stays lost after retry")
 assert(app.ui.find_child("DefeatRecovery",true,false)==null)
 app.game.new_campaign();app.game.death_door=true;app.game.action_saves=true
 app.game.trials.flags.sacrifice_cost=true;app.game.trials.flags.reset_pressure=true
 app.game.start_battle()
 for unit in app.game.units:
  if unit.id in ["lyra","oren"]:casualty(app.game,unit);unit.bleed_turns=1
 app.make_map();app.show_battle();await app.end_turn()
 assert(app.screen=="result" and app.ui.find_child("DefeatCommittedLosses",true,false)==null)
 var recovery=app.ui.find_child("DefeatRecovery",true,false)
 assert(recovery.text=="Next deployment recovery · Lyra (23 HP, 1 tonic), Oren (28 HP, 1 tonic)")
 assert(loaded.load_game(app.save_path)=="battle" and loaded.lost_ids().is_empty() and loaded.trials.injuries.size()==2)
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(recovery.get_global_rect()))
 await verify_victory_recovery(app)
 await verify_authored_sacrifice_feedback(app)
 verify_authored_rescue_window(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: downed countdown, rescue/carry/drop, revival, carrier loss, evacuation, irreversible deaths and movement, current recovery saves, validation and interrupted phase continuation")
 quit()

func verify_victory_recovery(app):
 var game=app.game
 for kind in ["recoverable","ordinary","permanent","finale"]:
  game.new_campaign(kind=="permanent");game.death_door=true;game.action_saves=true
  game.chapter=game.content.chapters.size()-1 if kind=="finale" else 2
  game.trials.flags.sacrifice_cost=kind!="ordinary"
  if kind in ["recoverable","finale"]:
   game.trials.injuries={"lyra":game.chapter,"sera":game.chapter+1,"ivo":game.chapter+1}
  game.start_battle();game.rng.seed=17
  var lyra=game.units.filter(func(unit):return unit.id=="lyra")[0]
  var oren=game.units.filter(func(unit):return unit.id=="oren")[0]
  var sera=game.units.filter(func(unit):return unit.id=="sera")[0]
  var ivo=game.units.filter(func(unit):return unit.id=="ivo")[0]
  casualty(game,oren);casualty(game,ivo);oren.bleed_turns=1
  game.begin_enemy_phase();game.next_player_turn()
  assert(oren.hp==0 and not Door.downed(oren) and Door.downed(ivo))
  var boss=game.living("enemy").filter(func(unit):return unit.boss)[0]
  lyra.x=3 if kind=="finale" else 4;lyra.y=3;lyra.speed=120
  boss.x=lyra.x+1;boss.y=lyra.y;boss.speed=0;boss.hp=1
  game.units=game.units.filter(func(unit):return unit.team=="player" or unit==boss)
  assert(game.result()=="" and game.can_attack(lyra,boss))
  app.make_map();app.show_battle();app.preferences.values.combat="map"
  app.click_tile(game.pos(lyra),lyra.id);app.click_tile(game.pos(boss),boss.id);await app.player_attack()
  assert(app.screen=="result" and game.result()=="victory")
  var state=JSON.parse_string(JSON.stringify(game.save_data("battle")))
  var copy=Rules.new();assert(copy.load_game(app.save_path)=="battle")
  assert(JSON.parse_string(JSON.stringify(copy.save_data("battle")))==state)
  var rows={}
  for unit in [lyra,oren,sera,ivo]:
   var choices=app.ui.find_children("*","Label",true,false).filter(func(label):return label.text.begins_with(unit.name+" · Lv "))
   assert(choices.size()==1);rows[unit.id]=choices[0]
  assert("Ready for the next march" in rows.lyra.text and "Rescued after battle" in rows.ivo.text)
  if kind=="recoverable":
   for unit in [oren,sera,ivo]:
    assert(("Next deployment · %d HP, 1 tonic"%(unit.max_hp-4)) in rows[unit.id].text)
  else:
   assert(rows.values().all(func(label):return not "Next deployment" in label.text))
   assert(("Fallen — permanently lost" if kind=="permanent" else "Recovering at camp") in rows.oren.text)
  for dimensions in [Vector2i(720,960),Vector2i(1024,640),Vector2i(1440,900)]:
   root.size=dimensions;app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
   await process_frame;await process_frame
   for row in rows.values():
    assert(row.get_parent().get_global_rect().grow(1).encloses(row.get_global_rect()))
    assert(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(row.get_global_rect()))
    assert(row.get_line_count()==row.get_visible_line_count(),"All result lines fit at each viewport size")
  assert(JSON.parse_string(JSON.stringify(game.save_data("battle")))==state,"Reading recovery preserves the settled battle and RNG")
  copy.finish_chapter()
  if kind=="finale":assert(copy.completed);continue
  copy.start_battle()
  if kind=="recoverable":
   for unit in copy.living("player"):
    var recovering=unit.id in ["oren","sera","ivo"]
    assert(unit.hp==unit.max_hp-(4 if recovering else 0) and unit.potions==(1 if recovering else 2))
 print("PASS: victory recovery reports the exact next deployment for withdrawn, standing and evacuated allies across three viewports, with expired, ordinary, permanent and final-battle exclusions")
