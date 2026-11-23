extends RefCounted
const MapSurface=preload("res://scripts/map_surface.gd")
const RiverBank=preload("res://scripts/river_bank.gd")
const MapGround=preload("res://scripts/map_ground.gd")
const WindCloth=preload("res://scripts/wind_cloth.gd")
const Architecture=preload("res://scripts/architecture.gd")
const Fortification=preload("res://scripts/fortification.gd")
const Fountain=preload("res://scripts/fountain.gd")
const AmbientDrift=preload("res://scripts/ambient_drift.gd")
const GroundCover=preload("res://scripts/ground_cover.gd")
const ConiferCrowns=preload("res://scripts/conifer_crowns.gd")
const BarrelVisuals=preload("res://scripts/barrel_visuals.gd")
const HarborBoat=preload("res://scripts/harbor_boat.gd")
const ArenaRidges=preload("res://scripts/arena_ridges.gd")
const SanctuaryPlinth=preload("res://scripts/sanctuary_plinth.gd")
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
var unit_block=BoxMesh.new()
var planes: Dictionary={}
static var arch_shapes: Dictionary={}
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

func ground_material(tile: int) -> ShaderMaterial:
 var key="ground"+str(tile)
 if materials.has(key):return materials[key]
 var shader=preload("res://assets/shaders/ground.gdshader")
 var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("atlas_texture",atlas)
 m.set_shader_parameter("quadrant",Vector2((tile%2)*.5,(tile/2)*.5))
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

func plane_shape(size: Vector2) -> PlaneMesh:
 if not planes.has(size):
  var shape=PlaneMesh.new()
  shape.size=size
  planes[size]=shape
 return planes[size]

func ground(parent,p,size,tile,blended: Material=null):
 return mesh(parent,plane_shape(size),p,Vector3.ONE,blended if blended!=null else ground_material(tile))

func cylinder(parent,p,height,radius,color,top=-1.0):
 var shape=CylinderMesh.new();shape.height=height;shape.bottom_radius=radius;shape.top_radius=radius if top<0 else top;shape.radial_segments=8
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
   var shape=QuadMesh.new();shape.size=Vector2(1.15+rng.randf()*.18,1.0+rng.randf()*.15)
   var n=mesh(parent,shape,center,Vector3.ONE,foliage_material(leaf_type))
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

func sanctuary(parent,p):
 mesh(parent,SanctuaryPlinth.mesh(),p,Vector3.ONE,SanctuaryPlinth.material()).name="SanctuaryPlinth"

func house(parent,p,scale_value=1.0,roof_variant=-1,warehouse=false):
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
 block(root,Vector3(.5,1.97,-.3),Vector3(.29,.08,.3),Color("686c68"))
 for z in [-.25,.18]:barrel(root,Vector3(.95,0,z),.75)
 var sign=block(root,Vector3(-.56,.92,.78),Vector3(.28,.18,.045),Color("74634c"));sign.rotation.z=.05
 block(root,Vector3(-.56,.92,.81),Vector3(.12,.025,.01),Color("c2af78"))
 for x in [-.7,.7]:
  var shrub=SphereMesh.new();shrub.radius=.15;shrub.height=.25;shrub.radial_segments=7;shrub.rings=4
  mesh(root,shrub,Vector3(x,.13,.78),Vector3(1,.8,1),detail_material(1))

func landscape(parent,game):
 # Surrounding land continues beyond the playable cells instead of exposing a board edge.
 var ground_paint=MapGround.material(game,atlas)
 ground(parent,Vector3(7,-.15,5),Vector2(64,64),0,ground_paint)
 var theme=game.info().get("environment","village")
 var building_cells={}
 for item in game.info().get("landmarks",[]):
  if item.has("footprint"):
   var area=item.footprint
   for y in range(area[1],area[1]+area[3]):
    for x in range(area[0],area[0]+area[2]):building_cells[Vector2i(x,y)]=true
 if theme in ["village","river"]:
  var water=water_material(theme)
  var river=plane_shape(Vector2(2 if theme=="river" else 1,64))
  mesh(parent,river,Vector3(5.5 if theme=="river" else 7,-.07,5),Vector3.ONE,water)
 for y in range(game.board_size().y):
  for x in range(game.board_size().x):
   var t=game.terrain(Vector2i(x,y));var p=Vector3(x,0,y)
   if t in ["~","="]:
    var water=water_material(theme)
    var water_cell=mesh(parent,plane_shape(Vector2.ONE),p-Vector3(0,.07,0),Vector3.ONE,water);water_cell.name="MapWater"
    if theme in MapGround.NATURAL and t=="~":
     var bank=RiverBank.build(game,Vector2i(x,y))
     if bank!=null:
      var shore=mesh(parent,bank,p,Vector3.ONE,ground_paint);shore.name="RiverBank"
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
 for item in game.info().get("landmarks",[]):
  landmark(parent,Vector3(item.position[0],0,item.position[1]),item.kind)
 if theme in ["village","river","forest","road","castle"]:
  var base=-.15 if theme=="forest" else 0.0
  for i in range(22):tree(parent,Vector3(-4+(i*7)%23,base,-3-(i%3)*1.3),i*23,theme)
  for i in range(12):tree(parent,Vector3(-3+(i*13)%21,base,12+i%3),i*11,theme)
 elif theme=="mountain":
  for i in range(16):boulder(parent,Vector3(-3+(i*5)%22,.2,-3-i%3),2.5)
  for i in range(7):tree(parent,Vector3(-3+(i*9)%22,-.15,-6-(i%3)),i*31,theme)
 elif theme in ["harbor","aqueduct"]:
  var sea=plane_shape(Vector2(55,35))
  mesh(parent,sea,Vector3(7,-.12,26),Vector3.ONE,water_material(theme))

 ground_cover.add_map(parent,game,building_cells)
 if batching_enabled:batcher.combine(parent)
 var atmosphere=AmbientDrift.new();parent.add_child(atmosphere)
 atmosphere.position=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 atmosphere.configure(theme,Vector3(game.board_size().x+6,3,game.board_size().y+6),false,game.chapter)

func landmark(parent,p,kind,roof_variant=-1):
 var stone=Color("969b91")
 if kind in ["house","warehouse"]:
  var warehouse=kind=="warehouse"
  house(parent,p,1.4 if warehouse else 1.2,roof_variant,warehouse)
 elif kind=="fountain":
  Fountain.build(parent,p,water_material())
 elif kind=="tower":
  var tower=mesh(parent,Fortification.tower(),p,Vector3.ONE,Fortification.material());tower.name="FortifiedTower"
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
  sail.configure(Vector2(1.3,1.4),Color("dcd4b9"),false,p.x*.71+p.z*.37)
 elif kind=="camp":
  var tent=cylinder(parent,p+Vector3(0,.5,0),1,.8,Color("c7bba1"),0);tent.scale.z=1.5
  cylinder(parent,p+Vector3(1,.06,0),.1,.3,Color("6a5c4b"))
 elif kind=="engine":
  sun_engine(parent,p+Vector3.DOWN*.06,.46)
 elif kind=="observatory":
  cylinder(parent,p+Vector3(0,.2,0),.4,1.3,stone)
  var orbit=preload("res://scripts/clockwork_orbit.gd").new();parent.add_child(orbit);orbit.position=p+Vector3(0,1.5,0);orbit.configure(kind)
 elif kind=="furnace":furnace(parent,p)
 elif kind=="ruin":
  for i in range(3):cylinder(parent,p+Vector3(i*.6,.4+i*.2,0),.8+i*.4,.22,stone)

func furnace(parent: Node3D,p: Vector3,scale_value=1.0):
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

func combat_context(game,a,b,screen_direction=1.0) -> Dictionary:
 var midpoint=Vector2(a.x+b.x,a.y+b.y)*.5
 var axis=Vector2(b.x-a.x,b.y-a.y).normalized()
 if axis.is_zero_approx():axis=Vector2.RIGHT
 axis*=screen_direction
 var depth=Vector2(-axis.y,axis.x)
 var candidates=[]
 for item in game.info().get("landmarks",[]):
  var delta=Vector2(item.position[0],item.position[1])-midpoint
  if delta.length()>8:continue
  candidates.append({"kind":item.kind,"roof_variant":Architecture.variant_at(Vector3(item.position[0],0,item.position[1])),"distance":delta.length(),"x":clampf(delta.dot(axis)*2.2,-11,11),"z":-7-clampf(absf(delta.dot(depth))*1.8,0,10)})
 candidates.sort_custom(func(left,right):return left.distance<right.distance)
 return {"chapter":game.chapter,"environment":game.info().get("environment","village"),"terrain":game.terrain(game.pos(b)),"landmarks":candidates.slice(0,2)}

func battle_tree(parent,point,seed_value,scale_value,theme=""):
 var group=Node3D.new();group.name="ArenaTree";group.position=point;group.scale=Vector3.ONE*scale_value;parent.add_child(group,true)
 tree(group,Vector3.ZERO,seed_value,theme)

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

func aqueduct_gallery(parent: Node3D,center: Vector3):
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
 var shelf=ground(parent,center+Vector3(0,0,-26),Vector2(32,32),3)
 shelf.name="AqueductFarWalk"

func aqueduct_parapet(parent: Node3D,center: Vector3):
 var masonry=detail_material(3)
 block(parent,center+Vector3(0,.19,-2.81),Vector3(23.6,.40,.33),masonry).name="AqueductParapet"
 block(parent,center+Vector3(0,.425,-2.81),Vector3(23.7,.12,.44),Color("b7b9a8")).name="ArenaRailing"

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

func sun_engine_basin(parent: Node3D,anchor: Vector3):
 var water=plane_shape(Vector2(11.5,7.5))
 mesh(parent,water,anchor-Vector3.UP*.025,Vector3.ONE,water_material("engine")).name="EngineBasinWater"
 var masonry=detail_material(3)
 for x in [-5.75,5.75]:
  block(parent,anchor+Vector3(x,.035,0),Vector3(.24,.20,7.72),masonry).name="EngineBasinRim"
 for z in [-3.75,3.75]:
  block(parent,anchor+Vector3(0,.035,z),Vector3(11.5,.20,.24),masonry).name="EngineBasinRim"

func battle_landscape(parent,center,context={}):
 var theme=context.get("environment","village")
 parent.set_meta("environment",theme)
 var tile=context.get("terrain","p")
 parent.set_meta("terrain",tile)
 var stone=theme in ["abbey","aqueduct","observatory","castle","engine","furnace"]
 var wooden_floor=theme=="harbor" or tile=="="
 var surface=maxi(0,MapGround.surface_for(tile,theme))
 parent.set_meta("arena_surface",surface)
 var river=theme=="river"
 ground(parent,center-Vector3(0,.06,0),Vector2(70,70),3 if stone else 0)
 if not wooden_floor:ground(parent,center,Vector2(24,6),surface)
 if river or theme in ["harbor","aqueduct"] or tile=="=":
  var water=water_material(theme)
  var plane=plane_shape(Vector2(RiverBank.ARENA_WIDTH,60 if wooden_floor else 40))
  var water_level=-.055 if wooden_floor else RiverBank.ARENA_WATER_LEVEL
  var water_depth=-12.0 if wooden_floor else -23.0 if river else -22.0
  var water_surface=mesh(parent,plane,center+Vector3(0,water_level,water_depth),Vector3.ONE,water);water_surface.name="ArenaWater"
  if wooden_floor:arena_deck(parent,center)
  elif theme=="aqueduct":aqueduct_parapet(parent,center)
 if river:
  var far_ground=ground(parent,center+Vector3(0,0,RiverBank.ARENA_FAR_START-14.5),Vector2(RiverBank.ARENA_WIDTH,29),0)
  far_ground.name="ArenaFarBankGround"
  mesh(parent,RiverBank.arena_strip(true),center,Vector3.ONE,ground_material(0)).name="ArenaFarBank"
  if not wooden_floor:
   mesh(parent,RiverBank.arena_strip(false),center,Vector3.ONE,ground_material(surface)).name="ArenaNearBank"
   for index in range(14):
    var column=7+(index*7)%27
    var x=(float(column)/RiverBank.ARENA_COLUMNS-.5)*RiverBank.ARENA_WIDTH
    var position=center+RiverBank.arena_point(x,3.0/RiverBank.ARENA_ROWS,false)
    var reed=ground_cover.plant(parent,{"kind":2,"position":position,"height":.28+(index%3)*.045,"yaw":index*2.399})
    reed.name="ArenaBankReed"
 if theme in ["village","river","road","forest","harbor"]:
  var base=-.06 if theme=="forest" else 0.0
  var tree_line=RiverBank.ARENA_FAR_START-1 if river else -8.0
  for i in range(28 if theme=="forest" or tile=="f" else 17):
   battle_tree(parent,center+Vector3(-20+(i*11)%41,base,tree_line-(i%4)*3),i*83,2.6+(i%3)*.25,theme)
  if theme!="forest" and context.get("landmarks",[]).is_empty():
   for i in range(3):house(parent,center+Vector3(-12+i*11,0,-17),2.0+i*.2)
 var backdrop=context.get("landmarks",[])
 parent.set_meta("backdrop_count",backdrop.size())
 var mechanism=center+Vector3(0,0,-12 if theme=="engine" else -10)
 for item in backdrop:
  var depth=RiverBank.ARENA_FAR_START-1.5+(item.z+7)*.7 if river else item.z
  if theme=="aqueduct":depth=minf(depth,-11.0)
  if item.kind==theme and theme in ["engine","observatory"]:
   mechanism.x=center.x+clampf(item.x,-3.8,3.8)
   mechanism.z=minf(mechanism.z,center.z+depth)
   continue
  var group=Node3D.new();group.name="ArenaLandmark";parent.add_child(group,true);group.position=center+Vector3(item.x,0,depth)
  group.scale=Vector3.ONE*(2.1 if item.kind in ["house","warehouse","tower","spire","arch","furnace"] else 1.4)
  landmark(group,Vector3.ZERO,item.kind,item.get("roof_variant",0))
 if theme in ["village","road"]:
  cart(parent,center+Vector3(-6,0,-3.8));fence(parent,center+Vector3(3,0,-4),5.0)
  for i in range(3):barrel(parent,center+Vector3(6+i*.4,0,-4.3),1.0)
 if theme=="aqueduct":aqueduct_gallery(parent,center)
 if theme in ["abbey","observatory","castle"]:
  for x in ([] if theme=="castle" else range(-12,13,4)):
   cylinder(parent,center+Vector3(x,1.8,-5),3.6,.32,Color("9e9d8d"))
   cylinder(parent,center+Vector3(x,.12,-5),.24,.5,Color("7f8178"))
   cylinder(parent,center+Vector3(x,3.5,-5),.3,.48,Color("c2bea7"))
   if theme=="abbey" and x<12:
    arch_span(parent,center+Vector3(x+2,3.55,-5),1.65,.35,.8)
  if theme=="castle":
   Fortification.build_castle_wall(self,parent,center+Vector3(0,0,-9))
  elif theme=="observatory":
   var orbit=preload("res://scripts/clockwork_orbit.gd").new();parent.add_child(orbit);orbit.position=mechanism+Vector3.UP*2.6;orbit.configure(theme,1.54,.55)
 if ArenaRidges.LANDSCAPES.has(theme):
  ArenaRidges.build(parent,center,theme)
  if theme=="mountain":
   for i in range(16):boulder(parent,center+Vector3(-12+(i*7)%25,.4,-4-i%3),1.0+i%3*.3)
   for i in range(8):
    battle_tree(parent,center+Vector3(-17+(i*11)%35,-.06,-9-i%3*2),i*47,2.2+i%3*.2,theme)
 if theme=="furnace" and backdrop.is_empty():
  for x in [-5,5]:furnace(parent,center+Vector3(x,0,-8),2.1)
 if theme=="engine":
  sun_engine_basin(parent,mechanism)
  sun_engine(parent,mechanism)
 ground_cover.add_arena(parent,center,context)
 if batching_enabled:batcher.combine(parent)
 var atmosphere=AmbientDrift.new();parent.add_child(atmosphere);atmosphere.position=center+Vector3(0,0,-3)
 atmosphere.configure(theme,Vector3(28,4,14),true)
 return theme

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
