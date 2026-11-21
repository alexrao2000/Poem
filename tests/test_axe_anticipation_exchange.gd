extends SceneTree
const Trail=preload("res://scripts/combat_trail.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var app
var mode=""
var strikes=0
var total=0
var prepared=0
func _initialize():call_deferred("run")
func observe(node):
 if node is Imported and mode=="skip_windup" and node.model.get_meta("character_identity","")=="mara":
  while is_instance_valid(node) and node.pose_name!="critical_windup":await process_frame
  assert(is_instance_valid(node));prepared+=1;app.skip_combat=true;return
 if not node is Trail:return
 await process_frame
 var attacker=node.followed.get_ref();assert(attacker is Imported and attacker.pose_name=="strike")
 assert(attacker.player.current_animation==("AxeCriticalAttack" if strikes==0 else "Sword_Attack"),"Actual critical then ordinary swings select distinct private clips")
 strikes+=1;total+=1
 if mode=="skip_strike":app.skip_combat=true
func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-axe-anticipation-exchange.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.combat="all";app.game.start_battle();app.make_map();app.show_battle();app.stage.child_entered_tree.connect(observe)
 var foe=app.game.living("enemy")[0].duplicate(true);foe.job="Corsair";foe.weapon="axe";foe.item="war_hammer";foe.boss=false
 var cases=[]
 for id in ["mara","dax","hale"]:
  for promotion in ["","stormbreaker","trailguard"]:cases.append([id,promotion,""])
 cases.append_array([["mara","","counter"],["mara","","skip_windup"],["mara","","skip_strike"]])
 for index in range(cases.size()):
  var entry=cases[index];mode=entry[2];strikes=0
  var a=app.game.roster.filter(func(value):return value.id==entry[0])[0].duplicate(true);a.team="player";a.acted=false;a.moved=false;a.promotion=entry[1];a.item=["iron_axe","hatchet","great_axe","war_hammer"][index%4];a.x=8;a.y=4;a.hp=12
  var b=foe.duplicate(true);b.x=9;b.y=4;b.hp=12;app.game.units=[a,b];app.refresh_pieces();app.busy=true
  var attacker=b if mode=="counter" else a;var target=a if mode=="counter" else b;target.hp=4
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var view=app.map_navigation.capture_view()
  var events=[{"actor":attacker.id,"target":target.id,"damage":6,"remaining":6,"hit":true,"crit":true},{"actor":attacker.id,"target":target.id,"damage":2,"remaining":4,"hit":true,"crit":false}]
  await app.cinematic(a,b,events,{a.id:12,b.id:12});await process_frame
  assert(strikes==(0 if mode=="skip_windup" else 1 if mode=="skip_strike" else 2))
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.map_navigation.capture_view()==view)
  assert(app.world.visible and not app.stage.visible and not app.stage.has_node("CombatTrail"),"Skipping and ordinary completion clean up transient attacks")
  app.busy=false
 assert(total==21 and prepared==1)
 await Shutdown.dispose(app);await process_frame
 print("PASS: nine base/promoted Corsair exchanges, enemy counter, 21 actual critical/ordinary swings, critical preparation/strike interruption and exact campaign/RNG/map restoration")
 quit()
