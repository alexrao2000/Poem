extends Node3D
## A small elemental gathering follows the casting socket through anticipation.
## Release fixes it in world space and dissipates it as the projectile leaves.
const Spell=preload("res://scripts/combat_spell.gd")
const Seal=preload("res://scripts/casting_seal.gd")
const Impact=preload("res://scripts/combat_impact.gd")
var caster: Node3D
var spell=""
var strength=0.0
var age=0.0
var released=false
var motes: Array=[]
var ring: MeshInstance3D
var seal: MeshInstance3D
var floor_position=Vector3.ZERO
var floor_basis=Basis.IDENTITY
var motion: Tween

func begin(actor: Node3D,folio: String,duration: float):
 name="CombatCharge";caster=actor;spell=folio
 var colors=Spell.palette(spell)
 ring=MeshInstance3D.new();ring.name="GatheringRing"
 var shape=TorusMesh.new();shape.inner_radius=.18;shape.outer_radius=.19;shape.rings=24;shape.ring_segments=4
 ring.mesh=shape;ring.rotation.x=PI/2;ring.material_override=material(colors.accent);add_child(ring)
 for i in range(3):
  var mote=MeshInstance3D.new();mote.name="Element"+str(i)
  if spell=="gale":mote.mesh=Spell.crescent()
  elif spell=="thunder":mote.mesh=Spell.bolt()
  else:
   var ember=SphereMesh.new();ember.radius=.045;ember.height=.09;ember.radial_segments=8;ember.rings=4;mote.mesh=ember
  mote.material_override=material(colors.core if i==0 else colors.wake);add_child(mote);motes.append(mote)
 seal=MeshInstance3D.new();seal.name="CastingSeal";seal.mesh=Seal.shape(spell)
 seal.material_override=material(Color.WHITE);add_child(seal)
 for node in [ring,seal]+motes:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _process(0)
 motion=create_tween();motion.tween_property(self,"strength",1.0,maxf(duration,.01)).set_trans(Tween.TRANS_SINE)

static func material(color: Color) -> StandardMaterial3D:
 var result=Impact.accent_material();result.albedo_color=color;return result

func release():
 if released:return
 _process(0);released=true
 if motion and motion.is_valid():motion.kill()
 motion=create_tween();motion.tween_property(self,"strength",0.0,.12);motion.tween_callback(queue_free)

func _process(dt):
 if ring==null:return
 if not released:
  if not is_instance_valid(caster):queue_free();return
  global_position=caster.socket_position("projectile")
  global_basis=caster.global_basis.orthonormalized()
  floor_position=caster.global_position+Vector3.UP*.025
  var forward=-caster.global_basis.z;forward.y=0
  floor_basis=Basis.looking_at(forward.normalized(),Vector3.UP) if forward.length_squared()>.00001 else Basis.IDENTITY
 age+=dt
 var extent=.72+strength*.28 if not released else 1.0+(1.0-strength)*.14
 var turn=age*.12
 seal.global_transform=Transform3D(floor_basis*Basis(Vector3.UP,turn)*Basis.from_scale(Vector3(extent,1,extent)),floor_position)
 seal.material_override.albedo_color.a=strength*.52
 ring.scale=Vector3.ONE*(.55+strength*.45)
 ring.material_override.albedo_color.a=strength*.35
 for i in range(motes.size()):
  var phase=age*4.0+i*TAU/3
  var radius=.19*(.4+strength*.6)
  var mote=motes[i]
  mote.position=Vector3(cos(phase)*radius,sin(phase)*radius,-.025)
  mote.rotation=Vector3(0,0,phase)
  var size_value=(.35 if spell=="gale" else .16 if spell=="thunder" else 1.0)*(.5+strength*.5)
  mote.scale=Vector3.ONE*size_value
  if spell=="ember":mote.scale.y*=1.8
  mote.material_override.albedo_color.a=strength*.7
