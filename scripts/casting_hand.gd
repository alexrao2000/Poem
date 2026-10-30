extends RefCounted
## Small open hands with a tapered palm, four separate fingers and a thumb.
## Mirroring the joint positions keeps triangle winding and lighting outward.
static var shapes={}

static func append(surface: SurfaceTool,shape: Mesh,transform: Transform3D):
 var arrays=shape.surface_get_arrays(0)
 var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uv=arrays[Mesh.ARRAY_TEX_UV];var indices=arrays[Mesh.ARRAY_INDEX]
 if indices==null or indices.is_empty():indices=range(vertices.size())
 var normal_basis=transform.basis.inverse().transposed()
 for i in range(0,indices.size(),3):
  var a=transform*vertices[indices[i]];var b=transform*vertices[indices[i+1]];var c=transform*vertices[indices[i+2]]
  # SphereMesh's collapsed pole quads contain zero-area triangles.
  if (c-a).cross(b-a).length_squared()<.000000000000000001:continue
  for j in range(3):
   var index=indices[i+j]
   surface.set_normal((normal_basis*normals[index]).normalized());surface.set_uv(uv[index]);surface.add_vertex(transform*vertices[index])

static func triangle(surface: SurfaceTool,points: Array,normals: Array,uvs: Array):
 var order=[0,1,2]
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(normals[0]+normals[1]+normals[2])<0:order=[0,2,1]
 for i in order:surface.set_normal(normals[i]);surface.set_uv(uvs[i]);surface.add_vertex(points[i])

static func digit(surface: SurfaceTool,path: Array,radii: Array):
 var rings=[];var outward=[];var axes=[]
 for i in range(path.size()):
  var axis=(path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized();axes.append(axis)
  var rotation=Basis(Quaternion(Vector3.UP,axis));var ring=[];var normals=[]
  for j in range(7):
   var angle=j/6.0*TAU;var normal=rotation*Vector3(cos(angle),0,sin(angle))
   ring.append(path[i]+normal*radii[i]);normals.append(normal)
  rings.append(ring);outward.append(normals)
 for i in range(path.size()-1):
  for j in range(6):
   for corners in [[[i,j],[i+1,j],[i+1,j+1]],[[i,j],[i+1,j+1],[i,j+1]]]:
    var points=[];var normals=[];var uvs=[]
    for corner in corners:
     points.append(rings[corner[0]][corner[1]]);normals.append(outward[corner[0]][corner[1]]);uvs.append(Vector2(corner[1]/6.0,corner[0]/float(path.size()-1)))
    triangle(surface,points,normals,uvs)
 for i in [0,path.size()-1]:
  var normal=axes[i]*(-1 if i==0 else 1)
  for j in range(6):triangle(surface,[path[i],rings[i][j],rings[i][j+1]],[normal,normal,normal],[Vector2(.5,.5),Vector2(j/6.0,0),Vector2((j+1)/6.0,0)])

static func mesh(side: int) -> ArrayMesh:
 if shapes.has(side):return shapes[side]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var palm=SphereMesh.new();palm.radius=1;palm.height=2;palm.radial_segments=12;palm.rings=4
 append(surface,palm,Transform3D(Basis.from_scale(Vector3(.046,.050,.027)),Vector3.ZERO))
 var lengths=[.047,.064,.069,.056]
 for i in range(4):
  var x=(-.033+i*.022)*side;var spread=(i-1.5)*.005*side
  var start=Vector3(x,-.029,-.003)
  var knuckle=Vector3(x+spread,-.029-lengths[i]*.53,-.007)
  var tip=Vector3(x+spread*1.4,-.029-lengths[i],-.019)
  digit(surface,[start,knuckle,tip],[.010,.009,.006])
 var thumb=[Vector3(.039*side,.014,0),Vector3(.061*side,-.007,-.008),Vector3(.073*side,-.027,-.019)]
 digit(surface,thumb,[.014,.012,.008])
 surface.index();surface.generate_tangents();shapes[side]=surface.commit();return shapes[side]
