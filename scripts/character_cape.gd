extends RefCounted
# Class cuts share the existing shoulder attachment, fabric UVs and bounded
# cloth shader. The ranger half-cloak leaves the right-side quiver exposed.

const CUTS={"standard":{"length":.94,"width":.75,"depth":.42},"mantle":{"length":.52,"width":.68,"depth":.27},"half":{"length":.84,"width":.40,"depth":.34},"forked":{"length":.92,"width":.72,"depth":.39},"riding":{"length":.72,"width":.65,"depth":.34}}
const CLASSES={"Knight":"mantle","Corsair":"mantle","Ranger":"half","Duelist":"forked","Rider":"riding"}
static var meshes={}

static func cut_for(job: String,personal="") -> String:
 return personal if CUTS.has(personal) else CLASSES.get(job,"standard")

static func point(cut: String,u: float,v: float) -> Vector3:
 var profile=CUTS[cut];var length=float(profile.length)
 var x=(u-.5)*lerpf(.5,profile.width,v)
 if cut=="half":x=lerpf(-.28-.12*v,-.01-.03*v,u);length=lerpf(.84,.64,u)
 var notch=pow(v,6)*.24*maxf(0,1-absf(u-.5)*6) if cut=="forked" else 0.0
 return Vector3(x,-v*(length+.04*sin(u*PI))+notch,v*profile.depth+sin(u*PI)*.10+sin(u*PI*6)*v*.025)

static func mesh(cut: String) -> ArrayMesh:
 if not CUTS.has(cut):cut="standard"
 if meshes.has(cut):return meshes[cut]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(6):
  for column in range(6):
   var points=[];var uvs=[]
   for corner in [[column,row],[column+1,row],[column+1,row+1],[column,row+1]]:
    var u=corner[0]/6.0;var v=corner[1]/6.0;points.append(point(cut,u,v));uvs.append(Vector2(u,v))
   for index in [0,1,2,0,2,3]:surface.set_uv(uvs[index]);surface.add_vertex(points[index])
 surface.generate_normals();meshes[cut]=surface.commit();return meshes[cut]
