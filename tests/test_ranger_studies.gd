extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var flights=0
var departures=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Projectile:
  await process_frame
  if node.kind!="bow":return
  var archers=node.get_parent().get_children().filter(func(child):return child is Imported and child.kind=="bow" and child.pose_name=="strike")
  assert(archers.size()==1)
  var bow=archers[0].model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow");var arrow=bow.get_node("Weapon/NockedArrow")
  assert(not arrow.visible and bow.projectile_spent,"Actual launch removes the held arrow")
  var tip=arrow.to_global(Vector3(0,0,-Projectile.ARROW_LENGTH*.5-.075))
  assert(node.origin.distance_to(tip)<.001,"Flight starts at the actual aimed arrow tip")
  flights+=1
 elif node is Defeat:
  await process_frame
  if not node.actor is Imported:return
  var victim=node.actor
  while is_instance_valid(node) and victim.visible:await process_frame
  assert(not victim.visible and victim.model.get_node("Identity").blink.closed);departures+=1
func skip_phase(app,key: String,record: Dictionary):
 var deadline=Time.get_ticks_msec()+8000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  var found=app.stage.has_node("CombatProjectile") if key=="projectile" else app.stage.get_children().any(func(node):return node is Imported and node.pose_name==key)
  if not found:continue
  record.requested=true;var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;app._input(tab);return
 assert(false,"Reached the requested archer skip phase")
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-ranger-studies-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for key in ["ranger_female","ranger_male"]:
  app.show_debug_tools("camp");await process_frame;app.ui.find_child("ModelStudy_"+key,true,false).pressed.emit();await process_frame
  assert(app.preview_actor is Imported and app.preview_actor.kind=="bow")
  for index in range(3):
   var selector=app.ui.find_child("StudyEquipment",true,false);var item=selector.get_item_metadata(index)
   app.preview_actor.rotation.y=.7;selector.select(index);selector.item_selected.emit(index);await process_frame;await process_frame
   var bow=app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow")
   assert(bow.equipped==item and is_equal_approx(app.preview_actor.rotation.y,.7))
   var actions=app.stage.get_node("PreviewActionPlayer");actions.play("strike");await actions.finished
   assert(not bow.get_node("Weapon/NockedArrow").visible and bow.projectile_spent,"Source replay includes the actual arrow release")
   actions.play("idle");await actions.finished;assert(bow.get_node("Weapon/NockedArrow").visible)
   for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
    for control in app.ui.find_children("*","Button",true,false):
     if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()))
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.debug_session.load_chapter(app.game,11);app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch)
 var catalog=app.fighters.models.catalog.duplicate(true);var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var opponent=app.game.living("enemy")[0].duplicate(true);opponent.x=9;opponent.y=4
 for pair in [["ranger_female","sera"],["ranger_male","ari"]]:
  var spec=studies[pair[0]].duplicate(true);spec.appearance="Identity";app.fighters.models.catalog={"characters":{pair[1]:spec}}
  var unit=app.game.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player";unit.x=7;unit.y=4
  before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
  for item in ["scout_bow","recurve","longbow"]:
   unit.item=item;opponent.job="Rider" if item=="longbow" else "Knight";opponent.weapon="lance";opponent.item="iron_lance"
   var counter=item=="recurve"
   await app.cinematic(opponent if counter else unit,unit if counter else opponent,[{"actor":unit.id,"target":opponent.id,"damage":0 if counter else 2,"remaining":20 if counter else 18,"hit":not counter,"crit":item=="longbow"}],{unit.id:unit.hp,opponent.id:20})
  await app.cinematic(opponent,unit,[{"actor":opponent.id,"target":unit.id,"damage":unit.hp,"remaining":0,"hit":true,"crit":false}],{unit.id:unit.hp,opponent.id:20})
  for phase in ["windup","projectile"]:
   var record={"requested":false};skip_phase(app,phase,record)
   await app.cinematic(unit,opponent,[{"actor":unit.id,"target":opponent.id,"damage":2,"remaining":18,"hit":true,"crit":false}],{unit.id:unit.hp,opponent.id:20})
   assert(record.requested and app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng,"Bow playback and skipping never alter resolved campaign state")
 assert(flights==8 and departures==2,"Six full shots, two flight skips and both body defeats use the new bow path")
 app.fighters.models.catalog=catalog;app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: both Ranger study buttons, six item/replay bindings, three-size controls, actual arrow-tip launches, foot/mounted/critical/missed counter shots, two defeats, four skips, map return and exact campaign/RNG isolation")
 quit()
