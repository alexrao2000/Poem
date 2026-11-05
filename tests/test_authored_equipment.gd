extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var game=Rules.new();game.start_battle();var unit=game.units[0].duplicate(true);var world=Node3D.new();root.add_child(world);var count=0
 for gender in ["female","male"]:
  var library=Models.new("");library.catalog={"characters":{unit.id:studies[gender]}}
  for item in studies[gender].supported_items:
   unit.item=item;unit.weapon="sword"
   var actor=library.build(world,unit,Vector3.ZERO);assert(actor!=null and library.issues.is_empty());await process_frame
   var grip=actor.model.get_node(studies[gender].equipment);var weapon=grip.get_node("Weapon")
   assert(grip.equipped==item and weapon.get_meta("equipment")==item,"Imported actor uses the actual equipped item")
   var blade=weapon.get_node("SwordBlade")
   assert(blade.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==Fighters.EquipmentVisuals.blade(item).surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Original equipment shape and width are preserved")
   assert(blade.material_override.get_shader_parameter("tint")==Color(Fighters.EquipmentVisuals.profiles[item].steel),"The selected sword keeps its own steel palette")
   var expected=Fighters.EquipmentVisuals.trail_edge("sword",item);var edge=actor.weapon_trail_points()
   assert(edge[0].is_equal_approx(weapon.to_global(expected[0])) and edge[1].is_equal_approx(weapon.to_global(expected[1])),"Blade sockets are rebuilt with equipment")
   var target=Vector3(0,1.1,-1.4);actor.aim_at(target)
   await actor.pose("windup",.02).finished;await actor.pose("strike",.04).finished
   edge=actor.weapon_trail_points()
   assert(Geometry3D.get_closest_point_to_segment(target,edge[0],edge[1]).distance_to(target)<.006,"Every supported sword retains fitted contact")
   actor.queue_free();await process_frame;count+=1
  unit.item="estoc"
  assert(library.build(world,unit,Vector3.ZERO)==null and library.issues.is_empty(),"Unsupported thrust equipment deliberately uses the existing fallback")
  var painter=Fighters.new();painter.models=library
  var fallback=painter.build(world,unit,Vector3.ZERO)
  assert(fallback is Fighters.Actor and fallback.attack_style=="thrust","Estoc preserves its point-first combat animation")
  fallback.queue_free();await process_frame
 for change in [{"supported_items":[]},{"supported_items":[7]},{"equipment":false},{"equipment":"Missing"}]:
  var spec=studies.female.duplicate(true);spec.merge(change,true);var library=Models.new("");library.catalog={"characters":{unit.id:spec}};unit.item="iron_sword"
  var before=world.get_child_count();assert(library.build(world,unit,Vector3.ZERO)==null and not library.issues.is_empty() and world.get_child_count()==before,"Invalid equipment configuration leaves no partial actor")
 world.queue_free();await process_frame
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-authored-equipment-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var snapshot=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for gender in ["female","male"]:
  app.show_source_model_view(gender);await process_frame
  var target=app.ui.find_child("StudyTarget",true,false);target.select(2);target.item_selected.emit(2);await app.stage.get_node("PreviewActionPlayer").finished
  for index in [2,1,0]:
   var selector=app.ui.find_child("StudyEquipment",true,false);var item=selector.get_item_metadata(index)
   app.preview_actor.rotation.y=.75;selector.select(index);selector.item_selected.emit(index);await process_frame;await process_frame
   assert(app.preview_unit.item==item and is_equal_approx(app.preview_actor.rotation.y,.75),"Study item changes rebuild the equipped actor while preserving the inspection angle")
   assert(app.preview_actor.model.get_node(studies[gender].equipment).equipped==item)
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,app.ui.size).grow(.1).encloses(control.get_global_rect()),"Equipment selector stays inside the compact viewer")
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==snapshot and app.game.rng.state==rng,"Equipment study never equips a campaign unit or changes randomness")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," authored equipment bindings, original shapes/materials/trails, fitted contacts, explicit estoc thrust fallback, invalid specifications and real compact viewer switching without campaign changes")
 quit()
