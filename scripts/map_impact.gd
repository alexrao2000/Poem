extends Node3D
## Small contact accents share the combat palette and spark shapes. The map
## keeps its own single damage label; misses emit no impact or gameplay rolls.
const Impact=preload("res://scripts/combat_impact.gd")
const Spell=preload("res://scripts/combat_spell.gd")
var glow: MeshInstance3D
var burst: MeshInstance3D
var motion: Tween

func contact(point: Vector3,view: Camera3D,event: Dictionary,spell="") -> Tween:
 name="MapImpact";global_transform=Transform3D(view.global_basis.scaled(Vector3.ONE*(.55 if event.crit else .45)),point)
 var blocked=event.damage<=0
 glow=MeshInstance3D.new();glow.name="ContactGlow";add_child(glow)
 var quad=QuadMesh.new();quad.size=Vector2.ONE*(.5 if blocked else 1.3 if event.crit else .9);glow.mesh=quad
 var surface=overlay();surface.albedo_texture=Impact.radial_texture()
 surface.albedo_color=Color("9caab5") if blocked else Color("ffca76") if spell.is_empty() else Spell.palette(spell).accent
 glow.material_override=surface;glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 motion=create_tween().set_parallel(true)
 motion.tween_property(glow,"scale",Vector3.ONE*1.3,.16).from(Vector3.ONE*.4)
 motion.tween_property(surface,"albedo_color:a",0.0,.20)
 if not blocked:
  burst=MeshInstance3D.new();burst.name="CriticalForks" if event.crit else "Sparks";add_child(burst)
  burst.mesh=Impact.burst_mesh(event.crit,spell);burst.material_override=overlay();burst.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  motion.tween_property(burst,"scale",Vector3.ONE*1.1,.20).from(Vector3.ONE*.45)
  motion.tween_property(burst.material_override,"albedo_color:a",0.0,.20)
 motion.finished.connect(queue_free)
 return motion

static func overlay() -> StandardMaterial3D:
 var surface=Impact.accent_material();surface.no_depth_test=true;surface.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED;surface.render_priority=3
 return surface
