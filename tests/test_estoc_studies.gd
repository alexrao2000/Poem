extends SceneTree
# Exercise the real source viewer and campaign combat path, including skips.

const Imported=preload("res://scripts/imported_fighter.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Trail=preload("res://scripts/combat_trail.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var contacts=0
var trails=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Impact:
  await process_frame
  var actors=node.get_parent().get_children().filter(func(child):return child is Imported and child.point_trail_width>0 and child.pose_name=="strike")
  if actors.is_empty():return
  assert(actors[0].sockets.trail_tip.global_position.distance_to(node.global_position)<.012,str(["Real estoc contact",contacts,actors[0].model.get_meta("character_identity",actors[0].model.get_meta("enemy_appearance","")),actors[0].sockets.trail_tip.global_position,node.global_position]))
  contacts+=1
 elif node is Trail:
  await process_frame
  if not is_instance_valid(node) or node.followed==null:return
  var actor=node.followed.get_ref()
  if not actor is Imported or actor.point_trail_width<=0:return
  assert(is_equal_approx(actor.weapon_trail_points()[0].distance_to(actor.weapon_trail_points()[1]),.032))
  trails+=1
func skip_phase(app,phase: String,record: Dictionary):
 var deadline=Time.get_ticks_msec()+8000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if not app.stage.visible:continue
  if app.stage.get_children().any(func(node):return node is Imported and node.point_trail_width>0 and node.pose_name==phase):
   record.requested=true;app.skip_combat=true;return
 assert(false,"Estoc playback reached the requested skip phase")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-estoc-studies-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for key in ["female","male","vanguard","vanguard_male","enemy_duelist","enemy_vanguard"]:
  app.show_source_model_view(key,"estoc",true);await process_frame
  var actor=app.preview_actor;assert(actor is Imported and actor.contact==null and actor.point_trail_width==.032)
  var target=app.ui.find_child("StudyTarget",true,false);assert(target!=null)
  for choice in [1,2]:
   target.select(choice);target.item_selected.emit(choice);await app.stage.get_node("PreviewActionPlayer").finished
   assert(actor.sockets.trail_tip.global_position.distance_to(actor.get_node("StudyContactTarget").global_position)<.006)
  var actions=app.stage.get_node("PreviewActionPlayer")
  for key_value in ["recover","strike","down","idle"]:
   actions.play(key_value);await actions.finished
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");assert(rig.get_bone_pose_position(rig.find_bone("root")).is_equal_approx(Vector3.ZERO))
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for button in app.ui.find_children("*","Button",true,false):
    if button.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(button.get_global_rect()))
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.debug_session.end(app.game);app.preferences.values.character_models="revised";app.game.start_battle();app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch)
 var enemy=app.game.living("enemy").filter(func(unit):return not unit.get("boss",false))[0].duplicate(true);enemy.x=9;enemy.y=4;enemy.job="Knight";enemy.weapon="lance";enemy.item="iron_lance"
 before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 for id in ["nell","silas","yuna","lyra","cassian","rhea"]:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.item="estoc";unit.x=8;unit.y=4
  var blocked=id in ["nell","cassian"];enemy.job="Knight" if blocked else "Rider"
  await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":0 if blocked else 2,"remaining":20 if blocked else 18,"hit":true,"crit":id in ["silas","rhea"]}],{unit.id:unit.hp,enemy.id:20})
 for job in ["Vanguard","Duelist"]:
  enemy.job=job;enemy.weapon="sword";enemy.item="estoc"
  var ally=app.game.roster[0].duplicate(true);ally.team="player";ally.x=8;ally.y=4
  await app.cinematic(ally,enemy,[{"actor":enemy.id,"target":ally.id,"damage":2,"remaining":ally.hp-2,"hit":true,"crit":true}],{enemy.id:20,ally.id:ally.hp})
  for phase in ["windup","strike"]:
   var record={"requested":false};skip_phase(app,phase,record)
   await app.cinematic(enemy,ally,[{"actor":enemy.id,"target":ally.id,"damage":2,"remaining":ally.hp-2,"hit":true,"crit":false}],{enemy.id:20,ally.id:ally.hp})
   assert(record.requested and app.world.visible and app.pieces.visible and not app.stage.visible,str([job,phase,record,app.world.visible,app.pieces.visible,app.stage.visible]))
 assert(contacts==8 and trails>=8,"Eight complete player/enemy thrusts and their narrow trails were observed")
 assert(app.game.save_data("battle")==before and app.game.rng.state==rng and app.world.visible and app.pieces.visible and not app.stage.visible)
 app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: six estoc study viewers, twelve foot/mounted targets, repeatable recovery/fall/reset, three-size controls, eight actual player/enemy/critical/counter/shield contacts, narrow trails, four skips and exact campaign/RNG isolation")
 quit()
