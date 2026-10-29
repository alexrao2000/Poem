extends RefCounted
# Original articulated low-poly actors. Nodes are named for animation replacement.
var geo = preload("res://scripts/scenery.gd").new()

func ellipsoid(parent,p,size,color):
 var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=12;shape.rings=7
 return geo.mesh(parent,shape,p,size,geo.material(color))

func cloth(parent,points,color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in [0,1,2,0,2,3]:st.add_vertex(points[i])
 st.generate_normals()
 var material=geo.material(color).duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED
 return geo.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,material)

func joint(parent,node_name,p):
 var n=Node3D.new();n.name=node_name;n.position=p;parent.add_child(n);return n

func build(parent,u,p) -> Node3D:
 var actor=joint(parent,"Fighter",p)
 var tint=Color(u.color);var blue=Color("354c77") if u.team=="player" else Color("853e43")
 var skin=Color("e0ba98");var steel=Color("a8b3bb");var gold=Color("bca26b");var leather=Color("554337")
 var heavy=u.job=="Knight";var robe=u.weapon in ["magic","staff"]
 var torso=joint(actor,"Torso",Vector3(0,1.2,0))
 geo.cylinder(torso,Vector3(0,.13,0),.48,.20,blue,.26)
 ellipsoid(torso,Vector3(0,.27,-.055),Vector3(.235,.26,.13),steel if not robe else tint)
 geo.cylinder(torso,Vector3(0,-.09,0),.08,.205,leather)
 geo.block(torso,Vector3(0,-.09,-.21),Vector3(.08,.07,.025),gold)
 # A layered coat/tassets with gold hem and a moving cape silhouette.
 geo.cylinder(torso,Vector3(0,-.28,.01),.34,.27,blue,.19)
 geo.cylinder(torso,Vector3(0,-.45,.01),.035,.275,gold,.27)
 if robe:
  geo.cylinder(actor,Vector3(0,.55,0),.85,.32,tint,.20)
  geo.cylinder(actor,Vector3(0,.13,0),.035,.325,gold,.32)
 var cape=joint(torso,"Cape",Vector3(0,.35,.12))
 cloth(cape,[Vector3(-.24,0,0),Vector3(.24,0,0),Vector3(.34,-.95,.3),Vector3(-.38,-1.02,.32)],tint.darkened(.2))
 cloth(cape,[Vector3(-.22,-.02,-.01),Vector3(.22,-.02,-.01),Vector3(.30,-.9,.29),Vector3(-.34,-.96,.31)],blue)
 for sign_value in [-1,1]:
  var leg=joint(actor,"LeftLeg" if sign_value<0 else "RightLeg",Vector3(sign_value*.13,.85,0))
  geo.cylinder(leg,Vector3(0,-.18,0),.37,.08,Color("3c3f48"),.10)
  ellipsoid(leg,Vector3(0,-.36,-.02),Vector3(.10,.11,.09),steel)
  geo.cylinder(leg,Vector3(0,-.54,0),.32,.085,steel if heavy else leather,.07)
  ellipsoid(leg,Vector3(0,-.74,-.07),Vector3(.10,.08,.18),leather)
  var arm=joint(actor,"Arm" if sign_value>0 else "LeftArm",Vector3(sign_value*.27,1.5,0))
  ellipsoid(arm,Vector3(sign_value*.035,-.015,0),Vector3(.17 if heavy else .12,.12,.15),steel)
  geo.cylinder(arm,Vector3(0,-.16,0),.28,.07,blue,.085)
  ellipsoid(arm,Vector3(0,-.3,0),Vector3(.073,.073,.073),steel)
  geo.cylinder(arm,Vector3(0,-.43,-.045),.25,.07,steel,.06)
  ellipsoid(arm,Vector3(0,-.59,-.075),Vector3(.075,.085,.065),leather)
  arm.rotation.x=-.12
  if sign_value>0:weapon(arm,u.weapon,gold,steel,leather)
  elif heavy:
   var shield=geo.cylinder(arm,Vector3(-.04,-.35,-.17),.08,.29,blue)
   shield.rotation.x=PI/2;shield.scale=Vector3(.8,1,1.3)
   geo.block(arm,Vector3(-.04,-.35,-.22),Vector3(.055,.45,.025),gold)
 geo.cylinder(actor,Vector3(0,1.63,0),.15,.075,skin)
 var head=joint(actor,"Head",Vector3(0,1.79,0))
 ellipsoid(head,Vector3.ZERO,Vector3(.145,.19,.14),skin)
 ellipsoid(head,Vector3(0,-.01,-.135),Vector3(.025,.035,.035),skin)
 if heavy:
  ellipsoid(head,Vector3(0,.045,.015),Vector3(.16,.19,.16),steel)
  geo.block(head,Vector3(0,.005,-.15),Vector3(.24,.045,.025),Color("303841"))
  geo.block(head,Vector3(0,-.055,-.16),Vector3(.05,.15,.03),gold)
 else:
  var hair=Color("623c31") if u.job=="Vanguard" else (Color("34313d") if u.job=="Duelist" else Color("a68960"))
  ellipsoid(head,Vector3(0,.085,.025),Vector3(.157,.145,.155),hair)
  for i in range(7):
   var bang=geo.cylinder(head,Vector3((i-3)*.04,.065,-.115),.19,.035,hair,.002)
   bang.rotation.x=PI+.2;bang.rotation.z=(i-3)*.12
  for x in [-.061,.061]:
   geo.block(head,Vector3(x,-.014,-.134),Vector3(.053,.033,.012),Color("eee6d8"))
   geo.block(head,Vector3(x,-.014,-.142),Vector3(.022,.028,.008),Color("394c5c"))
  if u.job in ["Vanguard","Ranger"]:
   ellipsoid(head,Vector3(0,-.14,.14),Vector3(.13,.25,.09),hair)
 if u.job=="Rider":
  # Mount is a separate articulated silhouette; rider root is raised above the saddle.
  var riding=joint(parent,"MountedFighter",p)
  actor.reparent(riding);actor.position=Vector3(0,.75,0)
  var horse=joint(riding,"Horse",Vector3(0,.85,0))
  ellipsoid(horse,Vector3.ZERO,Vector3(.34,.4,.68),Color("77513a"))
  ellipsoid(horse,Vector3(0,.34,-.52),Vector3(.19,.47,.2),Color("77513a"))
  ellipsoid(horse,Vector3(0,.63,-.66),Vector3(.16,.21,.30),Color("77513a"))
  for x in [-.23,.23]:
   for z in [-.4,.43]:
    geo.cylinder(horse,Vector3(x,-.45,z),.85,.055,Color("5b3e32"))
    ellipsoid(horse,Vector3(x,-.84,z),Vector3(.075,.055,.10),Color("30333a"))
  # Animation code locates the rider's arm through the returned root.
  var arm=actor.get_node("Arm");arm.reparent(riding);arm.name="Arm"
  return riding
 return actor

func weapon(arm,kind,gold,steel,leather):
 var hand=joint(arm,"Weapon",Vector3(0,-.59,-.09))
 if kind in ["magic","staff"]:
  geo.cylinder(hand,Vector3(0,.05,0),1.35,.022,leather)
  var orb=ellipsoid(hand,Vector3(0,.78,0),Vector3(.11,.11,.11),Color("79cbdb"))
  var glow=orb.material_override.duplicate();glow.emission_enabled=true;glow.emission=Color("6ebfce");glow.emission_energy_multiplier=1.4;orb.material_override=glow
 elif kind=="bow":
  for i in range(10):
   var t=float(i)/9*PI
   var segment=geo.block(hand,Vector3(0,cos(t)*.45,-sin(t)*.22),Vector3(.035,.14,.035),leather)
   segment.rotation.x=-t
  geo.block(hand,Vector3.ZERO,Vector3(.009,.9,.009),Color("d6c9a4"))
 else:
  var grip=geo.cylinder(hand,Vector3(0,0,-.08),.23,.027,leather);grip.rotation.x=PI/2
  if kind=="lance":
   var shaft=geo.cylinder(hand,Vector3(0,0,-.5),1.8,.024,leather);shaft.rotation.x=PI/2
   var tip=geo.cylinder(hand,Vector3(0,0,-1.48),.28,.075,steel,0);tip.rotation.x=-PI/2
  elif kind=="axe":
   var shaft=geo.cylinder(hand,Vector3(0,0,-.35),.9,.029,leather);shaft.rotation.x=PI/2
   cloth(hand,[Vector3(-.20,0,-.65),Vector3(.20,0,-.65),Vector3(.29,0,-.97),Vector3(-.29,0,-.97)],steel)
  else:
   geo.block(hand,Vector3(0,0,-.21),Vector3(.24,.04,.055),gold)
   var blade=geo.cylinder(hand,Vector3(0,0,-.65),.85,.055,steel,0);blade.rotation.x=-PI/2;blade.scale.x=.35
