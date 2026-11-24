extends MultiMeshInstance3D
## The village uses one transparent draw for every chimney in the current view.
const Drift=preload("res://scripts/ambient_drift.gd")
const OUTLET=Vector3(.5,2.01,-.3)
const WIND=Vector2(.84,-.5425864)
const WISPS=6
const LIFETIME=4.8
const TINT=Color("d0cec5")
var vents: Array=[]
var wind: Vector2
var clock: Drift
var instance_data=PackedFloat32Array()

static func vent(position: Vector3,scale_value: float,site: Vector2) -> Dictionary:
 return {"origin":position+OUTLET*scale_value,"scale":scale_value,"phase":fposmod(site.x*.17+site.y*.31,1.0)}

func configure(sites: Array,direction: Vector2,atmosphere: Drift):
 name="ChimneySmoke";vents=sites;wind=direction;clock=atmosphere
 var paint=Drift.appearance_for("dust")
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material_override=paint.material
 multimesh=MultiMesh.new()
 multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
 multimesh.mesh=paint.mesh;multimesh.instance_count=vents.size()*WISPS
 var bounds=AABB(vents[0].origin,Vector3.ZERO)
 for site in vents:
  var bottom=site.origin-Vector3(1.85,.65,1.85)*site.scale
  bounds=bounds.merge(AABB(bottom,Vector3(3.7,3.0,3.7)*site.scale))
 multimesh.custom_aabb=bounds
 instance_data.resize(multimesh.instance_count*16)
 for index in multimesh.instance_count:
  var offset=index*16
  instance_data[offset+12]=TINT.r
  instance_data[offset+13]=TINT.g
  instance_data[offset+14]=TINT.b
 update_from_clock()

func update_from_clock():
 var sideways=Vector2(-wind.y,wind.x)
 for vent_index in vents.size():
  var site=vents[vent_index]
  for index in WISPS:
   var phase=fposmod(clock.elapsed/LIFETIME+site.phase+float(index)/WISPS,1.0)
   var curl=sideways*sin(phase*TAU+site.phase*TAU)*.20*phase
   var drift=wind*(phase*phase*1.05)+curl
   var point=site.origin+Vector3(drift.x,.04+phase*1.60,drift.y)*site.scale
   var width=(.18+.75*phase)*site.scale
   var offset=(vent_index*WISPS+index)*16
   instance_data[offset]=width*1.08
   instance_data[offset+5]=width*.82
   instance_data[offset+10]=width
   instance_data[offset+3]=point.x
   instance_data[offset+7]=point.y
   instance_data[offset+11]=point.z
   instance_data[offset+15]=smoothstep(0,.14,phase)*(1-smoothstep(.53,1,phase))*.52
 multimesh.buffer=instance_data

func _process(_dt):
 if is_visible_in_tree():update_from_clock()
