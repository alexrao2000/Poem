extends Node3D
# Original elemental silhouettes rise from the recipient's floor at contact.
# Cached colored ribbons use one additive draw per effect, no shadow casting,
# and a bounded presentation clock independent of the resolved combat result.

const Spell=preload("res://scripts/combat_spell.gd")
const DURATION=.46
static var meshes={}
var spell=""
var progress=0.0
var body: MeshInstance3D
var height_scale=1.0
var critical_scale=1.0

func begin(folio: String,ground: Vector3,contact_height: float,critical: bool,surface: StandardMaterial3D):
 name="ElementalBurst";spell=folio;global_position=ground;global_basis=Basis.IDENTITY
 height_scale=clampf(contact_height/1.1,.8,1.8);critical_scale=1.15 if critical else 1.0
 body=MeshInstance3D.new();body.name=folio.capitalize()+"Impact";body.mesh=shape(folio)
 body.material_override=surface;body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(body);apply_progress()

func _process(delta):
 if body==null:return
 progress=minf(1,progress+maxf(0,delta)/DURATION);apply_progress()
 if progress>=1:queue_free()

func apply_progress():
 var growth=1.0-pow(1.0-progress,3)
 var width=(.65+growth*.55)*critical_scale
 var height=(.65+growth*.45)*height_scale
 if spell=="gale":
  body.rotation.y=progress*TAU*.65
  width=(.7+growth*.5)*critical_scale;height=(.55+growth*.55)*height_scale
 elif spell=="thunder":width=critical_scale;height=height_scale
 body.scale=Vector3(width,height,width)
 body.material_override.albedo_color.a=pow(1.0-progress,1.3)*(.85 if spell=="thunder" else .7)

static func shape(folio: String) -> ArrayMesh:
 if meshes.has(folio):return meshes[folio]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var colors=Spell.palette(folio)
 if folio=="gale":
  for strand in range(3):
   for step in range(32):
    var a=wind_point(strand,step/32.0);var b=wind_point(strand,(step+1)/32.0)
    var wa=sin(step/32.0*PI)*.095;var wb=sin((step+1)/32.0*PI)*.095
    quad(surface,a-Vector3.UP*wa,a+Vector3.UP*wa,b+Vector3.UP*wb,b-Vector3.UP*wb,colors.core if strand==0 else colors.accent)
 elif folio=="thunder":
  var path=[Vector3(.08,2.7,0),Vector3(-.15,2.22,.035),Vector3(.13,1.77,-.025),Vector3(-.08,1.28,.015),Vector3(.11,.72,-.02),Vector3(0,.035,0)]
  for axis in [Vector3.RIGHT,Vector3.BACK]:
   for step in range(path.size()-1):
    strip(surface,path[step],path[step+1],axis,.033,.024,colors.core)
   for branch in range(3):
    var start=path[branch+1];var side=-1 if branch%2 else 1
    var elbow=start+Vector3(side*.35,-.23,.06);var end=elbow+Vector3(side*.18,-.34,-.10)
    strip(surface,start,elbow,axis,.022,.016,colors.accent)
    strip(surface,elbow,end,axis,.016,0,colors.accent)
 else:
  for tongue in range(7):
   var angle=tongue*TAU/7;var side=Vector3(cos(angle),0,sin(angle))
   var root=side*(.13 if tongue==0 else .32)
   var height=1.8 if tongue==0 else 1.2+(tongue%3)*.22
   for step in range(14):
    var t=step/14.0;var next=(step+1)/14.0
    var a=flame_point(root,side,t,height,tongue);var b=flame_point(root,side,next,height,tongue)
    var wa=.13*pow(1-t,.65);var wb=.13*pow(1-next,.65)
    var color=colors.core.lerp(colors.accent,t) if tongue%2==0 else colors.accent.lerp(colors.wake,t)
    strip(surface,a,b,side,wa,wb,color)
 var result=surface.commit();meshes[folio]=result;return result

static func wind_point(strand: int,t: float) -> Vector3:
 var angle=strand*TAU/3+t*TAU*1.15;var radius=.4+t*.15
 return Vector3(cos(angle)*radius,.08+t*1.65,sin(angle)*radius)

static func flame_point(root: Vector3,side: Vector3,t: float,height: float,tongue: int) -> Vector3:
 return root*(1-t*.7)+Vector3.UP*(.035+t*height)+side*sin(t*TAU+tongue*.7)*sin(t*PI)*.11

static func strip(surface: SurfaceTool,a: Vector3,b: Vector3,axis: Vector3,wa: float,wb: float,color: Color):
 quad(surface,a-axis*wa,a+axis*wa,b+axis*wb,b-axis*wb,color)

static func quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color):
 for points in [[a,b,c],[a,c,d]]:
  if (points[1]-points[0]).cross(points[2]-points[0]).length_squared()<1e-14:continue
  for point in points:surface.set_color(color);surface.add_vertex(point)
