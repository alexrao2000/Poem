extends RefCounted
# Original hair silhouettes follow each recruit's portrait identity. All pieces
# remain children of the head; loose lengths get a fixed-root motion joint.

static func build(painter,head,appearance,gold):
 var hair=Color(appearance.get("hair","623c31"));var style=appearance.get("hair_style","short")
 head.set_meta("hair_style",style)
 if style!="bald":
  if appearance.get("hair_fringe","")!="receding":
   painter.ellipsoid(head,Vector3(0,.085,.025),Vector3(.157,.145,.155),hair)
  else:
   painter.ellipsoid(head,Vector3(0,.055,.095),Vector3(.15,.125,.095),hair)
  if style=="curls":
   for i in range(13):
    var angle=i*TAU/13
    painter.ellipsoid(head,Vector3(cos(angle)*.13,.10+sin(i*2.4)*.045,sin(angle)*.12+.015),Vector3(.065,.075,.065),hair.lightened((i%3)*.025))
  else:
   fringe(painter,head,hair,appearance.get("hair_fringe","swept"))
 if style=="long":
  var lengths=[]
  for i in range(7):
   var x=(i-3)*.038
   lengths.append(painter.hair_lock(head,[Vector3(x,.1,.13),Vector3(x*1.2,-.1,.17),Vector3(x*1.3+.018*sin(i),-.32,.18),Vector3(x*1.25-.025*sin(i),-.55,.12)],.052,hair.lightened((i%3)*.025)))
  separate_lengths(head,lengths,Vector3(0,.1,.13),.075)
  for side in [-1,1]:
   painter.hair_lock(head,[Vector3(side*.13,.08,-.055),Vector3(side*.15,-.14,-.08),Vector3(side*.18,-.31,-.11),Vector3(side*.15,-.49,-.08)],.038,hair)
 elif style=="ponytail":
  painter.ellipsoid(head,Vector3(0,.10,.18),Vector3(.07,.055,.065),gold)
  var lengths=[]
  for i in range(5):
   var x=(i-2)*.025
   lengths.append(painter.hair_lock(head,[Vector3(x,.10,.18),Vector3(x*1.4,.0,.30),Vector3(x*1.6,-.24,.36),Vector3(x*1.3,-.51,.30)],.047,hair.lightened((i%3)*.025)))
  separate_lengths(head,lengths,Vector3(0,.1,.18),.14)
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

static func smooth_path(points: Array) -> Array:
 var result=[]
 for segment in range(points.size()-1):
  var a=points[segment];var b=points[segment+1]
  var before=points[maxi(0,segment-1)];var after=points[mini(points.size()-1,segment+2)]
  for sample in range(4):result.append(a.cubic_interpolate(b,before,after,sample/4.0))
 result.append(points[-1]);return result

static func separate_lengths(head: Node3D,pieces: Array,anchor: Vector3,strength: float):
 var fall=Node3D.new();fall.name="HairFall";head.add_child(fall);fall.position=anchor
 fall.set_meta("dynamic",true);fall.set_meta("sway_strength",strength)
 for piece in pieces:
  var original=piece.transform;piece.reparent(fall,false)
  piece.transform=Transform3D(Basis.IDENTITY,-anchor)*original
