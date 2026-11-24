extends RefCounted
const MapSurface=preload("res://scripts/map_surface.gd")
const RiverBank=preload("res://scripts/river_bank.gd")
const RiverChain=preload("res://scripts/river_chain.gd")
const MapGround=preload("res://scripts/map_ground.gd")
const WindCloth=preload("res://scripts/wind_cloth.gd")
const Architecture=preload("res://scripts/architecture.gd")
const Fortification=preload("res://scripts/fortification.gd")
const Fountain=preload("res://scripts/fountain.gd")
const AmbientDrift=preload("res://scripts/ambient_drift.gd")
const ChimneySmoke=preload("res://scripts/chimney_smoke.gd")
const GroundCover=preload("res://scripts/ground_cover.gd")
const ConiferCrowns=preload("res://scripts/conifer_crowns.gd")
const BarrelVisuals=preload("res://scripts/barrel_visuals.gd")
const HarborBoat=preload("res://scripts/harbor_boat.gd")
const HarborNet=preload("res://scripts/harbor_net.gd")
const HarborSignal=preload("res://scripts/harbor_signal.gd")
const HarborBreakwater=preload("res://scripts/harbor_breakwater.gd")
const HarborGulls=preload("res://scripts/harbor_gulls.gd")
const ArenaRidges=preload("res://scripts/arena_ridges.gd")
const PassEscarpment=preload("res://scripts/pass_escarpment.gd")
const RuinedColumns=preload("res://scripts/ruined_columns.gd")
const SanctuaryPlinth=preload("res://scripts/sanctuary_plinth.gd")
const TrailLanterns=preload("res://scripts/trail_lanterns.gd")
const GreywoodShelter=preload("res://scripts/greywood_shelter.gd")
const CinderfordMarket=preload("res://scripts/cinderford_market.gd")
const CinderfordStream=preload("res://scripts/cinderford_stream.gd")
const ReedTollhouse=preload("res://scripts/reed_tollhouse.gd")
const AbbeyMosaic=preload("res://scripts/abbey_mosaic.gd")
const ABBEY_GROVE_SITES=[
 Vector2(-7.9,-1.54),Vector2(-5.4,-.60),Vector2(-2.7,-1.70),Vector2(-1.05,-.43),
 Vector2(1.65,-1.50),Vector2(4.65,-.85),Vector2(6.85,-1.50),Vector2(8.15,-.55),
]
const KingsroadHoist=preload("res://scripts/kingsroad_hoist.gd")
const StarfallChart=preload("res://scripts/starfall_chart.gd")
const StarfallTerrain=preload("res://scripts/starfall_terrain.gd")
const AqueductWheel=preload("res://scripts/aqueduct_waterwheel.gd")
const AqueductReservoir=preload("res://scripts/aqueduct_reservoir.gd")
const ReddeepCart=preload("res://scripts/reddeep_slag_cart.gd")
const HearthFire=preload("res://scripts/hearth_fire.gd")
const ReddeepWorks=preload("res://scripts/reddeep_works.gd")
const ARENA_GROVE_CACHE_LIMIT=4
const EngineConduits=preload("res://scripts/sun_engine_conduits.gd")
const MAX_CACHED_CYLINDERS=256
const HOUSE_SCALE=1.2
const VILLAGE_HOUSE_BACKDROP_SCALE=1.7
const ROAD_CANAL_NEAR=-5.0
const ROAD_CANAL_FAR=-13.0
const MAP_WATER_LEVEL=-.07
const ROAD_CANAL_LEVEL=-.11
const HARBOR_QUAY_EDGE=-5.4
const HARBOR_QUAY_LEVEL=-.11
const MILL_MAP_SITE=Vector3(8.25,-.15,-2.85)
const MILL_ARENA_SITE=Vector3(-9,0,-13)
const MILL_ALTERNATE_SITE=Vector3(-2,0,-15)
const MILL_DISTANT_SITE=Vector3(-9,0,-21)
const PASS_BEACON_SITES={
 "PassBeaconWest":{"field":Vector2(-8.13,-.35),"arena":Vector2(-3.1,-4.25)},
 "PassBeaconEast":{"field":Vector2(12.57,-.98),"arena":Vector2(8.2,-4.68)},
}
# Left and right roadside groves lead into a lower, more distant orchard.
const VILLAGE_TREES=[
 {"position":Vector2(-15.7,-8.8),"scale":2.3},
 {"position":Vector2(-17.4,-13.1),"scale":2.55},
 {"position":Vector2(-12.0,-14.4),"scale":2.4},
 {"position":Vector2(15.5,-9.1),"scale":2.37},
 {"position":Vector2(18.6,-11.8),"scale":2.65},
 {"position":Vector2(11.7,-15.1),"scale":2.4},
 {"position":Vector2(-18.9,-22.3),"scale":2.95},
 {"position":Vector2(-13.7,-24.8),"scale":2.7},
 {"position":Vector2(-9.9,-22.6),"scale":2.45},
 {"position":Vector2(-5.2,-24.3),"scale":2.68},
 {"position":Vector2(.2,-25.0),"scale":2.55},
 {"position":Vector2(5.5,-22.5),"scale":2.37},
 {"position":Vector2(9.8,-25.1),"scale":2.55},
 {"position":Vector2(14.8,-21.9),"scale":2.7},
 {"position":Vector2(19.1,-24.1),"scale":2.9},
]
enum BuildingFinish { LIME_PLASTER, OCHRE_PLASTER, OAK, DECK_WOOD }
const BUILDING_FINISHES=[
 {"color":Color("c5bca4"),"scale":.66,"weight":.66},
 {"color":Color("b19e80"),"scale":.60,"weight":.56},
 {"color":Color("655240"),"scale":.64,"weight":.68},
 {"color":Color("8b7a68"),"scale":.70,"weight":.62},
]
const WATER_STYLES={
 "river":{"deep_color":Color("28453b"),"crest_color":Color("a4b593"),"flow_direction":Vector2(0,1),"wave_scale":Vector2(.94,1.08),"wave_speed":1.14,"crest_strength":.31},
 "road":{"deep_color":Color("285054"),"crest_color":Color("a3b8a6"),"flow_direction":Vector2(1,0),"wave_scale":Vector2(.83,.92),"wave_speed":.86,"crest_strength":.30},
 "harbor":{"deep_color":Color("263945"),"crest_color":Color("b4ad98"),"flow_direction":Vector2(.8,.6),"wave_scale":Vector2(.51,.62),"wave_speed":.54,"crest_strength":.43},
 "aqueduct":{"deep_color":Color("425654"),"crest_color":Color("94a29b"),"flow_direction":Vector2(1,0),"wave_scale":Vector2(.82,1.4),"wave_speed":.42,"crest_strength":.24},
 "furnace":{"deep_color":Color("404144"),"crest_color":Color("be9675"),"flow_direction":Vector2(0,1),"wave_scale":Vector2(.72,1.02),"wave_speed":.47,"crest_strength":.27},
 "engine":{"deep_color":Color("354351"),"crest_color":Color("91a9b8"),"flow_direction":Vector2(.6,.8),"wave_scale":Vector2(.64,.76),"wave_speed":.34,"crest_strength":.29},
}
# Shared landscape construction for the tactical board and battle stage.
# Masonry spans use closed wedge stones with small joints and an open underside.
var materials: Dictionary = {}
var batching_enabled=true
var batcher=preload("res://scripts/static_batch.gd").new()
var ground_cover=GroundCover.new()
var conifer_crowns=ConiferCrowns.new()
var reddeep_works=ReddeepWorks.new()
var arena_groves: Dictionary={}
var unit_block=BoxMesh.new()
var leaf_card=QuadMesh.new()
var planes: Dictionary={}
var cylinders: Dictionary={}
var cylinder_environment=""
static var arch_shapes: Dictionary={}
static var aqueduct_fall: ArrayMesh
var atlas: Texture2D
var environment_atlas: Texture2D
var foliage_atlas: Texture2D
var building_atlas: Texture2D

func _init():
 atlas=load("res://assets/art/terrain-atlas.png")
 environment_atlas=load("res://assets/art/environment-atlas.png")
 foliage_atlas=load("res://assets/art/foliage-cards-v1.png")

func detail_material(tile: int) -> ShaderMaterial:
 var key="detail"+str(tile)
 if materials.has(key):return materials[key]
 var shader=Shader.new()
 shader.code="""shader_type spatial;
 uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
 uniform vec2 quadrant;
 void fragment() {
  ALBEDO=texture(atlas_texture,UV*0.496+0.002+quadrant).rgb*vec3(0.91,0.94,0.91);
  ROUGHNESS=0.9;
 }
 """
 var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("atlas_texture",environment_atlas)
 m.set_shader_parameter("quadrant",Vector2((tile%2)*.5,(tile/2)*.5));materials[key]=m
 return m

func water_material(theme="") -> ShaderMaterial:
 var style=WATER_STYLES.get(theme,{})
 var key="water" if style.is_empty() else "water_"+theme
 if not materials.has(key):
  var m=ShaderMaterial.new()
  m.shader=preload("res://assets/shaders/water.gdshader")
  for parameter in style:m.set_shader_parameter(parameter,style[parameter])
  materials[key]=m
 return materials[key]

func add_river_foam(parent: Node3D,position: Vector3,shape: ArrayMesh,arena=false):
 if shape==null:return
 var key="river_foam_arena" if arena else "river_foam_map"
 if not materials.has(key):
  var paint=ShaderMaterial.new();paint.shader=preload("res://assets/shaders/river_foam.gdshader")
  paint.set_shader_parameter("flow_direction",Vector2.RIGHT if arena else Vector2.DOWN)
  paint.set_shader_parameter("foam_depth",RiverBank.FOAM_DEPTH)
  materials[key]=paint
 var foam=mesh(parent,shape,position,Vector3.ONE,materials[key]);foam.name="RiverFoam"
 foam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func building_material(finish: int) -> ShaderMaterial:
 var key="building"+str(finish)
 if not materials.has(key):
  if building_atlas==null:building_atlas=load("res://assets/art/plaster-timber-v1.png")
  var style=BUILDING_FINISHES[finish]
  var paint=ShaderMaterial.new()
  paint.shader=preload("res://assets/shaders/plaster-timber.gdshader")
  paint.set_shader_parameter("atlas_texture",building_atlas)
  paint.set_shader_parameter("cell_origin",Vector2((finish%2)*.5,.5 if finish>=2 else 0.0))
  paint.set_shader_parameter("base_color",style.color)
  paint.set_shader_parameter("tile_scale",style.scale)
  paint.set_shader_parameter("paint_weight",style.weight)
  materials[key]=paint
 return materials[key]

func material(color: Color) -> StandardMaterial3D:
 var key=color.to_html()
 if materials.has(key):return materials[key]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.95
 materials[key]=m
 return m

func ground_material(tile: int,rain_soaked=false,ash_paving=false) -> ShaderMaterial:
 var key="ground"+str(tile)+("_rain" if rain_soaked else "")+("_ash" if ash_paving else "")
 if materials.has(key):return materials[key]
 var shader=preload("res://assets/shaders/ground.gdshader")
 var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("atlas_texture",atlas)
 m.set_shader_parameter("quadrant",Vector2((tile%2)*.5,(tile/2)*.5))
 if rain_soaked:m.set_shader_parameter("rain_soaked",true)
 if ash_paving:m.set_shader_parameter("ash_paving",true)
 if tile in [0,2]:
  m.set_shader_parameter("wang_enabled",true)
  m.set_shader_parameter("natural_surface",0 if tile==0 else 1)
  m.set_shader_parameter("wang_scale",float(atlas.get_width())/512.0)
  m.set_shader_parameter("wang_texture",load("res://assets/art/terrain-wang.png"))
 materials[key]=m
 return m

func mesh(parent: Node3D,shape: Mesh,p: Vector3,scale_value: Vector3,m: Material) -> MeshInstance3D:
 var n=MeshInstance3D.new();n.mesh=shape;n.position=p;n.scale=scale_value;n.material_override=m;parent.add_child(n);return n

func block(parent,p,size,paint):
 return mesh(parent,unit_block,p,size,paint if paint is Material else material(paint))

func timber_span(parent: Node3D,first: Vector3,last: Vector3,section: Vector2,paint: Material) -> MeshInstance3D:
 var span=block(parent,(first+last)*.5,Vector3(section.x,first.distance_to(last),section.y),paint)
 span.quaternion=Quaternion(Vector3.UP,(last-first).normalized())
 return span

func plane_shape(size: Vector2) -> PlaneMesh:
 if not planes.has(size):
  var shape=PlaneMesh.new()
  shape.size=size
  planes[size]=shape
 return planes[size]

func ground(parent,p,size,tile,blended: Material=null):
 return mesh(parent,plane_shape(size),p,Vector3.ONE,blended if blended!=null else ground_material(tile))

func cylinder(parent,p,height,radius,color,top=-1.0):
 var upper_radius=radius if top<0 else top
 var key=Vector3(height,radius,upper_radius)
 var shape=cylinders.get(key) as CylinderMesh
 if shape==null:
  shape=CylinderMesh.new();shape.height=height;shape.bottom_radius=radius
  shape.top_radius=upper_radius;shape.radial_segments=8
  if cylinders.size()<MAX_CACHED_CYLINDERS:cylinders[key]=shape
 return mesh(parent,shape,p,Vector3.ONE,material(color))

func boulder(parent,p,radius):
 var forms=preload("res://scripts/rock_forms.gd")
 var rock=mesh(parent,forms.mesh(forms.variant_at(p)),p,Vector3(radius,radius*.6,radius*.8),ground_material(1))
 rock.name="Boulder";return rock

func arch_span(parent,p,inner_radius=.5,thickness=.4,depth=.6):
 var key=Vector3(inner_radius,thickness,depth)
 if not arch_shapes.has(key):
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  var uv=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
  for segment in range(11):
   var a=segment*PI/11+.008;var b=(segment+1)*PI/11-.008
   var points=[]
   for z in [depth*.5,-depth*.5]:
    for entry in [[a,inner_radius],[a,inner_radius+thickness],[b,inner_radius+thickness],[b,inner_radius]]:
     points.append(Vector3(cos(entry[0])*entry[1],sin(entry[0])*entry[1],z))
   for face in [[0,1,2,3],[7,6,5,4],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
    for i in [0,1,2,0,2,3]:
     surface.set_uv(uv[i]);surface.add_vertex(points[face[i]])
  surface.generate_normals()
  arch_shapes[key]=surface.commit()
 var span=mesh(parent,arch_shapes[key],p,Vector3.ONE,detail_material(3));span.name="MasonryArch"
 return span

func tree(parent,p,seed_value=0,theme=""):
 if theme=="mountain" or (theme=="forest" and seed_value%4!=0):
  conifer(parent,p,seed_value,theme)
  return
 var rng=RandomNumberGenerator.new();rng.seed=seed_value+997
 var h=rng.randf_range(1.45,2.1)
 var trunk=cylinder(parent,p+Vector3(0,h*.32,0),h*.72,.075,Color.WHITE,.035)
 trunk.material_override=detail_material(2)
 for i in range(8):
  var angle=i*2.399
  var center=p+Vector3(cos(angle)*(.22+rng.randf()*.18),h*.65+float(i%3)*.18,sin(angle)*(.22+rng.randf()*.16))
  var leaf_type=2 if seed_value%5==0 else (seed_value+i)%2
  for card in range(3):
   var size=Vector2(1.15+rng.randf()*.18,1.0+rng.randf()*.15)
   var shape=leaf_card
   var card_scale=Vector3(size.x,size.y,1)
   if not batching_enabled:
    # Unbatched wind runs in the card's local units.
    shape=QuadMesh.new();shape.size=size;card_scale=Vector3.ONE
   var n=mesh(parent,shape,center,card_scale,foliage_material(leaf_type))
   n.rotation=Vector3(-1.05 if card==2 else -.25,angle+card*PI*.5,rng.randf_range(-.15,.15))
  var base=p+Vector3(0,h*.38,0)
  var branch=cylinder(parent,(base+center)*.5,base.distance_to(center),.03,Color.WHITE,.012)
  branch.quaternion=Quaternion(Vector3.UP,(center-base).normalized());branch.material_override=detail_material(2)

func conifer(parent,p,seed_value,theme):
 var rng=RandomNumberGenerator.new();rng.seed=seed_value+12043
 var mountain=theme=="mountain"
 var variant=seed_value%2+(2 if mountain else 0)
 var height=rng.randf_range(1.26,1.57) if mountain else rng.randf_range(1.44,1.72)
 var stem_height=height*.76
 var trunk=cylinder(parent,p+Vector3(0,stem_height*.5,0),stem_height,height*.043,Color.WHITE,height*.009)
 trunk.name="ConiferTrunk"
 trunk.material_override=detail_material(2)
 var crown=mesh(parent,conifer_crowns.shape(variant),p,Vector3.ONE*height,conifer_crowns.material())
 crown.name="ConiferCrown"
 crown.rotation.y=rng.randf()*TAU
 crown.extra_cull_margin=.02
 crown.set_meta("conifer_variant",variant)

func bridge(parent,p,vertical=false):
 var root=Node3D.new();parent.add_child(root);root.position=p
 if vertical:root.rotation.y=PI/2
 var deck=building_material(BuildingFinish.DECK_WOOD)
 for i in range(7):
  block(root,Vector3((i-3)*.145,MapSurface.BRIDGE_HEIGHT-.045,0),Vector3(.135,.09,.98),deck).name="BridgePlank"
 for z in [-.43,.43]:
  block(root,Vector3(0,.25,z),Vector3(1,.07,.055),Color("665747"))
  for x in [-.4,.4]:block(root,Vector3(x,.16,z),Vector3(.065,.4,.065),Color("655444"))
 var supports=building_material(BuildingFinish.OAK)
 for z in [-.27,.27]:
  block(root,Vector3(0,-.061,z),Vector3(1,.12,.11),supports).name="BridgeStringer"
  for x in [-.36,.36]:
   block(root,Vector3(x,-.145,z),Vector3(.105,.21,.115),supports).name="BridgePile"
 for x in [-.36,.36]:
  block(root,Vector3(x,-.11,0),Vector3(.115,.10,.68),supports).name="BridgeCrossbeam"

func sanctuary(parent,p):
 mesh(parent,SanctuaryPlinth.mesh(),p,Vector3.ONE,SanctuaryPlinth.material()).name="SanctuaryPlinth"

func house(parent,p,scale_value=1.0,roof_variant=-1,warehouse=false,vented=false):
 var root=Node3D.new();parent.add_child(root);root.position=p;root.scale=Vector3.ONE*scale_value
 root.name="House"
 if roof_variant<0:roof_variant=Architecture.variant_at(p)
 root.set_meta("roof_variant",roof_variant)
 var plaster=building_material(BuildingFinish.OCHRE_PLASTER if warehouse else BuildingFinish.LIME_PLASTER)
 var oak=building_material(BuildingFinish.OAK)
 block(root,Vector3(0,.6,0),Vector3(1.6,1.2,1.25),plaster).name="PlasterWall"
 # Stone foundation, half-timber braces, door and windows.
 var foundation=block(root,Vector3(0,.08,0),Vector3(1.7,.16,1.34),Color("8b8a79"));foundation.material_override=detail_material(3)
 for x in [-.76,0,.76]:block(root,Vector3(x,.6,.64),Vector3(.06,1.2,.06),oak)
 for y in [.2,.95]:block(root,Vector3(0,y,.64),Vector3(1.6,.055,.055),oak)
 block(root,Vector3(-.3,.39,.67),Vector3(.28,.65,.025),oak)
 block(root,Vector3(.4,.7,.67),Vector3(.27,.3,.025),Color("49616b"))
 for x in [.25,.55]:block(root,Vector3(x,.7,.69),Vector3(.06,.36,.05),Color("7a8379"))
 for y in [.54,.85]:block(root,Vector3(.4,y,.7),Vector3(.37,.045,.045),Color("796854"))
 block(root,Vector3(.4,.7,.71),Vector3(.025,.3,.025),Color("baab8e"))
 block(root,Vector3(-.3,.05,.85),Vector3(.5,.1,.4),Color("a4a18e"))
 for x in [-.48,-.12]:block(root,Vector3(x,.42,.7),Vector3(.05,.72,.05),Color("76624b"))
 block(root,Vector3(-.3,.79,.7),Vector3(.4,.06,.06),Color("76624b"))
 for x in [-.82,.82]:
  for z in [-.48,.48]:block(root,Vector3(x,.6,z),Vector3(.05,1.2,.06),oak)
  for y in [.25,.95]:block(root,Vector3(x,y,0),Vector3(.05,.06,1.25),oak)
 for z in [-.63,.63]:
  var gable=SurfaceTool.new();gable.begin(Mesh.PRIMITIVE_TRIANGLES)
  for point in [Vector3(-.8,1.2,z),Vector3(.8,1.2,z),Vector3(0,1.7,z)]:gable.add_vertex(point)
  gable.generate_normals()
  mesh(root,gable.commit(),Vector3.ZERO,Vector3.ONE,plaster).name="PlasterGable"
  block(root,Vector3(0,1.42,z),Vector3(.065,.55,.06),oak)
 var roof=mesh(root,Architecture.roof(roof_variant),Vector3.ZERO,Vector3.ONE,Architecture.material());roof.name="TiledRoof"
 var chimney=block(root,Vector3(.5,1.6,-.3),Vector3(.23,.7,.25),Color("8d8271"));chimney.material_override=detail_material(3)
 var cap=ChimneySmoke.OUTLET-Vector3.UP*.04
 var cap_color=Color("686c68")
 if vented:
  for side in [-1,1]:
   block(root,cap+Vector3(side*.09875,0,0),Vector3(.0925,.08,.30),cap_color).name="ChimneyRim"
   block(root,cap+Vector3(0,0,side*.10125),Vector3(.105,.08,.0975),cap_color).name="ChimneyRim"
 else:block(root,cap,Vector3(.29,.08,.30),cap_color)
 for z in [-.25,.18]:barrel(root,Vector3(.95,0,z),.75)
 var sign=block(root,Vector3(-.56,.92,.78),Vector3(.28,.18,.045),Color("74634c"));sign.rotation.z=.05
 block(root,Vector3(-.56,.92,.81),Vector3(.12,.025,.01),Color("c2af78"))
 for x in [-.7,.7]:
  var shrub=SphereMesh.new();shrub.radius=.15;shrub.height=.25;shrub.radial_segments=7;shrub.rings=4
  mesh(root,shrub,Vector3(x,.13,.78),Vector3(1,.8,1),detail_material(1))

func landscape(parent,game):
 cylinders.clear();cylinder_environment=""
 # Keep ground under the whole camera envelope, including larger authored maps.
 var board=game.board_size()
 var center=Vector2(board)*.5
 var extent=maxf(72,64*maxf(board.x/14.0,board.y/10.0))
 var ground_paint=MapGround.material(game,atlas)
 var theme=game.info().get("environment","village")
 var outer_paint=ground_material(0) if theme=="abbey" else ground_paint
 if theme=="observatory":
  StarfallTerrain.build_map(self,parent,Vector3(center.x,-.15,center.y),board)
 else:
  if theme=="furnace":outer_paint=ReddeepWorks.ash(self)
  ground(parent,Vector3(center.x,-.15,center.y),Vector2.ONE*extent,0,outer_paint)
 var building_cells={}
 for item in game.info().get("landmarks",[]):
  if item.has("footprint"):
   var area=item.footprint
   for y in range(area[1],area[1]+area[3]):
    for x in range(area[0],area[0]+area[2]):building_cells[Vector2i(x,y)]=true
 if theme=="village":
  CinderfordStream.build(self,parent,game,extent,MAP_WATER_LEVEL)
 elif theme=="river":
  var water=water_material(theme)
  var river=plane_shape(Vector2(2,extent))
  mesh(parent,river,Vector3(5.5,MAP_WATER_LEVEL,center.y),Vector3.ONE,water)
 for y in range(board.y):
  for x in range(board.x):
   var t=game.terrain(Vector2i(x,y));var p=Vector3(x,0,y)
   if t in ["~","="]:
    var water=water_material(theme)
    var water_cell=mesh(parent,plane_shape(Vector2.ONE),p+Vector3.UP*MAP_WATER_LEVEL,Vector3.ONE,water);water_cell.name="MapWater"
    if theme in MapGround.NATURAL and t=="~":
     var bank=RiverBank.build(game,Vector2i(x,y))
     if bank!=null:
      var shore=mesh(parent,bank,p,Vector3.ONE,ground_paint);shore.name="RiverBank"
     if theme=="river":add_river_foam(parent,p,RiverBank.foam_strip(bank,MAP_WATER_LEVEL))
    elif t=="~":
     for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
      if game.terrain(Vector2i(x,y)+direction) not in ["~","=","#"]:
       block(parent,p+Vector3(direction.x*.48,.015,direction.y*.48),Vector3(.08 if direction.x else 1,.16,.08 if direction.y else 1),Color("9d9e8e"))
   else:
    var floor=ground(parent,p,Vector2.ONE,0,ground_paint);floor.name="MapGround"
   if t=="=":bridge(parent,p,theme in ["harbor","road"])
   elif t=="f":tree(parent,p+Vector3(.22,0,-.22),x+y*17,theme)
   elif t=="h":boulder(parent,p+Vector3(.22,0,-.2),.32)
   elif t=="#" and theme=="mountain":boulder(parent,p+Vector3(0,.2,0),.8)
   elif t=="#" and not building_cells.has(Vector2i(x,y)):
    for row in range(3):
     for col in range(3):
      var stone=block(parent,p+Vector3((col-1)*.32+(.04 if row%2 else 0),.17+row*.28,0),Vector3(.3,.26,.7),Color.WHITE)
      stone.material_override=detail_material(3)
   elif t=="o":
    cylinder(parent,p+Vector3(.3,.65,-.3),1.3,.025,Color("a99463"))
    var flag=WindCloth.new();parent.add_child(flag);flag.position=p+Vector3(.3,1.05,-.3)
    flag.configure(Vector2(.45,.32),Color("a54c47"),true,x*.71+y*.37)
   elif t=="+":sanctuary(parent,p)
 # Authored landmarks communicate the chapter instead of a repeated village frame.
 var vents=[]
 for item in game.info().get("landmarks",[]):
  var site=Vector2(item.position[0],item.position[1])
  var position=Vector3(site.x,0,site.y)
  var vented=theme=="village" and item.kind=="house"
  landmark(parent,position,item.kind,-1,Vector2.INF,vented)
  if vented:vents.append(ChimneySmoke.vent(position,HOUSE_SCALE,site))
 if theme=="river":RiverChain.build(self,parent,Vector3(4.32,0,4.52),Vector3(6.68,0,4.52),.44,.25,.105)
 if theme=="village":
  village_mill(parent,MILL_MAP_SITE,.69)
  CinderfordMarket.build(self,parent,Vector3(1.5,0,2.5),.58)
 if theme=="abbey":
  AbbeyMosaic.build(self,parent,AbbeyMosaic.MAP_SITE,1.0)
  abbey_grove(parent,Vector3(center.x-.5,-.15,-2.25),1.0,.84)
 if theme=="harbor":
  HarborNet.build(self,parent,HarborNet.MAP_SITE,HarborNet.MAP_SCALE)
  HarborSignal.build(self,parent,HarborSignal.MAP_SITE,HarborSignal.MAP_SCALE)
 if theme=="road":KingsroadHoist.build(self,parent,KingsroadHoist.MAP_SITE,KingsroadHoist.MAP_SCALE,-.16)
 if theme=="aqueduct":AqueductWheel.new().build(self,parent,AqueductWheel.MAP_SITE,AqueductWheel.MAP_SCALE,-.28)
 if theme=="castle":Fortification.build_map_gate(self,parent)
 if theme=="furnace":
  ReddeepCart.build(self,parent,ReddeepCart.MAP_SITE,ReddeepCart.MAP_SCALE)
  reddeep_works.fringe(self,parent,board)
 if theme=="forest":TrailLanterns.roadside(parent)
 if theme in ["village","river","forest","road","castle"]:
  var base=-.15 if theme in ["forest","village"] else 0.0
  var far_spread=(board.x+9)/23.0
  var near_spread=(board.x+7)/21.0
  for i in range(22):
   var point=Vector3(-4+((i*7)%23)*far_spread,base,-3-(i%3)*1.3)
   tree(parent,CinderfordStream.tree_position(game,point) if theme=="village" else point,i*23,theme)
  for i in range(12):
   var point=Vector3(-3+((i*13)%21)*near_spread,base,board.y+2+i%3)
   tree(parent,CinderfordStream.tree_position(game,point) if theme=="village" else point,i*11,theme)
 elif theme=="mountain":
  var slope=PassEscarpment.build(parent,Vector3((game.board_size().x-1)*.5,-.15,-2.1),Vector3(.72,.66,.77))
  pass_beacons(parent,slope,false)
  PassEscarpment.add_talus(parent,Vector3(center.x-.5,-.15,board.y+.10))
  for i in range(16):boulder(parent,Vector3(-3+(i*5)%22,.2,-3-i%3),2.5)
  for i in range(7):
   var position=Vector3(-3+(i*9)%22,0,-6-i%3)
   position.y=PassEscarpment.height_at(slope,position)
   tree(parent,position,i*31,theme)
 elif theme=="aqueduct":
  AqueductReservoir.build(self,parent,board,extent)
 elif theme=="harbor":
  var sea=plane_shape(Vector2(55,35))
  mesh(parent,sea,Vector3(7,-.12,26),Vector3.ONE,water_material(theme))
  HarborBreakwater.build(self,parent,HarborBreakwater.MAP_SITE,HarborBreakwater.MAP_SCALE,PI)

 ground_cover.add_map(parent,game,building_cells)
 if batching_enabled:batcher.combine(parent)
 cylinders.clear()
 var atmosphere=AmbientDrift.new();parent.add_child(atmosphere)
 atmosphere.position=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 atmosphere.configure(theme,Vector3(game.board_size().x+6,3,game.board_size().y+6),false,game.chapter)
 if theme=="harbor":add_harbor_gulls(atmosphere,HarborBreakwater.MAP_SITE,HarborBreakwater.MAP_SCALE,PI)
 add_chimney_smoke(parent,vents,ChimneySmoke.WIND,atmosphere)

func add_harbor_gulls(atmosphere: AmbientDrift,site: Vector3,size: float,heading: float):
 var flock=HarborGulls.new()
 atmosphere.add_child(flock)
 flock.position=site-atmosphere.position;flock.rotation.y=heading;flock.scale=Vector3.ONE*size
 flock.configure()

func add_chimney_smoke(parent: Node3D,vents: Array,wind: Vector2,atmosphere: AmbientDrift):
 if vents.is_empty():return
 var smoke=ChimneySmoke.new();parent.add_child(smoke)
 smoke.configure(vents,wind,atmosphere)

func landmark(parent,p,kind,roof_variant=-1,map_site=Vector2.INF,vented=false):
 var stone=Color("969b91")
 if kind in ["house","warehouse"]:
  var warehouse=kind=="warehouse"
  house(parent,p,1.4 if warehouse else HOUSE_SCALE,roof_variant,warehouse,vented)
 elif kind=="fountain":
  Fountain.build(parent,p,water_material())
 elif kind=="tower":
  var tower=mesh(parent,Fortification.tower(),p,Vector3.ONE,Fortification.material());tower.name="FortifiedTower"
 elif kind=="tollhouse":
  ReedTollhouse.build(self,parent,p,.82)
 elif kind=="belfry":
  abbey_belfry(parent,p+Vector3(0,-.13,-1.31),1.0)
 elif kind=="spire":
  cylinder(parent,p+Vector3(0,1,0),2,.55,stone)
  cylinder(parent,p+Vector3(0,.15,0),.3,.7,stone.darkened(.15))
  cylinder(parent,p+Vector3(0,2,0),.25,.65,stone.lightened(.08))
  cylinder(parent,p+Vector3(0,2.8,0),1.5,.65,Color("586b75"),0)
 elif kind=="arch":
  for x in [-.7,.7]:
   var pillar=block(parent,p+Vector3(x,.55,0),Vector3(.4,1.1,.6),stone);pillar.material_override=detail_material(3)
   block(parent,p+Vector3(x,.08,0),Vector3(.5,.16,.7),stone.darkened(.1))
  arch_span(parent,p+Vector3(0,1.1,0))
 elif kind=="boat":
  mesh(parent,HarborBoat.hull(),p,Vector3.ONE,BarrelVisuals.material(false)).name="HarborHull"
  cylinder(parent,p+Vector3(0,1.18,0),2.16,.045,Color("685644"),.026).name="BoatMast"
  var yard=cylinder(parent,p+Vector3(.62,2.2,0),1.44,.023,Color("685644"),.014)
  yard.name="BoatYardarm";yard.rotation.z=-PI/2.0
  var sail=WindCloth.new();parent.add_child(sail);sail.position=p+Vector3(0,1.5,0)
  var site=Vector2(p.x,p.z) if map_site==Vector2.INF else map_site
  sail.set_meta("boat_site",site)
  sail.configure(Vector2(1.3,1.4),Color("dcd4b9"),false,site.x*.71+site.y*.37)
  harbor_rigging(parent,p)
 elif kind=="camp":
  GreywoodShelter.build(self,parent,p,.72)
 elif kind=="engine":
  sun_engine(parent,p+Vector3.DOWN*.06,.46)
 elif kind=="observatory":
  observatory(parent,p)
  StarfallChart.build(self,parent,p+Vector3(-1.94,-.15,.27),.66)
 elif kind=="furnace":furnace(parent,p,1.0,map_site)
 elif kind=="ruin":
  var ruin=mesh(parent,RuinedColumns.mesh(),p,Vector3.ONE,Fortification.material())
  ruin.name="RuinMasonry"
  ruin.set_meta("static_batch",true)

func harbor_rigging(parent: Node3D,point: Vector3):
 for line in HarborBoat.RIGGING:
  var direction: Vector3=line[0]-line[1]
  var cleat: Vector3=point+line[1]
  block(parent,cleat-Vector3.UP*.04,Vector3(.13,.12,.095),Color("8d7955")).name="BoatCleat"
  var stay=cylinder(parent,cleat+direction*.5,1.0,.014,Color("51483c"))
  stay.name="BoatStay"
  stay.quaternion=Quaternion(Vector3.UP,direction.normalized())
  stay.scale.y=direction.length()

func observatory(parent: Node3D,point: Vector3,in_arena=false):
 var dais=Node3D.new();dais.name="ObservatoryDais";dais.position=point
 if not in_arena:dais.scale=Vector3(.58,.25,.58)
 parent.add_child(dais)
 cylinder(dais,Vector3(0,-.47,0),1.26,2.18,Color("777771"),2.09).name="MeridianFooting"
 cylinder(dais,Vector3(0,.28,0),.34,1.91,Color("817f76"),1.65).name="MeridianPlinth"
 cylinder(dais,Vector3(0,.48,0),.18,1.68,Color("a19683"),1.59).name="MeridianTable"
 cylinder(dais,Vector3(0,.567,0),.045,1.38,Color("ae925d"),1.35).name="MeridianRim"
 cylinder(dais,Vector3(0,.584,0),.028,1.22,Color("535d63"),1.19).name="MeridianDial"
 for index in 12:
  var angle=index*TAU/12
  var cardinal=index%3==0
  var length=.29 if cardinal else .11
  var radius=1.14-length*.5
  var marker=block(dais,Vector3(sin(angle)*radius,.602,cos(angle)*radius),
   Vector3(.074 if cardinal else .038,.018,length),Color("c6af7e") if cardinal else Color("a99060"))
  marker.name="MeridianTick";marker.rotation.y=angle
 block(dais,Vector3(0,.607,0),Vector3(.086,.024,1.52),Color("c6af7e")).name="MeridianAxis"
 block(dais,Vector3(0,.602,0),Vector3(.95,.016,.065),Color("c6af7e")).name="MeridianAxis"
 var orbit=preload("res://scripts/clockwork_orbit.gd").new()
 parent.add_child(orbit)
 orbit.position=point+Vector3.UP*(2.6 if in_arena else 1.5)
 orbit.configure("observatory",1.54 if in_arena else 1.1,.55)

func furnace(parent: Node3D,p: Vector3,scale_value=1.0,map_site=Vector2.INF):
 var hearth=Node3D.new();hearth.name="FurnaceHearth";hearth.position=p
 hearth.scale=Vector3.ONE*scale_value;parent.add_child(hearth,true)
 var masonry=detail_material(3)
 var iron=material(Color("464148"))
 var brass=material(Color("a58761"))
 block(hearth,Vector3(0,-.025,0),Vector3(1.26,.29,1.02),masonry).name="HearthFoundation"
 block(hearth,Vector3(0,.53,-.39),Vector3(1.12,.87,.14),iron).name="FireboxBack"
 for x in [-.445,.445]:
  block(hearth,Vector3(x,.55,-.05),Vector3(.31,.88,.94),masonry).name="HearthJamb"
 arch_span(hearth,Vector3(0,.48,.36),.29,.17,.19)
 block(hearth,Vector3(0,1.02,-.025),Vector3(1.17,.25,.91),masonry).name="HearthHood"
 block(hearth,Vector3(0,1.22,-.075),Vector3(.84,.22,.68),iron).name="FlueShoulder"
 block(hearth,Vector3(0,1.31,-.08),Vector3(.63,.08,.59),brass).name="FlueCollar"
 for side in [-1,1]:
  block(hearth,Vector3(side*.245,1.76,-.08),Vector3(.09,.92,.52),iron).name="ChimneySide"
  block(hearth,Vector3(0,1.76,-.08+side*.215),Vector3(.40,.92,.09),iron).name="ChimneySide"
  block(hearth,Vector3(side*.245,2.23,-.08),Vector3(.13,.09,.56),brass).name="ChimneyLip"
  block(hearth,Vector3(0,2.23,-.08+side*.215),Vector3(.36,.09,.13),brass).name="ChimneyLip"
 for slot in range(-2,3):
  block(hearth,Vector3(slot*.105,.255,.428),Vector3(.028,.28,.045),iron).name="FurnaceGrate"
 block(hearth,Vector3(0,.34,.432),Vector3(.60,.044,.052),iron).name="GrateCrossbar"
 if not materials.has("furnace_coals"):
  var coals=StandardMaterial3D.new()
  coals.albedo_color=Color("a84f25");coals.emission_enabled=true;coals.emission=Color("ed7735")
  materials["furnace_coals"]=coals
 for i in range(7):
  var coal=block(hearth,Vector3((i%3-1)*.14,.15+i%2*.028,.24-floori(i/3.0)*.20),Vector3(.149,.10,.165),materials["furnace_coals"])
  coal.name="HearthCoal";coal.rotation=Vector3(.17*(i%3-1),i*.9,.14*(i%2))
 var fire=HearthFire.new();hearth.add_child(fire)
 fire.configure(Vector2(p.x,p.z) if map_site==Vector2.INF else map_site)

func combat_context(game,a,b,screen_direction=1.0) -> Dictionary:
 var midpoint=Vector2(a.x+b.x,a.y+b.y)*.5
 var axis=Vector2(b.x-a.x,b.y-a.y).normalized()
 if axis.is_zero_approx():axis=Vector2.RIGHT
 axis*=screen_direction
 var depth=Vector2(-axis.y,axis.x)
 var theme=game.info().get("environment","village")
 var tile=game.terrain(game.pos(b))
 var near_water=theme in ["road","harbor"] and nearby_channel(game,midpoint)
 var harbor_quayside=theme=="harbor" and tile!="=" and near_water
 var candidates=[]
 var tollhouse_x=INF
 for item in game.info().get("landmarks",[]):
  if theme=="harbor" and item.kind=="boat" and tile!="=" and not harbor_quayside:continue
  var site=Vector2(item.position[0],item.position[1])
  var delta=site-midpoint
  if delta.length()>8:continue
  if item.kind=="tollhouse":
   tollhouse_x=clampf(delta.dot(axis)*2.2-6.3,-10,-4)
   continue
  candidates.append({"kind":item.kind,"map_site":site,"roof_variant":Architecture.variant_at(Vector3(site.x,0,site.y)),"distance":delta.length(),"x":clampf(delta.dot(axis)*2.2,-11,11),"z":-7-clampf(absf(delta.dot(depth))*1.8,0,10)})
 candidates.sort_custom(func(left,right):return left.distance<right.distance)
 var context={"chapter":game.chapter,"environment":theme,"terrain":tile,
  "landmarks":candidates.slice(0,2),"road_canal":theme=="road" and near_water,"harbor_quay":harbor_quayside}
 if theme=="village":context.chimney_wind=Vector2(ChimneySmoke.WIND.dot(axis),ChimneySmoke.WIND.dot(depth))
 if context.road_canal:
  context.road_hoist=midpoint.distance_to(Vector2(KingsroadHoist.MAP_SITE.x,KingsroadHoist.MAP_SITE.z))<=3.5
 if theme=="castle":
  context.raised_gate=midpoint.distance_to(Vector2(Fortification.MAP_GATE_SITE.x,Fortification.MAP_GATE_SITE.z))<=4.0
 if theme=="furnace" and tile!="=":
  context.slag_cart=midpoint.distance_to(Vector2(ReddeepCart.MAP_SITE.x,ReddeepCart.MAP_SITE.z))<=3.3
 if is_finite(tollhouse_x):context.tollhouse_x=tollhouse_x
 if theme=="abbey" and tile=="p" and midpoint.distance_to(Vector2(AbbeyMosaic.MAP_SITE.x,AbbeyMosaic.MAP_SITE.z))<=3.0:
  context.mosaic_yaw=atan2(axis.y,axis.x)
 return context

func transfer_environment_motion(source: Node3D,destination: Node3D,theme: String):
 var previous_drift=source.get_node_or_null("AmbientDrift") as AmbientDrift
 var next_drift=destination.get_node_or_null("AmbientDrift") as AmbientDrift
 if previous_drift!=null and next_drift!=null and previous_drift.kind==next_drift.kind:
  next_drift.seek_elapsed(previous_drift.elapsed)
 if theme=="village":
  var smoke=destination.get_node_or_null("ChimneySmoke") as ChimneySmoke
  if smoke!=null:smoke.update_from_clock()
  var original=source.get_node_or_null("CinderfordMill/MillRotor")
  var counterpart=destination.get_node_or_null("CinderfordMill/MillRotor")
  if original!=null and counterpart!=null:counterpart.rotation.z=original.rotation.z
 elif theme in ["observatory","engine"]:
  var original=source.find_child("ClockworkOrbit",true,false)
  var counterpart=destination.find_child("ClockworkOrbit",true,false)
  if original!=null and counterpart!=null:
   counterpart.elapsed=original.elapsed
   counterpart.update_motion()
 elif theme=="aqueduct":
  var original=source.get_node_or_null("AqueductWaterwheel")
  var counterpart=destination.get_node_or_null("AqueductWaterwheel")
  if original!=null and counterpart!=null:counterpart.seek_phase(original.phase)
 elif theme=="castle":
  for standard in ["WindStandardLeft","WindStandardRight"]:
   var address="CastleGate/"+standard
   var original=source.get_node_or_null(address)
   var counterpart=destination.get_node_or_null(address)
   if original!=null and counterpart!=null:counterpart.seek_phase(original.phase)
 elif theme=="abbey":
  var original=source.get_node_or_null("EmptyBelfry/AbbeyBanner")
  var counterpart=destination.get_node_or_null("EmptyBelfry/AbbeyBanner")
  if original!=null and counterpart!=null:counterpart.seek_phase(original.phase)
 elif theme=="harbor":
  var flock=destination.get_node_or_null("AmbientDrift/HarborGulls")
  if flock!=null:flock.update_from_clock()
  var originals=boat_sails(source)
  var counterparts=boat_sails(destination)
  for site in counterparts:
   if originals.has(site):counterparts[site].seek_phase(originals[site].phase)
 elif theme=="mountain":
  for name in PASS_BEACON_SITES:
   var path=NodePath(name+"/BeaconFlame")
   var original=source.get_node_or_null(path)
   var counterpart=destination.get_node_or_null(path)
   if original!=null and counterpart!=null:counterpart.seek_phase(original.phase)
 elif theme=="furnace":
  var originals={}
  for fire in source.find_children("HearthFire","Node3D",true,false):
   originals[fire.get_meta("hearth_site")]=fire
  for fire in destination.find_children("HearthFire","Node3D",true,false):
   var original=originals.get(fire.get_meta("hearth_site"))
   if original!=null:fire.seek_phase(original.phase)

func boat_sails(parent: Node3D) -> Dictionary:
 var sails={}
 for node in parent.find_children("*","Node3D",true,false):
  if node is WindCloth and node.has_meta("boat_site"):
   sails[node.get_meta("boat_site")]=node
 return sails

func nearby_channel(game,midpoint: Vector2) -> bool:
 var nearest=Vector2i(midpoint.round())
 for y in range(nearest.y-2,nearest.y+3):
  for x in range(nearest.x-2,nearest.x+3):
   if midpoint.distance_squared_to(Vector2(x,y))<=4 and game.terrain(Vector2i(x,y))=="~":
    return true
 return false

func battle_tree(parent,point,seed_value,scale_value,theme=""):
 var group=Node3D.new();group.name="ArenaTree";group.position=point;group.scale=Vector3.ONE*scale_value;parent.add_child(group,true)
 tree(group,Vector3.ZERO,seed_value,theme)

func village_trees(parent: Node3D,center: Vector3,house_sites: Array):
 var sites=[]
 for index in VILLAGE_TREES.size():
  var tree_site=VILLAGE_TREES[index];var position=tree_site.position
  if house_sites.any(func(site):return absf(position.x-site.x)<4.7 and position.y>site.y-4.5):
   continue
  sites.append([center+Vector3(position.x,0,position.y),index*83,tree_site.scale])
 arena_grove(parent,sites,"village")

func arena_grove(parent: Node3D,sites: Array,theme: String):
 if not batching_enabled:
  for site in sites:battle_tree(parent,site[0],site[1],site[2],theme)
  return
 if sites.is_empty():return
 var grove=Node3D.new();grove.name="ArenaGrove";parent.add_child(grove)
 # A repeat fight reuses the baked foliage while its shader evaluates wind at each world position.
 var key=[theme,sites]
 var cached=arena_groves.get(key)
 if cached!=null:
  for surface in cached:
   var branch=mesh(grove,surface.mesh,Vector3.ZERO,Vector3.ONE,surface.material)
   branch.set_meta("static_batch",true)
   branch.cast_shadow=surface.shadow;branch.layers=surface.layers;branch.extra_cull_margin=surface.cull_margin
  return
 for site in sites:battle_tree(grove,site[0],site[1],site[2],theme)
 batcher.combine(grove)
 var surfaces=[]
 for child in grove.get_children():
  if child is MeshInstance3D:
   surfaces.append({"mesh":child.mesh,"material":child.material_override,"shadow":child.cast_shadow,
    "layers":child.layers,"cull_margin":child.extra_cull_margin})
  elif child.get_child_count()==0:
   grove.remove_child(child);child.queue_free()
 if arena_groves.size()>=ARENA_GROVE_CACHE_LIMIT:arena_groves.erase(arena_groves.keys()[0])
 arena_groves[key]=surfaces

func arena_deck(parent: Node3D,center: Vector3):
 var deck=building_material(BuildingFinish.DECK_WOOD)
 for column in range(42):
  var x=(column-20.5)*.5
  block(parent,center+Vector3(x,-.025,0),Vector3(.49,.05,4.98),deck).name="ArenaDeck"
 for z in [-1.86,1.86]:
  block(parent,center+Vector3(0,-.095,z),Vector3(21,.14,.2),deck).name="DeckBeam"
 arena_railing(parent,center,-2.42,20.5)

func arena_railing(parent: Node3D,center: Vector3,depth: float,width: float):
 for x in range(-10,11,2):
  block(parent,center+Vector3(x,.54,depth),Vector3(.13,1.1,.13),Color("72624f")).name="ArenaRailPost"
 block(parent,center+Vector3(0,.7,depth),Vector3(width,.12,.10),Color("8e7c60")).name="ArenaRailing"

func abbey_arcade(parent: Node3D,anchor: Vector3):
 var arcade=Node3D.new();arcade.name="AbbeyArcade";arcade.position=anchor
 parent.add_child(arcade)
 var stone=detail_material(3)
 block(arcade,Vector3(0,.07,0),Vector3(25.6,.26,2.68),stone).name="ArcadeWalk"
 block(arcade,Vector3(0,.03,1.55),Vector3(25.6,.18,.46),stone).name="ArcadeStep"
 for x in range(-12,13,4):
  block(arcade,Vector3(x,.31,0),Vector3(.94,.24,.93),stone).name="ArcadeFooting"
  cylinder(arcade,Vector3(x,1.67,0),2.56,.32,Color("a6a596"),.28).name="ArcadeShaft"
  block(arcade,Vector3(x,3.04,0),Vector3(.71,.25,.78),Color("99998a")).name="ArcadeCapital"
  block(arcade,Vector3(x,3.17,0),Vector3(.82,.12,.92),stone).name="ArcadeAbacus"
  if x<12:arch_span(arcade,Vector3(x+2,3.15,0),1.6,.42,.82)
 block(arcade,Vector3(0,5.23,0),Vector3(25.6,.34,.82),stone).name="ArcadeCoping"
 block(arcade,Vector3(0,5.43,0),Vector3(25.8,.10,1.06),Color("b7b3a0")).name="ArcadeCornice"

func abbey_grove(parent: Node3D,anchor: Vector3,spacing: float,size: float):
 # The same staggered tree line frames the map and the open arcade.
 for index in range(ABBEY_GROVE_SITES.size()):
  var site=ABBEY_GROVE_SITES[index]
  var tree_group=Node3D.new()
  tree_group.name="AbbeyGardenTree"
  tree_group.position=anchor+Vector3(site.x,0,site.y)*spacing
  tree_group.scale=Vector3(.64,1.28,.64)*size
  parent.add_child(tree_group,true)
  conifer(tree_group,Vector3.ZERO,index*137,"forest")

func abbey_belfry(parent: Node3D,anchor: Vector3,size: float):
 var tower=Node3D.new();tower.name="EmptyBelfry";tower.position=anchor
 tower.scale=Vector3.ONE*size;parent.add_child(tower)
 var stone=detail_material(3)
 var wood=building_material(BuildingFinish.OAK)
 block(tower,Vector3(0,.035,0),Vector3(1.53,.21,1.26),stone).name="BelfryFooting"
 block(tower,Vector3(0,.63,0),Vector3(1.28,1.12,1.03),stone).name="BelfryTrunk"
 block(tower,Vector3(0,1.21,0),Vector3(1.42,.15,1.17),stone).name="BelfrySill"
 var rod=cylinder(tower,Vector3(0,1.084,.593),.70,.025,Color("836949"))
 rod.name="BannerRail";rod.rotation.z=PI/2
 for side in [-1,1]:
  block(tower,Vector3(side*.319,1.084,.544),Vector3(.066,.070,.139),Color("56514a")).name="BannerBracket"
 var banner=WindCloth.new();tower.add_child(banner)
 banner.position=rod.position;banner.rotation.z=-PI/2
 banner.configure(Vector2(.72,.55),Color("775668"),true,2.85);banner.name="AbbeyBanner"
 for z in [-.44,.44]:
  for x in [-.54,.54]:
   block(tower,Vector3(x,1.853,z),Vector3(.42,1.28,.36),stone).name="BelfryPier"
  arch_span(tower,Vector3(0,2.48,z),.33,.23,.37).name="BelfryArch"
 for x in [-.54,.54]:
  block(tower,Vector3(x,2.46,0),Vector3(.20,.16,1.25),wood).name="BelfryBearing"
 block(tower,Vector3(0,2.43,0),Vector3(1.24,.13,.15),wood).name="BelfryYoke"
 for x in [-.12,.12]:
  var bolt=block(tower,Vector3(x,2.311,0),Vector3(.057,.15,.061),Color("574e46"))
  bolt.name="BelfryBolt";bolt.rotation.z=signf(x)*.20
 block(tower,Vector3(0,3.04,0),Vector3(1.59,.16,1.28),stone).name="BelfryCornice"
 for side in [-1,1]:
  var roof=block(tower,Vector3(side*.395,3.22,0),Vector3(.96,.108,1.48),Color("586670"))
  roof.name="BelfryRoof";roof.rotation.z=-side*.44

func aqueduct_gallery(parent: Node3D,center: Vector3,water_height: float):
 var gallery=Node3D.new();gallery.name="AqueductGallery";gallery.position=center+Vector3(0,0,-8.4);parent.add_child(gallery)
 var masonry=detail_material(3)
 for x in range(-12,13,4):
  block(gallery,Vector3(x,.055,0),Vector3(1.20,.27,1.15),masonry).name="GalleryFooting"
  block(gallery,Vector3(x,1.13,0),Vector3(.68,2.05,.80),masonry).name="GalleryPier"
  block(gallery,Vector3(x,2.105,0),Vector3(.93,.25,.93),Color("a6a698")).name="GalleryCapital"
  if x<12:
   arch_span(gallery,Vector3(x+2,2.10,0),1.65,.35,.86)
   block(gallery,Vector3(x+2,4.18,0),Vector3(3.98,.28,.96),masonry).name="ChannelStone"
 block(gallery,Vector3(0,4.36,0),Vector3(24.24,.12,1.12),Color("b7b9a8")).name="ChannelCoping"
 for spillway in [Vector2(-6.0,.46),Vector2(2.0,.32)]:
  block(gallery,Vector3(spillway.x,4.24,.52),Vector3(spillway.y+.20,.14,.54),masonry).name="SpillwayLip"
  var fall=mesh(gallery,aqueduct_spill_mesh(),Vector3(spillway.x,water_height,.79),
   Vector3(spillway.y,4.31-water_height,.52),Fountain.stream_material())
  fall.name="AqueductSpill";fall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var shelf=ground(parent,center+Vector3(0,0,-26),Vector2(32,32),3)
 shelf.name="AqueductFarWalk"
 AqueductWheel.new().build(self,parent,gallery.position+Vector3(-6,water_height,1.18),1.15,0.0)

static func spill_point(u: float,t: float) -> Vector3:
 return Vector3((u-.5)*(1.0+.40*t),1.0-pow(t,1.42),.18*t+.82*pow(t,.75))

static func aqueduct_spill_mesh() -> ArrayMesh:
 if aqueduct_fall!=null:return aqueduct_fall
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for section in 12:
  var top=section/12.0;var bottom=(section+1)/12.0
  var uv=[Vector2(0,top),Vector2(1,top),Vector2(1,bottom),Vector2(0,bottom)]
  var points=uv.map(func(point):return spill_point(point.x,point.y))
  var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for corner in [0,1,2,0,2,3]:
   tool.set_normal(normal);tool.set_uv(uv[corner]);tool.add_vertex(points[corner])
 aqueduct_fall=tool.commit();return aqueduct_fall

func aqueduct_parapet(parent: Node3D,center: Vector3):
 var masonry=detail_material(3)
 block(parent,center+Vector3(0,.19,-2.81),Vector3(23.6,.40,.33),masonry).name="AqueductParapet"
 block(parent,center+Vector3(0,.425,-2.81),Vector3(23.7,.12,.44),Color("b7b9a8")).name="ArenaRailing"

func kingsroad_canal(parent: Node3D,center: Vector3,paint: Material):
 var near_length=35.0-ROAD_CANAL_NEAR
 var far_length=35.0+ROAD_CANAL_FAR
 ground(parent,center+Vector3(0,0,(35.0+ROAD_CANAL_NEAR)*.5),Vector2(70,near_length),0,paint).name="ArenaGround"
 ground(parent,center+Vector3(0,0,(ROAD_CANAL_FAR-35.0)*.5),Vector2(70,far_length),0,paint).name="KingsroadFarBank"
 var water=plane_shape(Vector2(70.0,ROAD_CANAL_NEAR-ROAD_CANAL_FAR))
 var midpoint=(ROAD_CANAL_NEAR+ROAD_CANAL_FAR)*.5
 mesh(parent,water,center+Vector3(0,ROAD_CANAL_LEVEL,midpoint),Vector3.ONE,water_material("road")).name="KingsroadCanalWater"
 for depth in [ROAD_CANAL_NEAR,ROAD_CANAL_FAR]:
  block(parent,center+Vector3(0,-.13,depth),Vector3(70,.34,.40),detail_material(3)).name="CanalRevetment"
  block(parent,center+Vector3(0,.06,depth),Vector3(70,.10,.54),Color("9a9a88")).name="CanalCoping"

func harbor_quay(parent: Node3D,center: Vector3,surface: int):
 var land_depth=35.0-HARBOR_QUAY_EDGE
 ground(parent,center+Vector3(0,0,HARBOR_QUAY_EDGE+land_depth*.5),Vector2(70,land_depth),surface).name="ArenaGround"
 var sea=plane_shape(Vector2(70,60))
 var sea_center=center+Vector3(0,HARBOR_QUAY_LEVEL,HARBOR_QUAY_EDGE-sea.size.y*.5)
 mesh(parent,sea,sea_center,Vector3.ONE,water_material("harbor")).name="ArenaWater"
 var edge=center+Vector3(0,0,HARBOR_QUAY_EDGE)
 block(parent,edge-Vector3.UP*.20,Vector3(70,.42,.40),detail_material(3)).name="QuayWall"
 block(parent,edge+Vector3.UP*.04,Vector3(70,.12,.52),Color("9d9e8e")).name="QuayCoping"
 HarborNet.build(self,parent,center+HarborNet.ARENA_SITE,HarborNet.ARENA_SCALE)
 HarborSignal.build(self,parent,center+HarborSignal.ARENA_SITE,HarborSignal.ARENA_SCALE)
 for x in [-9,-4.5,0,4.5,9]:
  var foot=edge+Vector3(x,.27,.08)
  cylinder(parent,foot,.40,.085,Color("514c45"),.07).name="QuayBollard"
  cylinder(parent,foot+Vector3.UP*.205,.075,.12,Color("82725b"),.095).name="QuayBollardCap"

func reddeep_gantry(parent: Node3D,center: Vector3,backdrop: Array) -> Node3D:
 var depth=-11.5
 for item in backdrop:
  if item.kind=="furnace":depth=minf(depth,item.z-2.3)
 var gantry=Node3D.new();gantry.name="ReddeepGantry";gantry.position=center+Vector3(0,0,depth)
 parent.add_child(gantry)
 var stone=detail_material(3)
 var iron=Color("51424a")
 var edge=Color("80605a")
 for x in range(-12,13,6):
  block(gantry,Vector3(x,.13,0),Vector3(.94,.44,1.09),stone).name="GantryFooting"
  block(gantry,Vector3(x,2.33,0),Vector3(.38,4.09,.52),iron).name="GantryPost"
  block(gantry,Vector3(x,4.31,0),Vector3(.77,.28,.72),edge).name="GantrySaddle"
  block(gantry,Vector3(x,2.30,.268),Vector3(.12,3.90,.06),edge).name="GantryFlange"
  if x==12:continue
  for side in [-1,1]:
   var rise=Vector2(5.97,side*.96)
   var diagonal=block(gantry,Vector3(x+3,4.82,side*.104),Vector3(rise.length(),.125,.18),iron)
   diagonal.name="GantryDiagonal";diagonal.rotation.z=rise.angle()
 for y in [4.34,5.30]:
  block(gantry,Vector3(0,y,0),Vector3(24.7,.22,.51),iron).name="GantryChord"
  block(gantry,Vector3(0,y+.05,.26),Vector3(24.7,.08,.11),edge).name="GantryRim"
 for x in [-3.15,3.4]:
  block(gantry,Vector3(x,4.23,0),Vector3(.51,.27,.58),iron).name="HoistHanger"
  var drum=cylinder(gantry,Vector3(x,3.96,0),.32,.23,edge)
  drum.name="HoistDrum";drum.rotation.x=PI/2.0
  for offset in [-.11,.11]:
   block(gantry,Vector3(x+offset,3.26,0),Vector3(.032,1.16,.038),iron).name="HoistChain"
  block(gantry,Vector3(x,2.69,0),Vector3(.28,.09,.11),edge).name="HoistHookBlock"
  block(gantry,Vector3(x-.04,2.57,0),Vector3(.075,.18,.078),iron).name="HoistHook"
  block(gantry,Vector3(x+.02,2.49,0),Vector3(.16,.063,.078),iron).name="HoistToe"
 return gantry

func sun_engine(parent: Node3D,anchor: Vector3,scale_value=1.0):
 var chamber=Node3D.new();chamber.name="SunEngineChamber";chamber.position=anchor
 chamber.scale=Vector3.ONE*scale_value;parent.add_child(chamber)
 var iron=material(Color("434e55"))
 var bronze=material(Color("9e8155"))
 var masonry=detail_material(3)
 cylinder(chamber,Vector3(0,.11,0),.38,3.30,Color("565d58"),2.95).name="EngineFoundation"
 cylinder(chamber,Vector3(0,.31,0),.16,1.46,Color("a48657"),1.32).name="EngineSocket"
 for x in [-2.72,2.72]:
  for z in [-.80,.80]:
   block(chamber,Vector3(x,.13,z),Vector3(.96,.42,.96),masonry).name="EnginePylonFoot"
   block(chamber,Vector3(x,1.56,z),Vector3(.61,2.67,.61),iron).name="EnginePylonShaft"
   block(chamber,Vector3(x,2.94,z),Vector3(.75,.22,.75),bronze).name="EnginePylonCrown"
   block(chamber,Vector3(x,1.64,z+.31),Vector3(.11,2.24,.07),bronze).name="PylonFace"
  block(chamber,Vector3(x,2.83,0),Vector3(.14,.16,2.07),bronze).name="EngineBrace"
 var orbit=preload("res://scripts/clockwork_orbit.gd").new();chamber.add_child(orbit)
 orbit.position=Vector3.UP*3.45;orbit.configure("engine",1.875,1.2)
 EngineConduits.build(self,chamber,orbit.conduit_light)

func sun_engine_basin(parent: Node3D,anchor: Vector3):
 var water=plane_shape(Vector2(11.5,7.5))
 mesh(parent,water,anchor-Vector3.UP*.025,Vector3.ONE,water_material("engine")).name="EngineBasinWater"
 var masonry=detail_material(3)
 for x in [-5.75,5.75]:
  block(parent,anchor+Vector3(x,.035,0),Vector3(.24,.20,7.72),masonry).name="EngineBasinRim"
 for z in [-3.75,3.75]:
  block(parent,anchor+Vector3(0,.035,z),Vector3(11.5,.20,.24),masonry).name="EngineBasinRim"

func separate_village_houses(backdrop: Array) -> Array:
 if backdrop.size()!=2 or not backdrop.all(func(item):return item.kind=="house" and item.has("map_site")):return backdrop
 var nearer=backdrop[0]
 var farther=backdrop[1]
 var scale_value=HOUSE_SCALE*VILLAGE_HOUSE_BACKDROP_SCALE
 var width=2*Architecture.HALF_WIDTH*scale_value+.20
 var depth=2*Architecture.HALF_DEPTH*scale_value+.20
 if absf(nearer.x-farther.x)>=width or absf(nearer.z-farther.z)>=depth:return backdrop
 farther=farther.duplicate()
 farther.z=nearer.z-depth
 return [nearer,farther]

func battle_landscape(parent,center,context={}):
 var theme=context.get("environment","village")
 if theme!=cylinder_environment:
  cylinders.clear();cylinder_environment=theme
 parent.set_meta("environment",theme)
 var tile=context.get("terrain","p")
 parent.set_meta("terrain",tile)
 var stone=theme in ["abbey","aqueduct","observatory","castle","engine","furnace"]
 var wooden_floor=tile=="="
 var continuous_floor=not wooden_floor and theme in MapGround.CONTINUOUS_ARENAS
 var road_canal=theme=="road" and not wooden_floor and context.get("road_canal",false)
 var harbor_quayside=theme=="harbor" and not wooden_floor and context.get("harbor_quay",false)
 var surface=maxi(0,MapGround.surface_for(tile,theme))
 parent.set_meta("arena_surface",surface)
 var river=theme=="river"
 var rain_soaked=theme=="forest"
 if harbor_quayside:
  harbor_quay(parent,center,surface)
 elif continuous_floor:
  var paint=MapGround.arena_material(surface,center,atlas) if surface!=0 else null
  if rain_soaked:
   if paint==null:paint=ground_material(0,true)
   else:paint.set_shader_parameter("rain_soaked",true)
  if road_canal:
   kingsroad_canal(parent,center,paint)
   if context.get("road_hoist",false):
    KingsroadHoist.build(self,parent,center+Vector3(-3.68,0,ROAD_CANAL_NEAR+.69),1.48,1.02)
  else:ground(parent,center,Vector2(70,70),0,paint).name="ArenaGround"
 else:
  if theme=="observatory":
   StarfallTerrain.build_arena(self,parent,center-Vector3(0,.065,0))
   ground(parent,center+Vector3(0,-.06,5.0),Vector2(70,42),3).name="ObservatoryTerrace"
  else:
   var outer_paint=ground_material(0,true) if rain_soaked else null
   if theme=="furnace":outer_paint=ground_material(3,false,true)
   ground(parent,center-Vector3(0,.06,0),Vector2(70,70),3 if stone else 0,outer_paint)
  if not wooden_floor:
   var floor_paint=ground_material(surface,false,true) if theme=="furnace" and surface==3 else null
   ground(parent,center,Vector2(24,6),surface,floor_paint)
 var water_level=-.055 if wooden_floor else RiverBank.ARENA_WATER_LEVEL
 if river or theme=="aqueduct" or wooden_floor:
  var water=water_material(theme)
  var plane=plane_shape(Vector2(RiverBank.ARENA_WIDTH,60 if wooden_floor else 40))
  var water_depth=-12.0 if wooden_floor else -23.0 if river else -22.0
  var water_surface=mesh(parent,plane,center+Vector3(0,water_level,water_depth),Vector3.ONE,water);water_surface.name="ArenaWater"
  if wooden_floor:arena_deck(parent,center)
  elif theme=="aqueduct":aqueduct_parapet(parent,center)
 if theme=="harbor" and (harbor_quayside or wooden_floor):
  HarborBreakwater.build(self,parent,center+HarborBreakwater.ARENA_SITE+Vector3.UP*(water_level if wooden_floor else HARBOR_QUAY_LEVEL),1.0,0.0)
 if river:
  var chain_near=-2.02 if wooden_floor else RiverBank.ARENA_NEAR_START+.50
  var chain_far=RiverBank.ARENA_FAR_START-.65
  RiverChain.build(self,parent,center+Vector3(-5.4,0,chain_near),center+Vector3(-5.4,0,chain_far),1.18,.76,.29)
  var far_ground=ground(parent,center+Vector3(0,0,RiverBank.ARENA_FAR_START-14.5),Vector2(RiverBank.ARENA_WIDTH,29),0)
  far_ground.name="ArenaFarBankGround"
  mesh(parent,RiverBank.arena_strip(true),center,Vector3.ONE,ground_material(0)).name="ArenaFarBank"
  add_river_foam(parent,center,RiverBank.arena_foam_strip(true,water_level),true)
  if not wooden_floor:
   mesh(parent,RiverBank.arena_strip(false),center,Vector3.ONE,ground_material(surface)).name="ArenaNearBank"
   add_river_foam(parent,center,RiverBank.arena_foam_strip(false,water_level),true)
   for index in range(14):
    var column=7+(index*7)%27
    var x=(float(column)/RiverBank.ARENA_COLUMNS-.5)*RiverBank.ARENA_WIDTH
    var position=center+RiverBank.arena_point(x,3.0/RiverBank.ARENA_ROWS,false)
    var reed=ground_cover.plant(parent,{"kind":2,"position":position,"height":.28+(index%3)*.045,"yaw":index*2.399})
    reed.name="ArenaBankReed"
 var backdrop=context.get("landmarks",[])
 if theme=="village":backdrop=separate_village_houses(backdrop)
 var tollhouse=Vector3(context.get("tollhouse_x",INF),0,RiverBank.ARENA_FAR_START-1.9)
 if is_finite(tollhouse.x):ReedTollhouse.build(self,parent,center+tollhouse,2.50)
 if theme in ["village","river","road","forest","harbor"]:
  var base=-.06 if theme=="forest" and not continuous_floor else 0.0
  var tree_line=RiverBank.ARENA_FAR_START-1 if river else -8.0
  if road_canal:tree_line=ROAD_CANAL_FAR-1.8
  var house_sites=[]
  if theme!="forest" and not harbor_quayside and backdrop.is_empty():
   for i in range(3):
    var site=Vector2(-12+i*11,-17)
    house(parent,center+Vector3(site.x,0,site.y),2.0+i*.2)
    house_sites.append(site)
  if theme=="village":
   for item in backdrop:
    if item.kind in ["house","warehouse"]:house_sites.append(Vector2(item.x,item.z))
   village_trees(parent,center,house_sites)
   village_mill(parent,center+village_mill_site(house_sites),1.55)
   CinderfordMarket.build(self,parent,center+Vector3(1.25,0,-4.05),1.4)
  elif not harbor_quayside:
   var sites=[]
   for i in range(28 if theme=="forest" or tile=="f" else 17):
    var site=Vector3(-20+(i*11)%41,base,tree_line-(i%4)*3)
    if absf(site.x-tollhouse.x)<4.7 and absf(site.z-tollhouse.z)<3.4:continue
    sites.append([center+site,i*83,2.6+(i%3)*.25])
   arena_grove(parent,sites,theme)
 parent.set_meta("backdrop_count",backdrop.size())
 var mechanism=center+Vector3(0,0,-12 if theme=="engine" else -10)
 var belfry_lateral=-5.7
 var vents=[]
 for item in backdrop:
  var depth=RiverBank.ARENA_FAR_START-1.5+(item.z+7)*.7 if river else item.z
  var lateral=item.x
  if item.kind=="belfry":
   belfry_lateral=2.7 if lateral>=0 else -5.7
   continue
  if theme=="aqueduct":depth=minf(depth,-11.0)
  if road_canal:depth=minf(depth,ROAD_CANAL_FAR-1.8)
  if theme=="abbey":depth=minf(depth,-13.0)
  if theme=="mountain":depth=maxf(depth,-9.6)
  if harbor_quayside and item.kind=="warehouse":
   depth=HARBOR_QUAY_EDGE+2.45
   lateral=maxf(absf(lateral),5.8)*(-1.0 if lateral<0 else 1.0)
  if item.kind==theme and theme in ["engine","observatory"]:
   mechanism.x=center.x+clampf(item.x,-3.8,3.8)
   mechanism.z=minf(mechanism.z,center.z+depth)
   continue
  var map_site=item.get("map_site",Vector2.INF)
  var vented=theme=="village" and item.kind=="house" and map_site!=Vector2.INF
  var group=Node3D.new();group.name="ArenaLandmark";parent.add_child(group,true);group.position=center+Vector3(lateral,0,depth)
  group.scale=Vector3.ONE*(2.1 if item.kind in ["house","warehouse","tower","spire","arch","furnace"] else 1.4)
  # Give the village roofline room below the top of the close-up camera.
  if vented:group.scale=Vector3.ONE*VILLAGE_HOUSE_BACKDROP_SCALE
  if item.kind=="camp":group.scale=Vector3.ONE*2.5
  landmark(group,Vector3.ZERO,item.kind,item.get("roof_variant",0),map_site,vented)
  if vented:vents.append(ChimneySmoke.vent(group.position,group.scale.x*HOUSE_SCALE,map_site))
 if theme in ["village","road"]:
  cart(parent,center+Vector3(-6,0,-3.8));fence(parent,center+Vector3(3,0,-4),5.0)
  for i in range(3):barrel(parent,center+Vector3(6+i*.4,0,-4.3),1.0)
 if theme=="forest":TrailLanterns.fighting_lane(parent,center)
 if theme=="aqueduct":aqueduct_gallery(parent,center,water_level)
 if theme=="abbey":
  ground(parent,center+Vector3(0,-.025,-55.6),Vector2(170,88),0).name="AbbeyGardenLawn"
  abbey_grove(parent,center+Vector3(0,-.025,-14.6),1.85,2.24)
  abbey_arcade(parent,center+Vector3(0,0,-9.7))
  abbey_belfry(parent,center+Vector3(belfry_lateral,0,-6.5),1.35)
  if context.has("mosaic_yaw") and tile=="p":
   AbbeyMosaic.build(self,parent,center+AbbeyMosaic.ARENA_SITE,AbbeyMosaic.ARENA_SCALE,context.mosaic_yaw)
 if theme=="castle":
  Fortification.build_castle_wall(self,parent,center+Vector3(0,0,-9),context.get("raised_gate",false))
 elif theme=="observatory":
  for x in [-13,-9,-5.2,5.2,9,13]:
   cylinder(parent,center+Vector3(x,1.8,-5),3.6,.32,Color("9e9d8d")).name="ObservatoryColumnShaft"
   cylinder(parent,center+Vector3(x,.11,-5),.38,.5,Color("7f8178")).name="ObservatoryColumnBase"
   cylinder(parent,center+Vector3(x,3.5,-5),.3,.48,Color("c2bea7")).name="ObservatoryColumnCapital"
  observatory(parent,mechanism,true)
  var chart_side=-1.0 if mechanism.x>=center.x else 1.0
  StarfallChart.build(self,parent,mechanism+Vector3(chart_side*3.23,-.06,1.72),1.52)
 if ArenaRidges.LANDSCAPES.has(theme):
  ArenaRidges.build(parent,center+Vector3.UP*.06 if continuous_floor else center,theme)
  if theme=="mountain":
   var slope_origin=center+Vector3(0,0 if continuous_floor else -.06,-10.8)
   var slope=PassEscarpment.build(parent,slope_origin,Vector3(1,1.24,1))
   pass_beacons(parent,slope,true)
   for i in range(16):boulder(parent,center+Vector3(-12+(i*7)%25,.4,-4-i%3),1.0+i%3*.3)
   for i in range(8):
    var position=center+Vector3(-17+(i*11)%35,0,-12.8-i%3*2.25)
    position.y=PassEscarpment.height_at(slope,position)
    battle_tree(parent,position,i*47,2.2+i%3*.2,theme)
 if theme=="furnace":
  if backdrop.is_empty():
   for x in [-5,5]:furnace(parent,center+Vector3(x,0,-8),2.1)
  var gantry=reddeep_gantry(parent,center,backdrop)
  reddeep_works.build(self,parent,gantry.position+Vector3(0,-.06,-4.3),Vector3(1.68,1,1))
  if context.get("slag_cart",false):
   ReddeepCart.build(self,parent,center+ReddeepCart.ARENA_SITE,ReddeepCart.ARENA_SCALE,ReddeepCart.ARENA_YAW)
 if theme=="engine":
  sun_engine_basin(parent,mechanism)
  sun_engine(parent,mechanism)
 ground_cover.add_arena(parent,center,context)
 if batching_enabled:batcher.combine(parent)
 var atmosphere=AmbientDrift.new();parent.add_child(atmosphere);atmosphere.position=center+Vector3(0,0,-3)
 atmosphere.configure(theme,Vector3(28,4,14),true,context.get("chapter",0))
 if theme=="harbor" and (harbor_quayside or wooden_floor):
  add_harbor_gulls(atmosphere,center+HarborBreakwater.ARENA_SITE,1.0,0.0)
 add_chimney_smoke(parent,vents,context.get("chimney_wind",ChimneySmoke.WIND),atmosphere)
 return theme

func pass_beacons(parent: Node3D,slope: MeshInstance3D,arena: bool):
 var flame_paint=materials.get("pass_beacon_flame") as StandardMaterial3D
 if flame_paint==null:
  flame_paint=StandardMaterial3D.new();flame_paint.albedo_color=Color("e17838")
  flame_paint.emission_enabled=true;flame_paint.emission=Color("f0a150")
  materials["pass_beacon_flame"]=flame_paint
 for name in PASS_BEACON_SITES:
  var sites=PASS_BEACON_SITES[name]
  var offset=sites.arena if arena else sites.field
  var point=slope.transform*Vector3(offset.x,0,offset.y)
  point.y=PassEscarpment.height_at(slope,point)
  var beacon=Node3D.new();beacon.name=name;beacon.position=point
  beacon.scale=Vector3.ONE*(1.05 if arena else .55);parent.add_child(beacon,true)
  cylinder(beacon,Vector3(0,-.05,0),.67,.58,Color("626766"),.49).name="BeaconFooting"
  cylinder(beacon,Vector3(0,.49,0),.52,.41,Color("7e8179"),.33).name="BeaconPedestal"
  cylinder(beacon,Vector3(0,.773,0),.19,.32,Color("4a4b45"),.46).name="BeaconBowl"
  cylinder(beacon,Vector3(0,.86,0),.105,.47,Color("9a8160"),.47).name="BeaconRim"
  cylinder(beacon,Vector3(0,.917,0),.043,.32,Color("623a2e")).name="BeaconCoal"
  var flame=preload("res://scripts/beacon_flame.gd").new()
  flame.name="BeaconFlame";flame.position=Vector3(0,.92,0);beacon.add_child(flame,true)
  flame.seek_phase(sites.arena.x)
  var tongue=cylinder(flame,Vector3(0,.235,0),.52,.20,Color.WHITE,.012)
  tongue.rotation.z=.18;tongue.material_override=flame_paint
  tongue.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var edge=cylinder(flame,Vector3(-.13,.14,0),.31,.125,Color.WHITE,.01)
  edge.rotation.z=-.23;edge.material_override=flame_paint
  edge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func village_mill_site(houses: Array) -> Vector3:
 for site in [MILL_ARENA_SITE,MILL_ALTERNATE_SITE]:
  if not houses.any(func(house):
   var x_gap=absf(site.x-house.x)
   var footprint=x_gap<3.70 and absf(site.z-house.y)<3.50
   var sail_sweep=x_gap<5.20 and absf(site.z+1.49-house.y)<2.40
   return footprint or sail_sweep
  ):
   return site
 return MILL_DISTANT_SITE

func village_mill(parent: Node3D,point: Vector3,scale_value: float):
 var tower=Node3D.new();tower.name="CinderfordMill";tower.position=point
 tower.scale=Vector3.ONE*scale_value;parent.add_child(tower,true)
 var plaster=building_material(BuildingFinish.LIME_PLASTER)
 var oak=building_material(BuildingFinish.OAK)
 var strap=material(Color("726747"))
 var tip=material(Color("c6ae84"))
 var wall=cylinder(tower,Vector3(0,1.29,0),2.72,.76,Color.WHITE,.59)
 wall.name="MillStoneTower";wall.material_override=plaster
 cylinder(tower,Vector3(0,.095,0),.30,.82,Color("80776b"),.75).name="MillFoundation"
 cylinder(tower,Vector3(0,2.62,0),.19,.72,Color("514a42"),.72).name="MillEave"
 cylinder(tower,Vector3(0,3.11,0),.90,.73,Color("675445"),.075).name="MillRoof"
 block(tower,Vector3(0,.38,.73),Vector3(.29,.76,.08),oak).name="MillDoor"
 block(tower,Vector3(0,.785,.73),Vector3(.42,.10,.115),strap).name="MillLintel"
 var axle=cylinder(tower,Vector3(0,2.22,.69),.49,.092,Color("675445"))
 axle.name="MillAxle";axle.rotation.x=PI/2
 var rotor=preload("res://scripts/mill_rotor.gd").new()
 rotor.name="MillRotor";rotor.position=Vector3(0,2.22,.96);tower.add_child(rotor,true)
 var hub=cylinder(rotor,Vector3.ZERO,.13,.176,Color("826b4c"))
 hub.name="MillHub";hub.rotation.x=PI/2
 for index in 4:
  var arm=Node3D.new();arm.name="MillArm";rotor.add_child(arm,true)
  arm.rotation.z=index*PI*.5
  block(arm,Vector3(0,.84,0),Vector3(.086,1.68,.069),oak).name="MillSpar"
  block(arm,Vector3(.125,1.095,.011),Vector3(.274,1.15,.032),Color("d6c5a0")).name="MillSail"
  for y in [.59,1.62]:
   block(arm,Vector3(.117,y,.03),Vector3(.31,.051,.043),tip).name="MillSailTie"
 if batching_enabled:batcher.combine(rotor,false)

func barrel(parent,p,scale_value=1.0):
 BarrelVisuals.build(parent,p,scale_value)

func fence(parent,p,length=3.0):
 for i in range(int(length)+1):
  cylinder(parent,p+Vector3(i,.36,0),.72,.045,Color("6e604d"),.025)
 for y in [.25,.55]:block(parent,p+Vector3(length*.5,y,0),Vector3(length,.07,.04),Color("897659"))

func cart(parent,p):
 var root=Node3D.new();root.name="RoadCart";parent.add_child(root);root.position=p
 block(root,Vector3(0,.4,0),Vector3(.9,.10,1.3),Color("816b4f"))
 for x in [-.44,.44]:
  block(root,Vector3(x,.63,0),Vector3(.045,.4,1.3),Color("927e5e"))
  for z in [-.42,.42]:
   var shape=preload("res://scripts/cart_wheel.gd")
   var wheel=mesh(root,shape.mesh(),Vector3(x*1.22,.251,z),Vector3.ONE,shape.material());wheel.rotation.z=PI/2;wheel.name="SpokedWheel"
   var hub=cylinder(root,Vector3(x*1.3,.251,z),.07,.075,Color("a08a62"));hub.rotation.z=PI/2;hub.name="WheelHub"
 for z in [-.42,.42]:
  var axle=block(root,Vector3(0,.251,z),Vector3(1.16,.045,.045),Color("695b45"));axle.name="WheelAxle"
  for x in [-.36,.36]:
   var bearing=block(root,Vector3(x,.30,z),Vector3(.09,.14,.09),Color("695b45"));bearing.name="AxleBearing"
 for z in [-.63,.63]:block(root,Vector3(0,.62,z),Vector3(.9,.35,.05),Color("8f7959"))
 for x in [-.25,.25]:block(root,Vector3(x,.35,1.2),Vector3(.055,.065,1.3),Color("695b45"))
 barrel(root,Vector3(-.15,.46,-.15),.8)

func foliage_material(tile: int) -> ShaderMaterial:
 var key="foliage"+str(tile)
 if materials.has(key):return materials[key]
 var value=ShaderMaterial.new();value.shader=load("res://assets/shaders/foliage.gdshader")
 value.set_shader_parameter("foliage_atlas",foliage_atlas);value.set_shader_parameter("quadrant",Vector2((tile%2)*.5,(tile/2)*.5))
 materials[key]=value
 return value
