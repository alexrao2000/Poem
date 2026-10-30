extends SceneTree
const Drift=preload("res://scripts/ambient_drift.gd")
const Rules=preload("res://scripts/rules.gd")
const Scenery=preload("res://scripts/scenery.gd")

func _initialize():call_deferred("run")

func run():
 var game=Rules.new();var rng=game.rng.state;var saved=game.save_data("camp").duplicate(true)
 var host=Node3D.new();root.add_child(host)
 for theme in Drift.THEMES:
  for arena in [false,true]:
   var a=Drift.new();host.add_child(a);a.configure(theme,Vector3(24,4,18),arena,17);a.set_process(false)
   var b=Drift.new();host.add_child(b);b.configure(theme,Vector3(24,4,18),arena,17);b.set_process(false)
   assert(a.states==b.states,"Chapter atmosphere has a reproducible local seed")
   assert(a.get_child_count()==1 and a.cloud.multimesh.instance_count<=32,"All drift particles share one bounded instanced mesh")
   assert(a.cloud.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and a.find_children("*","Light3D",true,false).is_empty(),"Atmosphere adds no lights or shadows")
   assert(a.cloud.material_override.disable_fog,"Fog cannot reveal fully faded particle quads")
   if a.kind!="leaves":assert(a.cloud.material_override.billboard_keep_scale,"Camera-facing particles retain their small instance scales")
   if theme in ["forest","road"]:assert(a.kind=="leaves" and a.cloud.multimesh.mesh is ArrayMesh)
   elif theme in ["furnace","engine"]:assert(a.kind=="embers" and a.cloud.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD)
   for state in a.states:
    for phase in [0.0,.1,.25,.5,.75,.9,1.0]:
     var point=a.particle_position(state,phase)
     assert(a.cloud.multimesh.custom_aabb.has_point(point),"Particle paths remain inside their culling volume throughout a loop")
   var initial=a.cloud.multimesh.buffer
   a._process(.6)
   assert(a.cloud.multimesh.buffer!=initial,"Visible atmosphere actually uploads changed instance data")
   var buffer=a.cloud.multimesh.buffer
   assert(buffer.size()==a.states.size()*16,"Bulk upload contains every matrix and color")
   for i in range(a.states.size()):
    var offset=i*16
    var basis=Basis(Vector3(buffer[offset],buffer[offset+4],buffer[offset+8]),Vector3(buffer[offset+1],buffer[offset+5],buffer[offset+9]),Vector3(buffer[offset+2],buffer[offset+6],buffer[offset+10]))
    var position=Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
    var transform=Transform3D(basis,position)
    var bounds=transform*a.cloud.multimesh.mesh.get_aabb()
    assert(a.cloud.multimesh.custom_aabb.encloses(bounds),"Actual uploaded instance geometry stays within the culling volume")
    assert(basis.determinant()>0 and basis.orthonormalized().determinant()>.99,"Packed rows retain a valid rotated/scaled basis")
    assert(buffer[offset+15]>=0 and buffer[offset+15]<=.7,"Uploaded opacity remains restrained")
   host.hide();var elapsed=a.elapsed;var held=a.cloud.multimesh.buffer;a._process(1)
   assert(a.elapsed==elapsed and a.cloud.multimesh.buffer==held,"Hidden map/arena atmosphere suspends updates")
   host.show();a._process(.1);assert(a.elapsed>elapsed)
   # Every loop starts and ends transparent, rather than popping into view.
   var state=a.states[0]
   for phase in [0.0,.001,.999]:
    a.elapsed=(1-state.phase+phase)*state.life;a.update_particles()
    assert(a.cloud.multimesh.buffer[15]<.01,"Loop boundaries fade before particles recycle")
   a.queue_free();b.queue_free();await process_frame
 assert(game.rng.state==rng and game.save_data("camp")==saved,"Atmosphere never consumes campaign RNG or modifies saves")
 var scenery=Scenery.new()
 for chapter in range(12):
  game.chapter=chapter
  var map=Node3D.new();host.add_child(map);scenery.landscape(map,game)
  var atmosphere=map.get_node("AmbientDrift")
  assert(atmosphere.cloud.multimesh.instance_count>0 and atmosphere.position.y==0,"Every tactical chapter attaches its atmosphere after scenery batching")
  var arena=Node3D.new();host.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),{"environment":game.info().environment})
  var closeup=arena.get_node("AmbientDrift")
  assert(closeup.kind==atmosphere.kind and closeup.position.x==35,"Close-up arena retains the chapter atmosphere around its real stage origin")
  var reference=weakref(atmosphere);map.queue_free();arena.queue_free();await process_frame
  assert(reference.get_ref()==null,"Leaving a chapter releases its instanced atmosphere")
 host.queue_free();await process_frame
 print("PASS: twelve chapter atmospheres, 24 map/arena configurations, bounded instances, deterministic motion, hidden suspension, fade loops and cleanup")
 quit()
