extends SceneTree
## Actual enemy and counterattack falls must present a rescuable patient at
## contact, without a death fade or an early pose change before the lethal hit.
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-downed-contact-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 for scenario in ["enemy","counter","carrier"]:
  var counter=scenario=="counter"
  app.game.new_campaign(true);app.game.death_door=true;app.game.action_saves=true;app.game.start_battle()
  var lord=app.game.units.filter(func(u):return u.id=="lyra")[0];var patient=app.game.units.filter(func(u):return u.id=="oren")[0];var healer=app.game.units.filter(func(u):return u.id=="ivo")[0];var enemy=app.game.living("enemy")[0]
  lord.x=9;lord.y=5;patient.x=9;patient.y=4;patient.hp=1;patient.speed=0;healer.x=10;healer.y=5
  enemy.x=8;enemy.y=4;enemy.ai="guard";enemy.job="Vanguard";enemy.weapon="sword";enemy.item="iron_sword";enemy.pow=100;enemy.speed=50;enemy.defense=100;enemy.hp=enemy.max_hp;enemy.held_tonics=0
  var passenger=app.game.units.filter(func(u):return u.id=="sera")[0]
  app.game.units=[lord,patient,healer,enemy];app.game.rng.seed=309 if counter else 17
  if scenario=="carrier":
   passenger.team="player";passenger.acted=false;passenger.moved=false;passenger.x=9;passenger.y=3;passenger.hp=0
   app.game.units.append(passenger);app.game.DeathDoor.fall(app.game,passenger)
   assert(app.game.DeathDoor.rescue(app.game,patient,passenger))
  app.make_map();app.show_battle();await process_frame
  var visual=app.unit_nodes[patient.id];var observed=0;var saw_standing=false;var checked_save=false
  if counter:
   app.selected=patient;app.click_tile(app.game.pos(enemy));assert(app.target==enemy);app.player_attack()
  else:app.end_turn()
  assert(app.busy)
  var deadline=Time.get_ticks_msec()+15000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   visual=app.unit_nodes.get(patient.id)
   if is_instance_valid(visual) and not visual.is_queued_for_deletion():
    if visual.hp_ratio==0:
     observed+=1
     assert(not visual.departing and visual.visible and visual.sprite.modulate.a==1,"Rescuable allies must not disappear through the ordinary defeated-unit fade")
     assert(not is_instance_valid(visual.carry_marker),"A fallen carrier has released the passenger and must lose the carrying badge")
     assert(visual.downed and visual.spent and visual.player.state=="hurt" and visual.player.complete,"The held wounded pose begins at lethal contact")
     assert(is_instance_valid(visual.rescue_marker) and visual.rescue_marker.visible and visual.rescue_marker.get_meta("turns")==patient.bleed_turns)
     if not checked_save:
      var saved=Rules.new();assert(saved.load_game(app.save_path)=="battle")
      assert(canonical(saved.save_data("battle"))==canonical(app.game.save_data("battle")),"Downed state was already committed before its presentation")
      checked_save=true
    else:
     assert(not visual.downed and not is_instance_valid(visual.rescue_marker),"The final resolved casualty does not leak into earlier strike presentation")
     saw_standing=true
   var card=app.ui.get_node_or_null("CasualtyCard")
   if card!=null:assert(card.heading.text.ends_with("NEEDS RESCUE"));card.dismissed=true
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  assert(not app.busy and observed>2 and saw_standing and checked_save)
  assert(app.game.DeathDoor.downed(patient) and patient.bleed_turns==2 and app.unit_nodes[patient.id].downed and not app.unit_nodes[patient.id].departing)
  assert(not app.game.roster.filter(func(u):return u.id==patient.id)[0].fallen)
  app.selected=lord;app.rescue_ally(patient)
  while app.busy:await process_frame
  assert(patient.get("carried_by","")==lord.id and not app.unit_nodes.has(patient.id))
  app.selected=healer;app.heal_carried_ally(patient)
  while app.busy:
   await process_frame
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  assert(patient.hp>0 and not app.game.DeathDoor.downed(patient) and patient.acted and app.unit_nodes.has(patient.id) and not app.unit_nodes[patient.id].downed)
  assert(not is_instance_valid(app.unit_nodes[patient.id].rescue_marker))
 await Shutdown.dispose(app)
 print("PASS: actual enemy, counterattack and carrying-ally downing stays visible at contact, holds wounded pose/countdown only after lethal damage, preserves committed saves and completes rescue/carried healing")
 quit()
