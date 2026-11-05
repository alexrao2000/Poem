extends Node3D
# Local debug target follows the rotated model; it never enters the simulation.
var actor: Node3D
var parts=[]
var selected=0
var action="strike"

func _init():
 name="StudyContactTarget"
 var material=StandardMaterial3D.new();material.albedo_color=Color("eac47a");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 var ring=MeshInstance3D.new();var shape=TorusMesh.new();shape.inner_radius=.075;shape.outer_radius=.088;shape.rings=24;shape.ring_segments=6
 ring.mesh=shape;ring.rotation.x=PI/2;add_child(ring);parts.append(ring)
 for dimensions in [Vector3(.19,.008,.008),Vector3(.008,.19,.008)]:
  var cross=MeshInstance3D.new();var box=BoxMesh.new();box.size=dimensions;cross.mesh=box;add_child(cross);parts.append(cross)
 for part in parts:part.material_override=material;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;part.visible=false

func configure(subject: Node3D):actor=subject

func set_action(key: String):
 action=key;choose(selected)

func choose(index: int):
 selected=clampi(index,0,2)
 var distance=4.0 if action.begins_with("throw") else preload("res://scripts/fighter_actor.gd").melee_spacing(actor.kind)
 position=Vector3(0,1.1 if selected==1 else 1.85,-distance)
 for part in parts:part.visible=selected>0
 if selected>0:actor.aim_at(global_position)
 else:
  actor.clear_aim()

func _process(_delta):
 if selected>0 and is_instance_valid(actor):actor.aim_at(global_position)
