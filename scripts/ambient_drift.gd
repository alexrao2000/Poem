extends Node3D
# Sparse chapter atmosphere uses one instanced mesh and a private seed. Greywood
# rain and Windscar’s low crosswind appear on the map and in the arena.
const THEMES=["village","river","forest","abbey","road","harbor","mountain","aqueduct","observatory","furnace","castle","engine"]
static var rain_streak: ArrayMesh
var kind="dust"
var extent=Vector3(20,3,16)
var states: Array=[]
var cloud: MultiMeshInstance3D
var elapsed=0.0
var instance_buffer=PackedFloat32Array()

func configure(theme: String,dimensions: Vector3,arena=false,seed_value=0):
 name="AmbientDrift";extent=dimensions
 match theme:
  "forest":kind="rain"
  "mountain":kind="wind"
  "road":kind="leaves"
  "furnace","engine":kind="embers"
  "observatory":kind="aether"
  _:kind="dust"
 var count=(26 if arena else 18) if kind=="leaves" else (32 if arena else 22) if kind=="embers" else (24 if arena else 14)
 if kind=="rain":count=56 if arena else 36
 var random=RandomNumberGenerator.new();random.seed=7139+maxi(0,THEMES.find(theme))*4096+int(seed_value)
 var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1;material.disable_fog=true
 var shape: Mesh
 if kind=="leaves":
  shape=leaf_mesh();material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
 else:
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true
  if kind=="rain":shape=rain_mesh()
  else:
   var quad=QuadMesh.new();quad.size=Vector2.ONE;shape=quad
   material.albedo_texture=preload("res://scripts/combat_impact.gd").radial_texture()
  if kind in ["embers","aether"]:material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 cloud=MultiMeshInstance3D.new();cloud.name="DriftInstances";add_child(cloud)
 cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cloud.material_override=material
 var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_colors=true;instances.mesh=shape;instances.instance_count=count
 instances.custom_aabb=AABB(Vector3(-extent.x*.5,-.2,-extent.z*.5),extent+Vector3(0,.4,0));cloud.multimesh=instances
 instance_buffer.resize(count*16)
 for i in range(count):
  var color=Color("c4ac75") if kind=="leaves" else Color("f4af66") if kind=="embers" else Color("b3d4dc") if kind=="aether" else Color("e7dcc1")
  if kind=="rain":
   color=Color("d2e4ef").lerp(Color("c5d3df"),random.randf())
   states.append({"x":random.randf_range(-.42,.42),"z":random.randf_range(-.42,.42),"phase":random.randf(),"life":random.randf_range(.66,1.10),"scale":random.randf_range(.76,1.1),"color":color})
  elif kind=="wind":
   color=Color("d3e0e1").lerp(Color("a4babf"),random.randf())
   states.append({"x":random.randf_range(-.14,.14),"z":random.randf_range(-.35,.35),"phase":random.randf(),
    "life":random.randf_range(3.6,5.6),"scale":random.randf_range(.11,.19),"height":random.randf_range(.26,.83),
    "spin":random.randf_range(-2,2),"color":color})
  else:
   color=color.lerp(Color("efdab3"),random.randf_range(0,.25))
   states.append({"x":random.randf_range(-.23,.23),"z":random.randf_range(-.35,.35),"phase":random.randf(),"life":random.randf_range(7,12) if kind=="leaves" else random.randf_range(5,9),"spin":random.randf_range(-2,2),"scale":random.randf_range(.09,.14) if kind=="leaves" else random.randf_range(.04,.075),"color":color})
 update_particles()

static func leaf_mesh() -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[Vector3(-.26,0,0),Vector3(0,.7,0),Vector3(.26,0,0),Vector3(0,-.55,0)]
 for i in range(4):
  for point in [points[i],points[(i+1)%4],Vector3(0,0,-.07)]:surface.add_vertex(point)
 surface.generate_normals();return surface.commit()

static func rain_mesh() -> ArrayMesh:
 if rain_streak!=null:return rain_streak
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var corners=[Vector3(-.068,.22,0),Vector3(-.045,.22,0),Vector3(.086,-.21,0),Vector3(.062,-.21,0)]
 for index in [0,1,2,0,2,3]:
  surface.set_color(Color(1,1,1,.10 if index<2 else 1))
  surface.add_vertex(corners[index])
 surface.generate_normals()
 rain_streak=surface.commit()
 return rain_streak

func particle_position(state: Dictionary,phase: float) -> Vector3:
 if kind=="rain":
  return Vector3((state.x+(phase-.5)*.044)*extent.x,.15+(1-phase)*(extent.y-.3),state.z*extent.z)
 if kind=="wind":
  var lift=.18+.18*sin(phase*TAU+state.spin)
  return Vector3((state.x+(phase-.5)*.64)*extent.x,state.height+lift,(state.z+.064*sin(phase*TAU))*extent.z)
 var height=(1-phase) if kind=="leaves" else phase
 return Vector3((state.x+(phase-.5)*.42)*extent.x,.15+height*(extent.y-.3),(state.z+sin(phase*TAU+state.spin)*.08)*extent.z)

func update_particles():
 var opacity=.23 if kind=="rain" else .7 if kind=="leaves" else .65 if kind=="embers" else .35
 if kind=="wind":opacity=.27
 for i in range(states.size()):
  var state=states[i];var phase=fposmod(state.phase+elapsed/state.life,1)
  var rotation=Vector3(phase*TAU+state.spin,phase*TAU*state.spin,state.spin) if kind=="leaves" else Vector3.ZERO
  var dimensions=Vector3.ONE*state.scale
  if kind=="wind":
   var stretch=5.2+sin(phase*PI)*2.0
   dimensions*=Vector3(stretch,.70,1)
  var basis=Basis.from_euler(rotation).scaled(dimensions);var point=particle_position(state,phase)
  var color=state.color
  color.a=smoothstep(0,.12,phase)*(1-smoothstep(.82,1,phase))*opacity
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
