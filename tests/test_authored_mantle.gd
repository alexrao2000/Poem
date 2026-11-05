extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var spec=studies.vanguard.duplicate(true);spec.appearance="Identity"
 var models=Models.new("");models.catalog={"characters":{"lyra":spec}};var rules=Rules.new();var unit=rules.roster[0].duplicate(true);unit.team="player"
 var stage=Node3D.new();root.add_child(stage);var count=0;var lowest=INF
 for item in spec.supported_items:
  unit.item=item;var actor=models.build(stage,unit,Vector3(35,0,0));assert(actor!=null);await process_frame
  var identity=actor.model.get_node("Identity");var mantle=identity.mantle;var rig=actor.model.get_node("Rig/Armature/Skeleton3D")
  assert(identity.identity=="lyra" and identity.robe==null and identity.hair_motion.root!=null and identity.cloak.cloth.get_parent().get_meta("cape_cut")=="standard")
  assert(mantle!=null and mantle.anchor.bone_name=="spine_03" and mantle.garment.get_meta("batch_stats").batches<=2)
  assert(mantle.surfaces[0].get_shader_parameter("tint")==Color("e5dfce") and mantle.surfaces[1].get_shader_parameter("tint")==Color("bca26b"))
  var local=mantle.garment.transform;var meshes=mantle.garment.find_children("*","MeshInstance3D",true,false)
  for height in [0.0,.7]:
   actor.position.y=height;actor.rotation.y=.8 if height>0 else -PI/2;mantle._process(0)
   for material in mantle.surfaces:assert(material.get_shader_parameter("cloth_floor_enabled") and is_equal_approx(material.get_shader_parameter("cloth_floor_y"),height+.018))
   for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
    var mapping=actor.poses[key]
    for step in range(17):
     actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,float(step)/16),true,true);actor.player.pause();actor.refresh_skeleton()
     assert(mantle.anchor.transform.is_equal_approx(rig.get_bone_global_pose(rig.find_bone("spine_03"))) and mantle.garment.transform==local,"Mantle fitting follows the chest without drifting through its source poses")
     for mesh in meshes:
      for surface in range(mesh.mesh.get_surface_count()):
       for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
        var point=mesh.to_global(vertex);assert(point.is_finite() and actor.to_local(point).length()<3)
        lowest=minf(lowest,point.y-height)
        if key!="down":assert(point.y>height+.3,"The shoulder mantle stays above the ground throughout standing/travel poses")
     count+=1
  var other=models.build(stage,unit,Vector3(39,0,0));await process_frame
  assert(other.model.get_node("Identity").mantle.surfaces[0]!=mantle.surfaces[0])
  var defeat=load("res://scripts/combat_defeat.gd").new();stage.add_child(defeat);defeat.begin(actor);defeat.apply_visibility(.35)
  for material in mantle.surfaces:assert(is_equal_approx(material.get_shader_parameter("defeat_visibility"),.35))
  actor.position.y=1.1;mantle._process(0)
  for material in mantle.surfaces:assert(is_equal_approx(material.get_shader_parameter("cloth_floor_y"),1.118))
  defeat.queue_free();actor.queue_free();other.queue_free();await process_frame
 stage.queue_free();await process_frame
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-mantle-study-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 app.show_debug_tools("camp");app.ui.find_child("ModelStudy_vanguard",true,false).pressed.emit();await process_frame
 assert(app.preview_unit.id=="lyra" and app.preview_actor.model.get_node("Identity").mantle==null)
 app.ui.find_child("StudyStyle",true,false).button_pressed=true;await process_frame;await process_frame
 assert(app.preview_actor.model.get_node("Identity").mantle!=null)
 for index in range(3):
  var choice=app.ui.find_child("StudyEquipment",true,false);choice.select(index);choice.item_selected.emit(index);await process_frame;await process_frame
  assert(app.preview_unit.item==spec.supported_items[index] and app.preview_actor.model.get_meta("character_identity")=="lyra")
  var target=app.ui.find_child("StudyTarget",true,false);target.select(2);target.item_selected.emit(2);await app.stage.get_node("PreviewActionPlayer").finished
  var edge=app.preview_actor.weapon_trail_points();var contact=app.preview_actor.get_node("StudyContactTarget").global_position
  assert(Geometry3D.get_closest_point_to_segment(contact,edge[0],edge[1]).distance_to(contact)<.006)
 app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==saved and app.game.rng.state==rng)
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," mantle/chest poses across three swords and relocated floor planes, two material batches, original identity/hair/cape, private fading materials, real study/style/equipment/mounted contact, unchanged campaign; minimum raw cloth height ",lowest)
 quit()
