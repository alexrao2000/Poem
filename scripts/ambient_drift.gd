extends Node3D
# Sparse chapter atmosphere uses one instanced mesh and a private seed. Greywood
# rain and Windscar’s low crosswind appear on the map and in the arena.
const THEMES=["village","river","forest","abbey","road","harbor","mountain","aqueduct","observatory","furnace","castle","engine"]
static var unit_quad: QuadMesh
static var appearances: Dictionary={}
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
 var style=appearance_for(kind)
 cloud=MultiMeshInstance3D.new();cloud.name="DriftInstances";add_child(cloud)
 cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cloud.material_override=style.material
 var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_colors=true
 instances.mesh=style.mesh;instances.instance_count=count
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
  # Color and most transform components stay fixed for the life of the cloud.
  var offset=i*16
  var fixed_scale=Vector3.ONE*states[i].scale
  if kind=="wind":fixed_scale*=Vector3(1,.70,1)
  write_basis(offset,Basis.from_euler(Vector3.ZERO).scaled(fixed_scale))
  instance_buffer[offset+12]=color.r
  instance_buffer[offset+13]=color.g
  instance_buffer[offset+14]=color.b
 update_particles()

static func appearance_for(particle_kind: String) -> Dictionary:
 var additive=particle_kind in ["embers","aether"]
 var style="additive" if additive else particle_kind if particle_kind in ["rain","leaves"] else "radial"
 if appearances.has(style):return appearances[style]
 var paint=StandardMaterial3D.new();paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 paint.vertex_color_use_as_albedo=true;paint.vertex_color_is_srgb=true;paint.cull_mode=BaseMaterial3D.CULL_DISABLED
 paint.roughness=1;paint.disable_fog=true
 var shape: Mesh
 if style=="leaves":
  shape=leaf_mesh();paint.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
 else:
  paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  paint.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;paint.billboard_keep_scale=true
  if style=="rain":shape=rain_mesh()
  else:
   if unit_quad==null:
    unit_quad=QuadMesh.new();unit_quad.size=Vector2.ONE
   shape=unit_quad
   paint.albedo_texture=preload("res://scripts/combat_impact.gd").radial_texture()
  if additive:paint.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 var appearance={"mesh":shape,"material":paint}
 appearances[style]=appearance
 return appearance

static func leaf_mesh() -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[Vector3(-.26,0,0),Vector3(0,.7,0),Vector3(.26,0,0),Vector3(0,-.55,0)]
 for i in range(4):
  for point in [points[i],points[(i+1)%4],Vector3(0,0,-.07)]:surface.add_vertex(point)
 surface.generate_normals();return surface.commit()

static func rain_mesh() -> ArrayMesh:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var corners=[Vector3(-.068,.22,0),Vector3(-.045,.22,0),Vector3(.086,-.21,0),Vector3(.062,-.21,0)]
 for index in [0,1,2,0,2,3]:
  surface.set_color(Color(1,1,1,.10 if index<2 else 1))
  surface.add_vertex(corners[index])
 surface.generate_normals();return surface.commit()

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
  var offset=i*16
  if kind=="leaves":
   var rotation=Vector3(phase*TAU+state.spin,phase*TAU*state.spin,state.spin)
   write_basis(offset,Basis.from_euler(rotation).scaled(Vector3.ONE*state.scale))
  elif kind=="wind":
   var dimensions=Vector3.ONE*state.scale
   dimensions*=Vector3(5.2+sin(phase*PI)*2.0,.70,1)
   instance_buffer[offset]=dimensions.x
  var point=particle_position(state,phase)
  instance_buffer[offset+3]=point.x
  instance_buffer[offset+7]=point.y
  instance_buffer[offset+11]=point.z
  instance_buffer[offset+15]=smoothstep(0,.12,phase)*(1-smoothstep(.82,1,phase))*opacity
 cloud.multimesh.buffer=instance_buffer

func write_basis(offset: int,basis: Basis):
 # MultiMesh's bulk layout stores each transform in three rows before RGBA.
 for row in range(3):
  var start=offset+row*4
  instance_buffer[start]=basis.x[row]
  instance_buffer[start+1]=basis.y[row]
  instance_buffer[start+2]=basis.z[row]

func seek_elapsed(value: float):
 elapsed=value
 update_particles()

func _process(dt):
 if not is_visible_in_tree() or cloud==null:return
 elapsed+=dt;update_particles()
