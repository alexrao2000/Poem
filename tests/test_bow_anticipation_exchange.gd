extends SceneTree
const Charge=preload("res://scripts/combat_charge.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var character_ids=["sera","faye"]
var job="Ranger"
var weapon_kind="bow"
var promotion_ids=["","sharpshooter","pathfinder"]
var items=["scout_bow","recurve","longbow"]
var charges=0
var charge_frames=0
var app
var mode=""
var flights=0
var total=0
var preparations=0
var preparation_key="critical_windup"
var strike_key="strike"
func _initialize():call_deferred("run")
func observe(node):
 if node is Imported and mode=="skip_windup" and node.model.get_meta("character_identity","")==character_ids[0]:
  while is_instance_valid(node) and node.pose_name!=preparation_key:await process_frame
  assert(is_instance_valid(node));preparations+=1;app.skip_combat=true;return
 if node is Charge:
  await process_frame
  assert(weapon_kind=="magic" and node.caster is Imported)
  assert(node.caster.player.assigned_animation==("CriticalSpellEnter" if flights==0 else "Spell_Simple_Enter"))
  charges+=1
  while is_instance_valid(node) and not node.released and not node.is_queued_for_deletion():
   assert(node.global_position.distance_to(node.caster.socket_position("projectile"))<.001,"Gathering follows the animated casting palm throughout the windup")
   assert(node.seal.global_position.is_equal_approx(node.caster.global_position+Vector3.UP*.025),"The casting seal stays on the floor while the palm moves")
   charge_frames+=1
   await process_frame
  return
 if not node is Projectile:return
 await process_frame
 var archers=app.stage.get_children().filter(func(value):return value is Imported and value.kind==weapon_kind and value.pose_name==strike_key)
 assert(archers.size()==1)
 var actor=archers[0]
 if weapon_kind=="magic":
  var folio=actor.model.get_node("Rig/Armature/Skeleton3D/BookHand/Folio")
  assert(folio.critical_prepared==(flights==0) and actor.player.assigned_animation==("CriticalSpellRelease" if flights==0 else "Spell_Simple_Shoot"))
  assert(node.origin.distance_to(actor.socket_position("projectile"))<.001,"Actual critical/ordinary spells launch from the fitted free palm")
 elif weapon_kind=="lance":
  assert(actor.model.get_node("Identity").gaze.modifier.active,"Actual javelin releases keep looking toward the opponent")
  var grip=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip");var spear=actor.projectile_source()
  assert(grip.critical_throw_prepared==(flights==0) and not grip.critical_prepared and not spear.visible,"Actual critical throws preserve ranged preparation and release the held spear")
  assert(actor.player.assigned_animation=="LanceThrow" and node.body.has_node("HeldSpear"))
  assert(node.origin.distance_to(spear.get_node("TrailTip").global_position)<.001,"Actual critical and ordinary flights start at the fitted spear tip")
 else:
  var bow=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow");var arrow=bow.get_node("Weapon/NockedArrow")
  assert(bow.critical_prepared==(flights==0) and bow.projectile_spent and not arrow.visible,"Critical and ordinary actual shots keep distinct preparation and release the held arrow")
  assert(node.origin.distance_to(arrow.to_global(Vector3(0,0,-Projectile.ARROW_LENGTH*.5-.075)))<.001,"The actual flight starts at the fitted arrow tip")
 flights+=1;total+=1
 if mode=="skip_projectile":app.skip_combat=true
func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-bow-anticipation-exchange.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.combat="all";app.game.start_battle();app.make_map();app.show_battle();app.stage.child_entered_tree.connect(observe)
 var foe=app.game.living("enemy")[0].duplicate(true);foe.job=job;foe.weapon=weapon_kind;foe.item=items[-1];foe.boss=false
 var cases=[]
 for id in character_ids:
  for promotion in promotion_ids:cases.append([id,promotion,""])
 cases.append_array([[character_ids[0],"","counter"],[character_ids[0],"","skip_windup"],[character_ids[0],"","skip_projectile"]])
 for index in range(cases.size()):
  var entry=cases[index];mode=entry[2];flights=0
  var a=app.game.roster.filter(func(value):return value.id==entry[0])[0].duplicate(true);a.team="player";a.acted=false;a.moved=false;a.promotion=entry[1];a.item=items[index%items.size()];a.x=7;a.y=4;a.hp=12
  var b=foe.duplicate(true);b.x=9;b.y=4;b.hp=12;app.game.units=[a,b];app.refresh_pieces();app.busy=true
  var attacker=b if mode=="counter" else a;var target=a if mode=="counter" else b;target.hp=6
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var view=app.map_navigation.capture_view()
  var events=[{"actor":attacker.id,"target":target.id,"damage":6,"remaining":6,"hit":true,"crit":true},{"actor":attacker.id,"target":target.id,"damage":0,"remaining":6,"hit":false,"crit":false}]
  await app.cinematic(a,b,events,{a.id:12,b.id:12});await process_frame
  assert(flights==(0 if mode=="skip_windup" else 1 if mode=="skip_projectile" else 2))
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.map_navigation.capture_view()==view)
  assert(app.world.visible and not app.stage.visible and not app.stage.has_node("CombatProjectile"));app.busy=false
 assert(total==character_ids.size()*6+3 and preparations==1)
 assert(charges==(total+1 if weapon_kind=="magic" else 0))
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",character_ids.size()*3," base/promoted ",job," exchanges, enemy counter, ",total," actual critical/ordinary flights, ",charges," followed charges across ",charge_frames," frames, preparation/projectile skips, correct launch origin and exact campaign/RNG/map restoration")
 quit()
