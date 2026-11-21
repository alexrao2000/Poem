extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var app
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))

func setup():
 app.game.new_campaign();app.game.action_saves=true;app.game.start_battle()
 var lord=app.game.living("player")[0];var medic=app.game.living("enemy")[0];var patient=app.game.living("enemy")[1]
 lord.x=2;lord.y=4;medic.x=8;medic.y=4;patient.x=11;patient.y=4
 medic.job="Warden";medic.weapon="staff";medic.item="field_staff";medic.reach=1;medic.ai="pursue";medic.boss=false
 patient.hp=1;patient.boss=true
 app.game.units=[lord,medic,patient];app.game.begin_enemy_phase();patient.acted=true
 assert(app.game.restore_save(app.game.save_data("battle"))=="battle")
 return [app.game.units[1],app.game.units[2]]

func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-enemy-healing-%d.json"%Time.get_ticks_usec()
 root.add_child(app);await process_frame;app.preferences.values.auto_end=false
 var units=setup();var medic=units[0];var patient=units[1];var ai=Tactics.new()
 var before=app.game.save_data("battle").duplicate(true)
 var plan=ai.plan(app.game,medic)
 assert(plan.action=="heal" and plan.target==patient.id and plan.position!=app.game.pos(medic),"Enemy staff users approach an injured ally instead of treating their staff as a weapon")
 assert(app.game.save_data("battle")==before,"Healing planning is pure")
 medic.ai="guard";assert(ai.plan(app.game,medic).action=="wait","Guard healer cannot leave its post")
 patient.x=9;plan=ai.plan(app.game,medic)
 assert(plan.action=="heal" and plan.position==app.game.pos(medic),"Guard healer can help an adjacent ally")
 medic.hp=1;medic.held_tonics=1;assert(ai.plan(app.game,medic).action=="tonic","Critical self-preservation retains enemy held-tonic priority")
 for mode in ["current","revised","map","player","skip"]:
  units=setup();medic=units[0];patient=units[1]
  app.preferences.values.character_models="revised" if mode=="revised" else "current"
  app.preferences.values.combat=mode if mode in ["map","player"] else "all"
  app.make_map();app.show_battle();assert(app.persist_campaign("battle"))
  var rng=app.game.rng.state;var old_hp=patient.hp
  app.end_turn(true)
  assert(app.busy and medic.acted and patient.hp>old_hp,"Real enemy turn commits healing before its walk")
  var expected=Rules.new();assert(expected.load_game(app.save_path)=="battle");expected.next_player_turn()
  var saw_revised=false;var saw_arena=false;var saw_light=false;var saw_cue=false;var saw_hp_start=false;var saw_hp_end=false;var skipped=false
  while app.busy:
   await process_frame
   var hud=app.ui.get_node_or_null("CombatHUD")
   if hud!=null and not hud.is_queued_for_deletion():
    saw_arena=true
    assert(hud.records.values().all(func(record):return record.plate.enemy and not record.stats.visible and not record.matchup.visible),"Enemy healing shows two red health panels without damage forecasts")
    var hp=hud.records[patient.id].meter.value
    saw_hp_start=saw_hp_start or is_equal_approx(hp,float(old_hp));saw_hp_end=saw_hp_end or is_equal_approx(hp,float(patient.hp))
   for node in app.stage.get_children():
    if node is Heal:saw_light=true
    if mode=="revised" and node is Imported and node.kind=="staff":
     assert(node.model.get_meta("enemy_appearance")=="Warden","Enemy recovery uses the revised staff body");saw_revised=true
   for node in app.ui.get_children():
    if node is Label and node.text=="+%d"%(patient.hp-old_hp):saw_cue=true
   if mode=="skip" and saw_light and not skipped:
    var playback=app.ui.get_node_or_null("CombatPlayback")
    assert(playback!=null);playback.request_skip();skipped=true
  assert(app.game.rng.state==rng and canonical(app.game.save_data("battle"))==canonical(expected.save_data("battle")),"Healing feedback leaves committed state and random sequence unchanged")
  assert(is_equal_approx(app.unit_nodes[patient.id].hp_ratio,float(patient.hp)/patient.max_hp),"Returned map reflects healed enemy health")
  if mode=="revised":assert(saw_revised,"Actual enemy healer selects its revised body")
  if mode in ["map","player"]:assert(saw_cue and not saw_arena and not saw_light,"Map preference gives visible recovery feedback without a cutaway")
  else:
   assert(saw_arena and saw_light and saw_hp_start,"Enemy recovery presents staff light from the committed pre-heal health")
   assert(skipped if mode=="skip" else saw_hp_end,"Recovery reaches healed health or accepts a one-shot skip")
 await Shutdown.dispose(app)
 print("PASS: enemy healer approach/guard/tonic planning; five actual current/revised/map/player-only/skip turns with committed recovery, enemy health panels, field cues and unchanged state/RNG")
 quit()
