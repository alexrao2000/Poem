extends RefCounted
# Original class headgear echoes the anonymous enemy portraits. Hoods remain
# open toward -Z, preserving the painted eyes; all detail batches with the head.

static func build(painter,head,job,steel,gold,appearance={}):
 head.set_meta("enemy_headgear",job)
 if job in ["Ranger","Arcanist","Warden"]:
  var color=Color(appearance.get("hood",{"Ranger":"565a3e","Arcanist":"4d364c","Warden":"ded5bd"}[job]))
  var cap=painter.ellipsoid(head,Vector3(0,.14,.02),Vector3(.18,.11,.18),color);cap.material_override=painter.painted(color,0)
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(10):
   var points=[];var uvs=[]
   for corner in [[i,0],[i+1,0],[i+1,1],[i,1]]:
    var angle=corner[0]*PI/10;var lower=corner[1]==1;var radius=.21 if lower else .175
    points.append(Vector3(cos(angle)*radius,-.27 if lower else .17,sin(angle)*radius+.02))
    uvs.append(Vector2(corner[0]/10.0,corner[1]))
   for vertex in [0,2,1,0,3,2]:surface.set_uv(uvs[vertex]);surface.add_vertex(points[vertex])
  surface.generate_normals()
  painter.geo.mesh(head,surface.commit(),Vector3.ZERO,Vector3.ONE,painter.painted(color,0))
  for side in [-1,1]:
   painter.hair_lock(head,[Vector3(side*.12,.21,-.075),Vector3(side*.18,.08,-.06),Vector3(side*.21,-.25,.02)],.012,gold)
 if job in ["Vanguard","Ranger","Duelist"]:
  var color=steel if job=="Vanguard" else Color("853e43") if job=="Ranger" else Color("33343e")
  painter.shell(head,Vector3(0,0,-.10),[[-.16,.11,.06],[-.05,.13,.055],[.015,.12,.05]],color)
  if job=="Vanguard":
   for x in [-.05,0,.05]:painter.geo.block(head,Vector3(x,-.075,-.157),Vector3(.009,.07,.006),Color("30343c"))
 elif job=="Rider":
  painter.ellipsoid(head,Vector3(0,.17,.015),Vector3(.175,.10,.18),steel)
  for side in [-1,1]:
   painter.ellipsoid(head,Vector3(side*.15,-.02,.01),Vector3(.035,.13,.12),steel)
   var edge=painter.geo.block(head,Vector3(side*.14,.12,-.105),Vector3(.026,.025,.14),gold);edge.rotation.z=side*.12
 if job in ["Knight","Rider"]:
  painter.geo.block(head,Vector3(0,.255,.015),Vector3(.035,.035,.23),gold)
  for i in range(4):
   var x=(i-1.5)*.023
   painter.hair_lock(head,[Vector3(x,.265,.02),Vector3(x,.30,.18),Vector3(x,.12,.28),Vector3(x,-.13,.30)],.04,Color(appearance.get("crest","8b3943")))
 if appearance.has("circlet"):
  painter.shell(head,Vector3(0,.13,-.03),[[0,.174,.16],[.025,.174,.16]],gold)
  var jewel=painter.ellipsoid(head,Vector3(0,.143,-.196),Vector3(.026,.029,.012),Color(appearance.circlet));jewel.name="CommanderJewel"
