extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Charge=preload("res://scripts/combat_charge.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var study_key="caster"
var character_id="tarin"
var caster: Node3D
var shots=0
var charges=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Imported:caster=node
 elif node is Projectile:
  await process_frame
  assert(node.kind=="magic" and is_instance_valid(caster) and node.origin.distance_to(caster.socket_position("projectile"))<.001,"Actual spell flight starts at the imported casting palm")
  shots+=1
 elif node is Charge:
  await process_frame
  assert(node.caster is Imported and node.global_position.distance_to(node.caster.socket_position("projectile"))<.001,"Actual gathering follows the free casting hand")
  charges+=1
func sample(actor,mapping,time):
 actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var rules=Rules.new();var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player"
 var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))[study_key].duplicate(true);spec.appearance="Identity"
 var library=Models.new("");library.catalog={"characters":{character_id:spec}}
 var world=Node3D.new();root.add_child(world);var cases=0;var worst=0.0
 for item in spec.supported_items:
  unit.item=item;var actor=library.build(world,unit,Vector3(35,0,0));assert(actor!=null and library.issues.is_empty());await process_frame
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var hold=rig.get_node("FolioSupport");var hand=rig.get_node("BookHand");var book=hand.get_node("Folio/Weapon");var identity=actor.model.get_node("Identity")
  assert(identity.identity==character_id and identity.cloak.cloth.get_parent().get_meta("cape_cut")=="standard" and actor.pose_constraints.has(hold))
  assert(hand.get_node("Folio").equipped==item and book.get_node("Spellbook/LeftLeaf/PrintedPage").material_override.albedo_texture!=null)
  assert(actor.contact==null and actor.weapon_trail_points().is_empty(),"A caster does not acquire melee contact correction or blade sockets")
  for side in [-1,1]:
   actor.rotation.y=side*PI/2
   for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
    var mapping=actor.poses[key]
    for step in range(17):
     sample(actor,mapping,lerpf(mapping.from,mapping.to,step/16.0))
     var rotations=[];var positions=[];var scales=[]
     for bone in range(rig.get_bone_count()):rotations.append(rig.get_bone_pose_rotation(bone));positions.append(rig.get_bone_pose_position(bone));scales.append(rig.get_bone_pose_scale(bone))
     var destination=(rig.get_bone_global_pose(hold.chest)*hold.target).origin;var distance=hand.position.distance_to(destination);worst=maxf(worst,distance)
     assert(distance<(.051 if key=="down" else .0001),"Book support reaches its chest-relative target, with a bounded unreachable fall target")
     var current=hand.transform
     for repeat_sample in range(3):actor.refresh_skeleton();assert(hand.transform.is_equal_approx(current),"Repeated direct sampling cannot accumulate arm corrections")
     for bone in range(rig.get_bone_count()):assert(rig.get_bone_pose_rotation(bone).is_equal_approx(rotations[bone]) and rig.get_bone_pose_position(bone)==positions[bone] and rig.get_bone_pose_scale(bone)==scales[bone],"The prop solver restores animation input and never stretches bones")
     for mesh in book.find_children("*","MeshInstance3D",true,false):
      for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).y>.002,"All folios remain above the floor throughout the real clips")
     if key=="strike":assert(actor.to_local(actor.socket_position("projectile")).z<-.5,"The casting palm reaches in front of the body")
     cases+=1
  actor.pose("windup",.1);await create_timer(.12).timeout
  for weight in [0.0,.5,1.0]:
   hold.influence=weight;actor.refresh_skeleton();var expected=hand.transform
   await process_frame;await process_frame
   assert(hand.transform.is_equal_approx(expected),"Direct book support matches native modifier blending, including disabled influence")
  var frozen=hand.global_transform;var stop=load("res://scripts/combat_hit_stop.gd").new();world.add_child(stop);var pause=stop.play([actor],.1);pause.pause()
  await create_timer(.03).timeout;assert(hand.global_transform.is_equal_approx(frozen),"Native book support freezes with hit-stop")
  pause.play();await pause.finished;actor.queue_free();await process_frame
 world.queue_free();await process_frame
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-"+study_key+"-study-save.json";root.add_child(app);await process_frame
 app.show_source_model_view(study_key);assert(app.screen!="model","Casting studies remain behind Debug mode")
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var snapshot=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 app.show_debug_tools("camp");app.ui.find_child("ModelStudy_"+study_key,true,false).pressed.emit();await process_frame
 assert(app.preview_actor is Imported and app.preview_unit.id==character_id and app.ui.find_child("StudyTarget",true,false)==null)
 app.ui.find_child("StudyStyle",true,false).button_pressed=true;await process_frame;await process_frame
 for index in range(3):
  var choice=app.ui.find_child("StudyEquipment",true,false);choice.select(index);choice.item_selected.emit(index);await process_frame;await process_frame
  assert(app.preview_actor.model.get_node("Identity").identity==character_id and app.preview_unit.item==spec.supported_items[index])
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()),"Casting study controls fit compact and wide windows")
   var framing=app.stage.get_node("PreviewCamera");var actor=app.preview_actor
   for key in ["idle","windup","strike","down"]:
    var mapping=actor.poses[key];sample(actor,mapping,mapping.to);framing.measure();framing.reframe()
    for angle in [0.0,PI/2,PI]:
     actor.rotation.y=angle
     for entry in framing.geometry:
      if entry[0].is_visible_in_tree():
       for vertex in entry[1]:assert(framing.clear_rect().grow(.01).has_point(app.camera.unproject_position(entry[0].to_global(vertex))),"Tome, head and cloak retain the full preview frame")
  var playback=app.stage.get_node("PreviewActionPlayer");playback.play("strike");await playback.finished
  assert(app.preview_actor.pose_name=="strike")
 app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==snapshot and app.game.rng.state==rng,"Study choices never change campaign equipment, progression or rolls")
 app.debug_session.load_chapter(app.game,6);app.make_map();app.show_battle();app.busy=true
 var catalog=app.fighters.models.catalog.duplicate(true);app.fighters.models.catalog.characters[character_id]=spec
 app.stage.child_entered_tree.connect(watch)
 var enemy=app.game.living("enemy")[0];enemy.x=9;enemy.y=4;unit.x=7;unit.y=4
 for item in spec.supported_items:
  unit.item=item;var before=app.game.save_data("battle").duplicate(true);var seed=app.game.rng.state
  await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":3,"remaining":17,"hit":true,"crit":item=="thunder"}],{unit.id:unit.hp,enemy.id:20})
  assert(app.game.save_data("battle")==before and app.game.rng.state==seed)
 assert(shots==3 and charges==3,"All three elements complete their actual authored casting exchange")
 app.fighters.models.catalog=catalog;app.busy=false
 assert(not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",cases," casting/hold poses across three folios/headings, max unreachable fall target ",worst," m, unchanged bones, floor clearance, hit-stop, real three-size viewer/style/equipment replay and three actual elemental exchanges without campaign/RNG changes")
 quit()
