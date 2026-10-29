extends Node3D
# Original arrow, thrown spear and spell presentations follow an explicit arc.
# The tip tracks its flight tangent, including different mounted target heights.
const Spell=preload("res://scripts/combat_spell.gd")
var origin=Vector3.ZERO
var destination=Vector3.ZERO
var arc=0.0
var progress=0.0
var kind="bow"
var spell=""
var body: Node3D
var trail: Array=[]
var motion: Tween

func launch(from: Vector3,to: Vector3,weapon: String,duration=.23,spell_id="") -> Tween:
 name="CombatProjectile";origin=from;destination=to;kind=weapon;spell=spell_id
 arc=.14 if kind=="bow" else .08 if kind=="lance" else .04
 body=Node3D.new();body.name="FlightBody";add_child(body)
 if kind in ["bow","lance"]:
  var length=.72 if kind=="bow" else 1.3
  var shaft=CylinderMesh.new();shaft.height=length;shaft.top_radius=.012 if kind=="bow" else .021;shaft.bottom_radius=shaft.top_radius;shaft.radial_segments=8
  var pole=piece(body,shaft,Color("78604a"));pole.rotation.x=PI/2
  var point=CylinderMesh.new();point.height=.15 if kind=="bow" else .24;point.bottom_radius=.04 if kind=="bow" else .065;point.top_radius=0;point.radial_segments=4
  var tip=piece(body,point,Color("d5dce1"));tip.name="Tip";tip.position.z=-length*.5;tip.rotation.x=-PI/2
  if kind=="bow":
   for angle in [0,TAU/3,TAU*2/3]:
    var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p in [Vector3(0,0,.20),Vector3(.075,0,.34),Vector3(0,0,.34)]:surface.add_vertex(p)
    surface.generate_normals()
    var feather=piece(body,surface.commit(),Color("c5d1c9"));feather.rotation.z=angle
 else:
  var colors=Spell.palette(spell)
  var orb=SphereMesh.new();orb.radius=.14;orb.height=.28;orb.radial_segments=12;orb.rings=6
  if spell=="gale":
   for i in range(3):
    var ring=piece(body,Spell.crescent(),colors.accent,true);ring.name="WindCrescent"+str(i)
    ring.rotation=Vector3(.5,0,i*TAU/3);ring.position.z=(i-1)*.08
  elif spell=="thunder":
   for i in range(2):
    var bolt=piece(body,Spell.bolt(),colors.core if i==0 else colors.accent,true);bolt.name="ThunderBolt"+str(i);bolt.rotation.z=i*PI/2
  else:
   var core=piece(body,orb,colors.core,true);core.name="EmberCore" if spell=="ember" else "SpellCore"
   core.scale=Vector3(.85,.85,1.45) if spell=="ember" else Vector3.ONE
  for i in range(6):
   var mote=piece(self,orb,colors.wake,true);mote.name="Wake"+str(i);trail.append(mote)
 _process(0)
 motion=create_tween();motion.tween_property(self,"progress",1.0,duration).set_trans(Tween.TRANS_LINEAR)
 motion.tween_callback(func():_process(0);queue_free())
 return motion

func point_at(t: float) -> Vector3:
 t=clampf(t,0,1)
 return origin.lerp(destination,t)+Vector3.UP*sin(t*PI)*arc

func _process(_dt):
 if body==null:return
 global_position=point_at(progress)
 var direction=destination-origin+Vector3.UP*cos(progress*PI)*PI*arc
 if direction.length_squared()>.0001:
  body.look_at(global_position+direction,Vector3.FORWARD if direction.normalized().cross(Vector3.UP).length_squared()<.001 else Vector3.UP)
 if kind=="magic" and spell=="gale":body.rotate_object_local(Vector3.FORWARD,progress*TAU*2)
 for i in range(trail.size()):
  var t=progress-(i+1)*.045
  trail[i].visible=t>=0
  trail[i].global_position=point_at(t)
  trail[i].scale=Vector3.ONE*(.65-i*.085)

static func piece(parent: Node3D,mesh: Mesh,color: Color,unlit=false) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=mesh
 var material=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.65
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 if unlit:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 node.material_override=material;parent.add_child(node);return node
