extends Node3D
# Sparse chapter atmosphere uses one instanced mesh and its own deterministic
# seed. It has no collision, lights, shadows or access to campaign randomness.
const THEMES=["village","river","forest","abbey","road","harbor","mountain","aqueduct","observatory","furnace","castle","engine"]
var kind="dust"
var extent=Vector3(20,3,16)
var states: Array=[]
var cloud: MultiMeshInstance3D
var elapsed=0.0
var instance_buffer=PackedFloat32Array()

func configure(theme: String,dimensions: Vector3,arena=false,seed_value=0):
 name="AmbientDrift";extent=dimensions
 kind="leaves" if theme in ["forest","road"] else "embers" if theme in ["furnace","engine"] else "aether" if theme=="observatory" else "dust"
 var count=(26 if arena else 18) if kind=="leaves" else (32 if arena else 22) if kind=="embers" else (24 if arena else 14)
 var random=RandomNumberGenerator.new();random.seed=7139+maxi(0,THEMES.find(theme))*4096+int(seed_value)
 var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1;material.disable_fog=true
 var shape: Mesh
 if kind=="leaves":
  shape=leaf_mesh();material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
 else:
  var quad=QuadMesh.new();quad.size=Vector2.ONE;shape=quad
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true
  material.albedo_texture=preload("res://scripts/combat_impact.gd").radial_texture()
  if kind in ["embers","aether"]:material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 cloud=MultiMeshInstance3D.new();cloud.name="DriftInstances";add_child(cloud)
 cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cloud.material_override=material
 var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_colors=true;instances.mesh=shape;instances.instance_count=count
 instances.custom_aabb=AABB(Vector3(-extent.x*.5,-.2,-extent.z*.5),extent+Vector3(0,.4,0));cloud.multimesh=instances
 instance_buffer.resize(count*16)
 for i in range(count):
  var color=Color("9cab73") if kind=="leaves" and theme=="forest" else Color("c4ac75") if kind=="leaves" else Color("f4af66") if kind=="embers" else Color("b3d4dc") if kind=="aether" else Color("e7dcc1")
  color=color.lerp(Color("efdab3"),random.randf_range(0,.25))
  states.append({"x":random.randf_range(-.23,.23),"z":random.randf_range(-.35,.35),"phase":random.randf(),"life":random.randf_range(7,12) if kind=="leaves" else random.randf_range(5,9),"spin":random.randf_range(-2,2),"scale":random.randf_range(.09,.14) if kind=="leaves" else random.randf_range(.04,.075),"color":color})
 update_particles()

static func leaf_mesh() -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[Vector3(-.26,0,0),Vector3(0,.7,0),Vector3(.26,0,0),Vector3(0,-.55,0)]
 for i in range(4):
  for point in [points[i],points[(i+1)%4],Vector3(0,0,-.07)]:surface.add_vertex(point)
 surface.generate_normals();return surface.commit()

func particle_position(state: Dictionary,phase: float) -> Vector3:
 var height=(1-phase) if kind=="leaves" else phase
 return Vector3((state.x+(phase-.5)*.42)*extent.x,.15+height*(extent.y-.3),(state.z+sin(phase*TAU+state.spin)*.08)*extent.z)

func update_particles():
 for i in range(states.size()):
  var state=states[i];var phase=fposmod(state.phase+elapsed/state.life,1)
  var rotation=Vector3(phase*TAU+state.spin,phase*TAU*state.spin,state.spin) if kind=="leaves" else Vector3.ZERO
  var basis=Basis.from_euler(rotation).scaled(Vector3.ONE*state.scale);var point=particle_position(state,phase)
  var color=state.color
  color.a=smoothstep(0,.12,phase)*(1-smoothstep(.82,1,phase))*(.7 if kind=="leaves" else .65 if kind=="embers" else .35)
  # MultiMesh's public bulk format is three matrix rows plus RGBA. One upload
  # also remains inspectable under the headless renderer's limited readback.
  for row in range(3):
   var offset=i*16+row*4
   instance_buffer[offset]=basis.x[row];instance_buffer[offset+1]=basis.y[row];instance_buffer[offset+2]=basis.z[row];instance_buffer[offset+3]=point[row]
  instance_buffer[i*16+12]=color.r;instance_buffer[i*16+13]=color.g;instance_buffer[i*16+14]=color.b;instance_buffer[i*16+15]=color.a
 cloud.multimesh.buffer=instance_buffer

func _process(dt):
 if not is_visible_in_tree() or cloud==null:return
 elapsed+=dt;update_particles()
