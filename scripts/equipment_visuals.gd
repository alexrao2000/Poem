extends RefCounted
## Equipment appearance is separate from rules and preserves weapon contact
## reach. Missing/mismatched item IDs use the same kind's company equipment.
const Blades=preload("res://scripts/weapon_blades.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Book=preload("res://scripts/spellbook.gd")
const DEFAULT={"sword":"iron_sword","lance":"iron_lance","axe":"iron_axe","bow":"scout_bow","magic":"ember","staff":"field_staff"}
static var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_looks.json"))
static var shapes={}

static func resolve(kind: String,item: String) -> String:
 return item if profiles.has(item) and profiles[item].kind==kind else DEFAULT.get(kind,"iron_sword")

static func blade(item: String) -> Mesh:
 if shapes.has(item):return shapes[item]
 var look=profiles[item];var shape: Mesh
 if look.kind=="sword":
  var width=float(look.width)
  shape=Blades.pointed([Vector3(-.235,.048*width,.018),Vector3(-.29,.065*width,.022),Vector3(-.91,.035*width,.014)],-1.075)
 elif look.kind=="lance":shape=Blades.spear(-1.34,-1.43,-1.62,look.width)
 elif look.shape=="hammer":shape=Blades.hammer()
 elif look.shape=="hatchet":shape=Blades.hatchet()
 else:shape=Blades.axe()
 shapes[item]=shape;return shape

static func build(painter,arm: Node3D,kind: String,item: String) -> Node3D:
 item=resolve(kind,item)
 var look=profiles[item];var gold=Color(look.accent);var steel=Color(look.steel);var wood=Color(look.grip)
 var hand=painter.joint(arm,"Weapon",Vector3(0,-.29,-.04));hand.set_meta("equipment",item)
 var metal=painter.painted(steel,1,true)
 if kind=="magic":
  Book.build(painter,hand,gold,Color(look.cover),Color(look.ribbon))
 elif kind=="staff":
  painter.geo.cylinder(hand,Vector3(0,.05,0),1.35,.022,wood)
  var orb=painter.ellipsoid(hand,Vector3(0,.78,0),Vector3(.11,.11,.11),Color(look.core))
  var glow=orb.material_override.duplicate();glow.emission_enabled=true;glow.emission=Color(look.core);glow.emission_energy_multiplier=1.4;orb.material_override=glow
  for i in range(int(look.rings)):
   var ring=TorusMesh.new();ring.inner_radius=.09;ring.outer_radius=.115;ring.rings=16;ring.ring_segments=8
   painter.geo.mesh(hand,ring,Vector3(0,.70+i*.055,0),Vector3.ONE,painter.geo.material(gold))
 elif kind=="bow":
  hand.rotation.x=-1.5;hand.set_meta("bow_height",float(look.height))
  for i in range(12):
   var t=float(i)/12*PI;var next_t=float(i+1)/12*PI
   var start=Vector3(0,cos(t)*look.height,.22-sin(t)*.22+sin(t*4)*look.curve)
   var end=Vector3(0,cos(next_t)*look.height,.22-sin(next_t)*.22+sin(next_t*4)*look.curve)
   var segment=painter.geo.cylinder(hand,(start+end)*.5,start.distance_to(end)+.008,look.thickness,wood)
   segment.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
  for key in ["BowStringTop","BowStringBottom"]:
   var segment=painter.joint(hand,key,Vector3.ZERO)
   painter.geo.block(segment,Vector3.ZERO,Vector3(.007,1,.007),Color("d6c9a4"))
  var arrow=painter.joint(hand,"NockedArrow",Vector3(0,0,-.14));Projectile.physical_geometry(arrow,"bow")
  painter.geo.cylinder(hand,Vector3.ZERO,.13,look.thickness*1.4,gold)
 else:
  var grip=painter.geo.cylinder(hand,Vector3(0,0,-.08),.23,.027,wood);grip.rotation.x=PI/2
  if kind=="lance":
   var shaft=painter.geo.cylinder(hand,Vector3(0,0,-.5),1.8,.024,wood);shaft.rotation.x=PI/2
   var tip=painter.geo.mesh(hand,blade(item),Vector3.ZERO,Vector3.ONE,metal);tip.name="SpearBlade"
   if look.get("lugs",false):
    painter.geo.block(hand,Vector3(0,0,-1.38),Vector3(.30,.045,.045),gold)
  elif kind=="axe":
   var shaft=painter.geo.cylinder(hand,Vector3(0,0,-.35),.9,.029,wood);shaft.rotation.x=PI/2
   var head=painter.geo.mesh(hand,blade(item),Vector3.ZERO,Vector3(float(look.width),1,1),metal)
   head.name="HammerHead" if look.shape=="hammer" else "AxeBlade"
  else:
   if look.guard=="swept":
    for side in [-1,1]:
     var guard=painter.geo.block(hand,Vector3(side*.07,0,-.21+side*.025),Vector3(.15,.035,.045),gold);guard.rotation.y=side*.35
   elif look.guard=="ring":
    var ring=TorusMesh.new();ring.inner_radius=.045;ring.outer_radius=.063;ring.rings=16;ring.ring_segments=8
    var guard=painter.geo.mesh(hand,ring,Vector3(0,0,-.21),Vector3.ONE,painter.geo.material(gold));guard.rotation.x=PI/2
    painter.geo.block(hand,Vector3(0,0,-.21),Vector3(.20,.032,.035),gold)
   else:painter.geo.block(hand,Vector3(0,0,-.21),Vector3(.24,.04,.055),gold)
   var edge=painter.geo.mesh(hand,blade(item),Vector3.ZERO,Vector3.ONE,metal);edge.name="SwordBlade"
 return hand
