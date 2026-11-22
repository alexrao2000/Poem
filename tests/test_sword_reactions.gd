extends SceneTree
# Revised fighters hold the source clip's recoil segment instead of
# racing through its recovery. Sample actual fitted actors, both headings and
# every configured weapon/promotion; check backward displacement and grounded equipment.

const Models=preload("res://scripts/debug_source_models.gd")
const Enemies=preload("res://scripts/revised_enemy_models.gd")
const Vertices=preload("helpers/authored_vertices.gd")
var study_ids=["female","male","vanguard","vanguard_male"]
var jobs=["Vanguard","Duelist"]
var equipment={"sword":["iron_sword","dueling_sword","tempered_sword","estoc"]}
var expected_variants=80
func _initialize():call_deferred("run")
func endpoint(actor,key: String) -> Vector3:
 var motion=actor.pose(key,.12);motion.pause();motion.custom_step(.121)
 return actor.to_local(actor.socket_position("gaze"))
func run():
 var world=Node3D.new();root.add_child(world)
 var rules=load("res://scripts/rules.gd").new();var saved=rules.save_data("camp").duplicate(true);var random=rules.rng.state
 var models=Models.new(study_ids);var enemies=Enemies.new();var units=[]
 for source in rules.roster:
  if source.job not in jobs:continue
  var paths=[""];paths.append_array(rules.promotions.filter(func(path):return path.base==source.job).map(func(path):return path.id))
  for promotion in paths:
   var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;units.append(unit)
 for job in jobs:
  var unit=rules.roster.filter(func(value):return value.job==job)[0].duplicate(true);unit.id="reaction_enemy_"+job;unit.team="enemy";units.append(unit)
 var count=0;var minimum=INF;var retreat=INF;var samples=0
 for source in units:
  for item in equipment[source.weapon]:
   var unit=source.duplicate(true);unit.item=item
   var actor=(models if unit.team=="player" else enemies).build(world,unit,Vector3.ZERO)
   assert(actor!=null);await process_frame;actor.set_process(false)
   var spec=models.models.catalog.characters[unit.id] if unit.team=="player" else enemies.models.catalog.enemy_classes[unit.job]
   var grip=actor.model.get_node(NodePath(spec.equipment))
   var cache=Vertices.prepare(actor).filter(func(entry):return grip.is_ancestor_of(entry[0]))
   var source_clip=actor.player.get_animation("Hit_Chest")
   assert(actor.poses.hit.to==source_clip.length,"Ordinary reactions retain their full source interval")
   for facing in [-PI/2,PI/2]:
    actor.rotation.y=facing
    var ordinary=endpoint(actor,"hit");var critical=endpoint(actor,"critical_hit")
    retreat=minf(retreat,critical.z-ordinary.z)
    assert(critical.z>ordinary.z+.20,"Critical recoil remains visibly farther away from the opponent at the held endpoint")
    assert(actor.pose_name=="critical_hit" and not actor.player.is_playing())
    for step in range(13):
     var time=actor.poses.critical_hit.to*step/12.0
     actor.player.play("Hit_Chest",0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
     minimum=minf(minimum,Vertices.minimum(actor,cache));samples+=1
     assert(minimum>-.01,"Critical recoil retains the actual fitted weapon's floor clearance")
    var held=endpoint(actor,"critical_hit")
    for frame in range(2):await process_frame
    assert(actor.to_local(actor.socket_position("gaze")).distance_to(held)<.001,"Completed critical recoil holds until another pose takes over")
    await actor.pose("idle",.08).finished
    var ready=actor.to_local(actor.socket_position("gaze"));assert(ready.distance_to(held)>.10,"Ordinary recovery releases the held recoil")
   actor.queue_free();await process_frame;count+=1
 assert(count==expected_variants and samples==expected_variants*26 and models.models.issues.is_empty() and enemies.models.issues.is_empty())
 assert(rules.save_data("camp")==saved and rules.rng.state==random)
 world.queue_free();await process_frame
 print("PASS: ",count," fitted reaction variants, ",samples," source samples, both headings, full ordinary intervals, critical head retreat ",retreat," m, weapon floor ",minimum," m, held recoil/ready recovery and unchanged campaign/RNG")
 quit()
