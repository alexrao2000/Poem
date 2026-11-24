extends "res://scripts/combat_heal.gd"
## A brief staff connection precedes the existing map recovery cue. Self-use
## items keep only the bloom. Shared staff light uses no gameplay random rolls.
const FLIGHT_TIME=.12
const BLOOM_TIME=.35

func cast(from: Vector3,to: Vector3,ground: Vector3,connection=true,crystal=TRAIL_FRINGE) -> Tween:
 name="MapHeal";origin=from;destination=to;global_basis=Basis.IDENTITY
 if connection:add_staff_trails(4,.13,.02,crystal)
 var ring=MeshInstance3D.new();ring.name="RecoveryRing"
 var shape=TorusMesh.new();shape.inner_radius=.28;shape.outer_radius=.32;shape.rings=24;shape.ring_segments=6;ring.mesh=shape
 var surface=Impact.accent_material();surface.albedo_color=Color("a4e8c2");surface.render_priority=1
 ring.material_override=surface;add_child(ring);ring.position=to_local(ground+Vector3.UP*.08);ring.hide();rings.append(ring)
 glow=light(.55,Color("a0e6c0"));glow.name="RecoveryGlow";glow.position=to_local(to);glow.hide()
 for mesh in find_children("*","MeshInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh.material_override.no_depth_test=true;mesh.material_override.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
  if mesh!=ring:mesh.material_override.render_priority=3
 travel(0)
 motion=create_tween();motion.tween_method(travel,0.0,1.0,FLIGHT_TIME)
 motion.tween_callback(func():
  for entry in trails:entry.node.hide()
  map_bloom(0);has_arrived=true;arrived.emit())
 motion.tween_method(map_bloom,0.0,1.0,BLOOM_TIME)
 motion.finished.connect(queue_free)
 return motion

func map_bloom(progress: float):
 var ring=rings[0];ring.show();ring.scale=Vector3.ONE*(1+progress*.7);ring.material_override.albedo_color.a=(1-progress)*.8
 glow.show();glow.scale=Vector3.ONE*(.65+progress*.65);glow.material_override.albedo_color.a=sin(PI*progress)*.4
