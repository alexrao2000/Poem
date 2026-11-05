extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-corsair-studies-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var before=app.game.save_data("camp").duplicate(true);var seed=app.game.rng.state
 for key in ["corsair_female","corsair_male"]:
  app.show_debug_tools("camp");await process_frame
  app.ui.find_child("ModelStudy_"+key,true,false).pressed.emit();await process_frame
  assert(app.preview_actor is Imported and app.preview_actor.kind=="axe")
  for index in range(4):
   var choice=app.ui.find_child("StudyEquipment",true,false);var item=choice.get_item_metadata(index)
   app.preview_actor.rotation.y=.75;choice.select(index);choice.item_selected.emit(index);await process_frame;await process_frame
   assert(app.preview_unit.item==item and is_equal_approx(app.preview_actor.rotation.y,.75))
   for target in [1,2]:
    var selector=app.ui.find_child("StudyTarget",true,false);selector.select(target);selector.item_selected.emit(target);await app.stage.get_node("PreviewActionPlayer").finished
    var edge=app.preview_actor.weapon_trail_points();var point=app.preview_actor.get_node("StudyContactTarget").global_position
    assert(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)<.01,"Actual target controls use the axe's combat spacing")
   for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
    root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
    for control in app.ui.find_children("*","Button",true,false):
     if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()))
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==seed)
 await Shutdown.dispose(app);await process_frame
 print("PASS: both Corsair study buttons, eight real equipment switches, sixteen foot/mounted target selections, preserved view angle, three-size controls and exact campaign/RNG isolation")
 quit()
