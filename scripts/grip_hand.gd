extends RefCounted
## Curled glove silhouettes retain the former hand envelope and elbow joint.
## Four fingers close around the longitudinal weapon grip; thumbs are mirrored.
const Form=preload("res://scripts/casting_hand.gd")
static var shapes={}

static func mesh(side: int) -> ArrayMesh:
 if shapes.has(side):return shapes[side]
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var palm=SphereMesh.new();palm.radius=1;palm.height=2;palm.radial_segments=12;palm.rings=4
 Form.append(surface,palm,Transform3D(Basis.from_scale(Vector3(.022,.057,.053)),Vector3(.045*side,.004,0)))
 for index in range(4):
  var z=-.043+index*.028
  var taper=1.0-absf(index-1.5)*.07
  var path=[Vector3(.044,-.023,z),Vector3(.021,-.058*taper,z),Vector3(-.029,-.046*taper,z),Vector3(-.039,-.008,z),Vector3(-.034,.018,z)]
  for i in range(path.size()):path[i].x*=side
  Form.digit(surface,path,[.013,.013,.012,.011,.008])
 var thumb=[Vector3(.043*side,.035,.042),Vector3(.013*side,.037,.049),Vector3(-.020*side,.024,.037),Vector3(-.035*side,.006,.019)]
 Form.digit(surface,thumb,[.016,.015,.013,.009])
 surface.index();surface.generate_tangents();shapes[side]=surface.commit();return shapes[side]
