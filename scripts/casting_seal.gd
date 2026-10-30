extends RefCounted
# Original elemental seals are thin ground-plane strokes with transparent edges.
# Immutable geometry is shared; charge strength and release own each material.

const Spell=preload("res://scripts/combat_spell.gd")
static var meshes={}

static func shape(folio: String) -> ArrayMesh:
 if meshes.has(folio):return meshes[folio]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var colors=Spell.palette(folio)
 for i in range(64):
  var angle=i*TAU/64;var next=(i+1)*TAU/64
  stroke(surface,polar(angle,.56),polar(next,.56),.008,colors.accent)
  if i%16<12:stroke(surface,polar(angle,.65),polar(next,.65),.005,colors.wake)
 for i in range(4):
  var angle=i*TAU/4
  stroke(surface,polar(angle,.25),polar(angle+PI*.5,.25),.009,colors.core)
  stroke(surface,polar(angle,.61),polar(angle,.69),.012,colors.core)
 var count=3 if folio=="ember" else 4 if folio=="gale" else 6
 for i in range(count):
  var angle=i*TAU/count+PI*.25
  var axis=polar(angle,1);var tangent=Vector3(-axis.z,0,axis.x)
  if folio=="ember":
   var tip=axis*.50;var left=axis*.32+tangent*.08;var right=axis*.32-tangent*.08
   stroke(surface,left,tip,.01,colors.accent);stroke(surface,tip,right,.01,colors.core)
   stroke(surface,right,left,.006,colors.wake)
  elif folio=="gale":
   for offset in [-.035,.035]:
    var center=axis*(.40+offset)
    stroke(surface,center-tangent*.08-axis*.025,center+tangent*.045,.008,colors.accent)
    stroke(surface,center+tangent*.045,center-tangent*.005+axis*.05,.008,colors.core)
  else:
   var points=[axis*.50-tangent*.025,axis*.41+tangent*.025,axis*.41-tangent*.025,axis*.30+tangent*.025]
   for j in range(3):stroke(surface,points[j],points[j+1],.009,colors.core if j==1 else colors.accent)
 var mesh=surface.commit();meshes[folio]=mesh;return mesh

static func polar(angle: float,radius: float) -> Vector3:
 return Vector3(cos(angle)*radius,0,sin(angle)*radius)

static func stroke(surface: SurfaceTool,a: Vector3,b: Vector3,width: float,color: Color):
 var side=(b-a).normalized().cross(Vector3.UP)*width
 for sign_value in [-1,1]:
  var vertices=[a,b,b+side*sign_value,a+side*sign_value]
  for index in [0,1,2,0,2,3]:
   surface.set_normal(Vector3.UP)
   surface.set_color(Color(color,0.0 if index>=2 else .8))
   surface.add_vertex(vertices[index])
