extends SceneTree
const Fighters=preload("res://scripts/fighters.gd")
const Costumes=preload("res://scripts/promotion_costume.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")

func signature(actor):
 var count=0;var x=0.0;var y=0.0;var z=0.0;var u=0.0;var v=0.0
 var relative=actor.global_transform.affine_inverse()
 for node in actor.find_children("*","MeshInstance3D",true,false):
  var transform=relative*node.global_transform
  for surface in range(node.mesh.get_surface_count()):
   var arrays=node.mesh.surface_get_arrays(surface);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var uv=arrays[Mesh.ARRAY_TEX_UV]
   if indices==null or indices.is_empty():indices=range(points.size())
   for index in indices:
    var point=transform*points[index];x+=point.x;y+=point.y;z+=point.z;count+=1
    if uv!=null:u+=uv[index].x;v+=uv[index].y
 return {"count":count,"sum":Vector3(x,y,z),"uv":Vector2(u,v)}

func run():
 var rules=Rules.new();var fighters=Fighters.new();fighters.batching_enabled=false
 var stage=Node3D.new();root.add_child(stage);var seen={};var variants={};var checked=0
 var original=rules.roster.duplicate(true);var rng=rules.rng.state
 assert(Costumes.looks.size()==rules.promotions.size(),"Every actual training branch has a costume profile")
 for unit_entry in rules.roster:
  var unit=unit_entry.duplicate(true);unit.team="player"
  var base=fighters.build(stage,unit,Vector3.ZERO);base.set_process(false);base.pose_tween.kill()
  var base_shape=signature(base)
  assert(not base.has_meta("promotion_look"),"Unpromoted recruits retain their original costumes")
  for path in rules.promotion_options(unit):
   assert(Costumes.looks[path.id].base==unit.job,"Visual profiles agree with actual training eligibility")
   var promoted=unit.duplicate(true);promoted.promotion=path.id
   var actor=fighters.build(stage,promoted,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
   assert(actor.get_meta("promotion_look")==path.id,"Every recruit receives its selected branch silhouette")
   assert(actor.rest==base.rest and actor.kind==base.kind and actor.mounted==base.mounted,"Clothing leaves rig proportions, weapon ownership and mounts intact")
   assert(actor.bone("Head").get_meta("hair_style")==base.bone("Head").get_meta("hair_style") and actor.get_meta("costume_colors")==base.get_meta("costume_colors"),"Individual hair and clothing palette survive training")
   assert(actor.find_children("PaintedFace","MeshInstance3D",true,false).size()==1,"Training never masks or duplicates the recruit's painted face")
   var before=signature(actor)
   assert(before.count>base_shape.count,"Each branch adds actual costume geometry")
   if not seen.has(path.id):
    seen[path.id]=true;variants[path.id]=before
    var joints=actor.bones.duplicate();fighters.batch_rig(actor);var after=signature(actor)
    assert(before.count==after.count and before.sum.distance_to(after.sum)<.05 and before.uv.distance_to(after.uv)<.05,"Batching preserves the promoted costume's full geometry and UVs")
    for key in joints:assert(actor.bone(key)==joints[key],"Costume batching keeps all animation joints")
   for pose in ["idle","windup","strike","recover"]:
    base.pose(pose,.001);var motion=actor.pose(pose,.001);await motion.finished
    base.elapsed=.2;actor.elapsed=.2;base._process(0);actor._process(0)
    for key in base.bones:assert(base.bone(key).global_transform.is_equal_approx(actor.bone(key).global_transform),"Added clothing cannot alter animation, planted feet or weapon sockets")
    assert(base.socket_position("projectile").distance_to(actor.socket_position("projectile"))<.0001,"Both costume branches use the original launch point")
   checked+=1;actor.queue_free();await process_frame
  base.queue_free();await process_frame
 assert(seen.size()==16 and checked==48,"Both branches cover all twenty-four recruits")
 for job in rules.content.classes:
  var choices=rules.promotions.filter(func(path):return path.base==job)
  var a=variants[choices[0].id];var b=variants[choices[1].id]
  assert(a.count!=b.count or a.sum.distance_to(b.sum)>.05,"Each base class has visibly different branch geometry")
 var invalid=rules.roster[0].duplicate(true);invalid.team="player";invalid.promotion="bastion"
 var actor=fighters.build(stage,invalid,Vector3.ZERO)
 assert(not actor.has_meta("promotion_look"),"Incompatible external preview data falls back to the base costume")
 actor.queue_free();await process_frame
 assert(rules.roster==original and rules.rng.state==rng,"Costume rendering never changes campaign progress or randomness")
 stage.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-costume-preview-save.json";root.add_child(app);await process_frame
 var roster=app.game.roster.duplicate(true);var state=app.game.rng.state
 for id in ["standard_bearer","star_sage","iron_lancer"]:
  var path=app.game.promotions.filter(func(value):return value.id==id)[0]
  var unit=app.game.roster.filter(func(value):return value.job==path.base)[0]
  app.confirm_promotion(unit,path);await process_frame
  var preview_button=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Preview outfit")[0]
  preview_button.pressed.emit();await process_frame
  assert(app.screen=="model" and app.preview_actor.get_meta("promotion_look")==id,"Training opens the actual branch costume before commitment")
  assert(app.preview_unit!=unit and app.game.roster==roster,"Preview uses an isolated unit copy and never grants training")
  var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;app._unhandled_input(escape)
  assert(app.screen=="promotion_confirm" and not app.preview_return.is_valid(),"Escape restores the same training decision and clears its callback")
 assert(app.game.rng.state==state and app.game.roster==roster,"Inspecting outfits never changes progression or combat randomness")
 app.show_model_view(app.game.roster[0]);app.close_model_view();assert(app.screen=="dossier","Ordinary model viewing still returns to the record")
 app.queue_free();await process_frame
 print("PASS: 48 promoted recruit looks, 16 branch profiles, personal identity, animated joint/socket equivalence, costume batching and read-only training previews")
 quit()
