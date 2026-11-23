extends RefCounted
## Cross sections flare from the keel to the deck. The raised prow and squared
## stern keep the profile readable beside the harbor's larger architecture.
const RIBS=[
 {"z":-1.51,"half_width":.38,"keel":-.055,"deck":.245},
 {"z":-1.28,"half_width":.56,"keel":-.17,"deck":.225},
 {"z":-.83,"half_width":.71,"keel":-.265,"deck":.205},
 {"z":-.34,"half_width":.78,"keel":-.31,"deck":.198},
 {"z":.20,"half_width":.76,"keel":-.30,"deck":.200},
 {"z":.70,"half_width":.63,"keel":-.24,"deck":.218},
 {"z":1.13,"half_width":.43,"keel":-.13,"deck":.248},
 {"z":1.44,"half_width":.22,"keel":.005,"deck":.30},
 {"z":1.63,"half_width":.045,"keel":.105,"deck":.36}
]
const PROFILE=[
 Vector2(-1,1),Vector2(-.95,.80),Vector2(-.73,.40),Vector2(-.28,0),
 Vector2(.28,0),Vector2(.73,.40),Vector2(.95,.80),Vector2(1,1)
]
const STRAKES=[Color("685346"),Color("8b6c52"),Color("765743"),Color("51443e")]
static var shape: ArrayMesh

static func point(rib: int,profile_index: int) -> Vector3:
 var section=RIBS[rib]
 var profile=PROFILE[profile_index]
 return Vector3(section.half_width*profile.x,lerpf(section.keel,section.deck,profile.y),section.z)

static func face(surface: SurfaceTool,vertices: Array,paint: Color):
 for vertex in vertices:
  surface.set_color(paint)
  surface.set_uv(Vector2(vertex.x/1.6+.5,vertex.z/3.3+.5))
  surface.add_vertex(vertex)

static func hull() -> ArrayMesh:
 if shape!=null:return shape
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_smooth_group(-1)
 for rib in range(RIBS.size()-1):
  for band in PROFILE.size():
   var next=(band+1)%PROFILE.size()
   var a=point(rib,band)
   var b=point(rib+1,band)
   var c=point(rib+1,next)
   var d=point(rib,next)
   var paint=Color("a18765") if next==0 else STRAKES[mini(band,PROFILE.size()-2-band)]
   face(surface,[a,b,c,a,c,d],paint.lightened(float(rib%3)*.012))
 for end in [0,RIBS.size()-1]:
  for band in range(1,PROFILE.size()-1):
   var a=point(end,0)
   var b=point(end,band)
   var c=point(end,band+1)
   face(surface,[a,b,c] if end==0 else [a,c,b],Color("735c47"))
 surface.generate_normals()
 shape=surface.commit()
 return shape
