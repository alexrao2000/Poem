extends RefCounted
## Reed Crossing's fitted iron chain and two stone anchor posts.

static var link_mesh: TorusMesh
static var chain_iron: StandardMaterial3D
const DROP_DISTANCE=.79

static func build(painter,parent: Node3D,first: Vector3,second: Vector3,height: float,sag: float,link_size: float) -> MultiMeshInstance3D:
 var chain=Node3D.new();chain.name="CrossingChain";chain.position=(first+second)*.5
 parent.add_child(chain)
 if link_mesh==null:
  link_mesh=TorusMesh.new();link_mesh.inner_radius=.62;link_mesh.outer_radius=1.0
  link_mesh.rings=12;link_mesh.ring_segments=6
  chain_iron=StandardMaterial3D.new();chain_iron.albedo_color=Color("665f52")
  chain_iron.metallic=.46;chain_iron.roughness=.65
 var stone=painter.detail_material(3)
 for foothold in [first,second]:
  var point=foothold-chain.position
  painter.block(chain,point,Vector3(.63,.20,.73)*height,stone).name="ChainPlinth"
  painter.block(chain,point+Vector3.UP*height*.47,Vector3(.47,.98,.46)*height,stone).name="ChainPost"
  painter.block(chain,point+Vector3.UP*height,Vector3(.57,.23,.55)*height,chain_iron).name="ChainAnchor"
 var start=first-chain.position+Vector3.UP*height
 var finish=second-chain.position+Vector3.UP*height
 var span=finish-start
 var links=ceili(span.length()/(1.48*link_size))+1
 var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D
 instances.mesh=link_mesh;instances.instance_count=links
 var data=PackedFloat32Array();data.resize(links*12)
 var envelope=AABB()
 for index in links:
  var ratio=float(index)/(links-1)
  var position=start.lerp(finish,ratio)-Vector3.UP*(4*sag*ratio*(1-ratio))
  var tangent=(span+Vector3.UP*(4*sag*(2*ratio-1))).normalized()
  var lateral=tangent.cross(Vector3.UP).normalized()
  var vertical=lateral.cross(tangent).normalized()
  var basis=Basis(tangent,vertical,lateral).rotated(tangent,(PI*.5 if index%2 else 0.0))
  basis=basis.scaled_local(Vector3(1,.63,.54)*link_size)
  var transform=Transform3D(basis,position)
  var link_box=transform*link_mesh.get_aabb()
  envelope=link_box if index==0 else envelope.merge(link_box)
  for row in 3:
   var offset=index*12+row*4
   data[offset]=basis.x[row];data[offset+1]=basis.y[row];data[offset+2]=basis.z[row];data[offset+3]=position[row]
 instances.buffer=data;instances.custom_aabb=envelope.grow(.02)
 var mesh=MultiMeshInstance3D.new();mesh.name="IronLinks";mesh.multimesh=instances
 mesh.material_override=chain_iron;chain.add_child(mesh)
 return mesh

static func release(links: MultiMeshInstance3D,duration: float) -> Tween:
 var chain=links.multimesh
 var rest=chain.buffer
 var bounds=chain.custom_aabb
 chain.custom_aabb=bounds.merge(AABB(bounds.position-Vector3.UP*DROP_DISTANCE,bounds.size))
 var motion=links.create_tween()
 motion.tween_method(func(progress):
  var falling=rest.duplicate()
  for index in chain.instance_count:
   var ratio=float(index)/(chain.instance_count-1)
   var delay=ratio*.20
   var drop=clampf((progress-delay)/(1.0-delay),0.0,1.0)
   falling[index*12+7]-=DROP_DISTANCE*drop*drop
  chain.buffer=falling
 ,0.0,1.0,duration)
 return motion
