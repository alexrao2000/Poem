extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-enemy-families-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp"
 var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state;var profiles=app.fighters.profiles.duplicate(true);var looks=app.fighters.enemy_looks.duplicate(true)
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var count=0;var materials=[]
 for key in studies:
  var spec=studies[key]
  if not spec.has("study_enemy_class"):continue
  var job=spec.study_enemy_class
  var rejected=load("res://scripts/debug_source_models.gd").new([key]);assert(rejected.identities.is_empty() and not rejected.models.issues.is_empty())
  app.show_debug_tools("camp");app.ui.find_child("ModelStudy_"+key,true,false).pressed.emit();await process_frame
  assert(app.preview_actor is Imported and app.preview_unit.team=="enemy" and app.preview_actor.model.get_node("Identity").identity.is_empty())
  app.preview_actor.rotation.y=.6;app.ui.find_child("StudyStyle",true,false).button_pressed=true;await process_frame;await process_frame
  for index in range(spec.supported_items.size()):
   var selector=app.ui.find_child("StudyEquipment",true,false);selector.select(index);selector.item_selected.emit(index);await process_frame;await process_frame
   var actor=app.preview_actor;var identity=actor.model.get_node("Identity");var appearance=looks[job]
   assert(app.preview_unit.team=="enemy" and is_equal_approx(actor.rotation.y,.6))
   assert(actor.model.get_meta("enemy_appearance")==job and identity.head.get_meta("face_variant")==int(appearance.face_variant))
   assert(identity.cloak.cloth.material_override.get_shader_parameter("cape_mark")==app.fighters.IMPERIAL_CAPE)
   for material in identity.painted_materials:
    assert(material.get_shader_parameter("tint")==Color(appearance.skin if material.get_meta("dye_mode")==3 else appearance.cloth))
    assert(material not in materials,"Different studies own their dye materials");materials.append(material)
   if job=="Knight":assert(not identity.head.get_node("PaintedFace").visible and identity.hair_motion.root==null)
   if job=="Rider":assert(actor.model.get_node("Mount").enemy_colors)
   if job=="Vanguard":assert(identity.armor!=null and identity.light_armor and identity.mantle==null)
   await actor.pose("down",.01).finished;assert(identity.blink.closed)
   count+=1
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()))
  var enemy=app.preview_unit.duplicate(true);app.close_model_view();await process_frame
  var fallback=app.make_fighter(enemy,Vector3.ZERO);assert(fallback is Actor,"Anonymous enemy studies leave campaign selection unchanged");fallback.queue_free();await process_frame
 assert(count>=22 and app.game.save_data("camp")==before and app.game.rng.state==rng and app.fighters.profiles==profiles and app.fighters.enemy_looks==looks)
 await Shutdown.dispose(app);await process_frame
 print("PASS: eight anonymous enemy studies, ",count," equipment bindings, source/style controls, private faction dyes and imperial cloaks, closed expressions, three UI sizes, ordinary fallback and exact campaign/RNG/profile isolation")
 quit()
