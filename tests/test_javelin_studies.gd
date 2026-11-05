extends SceneTree
const Actor=preload("res://scripts/fighter_actor.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var study_pairs=[["knight_female","petra"],["knight_male","oren"]]
var save_name="javelin"
var flights=0
var observing=false
var recoveries=0
func _initialize():call_deferred("run")
func watch(node):
 if not node is Projectile:return
 await process_frame
 var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.kind=="lance" and child.pose_name=="throw")
 assert(actors.size()==1)
 var actor=actors[0];var weapon=actor.projectile_source()
 assert(weapon!=null and not weapon.visible and node.body.has_node("HeldSpear"),"Actual thrown attack hides the held spear and snapshots its fitted geometry")
 assert(node.origin.distance_to(weapon.get_node("TrailTip").global_position)<.001,"Real flight starts at the aimed tip")
 assert(node.body.get_node("HeldSpear/LanceShaft").mesh==weapon.get_node("LanceShaft").mesh)
 flights+=1
func observe(app):
 var previous=0
 while observing:
  await process_frame
  if not app.stage.visible:continue
  var actors=app.stage.get_children().filter(func(node):return node is Imported and node.pose_name=="recover")
  if actors.is_empty():previous=0;continue
  var actor=actors[0]
  if previous==actor.get_instance_id():continue
  previous=actor.get_instance_id();recoveries+=1
  assert(actor.player.current_animation=="LanceThrowRecover" and not actor.projectile_source().visible,"Real ranged exchanges use the empty-hand recovery")
func skip_phase(app,key: String,record: Dictionary):
 var deadline=Time.get_ticks_msec()+8000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  var found=app.stage.has_node("CombatProjectile") if key=="projectile" else app.stage.get_children().any(func(node):return node is Imported and node.pose_name==key)
  if not found:continue
  record.requested=true;var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;app._input(tab);return
 assert(false,"Reached the requested javelin skip phase")
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-"+save_name+"-studies-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 var ordinary_unit=app.game.roster.filter(func(value):return value.id=="oren")[0].duplicate(true);ordinary_unit.team="player";ordinary_unit.item="javelin"
 app.show_model_view(ordinary_unit);await process_frame
 var original=app.preview_actor;assert(original is Actor)
 var replay=app.stage.get_node("PreviewActionPlayer")
 for action in ["throw","throw","throw_recover","idle"]:
  replay.play(action);await replay.finished;assert(original.bones.Weapon.visible==(action=="idle"),"Original models also reload and release correctly when replayed")
 app.close_model_view();await process_frame
 for study in study_pairs:
  var key=study[0]
  app.show_source_model_view(key,"javelin",true);await process_frame;await process_frame
  assert(app.preview_actor is Imported)
  var choice=app.ui.find_child("PreviewAction",true,false);var controller=app.stage.get_node("PreviewActionPlayer");var weapon=app.preview_actor.projectile_source()
  var available=[]
  for index in range(choice.item_count):available.append(choice.get_item_metadata(index))
  for key_value in ["throw_windup","throw","throw_recover","strike"]:assert(key_value in available)
  var target=app.ui.find_child("StudyTarget",true,false);target.select(2);target.item_selected.emit(2);await controller.finished
  for action in ["throw","throw_recover","throw_recover","idle","strike","recover"]:
   var index=available.find(action);choice.select(index);choice.item_selected.emit(index);await controller.finished
   assert(is_equal_approx(absf(app.preview_actor.get_node("StudyContactTarget").position.z),4.0 if action.begins_with("throw") else 2.1),"Preview targets follow melee or throwing reach")
   assert(weapon.visible==(action not in ["throw","throw_recover"]),"Source action selection and replay preserve held/empty hand state")
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()))
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.debug_session.load_chapter(app.game,11);app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch);observing=true;observe(app)
 var catalog=app.fighters.models.catalog.duplicate(true);var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var enemy=app.game.living("enemy")[0].duplicate(true);enemy.x=9;enemy.y=4;enemy.weapon="lance";enemy.item="javelin"
 for pair in study_pairs:
  var spec=studies[pair[0]].duplicate(true);spec.appearance="Identity";app.fighters.models.catalog={"characters":{pair[1]:spec}}
  var unit=app.game.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player";unit.x=7;unit.y=4;unit.item="javelin"
  before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
  for mode in ["hit","miss","critical","blocked"]:
   enemy.job="Rider" if mode=="critical" else "Knight"
   var counter=mode=="miss";var damage=0 if mode in ["miss","blocked"] else 2
   await app.cinematic(enemy if counter else unit,unit if counter else enemy,[{"actor":unit.id,"target":enemy.id,"damage":damage,"remaining":20-damage,"hit":not counter,"crit":mode=="critical"}],{unit.id:unit.hp,enemy.id:20})
  for phase in ["throw_windup","projectile","recover"]:
   var record={"requested":false};skip_phase(app,phase,record)
   await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":2,"remaining":18,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
   assert(record.requested)
   assert(app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
   assert(not app.stage.has_node("CombatProjectile"))
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng,"Throwing and skipping preserve already-resolved campaign/RNG state")
 observing=false;await process_frame
 assert(flights==12 and recoveries==10,"Eight complete throws, two flight skips and two recovery skips use fitted flight and recovery")
 app.fighters.models.catalog=catalog;app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: both-body javelin controls and repeatable recovery, three-size UI, twelve actual fitted flights including foot/mounted/critical/missed-counter/guarded contacts, six skips, empty-hand recoveries, map return and campaign/RNG isolation")
 quit()
