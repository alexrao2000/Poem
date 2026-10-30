extends SceneTree
const Commanders=preload("res://scripts/commanders.gd")
const Portraits=preload("res://scripts/portraits.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Cutin=preload("res://scripts/critical_cutin.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var observed_cutin=false

func _initialize():call_deferred("run")

func watch_cutin(node):
 if not node is Cutin:return
 await process_frame
 assert(node.get_node("Quote").text==Commanders.profiles["Regent Vael"].critical_quote,"Real commander critical uses its own authored call")
 assert(node.get_node("Portrait").texture.atlas.atlas.resource_path.ends_with("commanders-v1.png"),"Real critical uses the commander's own eye crop")
 observed_cutin=true

func run():
 var rules=Rules.new();var portraits=Portraits.new();var painter=Fighters.new()
 var stage=Node3D.new();root.add_child(stage);var host=Control.new();root.add_child(host)
 var seen=[];var regions=[];var class_looks=painter.enemy_looks.duplicate(true);var layouts=0
 assert(Commanders.profiles.size()==12)
 for chapter in range(12):
  rules.chapter=chapter;rules.start_battle()
  var boss=rules.units.filter(func(unit):return unit.get("boss",false))[0]
  var entry=Commanders.profile(boss);assert(not entry.is_empty() and entry.job==boss.job)
  var saved=rules.save_data("battle").duplicate(true);var rng=rules.rng.state
  var portrait=portraits.get_unit_portrait(boss);var critical=portraits.get_critical_portrait(boss)
  assert(portrait not in seen and portrait.filter_clip and portrait.atlas.get_size()==Vector2(1254,1254),"Reused enemy IDs select twelve separate isolated portrait regions")
  for region in regions:assert(not region.intersects(portrait.region),"No commander portrait samples a neighboring cell")
  assert(Rect2(Vector2.ZERO,portrait.atlas.get_size()).encloses(portrait.region))
  assert(critical.atlas==portrait and critical.filter_clip and Rect2(Vector2.ZERO,portrait.get_size()).encloses(critical.region),"Critical crop belongs to this portrait and remains inside its measured region")
  seen.append(portrait);regions.append(portrait.region)
  var actor=painter.build(stage,boss,Vector3.ZERO)
  assert(actor.get_meta("commander","")==entry.id and actor.get_meta("costume_colors").cloth==Color(entry.appearance.cloth) and actor.get_meta("costume_colors").cape==Color(entry.appearance.cape),"Each commander receives its own model palette")
  if entry.appearance.has("crest") or entry.appearance.has("circlet"):
   var color=Color(entry.appearance.get("crest",entry.appearance.get("circlet","ffffff")))
   assert(actor.bones.Head.find_children("*","MeshInstance3D",true,false).any(func(mesh):return mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color==color),"Commander's actual crest/jewel material survives head batching")
  actor.queue_free();await process_frame
  var ordinary=boss.duplicate(true);ordinary.boss=false
  assert(Commanders.profile(ordinary).is_empty() and portraits.get_unit_portrait(ordinary)!=portrait,"An ordinary soldier with a matching name keeps class art")
  actor=painter.build(stage,ordinary,Vector3.ZERO)
  assert(not actor.has_meta("commander") and actor.get_meta("costume_colors").cloth==Color(painter.enemy_looks[ordinary.job].cloth),"Commander colors cannot leak into following ordinary models")
  actor.queue_free();await process_frame
  var wrong=boss.duplicate(true);wrong.job="Ranger" if boss.job!="Ranger" else "Knight";assert(Commanders.profile(wrong).is_empty())
  wrong=boss.duplicate(true);wrong.team="player";assert(Commanders.profile(wrong).is_empty())
  wrong=boss.duplicate(true);wrong.name="Unknown commander";assert(Commanders.profile(wrong).is_empty() and portraits.get_unit_portrait(wrong)!=null,"Unknown old/custom commanders retain a usable class fallback")
  for size_value in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   host.size=size_value
   var cutin=Cutin.new();cutin.configure(host,boss,critical,entry.critical_quote);await process_frame
   for key in ["Heading","Quote"]:
    var label=cutin.get_node(key)
    assert(label.get_line_count()<=label.get_visible_line_count(),"Every commander's name and call fit its critical panel")
    assert(cutin.get_rect().size.x>=label.position.x+label.size.x)
   cutin.queue_free();await process_frame;layouts+=1
  assert(rules.save_data("battle")==saved and rules.rng.state==rng,"Commander appearance never changes chapter or battle data")
 assert(painter.enemy_looks==class_looks,"Shared class profiles remain unchanged")
 stage.queue_free();host.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-commanders-test.json";root.add_child(app);await process_frame
 for chapter in range(12):
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle();await process_frame
  var boss=app.game.units.filter(func(unit):return unit.get("boss",false))[0];var actor=app.unit_nodes[boss.id]
  var badge=actor.get_node("CommanderInsignia")
  assert(badge.no_depth_test and badge.billboard==BaseMaterial3D.BILLBOARD_ENABLED,"Commander crown remains a clear upright map marker")
  var point=app.camera.unproject_position(badge.global_position)
  assert(actor.screen_bounds(app.camera).has_point(point) and app.pick_map_unit(point)==boss,"Clicking the crown selects its commander")
  for unit in app.game.units:
   if not unit.get("boss",false):assert(not app.unit_nodes[unit.id].has_node("CommanderInsignia"),"Only the actual chapter commander receives a crown")
 var boss=app.game.units.filter(func(unit):return unit.get("boss",false))[0]
 app.ui.child_entered_tree.connect(watch_cutin);app.skip_combat=false
 await app.critical_cutin(boss)
 await process_frame
 assert(observed_cutin and not app.ui.has_node("CriticalCutin"),"Commander cut-in cleans up through the real presentation path")
 await Shutdown.dispose(app);await process_frame
 print("PASS: twelve isolated named commander portraits/model palettes, %d critical layouts, ordinary/custom fallbacks, shared-class isolation, clickable map crowns and real unique critical call"%layouts)
 quit()
