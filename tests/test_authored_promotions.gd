extends SceneTree
# Verify fitted patterns independently before campaign selection.
# Godot stores each skin weight as a truncated uint16; allow four quantization
# steps after mesh commit (4.5.1 servers/rendering_server.cpp, ARRAY_WEIGHTS).
const Vertices=preload("helpers/authored_vertices.gd")
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
var pairs=[["lyra","vanguard"],["cassian","vanguard_male"],["rhea","vanguard"]]
var promotion_ids=["standard_bearer","dawnblade"]
func _initialize():call_deferred("run")
func sample(actor,key: String,fraction: float):
 for listener in actor.pose_listeners:listener.combat_pose(key)
 var mapping=actor.poses[key];actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
 actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var count=0;var falls=0;var lowest=INF;var saved=rules.save_data("camp").duplicate(true);var rng=rules.rng.state
 for pair in pairs:
  for promotion_id in promotion_ids:
   var unit=rules.roster.filter(func(value):return value.id==pair[0])[0].duplicate(true);unit.team="player";unit.promotion=promotion_id
   var spec=studies[pair[1]].duplicate(true);spec.appearance="Identity";var models=Models.new("");models.catalog={"characters":{unit.id:spec}}
   var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null and models.issues.is_empty());await process_frame;actor.set_process(false)
   var identity=actor.model.get_node("Identity");var costume=identity.promotion;var rig=actor.model.get_node("Rig/Armature/Skeleton3D")
   assert(identity.identity==unit.id and identity.mantle==null and costume.id==promotion_id and actor.model.get_meta("promotion_look")==promotion_id)
   var look=load("res://scripts/promotion_costume.gd").looks[promotion_id]
   assert(costume.anchors.size()==5 and costume.panels.size()==(2 if look.has("tabard") else 4))
   assert(costume.anchors[0].get_node("Pattern/PromotionCostume").get_meta("components")==look.keys())
   for panel in costume.panels:
    var arrays=panel.mesh.surface_get_arrays(0);assert(arrays[Mesh.ARRAY_VERTEX].size()>50 and panel.skin.get_bind_count()==5 and panel.get_node(panel.skeleton)==rig)
    for vertex in range(arrays[Mesh.ARRAY_VERTEX].size()):
     var mass=0.0
     for influence in range(4):
      var at=vertex*4+influence;assert(arrays[Mesh.ARRAY_BONES][at]>=0 and arrays[Mesh.ARRAY_BONES][at]<5);mass+=arrays[Mesh.ARRAY_WEIGHTS][at]
     assert(absf(mass-1)<4.0/65535+.000001,"Committed skin weights remain normalized within their stored precision")
   for material in costume.surfaces:
    assert(material.next_pass!=null,"Promotion materials receive the same private outline treatment")
   var cache=Vertices.prepare(actor).filter(func(entry):
    var material=entry[0].get_active_material(0)
    return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
   identity.set_process(false);identity.hair_motion.update(0,"down",2)
   for step in range(129):
    sample(actor,"down",step/128.0);var floor=Vertices.minimum(actor,cache)-actor.global_position.y;lowest=minf(lowest,floor)
    assert(floor>.010,"Complete promoted outfit clears the floor without changing the existing source fall: %s %s %s"%[unit.id,promotion_id,floor]);falls+=1
   var resting=rig.get_bone_rest(rig.find_bone("root")).origin
   for key in ["idle","advance","windup","strike","recover","hit","evade","victory"]:
    for step in range(17):
     sample(actor,key,step/16.0)
     assert(rig.get_bone_pose_position(rig.find_bone("root")).is_equal_approx(resting))
     var points=Vertices.prepare(actor).filter(func(entry):return entry[0] in costume.panels)
     assert(is_finite(Vertices.minimum(actor,points)))
     for anchor in costume.anchors:assert(anchor.transform.is_equal_approx(rig.get_bone_global_pose(rig.find_bone(anchor.bone_name))),"Promotion plates follow the actual source joint")
     count+=1
   actor.position.y=1.1;costume._process(0)
   for material in costume.surfaces:assert(is_equal_approx(material.get_shader_parameter("cloth_floor_y"),1.118))
   var other=models.build(world,unit,Vector3.ZERO);await process_frame;assert(other.model.get_node("Identity").promotion.surfaces[0]!=costume.surfaces[0]);other.queue_free();await process_frame
   var defeat=load("res://scripts/combat_defeat.gd").new();world.add_child(defeat);defeat.begin(actor);defeat.apply_visibility(.35)
   for material in costume.surfaces:assert(is_equal_approx(material.get_shader_parameter("defeat_visibility"),.35))
   defeat.queue_free();actor.queue_free();await process_frame
 assert(rules.save_data("camp")==saved and rules.rng.state==rng)
 world.queue_free();await process_frame
 print("PASS: six fitted ",promotion_ids," outfits, subdivided normalized panel skins, ",falls," complete falling poses with floor ",lowest," m, ",count," standing/travel/action joint samples, reset root, relocated cloth floor, private outlines/fades and campaign/RNG isolation")
 quit()
