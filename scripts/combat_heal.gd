extends Node3D
# Staff light follows resolved healing. Fixed paths keep the effect independent
# of combat RNG, and the arrival signal synchronizes the HP display with contact.
signal arrived
const Impact=preload("res://scripts/combat_impact.gd")
var origin=Vector3.ZERO
var destination=Vector3.ZERO
var trails: Array=[]
var rings: Array=[]
var motes: Array=[]
var amount: Label3D
var glow: MeshInstance3D
var motion: Tween

func light(size_value: float,color: Color) -> MeshInstance3D:
 var mesh=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2.ONE*size_value;mesh.mesh=quad
 var material=Impact.accent_material();material.albedo_texture=Impact.radial_texture()
 material.albedo_color=color;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
 mesh.material_override=material;add_child(mesh);return mesh

func flight_point(progress: float,strand=0) -> Vector3:
 var t=clampf(progress,0,1);var arc=sin(t*PI)
 return origin.lerp(destination,t)+Vector3(0,arc*(.24+sin(t*TAU+strand*TAU/3)*.10),arc*cos(t*TAU+strand*TAU/3)*.16)

func play(from: Vector3,to: Vector3,ground: Vector3,healing: int) -> Tween:
 name="CombatHeal";origin=from;destination=to
 for strand in range(3):
  for step in range(7):
   var mote=light(.18-step*.018,Color("e5efbd") if strand==0 else Color("86e2b9"))
   trails.append({"node":mote,"strand":strand,"step":step})
 for i in range(2):
  var ring=MeshInstance3D.new();var shape=TorusMesh.new();shape.inner_radius=.42;shape.outer_radius=.46;shape.rings=32;shape.ring_segments=8;ring.mesh=shape
  var material=Impact.accent_material();material.albedo_color=Color("a4e8c2") if i==0 else Color("eee5b9");ring.material_override=material
  add_child(ring);ring.position=to_local(ground+Vector3.UP*(.06 if i==0 else .45));ring.hide();rings.append(ring)
 glow=light(1.1,Color("a0e6c0"));glow.position=to_local(to);glow.hide()
 for i in range(12):
  var mote=light(.10 if i%3 else .15,Color("ebf4d3"));mote.hide();motes.append(mote)
 amount=Label3D.new();amount.name="Recovery";amount.text="+"+str(healing);amount.font_size=80;amount.pixel_size=.0055
 amount.billboard=BaseMaterial3D.BILLBOARD_ENABLED;amount.modulate=Color("c6f6d2");amount.outline_modulate=Color("263e36");amount.outline_size=14;amount.no_depth_test=true
 add_child(amount);amount.hide()
 travel(0)
 motion=create_tween();motion.tween_method(travel,0.0,1.0,.32)
 motion.tween_callback(func():
  for entry in trails:entry.node.hide()
  bloom(0);arrived.emit())
 motion.tween_method(bloom,0.0,1.0,.65)
 motion.finished.connect(queue_free)
 return motion

func travel(progress: float):
 for entry in trails:
  var t=progress-entry.step*.025
  entry.node.visible=t>=0
  entry.node.position=to_local(flight_point(maxf(0,t),entry.strand))
  entry.node.material_override.albedo_color.a=(1.0-entry.step*.10)*minf(1,progress*8+.2)

func bloom(progress: float):
 var envelope=sin(PI*minf(progress*1.6,1))
 for i in range(rings.size()):
  var ring=rings[i];ring.show();ring.scale=Vector3.ONE*(.7+progress*(.7 if i==0 else .4))
  ring.material_override.albedo_color.a=(1-progress)*.8
 glow.show();glow.scale=Vector3.ONE*(.65+progress*.65);glow.material_override.albedo_color.a=envelope*.55
 for i in range(motes.size()):
  var t=fposmod(progress+float(i)/motes.size(),1.0);var angle=i*2.39996+progress*.7
  motes[i].show();motes[i].position=to_local(destination+Vector3(cos(angle)*.4,(t-.5)*1.1,sin(angle)*.4))
  motes[i].material_override.albedo_color.a=sin(t*PI)*(1-progress)
 amount.show();amount.position=to_local(destination+Vector3.UP*(.5+progress*.45));amount.modulate.a=1-smoothstep(.65,1.0,progress)
