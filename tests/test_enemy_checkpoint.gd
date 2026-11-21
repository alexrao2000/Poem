extends SceneTree
# Fixed choices isolate presentation ordering from AI scoring. Real movement,
# combat, healing, item use, persistence and enemy-phase continuation still run.

const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
class PlannedTactics extends "res://scripts/tactics.gd":
 var choice={}
 var applications=0
 func plan(_game,_unit):return choice
 func apply_plan(game,unit,action):
  applications+=1
  return super.apply_plan(game,unit,action)

var app
func _initialize():call_deferred("run")

func canonical(data):return JSON.parse_string(JSON.stringify(data))

func run():
 app=load("res://main.tscn").instantiate();app.settings_path=""
 app.save_path="/private/tmp/poem-enemy-checkpoint-%d.json"%Time.get_ticks_usec()
 root.add_child(app);await process_frame
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 var planner=PlannedTactics.new();app.tactics=planner
 for scenario in ["wait","kill","counter","tonic","heal","save_failure"]:
  app.game.new_campaign(true);app.game.action_saves=true;app.game.start_battle()
  var lord=app.game.living("player")[0];var ally=app.game.living("player")[1]
  var enemy=app.game.living("enemy")[0];var reserve=app.game.living("enemy")[1]
  lord.x=0;lord.y=0;ally.x=10;ally.y=4;enemy.x=8;enemy.y=4;reserve.x=12;reserve.y=7;reserve.boss=true
  enemy.job="Vanguard";enemy.weapon="sword";enemy.item="iron_sword";enemy.hp=enemy.max_hp;enemy.speed=50
  ally.job="Vanguard";ally.weapon="sword";ally.item="iron_sword"
  planner.choice={"position":Vector2i(9,4),"target":"","action":"wait"}
  if scenario=="kill":
   ally.hp=1;ally.speed=0;enemy.pow=100
   planner.choice.target=ally.id;planner.choice.action="attack"
  elif scenario=="counter":
   enemy.hp=1;enemy.speed=0;enemy.defense=0;ally.speed=50;ally.pow=100;ally.defense=100
   planner.choice.target=ally.id;planner.choice.action="attack"
  elif scenario=="tonic":
   enemy.hp=1;enemy.held_tonics=1;planner.choice.action="tonic"
  elif scenario=="heal":
   enemy.job="Warden";enemy.weapon="staff";enemy.item="field_staff";reserve.x=10;reserve.y=4;ally.x=0;ally.y=1;reserve.hp=1
   planner.choice.target=reserve.id;planner.choice.action="heal"
  app.game.units=[lord,ally,enemy,reserve];app.game.begin_enemy_phase();reserve.acted=true
  # Normalize the fixture through the same save boundary used by continuation.
  assert(app.game.restore_save(app.game.save_data("battle"))=="battle")
  enemy=app.game.units[2];ally=app.game.units[1];reserve=app.game.units[3]
  app.make_map();app.show_battle();assert(app.persist_campaign("battle"))
  var visual=app.unit_nodes[enemy.id];var old_ratio=visual.hp_ratio
  var old_rng=app.game.rng.state;var applications=planner.applications
  var working_path=app.save_path
  if scenario=="save_failure":app.save_path=working_path+"/missing/slot.json"
  app.end_turn(true)
  if scenario=="save_failure":
   assert(app.save_failed and not app.busy and app.moving_id.is_empty(),"Failed checkpoint stops before walking")
   assert(enemy.acted and app.game.pos(enemy)==Vector2i(9,4),"Resolved action stays available for retry")
   var blocked=app.game.save_data("battle").duplicate(true)
   app.end_turn(true)
   assert(planner.applications==applications+1 and app.game.save_data("battle")==blocked,"Another turn cannot run while saving fails")
   app.save_path=working_path;await app.retry_action_save()
   assert(not app.save_failed and app.game.phase=="player" and planner.applications==applications+1,"Save retry resumes without repeating the action")
   continue
  assert(app.busy and app.moving_id==enemy.id,"Observe the first suspended frame of the real enemy walk")
  assert(enemy.acted and app.game.pos(enemy)==Vector2i(9,4),"Enemy action resolves before its map walk: "+scenario)
  var saved=Rules.new();assert(saved.load_game(app.save_path)=="battle")
  assert(canonical(saved.save_data("battle"))==canonical(app.game.save_data("battle")),"Disk checkpoint includes the entire resolved enemy action")
  assert(not visual.spent and visual.hp_ratio==old_ratio,"Walking figure retains pre-action presentation")
  if scenario=="kill":assert(ally.hp==0 and app.game.roster.filter(func(u):return u.id==ally.id)[0].fallen)
  if scenario=="counter":assert(enemy.hp==0)
  if scenario=="tonic":assert(enemy.hp==13 and enemy.held_tonics==0)
  if scenario=="heal":assert(reserve.hp>1)
  assert((app.game.rng.state!=old_rng)==(scenario in ["kill","counter"]),"Only combat advances random rolls")
  var interrupted=saved.save_data("battle").duplicate(true)
  while app.busy:await process_frame
  var uninterrupted=canonical(app.game.save_data("battle"))
  assert(app.game.phase=="player" and planner.applications==applications+1)
  assert(app.game.restore_save(interrupted)=="battle")
  await app.resume_saved_battle()
  assert(planner.applications==applications+1,"Reload skips the resolved enemy even when its walk was interrupted")
  assert(canonical(app.game.save_data("battle"))==uninterrupted,"Reload reaches identical roster, health, inventory, turn and RNG: "+scenario)
 await Shutdown.dispose(app)
 print("PASS: five real enemy walks checkpoint movement, death, counter-death, tonic and healing before presentation; interrupted reloads finish identically without replay or reroll; failed saves block animation and retry without repeating actions")
 quit()
