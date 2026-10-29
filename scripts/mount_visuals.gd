extends RefCounted
# Original mounted silhouettes share the actor's existing joint batching. Coat
# palettes follow each rider's map artwork; head and tail remain articulated.

static func palette(id: String) -> Dictionary:
 return {
  "bram":{"coat":"8b5d43","mane":"392e29","muzzle":"665044"},
  "una":{"coat":"e5decf","mane":"b9aa93","muzzle":"82796f"},
  "elian":{"coat":"9fa8ad","mane":"e6e3d9","muzzle":"606a72"}
 }.get(id,{"coat":"77513a","mane":"392e29","muzzle":"5b3e32"})

static func build(painter,actor,id,cloth_color,gold,leather):
 var colors=palette(id);actor.set_meta("mount_appearance",colors)
 var coat=Color(colors.coat);var mane=Color(colors.mane);var muzzle=Color(colors.muzzle)
 var geo=painter.geo
 var horse=painter.joint(actor,"Horse",Vector3(0,.85,0))
 var body=painter.ellipsoid(horse,Vector3.ZERO,Vector3(.34,.4,.68),coat);body.name="HorseBody"
 painter.ellipsoid(horse,Vector3(0,.34,-.52),Vector3(.19,.47,.2),coat)
 var head=painter.joint(horse,"HorseHead",Vector3(0,.63,-.66));actor.register_bone("HorseHead",head)
 painter.ellipsoid(head,Vector3.ZERO,Vector3(.16,.21,.30),coat)
 painter.ellipsoid(head,Vector3(0,-.075,-.235),Vector3(.125,.12,.12),muzzle)
 for side in [-1,1]:
  var ear=painter.ellipsoid(head,Vector3(side*.10,.235,.03),Vector3(.045,.145,.065),coat);ear.rotation.z=side*-.16
  painter.ellipsoid(head,Vector3(side*.10,.24,-.025),Vector3(.022,.09,.012),muzzle)
  painter.ellipsoid(head,Vector3(side*.148,.045,-.11),Vector3(.018,.025,.036),Color("252831"))
  painter.ellipsoid(head,Vector3(side*.162,.055,-.12),Vector3(.006,.008,.01),Color("f1e9d4"))
  painter.ellipsoid(head,Vector3(side*.08,-.055,-.335),Vector3(.02,.016,.008),Color("302d2d"))
  var cheek=geo.block(head,Vector3(side*.147,-.005,-.06),Vector3(.018,.04,.35),leather);cheek.rotation.x=.22
  painter.ellipsoid(head,Vector3(side*.15,-.025,-.22),Vector3(.022,.03,.028),gold)
  painter.hair_lock(horse,[Vector3(side*.14,.60,-.84),Vector3(side*.23,.39,-.54),Vector3(side*.23,.36,-.18)],.015,leather)
 var noseband=geo.block(head,Vector3(0,-.005,-.275),Vector3(.26,.045,.025),leather);noseband.rotation.x=-.15
 for i in range(7):
  var z=-.55+i*.075;var y=.70-i*.075
  painter.hair_lock(horse,[Vector3(0,y,z),Vector3(.055,y-.06,z+.06),Vector3(.09,y-.20,z+.09)],.055,mane)
 painter.hair_lock(head,[Vector3(0,.20,.03),Vector3(.02,.19,-.15),Vector3(.035,.07,-.23)],.06,mane)
 for side in [-1,1]:
  painter.cloth(horse,[Vector3(side*.14,.36,-.25),Vector3(side*.14,.36,.35),Vector3(side*.36,-.10,.35),Vector3(side*.36,-.10,-.25)],cloth_color)
  painter.cloth(horse,[Vector3(side*.355,-.065,-.25),Vector3(side*.355,-.065,.35),Vector3(side*.36,-.10,.35),Vector3(side*.36,-.10,-.25)],gold)
  var stirrup=geo.block(horse,Vector3(side*.38,-.05,.02),Vector3(.055,.34,.035),leather)
  geo.block(horse,Vector3(side*.38,-.22,-.01),Vector3(.09,.025,.13),gold)
 painter.ellipsoid(horse,Vector3(0,.395,.055),Vector3(.245,.07,.28),leather)
 painter.ellipsoid(horse,Vector3(0,.46,-.18),Vector3(.24,.10,.055),leather)
 painter.ellipsoid(horse,Vector3(0,.46,.29),Vector3(.25,.105,.055),leather)
 var tail=painter.joint(horse,"HorseTail",Vector3(0,.10,.62));actor.register_bone("HorseTail",tail)
 for i in range(5):
  var x=(i-2)*.023
  painter.hair_lock(tail,[Vector3(x,0,0),Vector3(x*1.4,-.18,.12),Vector3(x*1.6,-.48,.19),Vector3(x*1.4,-.65,.12)],.044,mane)
 var index=0
 for x in [-.23,.23]:
  for z in [-.4,.43]:
   var leg=painter.joint(horse,"Leg"+str(index),Vector3(x,-.12,z));actor.register_bone("HorseLeg"+str(index),leg)
   geo.cylinder(leg,Vector3(0,-.17,0),.34,.065,coat,.085)
   painter.ellipsoid(leg,Vector3(0,-.34,0),Vector3(.07,.075,.07),coat)
   geo.cylinder(leg,Vector3(0,-.52,0),.34,.045,muzzle,.06)
   painter.ellipsoid(leg,Vector3(0,-.72,-.015),Vector3(.075,.055,.10),Color("30333a"));index+=1
