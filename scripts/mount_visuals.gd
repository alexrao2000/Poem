extends RefCounted
# Original mounted silhouettes share the actor's existing joint batching. Coat
# palettes follow each rider's map artwork; head and tail remain articulated.

const Head=preload("res://scripts/mount_head.gd")
const HEAD_PITCH=-.4
const BODY_HEIGHT=1.035
const RIDER_SPREAD=.5
const SADDLE_CENTER=Vector3(0,.395,.055)
const SADDLE_RADII=Vector3(.245,.07,.28)
const HOOF_CENTER=Vector3(0,-.86,-.015)
const HOOF_RADII=Vector3(.075,.055,.10)
const KNEE_CENTER=Vector3(0,-.41,0)
const LOWER_HOOF_CENTER=HOOF_CENTER-KNEE_CENTER
const FOOT_CENTER=Vector3(0,-.45,0)
const LEVEL_HOOF_CENTER=Vector3(0,0,-.015)

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
 var horse=painter.joint(actor,"Horse",Vector3(0,BODY_HEIGHT,0));actor.register_bone("Horse",horse)
 var body=painter.ellipsoid(horse,Vector3.ZERO,Vector3(.34,.4,.68),coat);body.name="HorseBody"
 painter.ellipsoid(horse,Vector3(0,.34,-.52),Vector3(.19,.47,.2),coat)
 var head=painter.joint(horse,"HorseHead",Vector3(0,.63,-.66));head.rotation.x=HEAD_PITCH;actor.register_bone("HorseHead",head)
 var skull=painter.geo.mesh(head,Head.mesh(),Vector3.ZERO,Vector3.ONE,geo.material(coat));skull.name="HorseSkull"
 var nose=painter.geo.mesh(head,Head.mesh(true),Vector3.ZERO,Vector3.ONE,geo.material(muzzle));nose.name="HorseMuzzle"
 for side in [-1,1]:
  var ear=painter.ellipsoid(head,Vector3(side*.10,.205,.03),Vector3(.040,.105,.055),coat);ear.rotation.z=side*-.16
  painter.ellipsoid(head,Vector3(side*.10,.21,-.018),Vector3(.020,.065,.012),muzzle)
  painter.ellipsoid(head,Vector3(side*.148,.045,-.11),Vector3(.018,.025,.036),Color("252831"))
  painter.ellipsoid(head,Vector3(side*.162,.055,-.12),Vector3(.006,.008,.01),Color("f1e9d4"))
  painter.ellipsoid(head,Vector3(side*.08,-.055,-.335),Vector3(.02,.016,.008),Color("302d2d"))
  painter.ellipsoid(head,Vector3(side*.15,-.025,-.22),Vector3(.022,.03,.028),gold)
 var bridle=geo.mesh(head,Head.bridle(),Vector3.ZERO,Vector3.ONE,geo.material(leather));bridle.name="FittedBridle"
 for i in range(7):
  var z=-.55+i*.075;var y=.70-i*.075
  painter.hair_lock(horse,[Vector3(0,y,z),Vector3(.055,y-.06,z+.06),Vector3(.09,y-.20,z+.09)],.055,mane)
 painter.hair_lock(head,[Vector3(0,.20,.03),Vector3(.02,.15,-.15),Vector3(.035,.07,-.23)],.06,mane)
 for side in [-1,1]:
  painter.cloth(horse,[Vector3(side*.14,.36,-.25),Vector3(side*.14,.36,.35),Vector3(side*.36,-.10,.35),Vector3(side*.36,-.10,-.25)],cloth_color)
  painter.cloth(horse,[Vector3(side*.355,-.065,-.25),Vector3(side*.355,-.065,.35),Vector3(side*.36,-.10,.35),Vector3(side*.36,-.10,-.25)],gold)
  var attachment=Vector3(side*.245,.395,-.20);var footrest=Vector3(side*.4124,-.1035,-.20)
  var strap=geo.block(horse,(attachment+footrest)*.5,Vector3(.035,attachment.distance_to(footrest),.025),leather)
  strap.quaternion=Quaternion(Vector3.UP,(attachment-footrest).normalized())
  var stirrup=geo.block(horse,footrest,Vector3(.14,.025,.16),gold)
  stirrup.name="LeftStirrup" if side<0 else "RightStirrup"
 var saddle=painter.ellipsoid(horse,SADDLE_CENTER,SADDLE_RADII,leather);saddle.name="SaddleSeat"
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
   geo.cylinder(leg,Vector3(0,-.205,0),.41,.065,coat,.085)
   painter.ellipsoid(leg,Vector3(0,-.41,0),Vector3(.07,.075,.07),coat)
   var knee=painter.joint(leg,"HorseKnee",KNEE_CENTER);actor.register_bone("HorseKnee"+str(index),knee)
   geo.cylinder(knee,Vector3(0,-.22,0),.44,.045,muzzle,.06)
   var foot=painter.joint(knee,"HorseFoot",FOOT_CENTER);actor.register_bone("HorseFoot"+str(index),foot)
   var hoof=painter.ellipsoid(foot,LEVEL_HOOF_CENTER,HOOF_RADII,Color("30333a"));hoof.name="Hoof";index+=1

 actor.reins=preload("res://scripts/mounted_reins.gd").new();actor.add_child(actor.reins)
 actor.reins.configure(actor,painter.painted(Color("b1a797"),3))
