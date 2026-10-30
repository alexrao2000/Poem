extends RefCounted
## Promotion silhouettes layer over personal colors without replacing the face,
## hair, weapon, joints or animation sockets. Authored actors keep precedence.
static var looks=JSON.parse_string(FileAccess.get_file_as_string("res://data/promotion_looks.json"))

static func build(painter,actor,unit,torso,cloth_color,cape_color,steel,gold,leather):
 var id=unit.get("promotion","");var look=looks.get(id,{})
 if unit.team!="player" or look.is_empty() or look.base!=unit.job:return
 actor.set_meta("promotion_look",id)
 var group=painter.joint(torso,"PromotionCostume",Vector3.ZERO)
 group.set_meta("components",look.keys())
 if look.has("mantle"):
  var width=float(look.mantle)
  painter.shell(group,Vector3.ZERO,[[.245,width,.205],[.34,width*.88,.18],[.46,.113,.095]],cape_color)
  painter.shell(group,Vector3.ZERO,[[.241,width+.002,.207],[.26,width-.009,.202]],gold)
 if look.has("tabard"):
  var bottom=-float(look.tabard)
  var points=[Vector3(-.12,-.105,-.226),Vector3(.12,-.105,-.226),Vector3(.155,bottom,-.263),Vector3(-.155,bottom,-.263)]
  painter.cloth(group,points,cape_color)
  painter.cloth(group,[points[3]+Vector3(0,.027,-.002),points[2]+Vector3(0,.027,-.002),points[2]+Vector3(0,0,-.002),points[3]+Vector3(0,0,-.002)],gold)
 if look.has("sash"):
  for side in [-1,1]:
   var bottom=-float(look.sash)+(0.06 if side<0 else 0)
   var points=[Vector3(side*.13,-.095,-.175),Vector3(side*.23,-.095,-.15),Vector3(side*.38,bottom,-.26),Vector3(side*.27,bottom+.06,-.28)]
   painter.cloth(group,points,cape_color)
   painter.cloth(group,[points[3]+Vector3(0,.025,-.002),points[2]+Vector3(0,.025,-.002),points[2]+Vector3(0,0,-.002),points[3]+Vector3(0,0,-.002)],gold)
 if look.has("stole"):
  for side in [-1,1]:
   var a=side*.055;var b=side*.13;var bottom=-float(look.stole)
   painter.cloth(group,[Vector3(a,.37,-.19),Vector3(b,.37,-.19),Vector3(b,0,-.245),Vector3(a,0,-.245)],cape_color)
   painter.cloth(group,[Vector3(a,0,-.245),Vector3(b,0,-.245),Vector3(b*1.3,bottom,-.29),Vector3(a*1.3,bottom,-.29)],cape_color)
   painter.cloth(group,[Vector3(a*1.3,bottom+.035,-.292),Vector3(b*1.3,bottom+.035,-.292),Vector3(b*1.3,bottom,-.292),Vector3(a*1.3,bottom,-.292)],gold)
 for side in [-1,1]:
  var arm=actor.bone("LeftArm" if side<0 else "Arm");var elbow=actor.bone("LeftElbow" if side<0 else "Elbow")
  if look.has("plates") and (side<0 or not look.get("one_shoulder",false)):
   var plates=painter.joint(arm,"PromotionLames",Vector3(side*.025,.035,0))
   for layer in range(int(look.plates)):
    var radius=float(look.plate_radius)-layer*.012;var y=-layer*.085
    painter.shell(plates,Vector3.ZERO,[[y-.07,radius,.158],[y+.015,radius*.9,.15],[y+.065,radius*.6,.10]],steel)
    painter.shell(plates,Vector3.ZERO,[[y-.074,radius+.001,.160],[y-.055,radius-.004,.158]],gold)
  if look.get("bracers",false):
   var bracer=painter.joint(elbow,"PromotionBracer",Vector3.ZERO)
   painter.shell(bracer,Vector3.ZERO,[[-.245,.072,.073],[-.08,.078,.075],[-.035,.084,.08]],steel)
   painter.geo.cylinder(bracer,Vector3(0,-.245,0),.025,.076,gold)
 if look.get("shield_rim",false):
  var ring=TorusMesh.new();ring.inner_radius=.278;ring.outer_radius=.312;ring.rings=16;ring.ring_segments=8
  var rim=painter.geo.mesh(actor.bone("LeftElbow"),ring,Vector3(-.04,-.16,-.215),Vector3(.8,1,1.3),painter.geo.material(gold));rim.name="PromotionShieldRim";rim.rotation.x=PI/2
 if look.get("satchel",false):
  painter.ellipsoid(group,Vector3(-.255,-.17,.025),Vector3(.10,.135,.085),leather)
  painter.geo.block(group,Vector3(-.26,-.12,-.06),Vector3(.16,.06,.02),cloth_color)
  painter.geo.block(group,Vector3(-.26,-.14,-.077),Vector3(.025,.04,.018),gold)
 if look.get("crossbelt",false):
  var strap=painter.geo.block(group,Vector3(0,.15,-.195),Vector3(.052,.47,.025),leather);strap.rotation.z=.48
  painter.geo.block(group,Vector3(-.08,.28,-.214),Vector3(.066,.055,.018),gold)
 if look.has("emblem"):
  var style=look.emblem
  if style=="star":
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in range(10):
    var a=-PI*.5+i*TAU/10;var b=-PI*.5+(i+1)*TAU/10
    var ra=.055 if i%2==0 else .026;var rb=.026 if i%2==0 else .055
    for point in [Vector3(0,.305,-.224),Vector3(cos(a)*ra,.305+sin(a)*ra,-.224),Vector3(cos(b)*rb,.305+sin(b)*rb,-.224)]:surface.set_uv(Vector2.ZERO);surface.add_vertex(point)
   surface.generate_normals();painter.geo.mesh(group,surface.commit(),Vector3.ZERO,Vector3.ONE,painter.geo.material(gold))
  elif style=="sun":painter.ellipsoid(group,Vector3(0,.305,-.227),Vector3(.048,.048,.014),gold)
  else:
   var badge=painter.geo.block(group,Vector3(0,.305,-.227),Vector3(.063,.063,.021),gold);badge.rotation.z=PI/4
