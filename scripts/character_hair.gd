extends RefCounted
# Original hair silhouettes follow each recruit's portrait identity. All pieces
# remain children of the head; loose lengths get a fixed-root motion joint.
const CAP_CENTER=Vector3(0,.085,.025)
const CAP_RADII=Vector3(.157,.145,.155)
const BRAID_ROWS=24
const BRAID_SIDES=6
static var braid_mesh: ArrayMesh

static func build(painter,head,appearance,gold):
 var hair=Color(appearance.get("hair","623c31"));var style=appearance.get("hair_style","short")
 head.set_meta("hair_style",style)
 if style!="bald":
  if appearance.get("hair_fringe","")!="receding":
   painter.ellipsoid(head,CAP_CENTER,CAP_RADII,hair)
  else:
   painter.ellipsoid(head,Vector3(0,.055,.095),Vector3(.15,.125,.095),hair)
  if style=="curls":
   for i in range(13):
    var angle=i*TAU/13
    painter.ellipsoid(head,Vector3(cos(angle)*.13,.10+sin(i*2.4)*.045,sin(angle)*.12+.015),Vector3(.065,.075,.065),hair.lightened((i%3)*.025))
  else:
   fringe(painter,head,hair,appearance.get("hair_fringe","swept"))
 if style=="long":
  if appearance.get("temple_braid",false):
   var material=painter.geo.material(hair.lightened(.095)).duplicate()
   material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
   material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
   material.set_meta("no_character_outline",true)
   painter.geo.mesh(head,temple_braid(),Vector3.ZERO,Vector3.ONE,material).name="TempleBraid"
  var lengths=[]
  for i in range(7):
   var x=(i-3)*.038
   lengths.append(painter.hair_lock(head,[Vector3(x,.1,.13),Vector3(x*1.2,-.1,.17),Vector3(x*1.3+.018*sin(i),-.32,.18),Vector3(x*1.25-.025*sin(i),-.55,.12)],.052,hair.lightened((i%3)*.025)))
  separate_lengths(head,lengths,Vector3(0,.1,.13),.075)
  for side in [-1,1]:
   painter.hair_lock(head,[Vector3(side*.13,.08,-.055),Vector3(side*.15,-.14,-.08),Vector3(side*.18,-.31,-.11),Vector3(side*.15,-.49,-.08)],.038,hair)
 elif style=="ponytail":
  var rise=float(appearance.get("ponytail_rise",0.0))
  var root=Vector3(0,.10+rise,.18-rise*.18)
  var tie_size=Vector3(.07,.055,.065)-Vector3(.12,.18,.20)*rise
  var tie=painter.ellipsoid(head,root,tie_size,Color(appearance.get("hair_tie",gold)))
  tie.name="PonytailTie"
  var lengths=[]
  for i in range(5):
   var x=(i-2)*.025
   var path=[root+Vector3(x,0,0),Vector3(x*1.4,rise*1.9,.30),
    Vector3(x*1.6,-.24+rise*1.4,.36-rise*.12),Vector3(x*1.3,-.51+rise,.30-rise*.08)]
   if rise>0:path=smooth_path(path,2)
   lengths.append(painter.hair_lock(head,path,.047,hair.lightened((i%3)*.025)))
  separate_lengths(head,lengths,root,.14)
 elif style in ["braid","side_braid"]:
  var front=style=="side_braid"
  var lengths=[]
  for i in range(9):
   var t=i/8.0;var x=.15 if front else sin(i*PI*.5)*.026
   var z=-.10-t*.08 if front else .17+sin(t*PI)*.10
   var plait=painter.ellipsoid(head,Vector3(x,.04-t*.58,z),Vector3(.067-t*.025,.055,.055),hair.lightened((i%2)*.035));plait.rotation.z=.42 if i%2 else -.42
   lengths.append(plait)
  lengths.append(painter.ellipsoid(head,Vector3(.15 if front else 0,-.51,-.18 if front else .18),Vector3(.045,.025,.04),gold))
  separate_lengths(head,lengths,Vector3(.15 if front else 0,.04,-.10 if front else .17),.06 if front else .10)
 elif style=="bun":
  painter.ellipsoid(head,Vector3(0,-.015,.19),Vector3(.105,.11,.09),hair)
  for i in range(5):
   var angle=i*TAU/5
   painter.ellipsoid(head,Vector3(cos(angle)*.065,-.015+sin(angle)*.07,.245),Vector3(.045,.045,.025),hair.lightened(.04))
  painter.ellipsoid(head,Vector3(.095,.015,.19),Vector3(.025,.025,.025),gold)
 elif style in ["beard","bald"]:
  var beard=preload("res://scripts/character_beard.gd").mesh(appearance.get("beard_style","full"))
  var piece=painter.geo.mesh(head,beard,Vector3.ZERO,Vector3.ONE,painter.geo.material(hair));piece.name="Beard"

static func braid_direction(t: float) -> Vector3:
 var angle=lerpf(.32,2.12,t)
 var elevation=lerpf(1.01,.29,t)
 return Vector3(-sin(angle)*cos(elevation),sin(elevation),-cos(angle)*cos(elevation))

static func temple_braid() -> ArrayMesh:
 if braid_mesh!=null:return braid_mesh
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Three narrow strands weave around an arc on the crown. Both ends taper
 # into the existing hair cap so the braid follows the head as one piece.
 for strand in range(3):
  var rings=[]
  for row in range(BRAID_ROWS+1):
   var t=float(row)/BRAID_ROWS
   var direction=braid_direction(t)
   var normal=(direction/CAP_RADII).normalized()
   var tangent=(braid_direction(t+.01)-braid_direction(t-.01))*CAP_RADII
   var lateral=normal.cross(tangent).normalized()
   var blend=smoothstep(0,.18,t)*smoothstep(0,.18,1-t)
   var wave=TAU*(t*3.1+strand/3.0)
   var center=CAP_CENTER+direction*CAP_RADII+normal*lerpf(-.014,.013,blend)
   center+=(lateral*sin(wave)*.014+normal*cos(wave)*.008)*blend
   var ring=[]
   for side in BRAID_SIDES:
    var angle=TAU*side/BRAID_SIDES
    var radial=lateral*cos(angle)+normal*sin(angle)
    ring.append([center+radial*lerpf(.003,.0085,blend),radial])
   rings.append(ring)
  var shade=[.76,.89,1.0][strand]
  surface.set_color(Color(shade,shade,shade))
  for row in range(BRAID_ROWS):
   for side in BRAID_SIDES:
    var next=(side+1)%BRAID_SIDES
    var corners=[rings[row][side],rings[row][next],rings[row+1][next],rings[row+1][side]]
    var order=[0,1,2,0,2,3]
    if (corners[1][0]-corners[0][0]).cross(corners[2][0]-corners[0][0]).dot(corners[0][1])>0:
     order=[0,2,1,0,3,2]
    for index in order:
     surface.set_normal(corners[index][1]);surface.add_vertex(corners[index][0])
 braid_mesh=surface.commit()
 return braid_mesh

static func fringe(painter,head,color,style):
 head.set_meta("hair_fringe",style)
 for i in range(7):
  var points=[];var radius=.027
  if style=="parted":
   var side=-1 if i<4 else 1;var index=i if i<4 else i-4
   points=[Vector3(side*.018,.19-index*.004,-.045),Vector3(side*(.055+index*.018),.155-index*.012,-.125),Vector3(side*(.108+index*.012),.095-index*.014,-.14),Vector3(side*(.14+index*.008),.025-index*.017,-.065)]
  elif style=="tousled":
   var x=(i-3)*.034;var length=.019 if i%2==0 else -.005
   points=[Vector3(x*.7,.19+length,-.025),Vector3(x+.012,.15+length,-.10),Vector3(x-.018,.085+length,-.159),Vector3(x-.026,.060+length,-.146)];radius=.026
  elif style=="cropped":
   var x=(i-3)*.038
   points=[Vector3(x*.85,.17,-.025),Vector3(x,.145+sin(i)*.01,-.075),Vector3(x+.006,.105,-.12),Vector3(x-.005,.085,-.13)];radius=.023
  elif style=="receding":
   var side=-1 if i<4 else 1;var index=i if i<4 else i-4
   points=[Vector3(side*(.09+index*.012),.14-index*.012,.025),Vector3(side*(.14+index*.006),.07-index*.012,.02),Vector3(side*.155,-.005-index*.008,.045)];radius=.020
  elif i<5:
   points=[Vector3(.055,.17,-.09),Vector3(-.055-i*.015,.13-i*.008,-.13),Vector3(-.105-i*.012,.04-i*.012,-.10),Vector3(-.13-i*.008,-.045-i*.009,-.06)]
  else:
   var index=i-5
   points=[Vector3(.07,.16,-.08),Vector3(.12+index*.02,.08,-.11),Vector3(.14+index*.015,-.05,-.06)];radius=.03
  var lock=painter.hair_lock(head,smooth_path(points),radius,color.lightened((i%3)*.025));lock.name="Fringe"+str(i)

static func smooth_path(points: Array,subdivisions=4) -> Array:
 var result=[]
 for segment in range(points.size()-1):
  var a=points[segment];var b=points[segment+1]
  var before=points[maxi(0,segment-1)];var after=points[mini(points.size()-1,segment+2)]
  for sample in range(subdivisions):result.append(a.cubic_interpolate(b,before,after,float(sample)/subdivisions))
 result.append(points[-1]);return result

static func separate_lengths(head: Node3D,pieces: Array,anchor: Vector3,strength: float):
 var fall=Node3D.new();fall.name="HairFall";head.add_child(fall);fall.position=anchor
 fall.set_meta("dynamic",true);fall.set_meta("sway_strength",strength)
 for piece in pieces:
  var original=piece.transform;piece.reparent(fall,false)
  piece.transform=Transform3D(Basis.IDENTITY,-anchor)*original
