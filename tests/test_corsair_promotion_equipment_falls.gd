extends SceneTree
# Heavy props can change the floor-aware arm pose and its rigid shoulder armor.
const Vertices=preload("helpers/authored_vertices.gd")
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new()
 var models=load("res://scripts/debug_source_models.gd").new(["corsair_female","corsair_male"]);var count=0;var lowest=INF
 for id in ["mara","dax","hale"]:
  for promotion in ["stormbreaker","trailguard"]:
   for item in ["iron_axe","hatchet","great_axe","war_hammer"]:
    var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.promotion=promotion;unit.item=item
    var actor=models.build(world,unit,Vector3(35,.65,0));assert(actor!=null);await process_frame;actor.set_process(false)
    var identity=actor.model.get_node("Identity");identity.set_process(false);identity.hair_motion.update(0,"down",2)
    var cache=Vertices.prepare(actor).filter(func(entry):
     var material=entry[0].get_active_material(0)
     return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
    for listener in actor.pose_listeners:listener.combat_pose("down")
    var mapping=actor.poses.down;actor.player.get_animation(mapping.clip).loop_mode=Animation.LOOP_NONE
    for step in range(129):
     actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,step/128.0),true,true);actor.player.pause();actor.refresh_skeleton()
     var y=Vertices.minimum(actor,cache)-actor.global_position.y;lowest=minf(lowest,y)
     assert(y>.01,str([id,promotion,item,step,y]));count+=1
    await actor.pose("idle").finished
    var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var position=rig.get_bone_pose_position(rig.find_bone("root"))
    assert(position.is_equal_approx(Vector3.ZERO),str([id,promotion,item,"ready root",position]))
    actor.queue_free();await process_frame
 world.queue_free();await process_frame
 print("PASS: ",count," complete promoted Corsair falls with all four axes/hammers, rigid plates, private support and fall-to-idle resets; minimum ",lowest," m")
 quit()
