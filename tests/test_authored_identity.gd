extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var rules=Rules.new();var painter=Fighters.new()
 var world=Node3D.new();root.add_child(world)
 for pair in [["female","nell"],["male","silas"]]:
  var gender=pair[0];var id=pair[1];var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.item="iron_sword"
  var spec=studies[gender].duplicate(true);spec.appearance="Identity"
  var library=Models.new("");library.catalog={"characters":{id:spec}}
  var actor=library.build(world,unit,Vector3.ZERO);assert(actor!=null and library.issues.is_empty());await process_frame
  var identity=actor.model.get_node("Identity");var appearance=painter.profiles[id].appearance
  assert(identity.identity==id and actor.model.get_meta("character_identity")==id)
  assert(identity.source_meshes.size()==4 and identity.source_meshes.all(func(mesh):return not mesh.visible),"Source head/eyes/brows/hair are replaced only on this instance")
  assert(identity.head.get_meta("face_shape")==appearance.face_shape and identity.head.get_meta("hair_style")==appearance.hair_style and identity.head.get_meta("face_variant")==Fighters.FACE_INDICES[id],"Imported body uses the recruit's original head, hair and painted face")
  assert(identity.head.get_meta("batch_stats").sources>identity.head.get_meta("batch_stats").batches,"Static head details share draw batches while retaining the face")
  assert(identity.painted_materials.size()>=3)
  for material in identity.painted_materials:
   var skin=material.get_meta("dye_mode")==3
   assert(material.get_shader_parameter("tint")==Color(appearance.skin if skin else appearance.cloth))
   assert(material.get_shader_parameter("reference_luma")>.005 and material.get_shader_parameter("reference_luma")<1,"Palette normalization measures the actual source texture")
   assert(material.get_shader_parameter("albedo_map")!=null and material.get_shader_parameter("has_normal"))
  actor.pose("critical_windup",.02);assert(identity.blink.focused and identity.blink.serious)
  actor.pose("hit",.02);assert(identity.blink.closed)
  actor.pose("down",.02);assert(identity.blink.closed and not identity.blink.focused)
  actor.pose("idle",.02);assert(not identity.blink.closed)
  var plain_library=Models.new("");plain_library.catalog={"characters":{id:studies[gender]}}
  var plain=plain_library.build(world,unit,Vector3(4,0,0));await process_frame
  assert(plain.model.get_node("Identity").identity.is_empty() and plain.model.get_node("Rig/Armature/Skeleton3D/Head_Eyes").visible,"Styled actor does not modify the original source scene")
  var other=library.build(world,unit,Vector3(8,0,0));await process_frame
  assert(other.model.get_node("Identity").blink.surface!=identity.blink.surface,"Each imported face owns its expression material")
  actor.face_opponent(plain);actor.pose("idle",.02);assert(identity.blink.serious)
  var hold=load("res://scripts/combat_hit_stop.gd").new();world.add_child(hold);var pause=hold.play([actor],.08);var clock=identity.blink.clock
  await create_timer(.03).timeout;assert(identity.blink.clock==clock,"Imported expression timing respects hit stop")
  await pause.finished
  actor.pose("down",.02)
  var fade=load("res://scripts/combat_defeat.gd").new();world.add_child(fade);fade.begin(actor);fade.apply_visibility(.5)
  assert(fade.shaders.size()>=identity.painted_materials.size()+1,"Dyed clothing and the painted face participate in defeat fade")
  for material in identity.painted_materials:
   assert(fade.copies.has(material) and fade.copies[material].get_shader_parameter("defeat_visibility")==.5)
  assert(other.visible and other.model.get_node("Identity").painted_materials[0]!=identity.painted_materials[0])
  fade.queue_free();actor.queue_free();other.queue_free();plain.queue_free();await process_frame
 world.queue_free();await process_frame
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-styled-model-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for gender in ["female","male"]:
  app.show_source_model_view(gender);await process_frame
  app.preview_actor.rotation.y=.7;app.ui.find_child("StudyStyle",true,false).button_pressed=true;await process_frame;await process_frame
  assert(not app.preview_actor.model.get_node("Identity").identity.is_empty() and is_equal_approx(app.preview_actor.rotation.y,.7),"Style toggle rebuilds the identity while retaining facing")
  var items=app.ui.find_child("StudyEquipment",true,false);items.select(2);items.item_selected.emit(2);await process_frame;await process_frame
  assert(app.ui.find_child("StudyStyle",true,false).button_pressed and app.preview_unit.item=="tempered_sword","Equipment changes preserve the style choice")
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,app.ui.size).grow(.1).encloses(control.get_global_rect()),"Styled preview controls stay inside the viewport")
   var framing=app.stage.get_node("PreviewCamera");var actor=app.preview_actor
   for pose_key in ["idle","strike","evade","down"]:
    var mapping=actor.poses[pose_key]
    actor.player.play(mapping.clip);actor.player.seek(mapping.to,true,true);actor.player.pause();actor.refresh_skeleton()
    framing.measure();framing.reframe()
    for facing in [0.0,PI*.5,PI]:
     actor.rotation.y=facing
     for entry in framing.geometry:
      if not entry[0].is_visible_in_tree():continue
      for corner in entry[1]:assert(framing.clear_rect().grow(.01).has_point(app.camera.unproject_position(entry[0].to_global(corner))),"Replacement head/hair and equipped sword remain framed through rotation and action poses")
  var target=app.ui.find_child("StudyTarget",true,false);target.select(2);target.item_selected.emit(2);await app.stage.get_node("PreviewActionPlayer").finished
  var edge=app.preview_actor.weapon_trail_points();var point=app.preview_actor.get_node("StudyContactTarget").global_position
  assert(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)<.006,"Original head and material styling preserve the actual blade fit")
  app.ui.find_child("StudyStyle",true,false).button_pressed=false;await process_frame
  assert(app.preview_actor.model.get_node("Identity").identity.is_empty(),"Style comparison is reversible")
  app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==saved and app.game.rng.state==rng)
 await Shutdown.dispose(app);await process_frame
 print("PASS: original Nell/Silas identities on imported bodies, private cloth/skin/face materials, expressions and hit-stop, defeat fade, reversible style/equipment selection, compact controls, target contact and unchanged campaign")
 quit()
