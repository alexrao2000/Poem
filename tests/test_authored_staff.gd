extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var study_key="warden"
var character_id="ivo"
var caster: Node3D
var recoveries=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Imported:caster=node
 elif node is Heal:
  await process_frame
  assert(is_instance_valid(caster) and node.origin.distance_to(caster.socket_position("projectile"))<.001,"Healing light starts at the held staff's actual crown")
  recoveries+=1
func sample(actor,key: String,fraction: float):
 var mapping=actor.poses[key];actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))[study_key].duplicate(true);spec.appearance="Identity"
 var rules=Rules.new();var unit=rules.roster.filter(func(value):return value.id==character_id)[0].duplicate(true);unit.team="player"
 var models=Models.new("");models.catalog={"characters":{character_id:spec}};var stage=Node3D.new();root.add_child(stage);var count=0;var lowest=INF;var worst=0.0;var grip_gap=0.0
 for item in spec.supported_items:
  unit.item=item;var actor=models.build(stage,unit,Vector3(35,0,0));assert(actor!=null and models.issues.is_empty());await process_frame;actor.set_process(false)
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var hand=rig.get_node("WeaponHand");var equipment=hand.get_node("Staff");var weapon=equipment.get_node("Weapon");var hold=equipment.hold
  assert(equipment.equipped==item and hold.model==actor.model and hold.corners.size()==8 and actor.pose_constraints.has(hold))
  assert(actor.contact==null and actor.weapon_trail_points().is_empty() and actor.model.get_node("Identity").robe.pieces.size()==2)
  var originals=[]
  for bone in range(rig.get_bone_count()):originals.append([rig.get_bone_pose_position(bone),rig.get_bone_pose_scale(bone)])
  var meshes=weapon.find_children("*","MeshInstance3D",true,false)
  for height in [0.0,.65]:
   actor.position.y=height;actor.rotation.y=-PI/2 if height==0 else PI/2
   for key in ["idle","advance","cast_windup","cast","recover","hit","evade","down","victory"]:
    var steps=65 if key=="down" else 17
    for step in range(steps):
     sample(actor,key,float(step)/(steps-1))
     var desired=hold.target_pose();var distance=hand.position.distance_to(desired.origin);worst=maxf(worst,distance)
     assert(distance<(.02 if key=="down" else .0001),"Floor-aware wrist target stays within the arm's bounded reach")
     assert(hand.basis.is_equal_approx(desired.basis),"The hand and held prop turn together during floor correction")
     var rotations=[]
     for bone in range(rig.get_bone_count()):rotations.append(rig.get_bone_pose_rotation(bone))
     var transform=hand.transform;actor.refresh_skeleton();assert(hand.transform.is_equal_approx(transform),"Repeated attachment samples do not accumulate wrist corrections")
     for bone in range(rig.get_bone_count()):
      assert(rig.get_bone_pose_rotation(bone).is_equal_approx(rotations[bone]) and rig.get_bone_pose_scale(bone)==originals[bone][1],"The solver restores animated input rotations and never stretches source bones")
     for mesh in meshes:
      for surface in range(mesh.mesh.get_surface_count()):
       for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
        var point=mesh.to_global(vertex);lowest=minf(lowest,point.y-height)
        assert(point.is_finite() and point.y>=height+.01,"Every actual staff vertex clears relocated floors, including dense fall samples")
     for name_value in ["index_04_leaf_r","middle_04_leaf_r","ring_04_leaf_r","pinky_04_leaf_r"]:
      var finger=rig.to_global(rig.get_bone_global_pose(rig.find_bone(name_value)).origin)
      # Direct sampling restores input bones; use the frozen grip through the
      # hand attachment to measure the final fingertip in the corrected pose.
      var local=rig.get_bone_global_pose(rig.find_bone("hand_r")).affine_inverse()*rig.get_bone_global_pose(rig.find_bone(name_value)).origin
      finger=hand.to_global(local)
      var nearest=Geometry3D.get_closest_point_to_segment(finger,weapon.to_global(Vector3(0,-.625,0)),weapon.to_global(Vector3(0,.725,0)))
      grip_gap=maxf(grip_gap,finger.distance_to(nearest));assert(finger.distance_to(nearest)<.05,"Equipped fingers stay wrapped around the staff shaft")
     assert(actor.socket_position("projectile").distance_to(weapon.to_global(Vector3(0,.78,0)))<.00001)
     count+=1
  actor.position.y=0;sample(actor,"cast",.5)
  for influence in [0.0,.5,1.0]:
   hold.influence=influence;actor.refresh_skeleton();var direct=hand.transform
   await process_frame;await process_frame
   assert(hand.transform.is_equal_approx(direct),"Native and direct staff constraints agree at partial influence")
  hold.influence=1
  var fade=load("res://scripts/combat_defeat.gd").new();stage.add_child(fade);fade.begin(actor);fade.motion.pause();fade.apply_visibility(.4)
  assert(weapon.get_node("StaffShaft").material_override.albedo_color.a<.401)
  fade.queue_free();actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-"+character_id+"-staff-study-save.json";root.add_child(app);await process_frame
 app.debug_session.begin(app.game,"camp");app.options_return="camp";var before=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 for item in spec.supported_items:
  app.show_source_model_view(study_key,item,true);await process_frame
  var choices=app.ui.find_child("PreviewAction",true,false);var cast_index=-1
  for index in range(choices.item_count):
   if choices.get_item_metadata(index)=="cast":cast_index=index
  assert(cast_index>=0,"Staff source study keeps its healing action instead of filtering out alias poses")
  choices.select(cast_index);choices.item_selected.emit(cast_index);await app.stage.get_node("PreviewActionPlayer").finished
  assert(app.preview_actor.pose_name=="cast" and app.preview_actor.kind=="staff")
  for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
   for control in app.ui.find_children("*","Button",true,false):
    if control.is_visible_in_tree():assert(Rect2(Vector2.ZERO,size_value).grow(.1).encloses(control.get_global_rect()))
 app.close_model_view();await process_frame
 assert(app.game.save_data("camp")==before and app.game.rng.state==rng)
 app.debug_session.load_chapter(app.game,6);app.make_map();app.show_battle();app.busy=true
 var catalog=app.fighters.models.catalog.duplicate(true);app.fighters.models.catalog.characters[character_id]=spec;app.stage.child_entered_tree.connect(watch)
 var patient=app.game.roster[0].duplicate(true);patient.team="player";patient.x=9;patient.y=4;patient.hp=patient.max_hp;unit.x=7;unit.y=4
 for item in spec.supported_items:
  unit.item=item;before=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state
  if item=="beacon_staff":patient.job="Rider";patient.weapon="lance"
  await app.cinematic(unit,patient,[{"actor":unit.id,"target":patient.id,"healing":6}],{unit.id:unit.hp,patient.id:patient.hp-6})
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng)
 assert(recoveries==3,"All three staves complete their authored healing flow, including a mounted patient")
 app.fighters.models.catalog=catalog;app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," actual staff/hand poses with dense falls, relocated floors, bounded reach ",worst," m, shaft grip ",grip_gap," m, minimum height ",lowest," m, native/direct influence, unchanged bones, fading, three-size study controls and three real healing exchanges")
 quit()
