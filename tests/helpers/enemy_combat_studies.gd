extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Shutdown=preload("game_shutdown.gd")
var jobs=[]
var contacts=0
var flights=0
var heals=0
var departures=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Impact:
  await process_frame
  var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.kind in ["sword","axe","lance"] and child.pose_name=="strike")
  if actors.is_empty():return
  var edge=actors[0].weapon_trail_points()
  assert(Geometry3D.get_closest_point_to_segment(node.global_position,edge[0],edge[1]).distance_to(node.global_position)<.015,"Enemy melee meets the actual fitted blade")
  contacts+=1
 elif node is Projectile:
  await process_frame
  var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.pose_name in ["strike","throw","cast"])
  assert(actors.size()==1);var actor=actors[0];var point=actor.socket_position("projectile")
  if actor.kind=="lance":
   var weapon=actor.projectile_source();assert(not weapon.visible and node.body.has_node("HeldSpear"));point=weapon.get_node("TrailTip").global_position
  elif actor.kind=="bow":
   var bow=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow");var arrow=bow.get_node("Weapon/NockedArrow")
   assert(not arrow.visible and bow.projectile_spent);point=arrow.to_global(Vector3(0,0,-Projectile.ARROW_LENGTH*.5-.075))
  assert(node.origin.distance_to(point)<.001,"Enemy flights leave the fitted weapon tip or casting hand")
  flights+=1
 elif node is Heal:
  await process_frame
  var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.kind=="staff")
  assert(actors.size()==1 and node.origin.distance_to(actors[0].socket_position("projectile"))<.001)
  heals+=1
 elif node is Defeat:
  await process_frame
  if not node.actor is Imported:return
  var victim=node.actor
  while is_instance_valid(node) and victim.visible:await process_frame
  assert(not victim.visible and victim.model.get_node("Identity").blink.closed);departures+=1
func skip_phase(app,record: Dictionary):
 var deadline=Time.get_ticks_msec()+8000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if app.stage.visible and app.stage.get_children().any(func(node):return node is Imported and node.pose_name in ["windup","cast_windup","throw_windup"]):
   record.requested=true;app.skip_combat=true;return
 assert(false,"Enemy skip reached its requested windup")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-enemy-combat-study.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.debug_session.load_chapter(app.game,6);app.make_map();app.show_battle();app.busy=true
 var before=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var profiles=app.fighters.profiles.duplicate(true);var looks=app.fighters.enemy_looks.duplicate(true)
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var catalog=app.fighters.models.catalog.duplicate(true)
 var ally=app.game.roster.filter(func(value):return value.id=="lyra")[0].duplicate(true);ally.team="player";ally.x=8;ally.y=4
 app.stage.child_entered_tree.connect(watch)
 var expected_contacts=0;var expected_flights=0;var expected_heals=0
 for job in jobs:
  var spec=studies["enemy_"+job.to_lower()].duplicate(true);spec.appearance="Identity";app.fighters.models.catalog={"enemy_classes":{job:spec}}
  var enemy=app.game.roster.filter(func(value):return value.id==spec.study_character)[0].duplicate(true);enemy.id="study_"+job;enemy.team="enemy";enemy.job=job;enemy.boss=false;enemy.x=9;enemy.y=4
  var target=ally.duplicate(true)
  if job=="Warden":target.team="enemy";target.id="study_patient"
  for index in range(spec.supported_items.size()):
   var item=spec.supported_items[index];enemy.item=item;enemy.x=10 if enemy.weapon in ["magic","bow","staff"] or item=="javelin" else 9
   var event={"actor":enemy.id,"target":target.id,"damage":2,"remaining":target.hp-2,"hit":true,"crit":index==1}
   if job=="Warden":event={"actor":enemy.id,"target":target.id,"healing":2};expected_heals+=1
   elif enemy.weapon in ["magic","bow"] or item=="javelin":expected_flights+=1
   else:expected_contacts+=1
   await app.cinematic(target if index==1 else enemy,enemy if index==1 else target,[event],{enemy.id:enemy.hp,target.id:target.hp-2 if job=="Warden" else target.hp})
  enemy.x=9
  for outcome in ["miss","guard","defeat"]:
   await app.cinematic(ally,enemy,[{"actor":ally.id,"target":enemy.id,"damage":enemy.hp if outcome=="defeat" else 0,"remaining":0 if outcome=="defeat" else enemy.hp,"hit":outcome!="miss","crit":false}],{enemy.id:enemy.hp,ally.id:ally.hp})
  var record={"requested":false};skip_phase(app,record)
  var last={"actor":enemy.id,"target":target.id,"damage":2,"remaining":target.hp-2,"hit":true,"crit":false}
  if job=="Warden":last={"actor":enemy.id,"target":target.id,"healing":2}
  await app.cinematic(enemy,target,[last],{enemy.id:enemy.hp,target.id:target.hp})
  assert(record.requested and app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng)
 assert(contacts==expected_contacts and flights==expected_flights and heals==expected_heals and departures==jobs.size(),str([contacts,expected_contacts,flights,expected_flights,heals,expected_heals,departures]))
 assert(app.fighters.profiles==profiles and app.fighters.enemy_looks==looks)
 app.fighters.models.catalog=catalog;app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: ",jobs," actual enemy equipment attacks/counters/criticals, ",contacts," fitted contacts, ",flights," weapon-tip/hand flights, ",heals," staff recoveries, dodges/guards/defeats, windup skips, map return and exact campaign/RNG/profile isolation")
 quit()
