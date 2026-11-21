extends SceneTree
const Projectile=preload("res://scripts/combat_projectile.gd")
const Trail=preload("res://scripts/combat_trail.gd")
const Finish=preload("res://scripts/combat_finish.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("res://tests/helpers/game_shutdown.gd")
var app
var mode=""
var seen=0
var peak=0.0
var completed=0
var expected_critical=false
var attacks=0
func _initialize():call_deferred("run")
func observe(node):
 if node is Imported and mode=="skip_windup" and node.model.get_meta("character_identity","")=="petra":
  while is_instance_valid(node) and node.pose_name!="critical_windup":await process_frame
  assert(is_instance_valid(node));app.skip_combat=true;return
 if node is Trail or node is Projectile:
  await process_frame
  var attacker=node.followed.get_ref() if node is Trail else app.stage.get_children().filter(func(value):return value is Imported and value.pose_name=="throw")[0]
  assert(attacker is Imported and attacker.pose_name in ["strike","throw"])
  assert(attacker.player.assigned_animation==("LanceThrow" if node is Projectile else "LanceStrike"),"Actual critical and normal attacks choose their own private source clips")
  attacks+=1
  if mode=="skip_strike":app.skip_combat=true
  return
 if not node is Finish:return
 await process_frame
 var actors=app.stage.get_children().filter(func(value):return value is Imported and not value.is_queued_for_deletion())
 var winners=actors.filter(func(value):return value.pose_name=="victory_flourish")
 assert(winners.size()==1 and actors.any(func(value):return value.pose_name=="down"),"Only the surviving revised fighter flourishes")
 seen+=1;var winner=winners[0];var driver=winner.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip")
 assert(driver.get_node("Weapon").visible and not driver.throwing)
 if mode=="skip_flourish":app.skip_combat=true;return
 while winner.pose_name=="victory_flourish":
  peak=maxf(peak,driver.finish);await process_frame
 assert(winner.pose_name=="victory" and driver.finish==0,"The flourish settles into the existing quiet held pose")
 if mode=="skip_hold":app.skip_combat=true;return
 completed+=1
func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-lance-finish-exchange.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.combat="all";app.game.start_battle();app.make_map();app.show_battle();app.stage.child_entered_tree.connect(observe)
 var foe=app.game.living("enemy")[0].duplicate(true);foe.job="Rider";foe.weapon="lance";foe.item="pike";foe.boss=false
 var cases=["petra","oren","rook","una","bram","elian","counter","survive","skip_flourish","skip_hold","skip_windup","skip_strike"]
 for index in range(cases.size()):
  mode=cases[index];seen=0;expected_critical=index%2==1 or mode in ["skip_windup","skip_strike"]
  var id=mode if index<6 else "petra";var a=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);a.team="player";a.acted=false;a.moved=false;a.item="javelin" if index%2 else "pike";a.hp=2;a.x=8;a.y=4
  if index<6:a.promotion=app.game.promotions.filter(func(value):return value.base==a.job)[index%2].id
  var b=foe.duplicate(true);b.x=10 if a.item=="javelin" else 9;b.y=4;b.hp=2;app.game.units=[a,b];app.refresh_pieces();app.busy=true
  var winner=b if mode=="counter" else a;var loser=a if mode=="counter" else b;loser.hp=1 if mode=="survive" else 0
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var view=app.map_navigation.capture_view()
  var event={"actor":winner.id,"target":loser.id,"damage":2-loser.hp,"remaining":loser.hp,"hit":true,"crit":expected_critical}
  await app.cinematic(a,b,[event],{a.id:2,b.id:2});await process_frame
  assert(seen==(0 if mode in ["survive","skip_windup","skip_strike"] else 1),"Finishing requires an actual resolved defeat")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.map_navigation.capture_view()==view,"Finishing/skip preserves resolved state, RNG and the exact map view")
  assert(app.world.visible and not app.stage.visible and not app.stage.has_node("CombatFinish") and not app.stage.has_node("CombatDefeat"),"Every exit cleans up transient finish effects")
  app.busy=false
 assert(attacks==11)
 assert(peak>.8 and completed==7,"Normal player and enemy finishes traverse the weapon settle and held victory")
 await Shutdown.dispose(app);await process_frame
 print("PASS: six promoted revised knight/rider victories, enemy counter victory, no finish on survival, critical preparation/strike and flourish/hold skipping, melee and javelin attack clips, weapon settle, private settle and exact campaign/RNG/map restoration")
 quit()
