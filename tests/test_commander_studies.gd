extends SceneTree
# Exercise the actual debug selector and mixed revised commander cinematics.
const Imported=preload("res://scripts/imported_fighter.gd")
const Commanders=preload("res://scripts/commanders.gd")
const Cutin=preload("res://scripts/critical_cutin.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var expected={}
var cutins=0
var impacts=0
var contacts=0
var actors=[]
func _initialize():call_deferred("run")
func watch_actor(node):
 if node is Imported and node.has_meta("commander"):actors.append(node.get_meta("commander"))
 if not node is Impact:return
 await process_frame;impacts+=1
 var attackers=node.get_parent().get_children().filter(func(child):return child is Imported and child.has_meta("commander") and child.kind in ["sword","lance"] and child.pose_name=="strike")
 if not attackers.is_empty():
  var edge=attackers[0].weapon_trail_points()
  assert(Geometry3D.get_closest_point_to_segment(node.global_position,edge[0],edge[1]).distance_to(node.global_position)<.015,"Commander melee meets its fitted blade")
  contacts+=1
func watch_cutin(node):
 if not node is Cutin:return
 await process_frame
 assert(node.get_node("Quote").text==expected.critical_quote and node.get_node("Portrait").texture.atlas.atlas.resource_path.ends_with("commanders-v1.png"))
 cutins+=1
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-commander-studies.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for chapter in range(12):
  app.show_debug_tools("camp");var selector=app.ui.find_child("CommanderStudy",true,false)
  assert(selector!=null and selector.item_count==12);selector.select(chapter);app.ui.find_child("ViewCommanderStudy",true,false).pressed.emit();await process_frame
  var actor=app.preview_actor;var profile=Commanders.profile(app.preview_unit)
  assert(actor is Imported and actor.get_meta("commander")==profile.id and app.preview_unit.name==app.game.content.chapters[chapter].boss)
  assert(app.ui.find_child("StudyEquipment",true,false)==null and app.ui.find_child("StudyStyle",true,false)==null,"Commander study keeps its own chapter loadout and identity")
  var actions=app.stage.get_node("PreviewActionPlayer")
  for pose in ["down","idle","strike"]:actions.play(pose);await actions.finished
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()),"Commander controls fit: "+app.preview_unit.name)
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng and not app.debug_session.revised_enemies,"Explicit previews do not change the enemy toggle or debug campaign")
 app.debug_session.end(app.game);app.preferences.values.character_models="revised";app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(watch_actor);app.ui.child_entered_tree.connect(watch_cutin)
 before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
 var rules=load("res://scripts/rules.gd").new();var ally=app.game.roster[0].duplicate(true);ally.team="player";ally.x=8;ally.y=4
 for chapter in range(12):
  rules.chapter=chapter;rules.start_battle();var enemy=rules.living("enemy").filter(func(unit):return unit.get("boss",false))[0].duplicate(true);enemy.x=10 if enemy.item=="javelin" or enemy.weapon in ["magic","bow"] else 9;enemy.y=4
  expected=Commanders.profile(enemy);var start=actors.size()
  await app.cinematic(ally,enemy,[{"actor":enemy.id,"target":ally.id,"damage":2,"remaining":ally.hp-2,"hit":true,"crit":true}],{enemy.id:enemy.hp,ally.id:ally.hp})
  assert(actors.slice(start)==[expected.id] and app.world.visible and app.pieces.visible and not app.stage.visible)
 assert(cutins==12 and impacts==12 and contacts==6,str([cutins,impacts,contacts]))
 assert(app.game.save_data("battle")==before and app.game.rng.state==rng)
 app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: twelve debug commander viewers, three-size controls, repeated fall/recovery/attack, unchanged toggle/campaign/RNG, twelve ordinary critical/counter exchanges with individual calls/portraits, six fitted melee contacts, six ranged impacts and map restoration")
 quit()
