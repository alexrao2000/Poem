extends RefCounted
const MapSurface=preload("res://scripts/map_surface.gd")
const RiverBank=preload("res://scripts/river_bank.gd")
const MapGround=preload("res://scripts/map_ground.gd")
const WindCloth=preload("res://scripts/wind_cloth.gd")
const Architecture=preload("res://scripts/architecture.gd")
const AmbientDrift=preload("res://scripts/ambient_drift.gd")
const GroundCover=preload("res://scripts/ground_cover.gd")
# Shared landscape construction for the tactical board and battle stage.
# Masonry spans use closed wedge stones with small joints and an open underside.
var materials: Dictionary = {}
var batching_enabled=true
var batcher=preload("res://scripts/static_batch.gd").new()
var ground_cover=GroundCover.new()
var atlas: Texture2D
var environment_atlas: Texture2D
var foliage_atlas: Texture2D

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

func water_material() -> ShaderMaterial:
 if materials.has("water"):return materials.water
 var m=ShaderMaterial.new();m.shader=load("res://assets/shaders/water.gdshader");materials.water=m;return m

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
 materials[key]=m
 return m

func mesh(parent: Node3D,shape: Mesh,p: Vector3,scale_value: Vector3,m: Material) -> MeshInstance3D:
 var n=MeshInstance3D.new();n.mesh=shape;n.position=p;n.scale=scale_value;n.material_override=m;parent.add_child(n);return n

func block(parent,p,size,color):
 return mesh(parent,BoxMesh.new(),p,size,material(color))

func ground(parent,p,size,tile,blended: Material=null):
 var shape=PlaneMesh.new();shape.size=size
 return mesh(parent,shape,p,Vector3.ONE,blended if blended!=null else ground_material(tile))

func cylinder(parent,p,height,radius,color,top=-1.0):
 var shape=CylinderMesh.new();shape.height=height;shape.bottom_radius=radius;shape.top_radius=radius if top<0 else top;shape.radial_segments=8
 return mesh(parent,shape,p,Vector3.ONE,material(color))

func boulder(parent,p,radius):
 var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=7;shape.rings=4
 return mesh(parent,shape,p,Vector3(radius,radius*.6,radius*.8),ground_material(1))

func arch_span(parent,p,inner_radius=.5,thickness=.4,depth=.6):
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var uv=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
 for segment in range(11):
  var a=segment*PI/11+.008;var b=(segment+1)*PI/11-.008
  var points=[]
  for z in [depth*.5,-depth*.5]:
   for entry in [[a,inner_radius],[a,inner_radius+thickness],[b,inner_radius+thickness],[b,inner_radius]]:
    points.append(Vector3(cos(entry[0])*entry[1],sin(entry[0])*entry[1],z))
  for face in [[0,1,2,3],[7,6,5,4],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
   for i in [0,1,2,0,2,3]:surface.set_uv(uv[i]);surface.add_vertex(points[face[i]])
 surface.generate_normals()
 var span=mesh(parent,surface.commit(),p,Vector3.ONE,detail_material(3));span.name="MasonryArch"
 return span

func tree(parent,p,seed_value=0):
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

func bridge(parent,p,vertical=false):
 var root=Node3D.new();parent.add_child(root);root.position=p
 if vertical:root.rotation.y=PI/2
 for i in range(7):
  block(root,Vector3((i-3)*.145,MapSurface.BRIDGE_HEIGHT-.045,0),Vector3(.135,.09,.98),Color("978367").lightened((i%3)*.025))
 for z in [-.43,.43]:
  block(root,Vector3(0,.25,z),Vector3(1,.07,.055),Color("665747"))
  for x in [-.4,.4]:block(root,Vector3(x,.16,z),Vector3(.065,.4,.065),Color("655444"))

func sanctuary(parent,p):
 cylinder(parent,p+Vector3(0,MapSurface.SANCTUARY_HEIGHT-.06,0),.08,.36,Color("b8b8a0"))
 block(parent,p+Vector3(0,MapSurface.SANCTUARY_HEIGHT-.01,0),Vector3(.35,.02,.08),Color("f5e4ac"))
 block(parent,p+Vector3(0,MapSurface.SANCTUARY_HEIGHT-.01,0),Vector3(.08,.02,.35),Color("f5e4ac"))

func house(parent,p,scale_value=1.0,roof_variant=-1):
 var root=Node3D.new();parent.add_child(root);root.position=p;root.scale=Vector3.ONE*scale_value
 root.name="House"
 if roof_variant<0:roof_variant=Architecture.variant_at(p)
 root.set_meta("roof_variant",roof_variant)
 block(root,Vector3(0,.6,0),Vector3(1.6,1.2,1.25),Color("c5bca4"))
 # Stone foundation, half-timber braces, door and windows.
 var foundation=block(root,Vector3(0,.08,0),Vector3(1.7,.16,1.34),Color("8b8a79"));foundation.material_override=detail_material(3)
 for x in [-.76,0,.76]:block(root,Vector3(x,.6,.64),Vector3(.06,1.2,.06),Color("695543"))
 for y in [.2,.95]:block(root,Vector3(0,y,.64),Vector3(1.6,.055,.055),Color("695543"))
 block(root,Vector3(-.3,.39,.67),Vector3(.28,.65,.025),Color("584c42"))
 block(root,Vector3(.4,.7,.67),Vector3(.27,.3,.025),Color("49616b"))
 for x in [.25,.55]:block(root,Vector3(x,.7,.69),Vector3(.06,.36,.05),Color("7a8379"))
 for y in [.54,.85]:block(root,Vector3(.4,y,.7),Vector3(.37,.045,.045),Color("796854"))
 block(root,Vector3(.4,.7,.71),Vector3(.025,.3,.025),Color("baab8e"))
 block(root,Vector3(-.3,.05,.85),Vector3(.5,.1,.4),Color("a4a18e"))
 for x in [-.48,-.12]:block(root,Vector3(x,.42,.7),Vector3(.05,.72,.05),Color("76624b"))
 block(root,Vector3(-.3,.79,.7),Vector3(.4,.06,.06),Color("76624b"))
 for x in [-.82,.82]:
  for z in [-.48,.48]:block(root,Vector3(x,.6,z),Vector3(.05,1.2,.06),Color("695543"))
  for y in [.25,.95]:block(root,Vector3(x,y,0),Vector3(.05,.06,1.25),Color("695543"))
 for z in [-.63,.63]:
  var gable=SurfaceTool.new();gable.begin(Mesh.PRIMITIVE_TRIANGLES)
  for point in [Vector3(-.8,1.2,z),Vector3(.8,1.2,z),Vector3(0,1.7,z)]:gable.add_vertex(point)
  gable.generate_normals()
  var plaster=material(Color("c5bca4")).duplicate();plaster.cull_mode=BaseMaterial3D.CULL_DISABLED
  mesh(root,gable.commit(),Vector3.ZERO,Vector3.ONE,plaster)
  block(root,Vector3(0,1.42,z),Vector3(.065,.55,.06),Color("695543"))
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
  var water=water_material()
  var river=PlaneMesh.new();river.size=Vector2(2 if theme=="river" else 1,64)
  mesh(parent,river,Vector3(5.5 if theme=="river" else 7,-.07,5),Vector3.ONE,water)
 for y in range(game.board_size().y):
  for x in range(game.board_size().x):
   var t=game.terrain(Vector2i(x,y));var p=Vector3(x,0,y)
   if t in ["~","="]:
    var water=water_material()
    var plane=PlaneMesh.new();plane.size=Vector2.ONE
    var water_cell=mesh(parent,plane,p-Vector3(0,.07,0),Vector3.ONE,water);water_cell.name="MapWater"
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
   elif t=="f":tree(parent,p+Vector3(.22,0,-.22),x+y*17)
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
  for i in range(22):tree(parent,Vector3(-4+(i*7)%23,0,-3-(i%3)*1.3),i*23)
  for i in range(12):tree(parent,Vector3(-3+(i*13)%21,0,12+i%3),i*11)
 elif theme=="mountain":
  for i in range(16):boulder(parent,Vector3(-3+(i*5)%22,.2,-3-i%3),2.5)
 elif theme in ["harbor","aqueduct"]:
  var sea=PlaneMesh.new();sea.size=Vector2(55,35)
  mesh(parent,sea,Vector3(7,-.12,26),Vector3.ONE,water_material())

 ground_cover.add_map(parent,game,building_cells)
 if batching_enabled:batcher.combine(parent)
 var atmosphere=AmbientDrift.new();parent.add_child(atmosphere)
 atmosphere.position=Vector3((game.board_size().x-1)*.5,0,(game.board_size().y-1)*.5)
 atmosphere.configure(theme,Vector3(game.board_size().x+6,3,game.board_size().y+6),false,game.chapter)

func landmark(parent,p,kind,roof_variant=-1):
 var stone=Color("969b91");var gold=Color("bba16b")
 if kind in ["house","warehouse"]:
  house(parent,p,1.4 if kind=="warehouse" else 1.2,roof_variant)
 elif kind=="fountain":
  cylinder(parent,p+Vector3(0,.08,0),.16,.46,stone)
  cylinder(parent,p+Vector3(0,.18,0),.12,.40,Color("5d8d9b"))
  cylinder(parent,p+Vector3(0,.42,0),.65,.09,stone)
  cylinder(parent,p+Vector3(0,.7,0),.08,.24,stone)
 elif kind in ["tower","spire"]:
  cylinder(parent,p+Vector3(0,1,0),2,.55,stone)
  cylinder(parent,p+Vector3(0,.15,0),.3,.7,stone.darkened(.15))
  cylinder(parent,p+Vector3(0,2,0),.25,.65,stone.lightened(.08))
  if kind=="spire":cylinder(parent,p+Vector3(0,2.8,0),1.5,.65,Color("586b75"),0)
  else:
   for i in range(8):block(parent,p+Vector3(cos(i*PI/4)*.55,2.3,sin(i*PI/4)*.55),Vector3(.22,.4,.22),stone)
 elif kind=="arch":
  for x in [-.7,.7]:
   var pillar=block(parent,p+Vector3(x,.55,0),Vector3(.4,1.1,.6),stone);pillar.material_override=detail_material(3)
   block(parent,p+Vector3(x,.08,0),Vector3(.5,.16,.7),stone.darkened(.1))
  arch_span(parent,p+Vector3(0,1.1,0))
 elif kind=="boat":
  var hull=cylinder(parent,p+Vector3(0,-.08,0),.4,.65,Color("605141"),.9);hull.scale.z=2.0
  block(parent,p+Vector3(0,.18,0),Vector3(1.2,.1,2.8),Color("9b886b"))
  cylinder(parent,p+Vector3(0,1.1,0),2.2,.045,Color("685644"))
  var sail=WindCloth.new();parent.add_child(sail);sail.position=p+Vector3(0,1.5,0)
  sail.configure(Vector2(1.3,1.4),Color("dcd4b9"),false,p.x*.71+p.z*.37)
 elif kind=="camp":
  var tent=cylinder(parent,p+Vector3(0,.5,0),1,.8,Color("c7bba1"),0);tent.scale.z=1.5
  cylinder(parent,p+Vector3(1,.06,0),.1,.3,Color("6a5c4b"))
 elif kind in ["engine","observatory"]:
  cylinder(parent,p+Vector3(0,.2,0),.4,1.3,stone)
  var ring=TorusMesh.new();ring.inner_radius=1.05;ring.outer_radius=1.15
  var orbit=mesh(parent,ring,p+Vector3(0,1.5,0),Vector3.ONE,material(gold));orbit.rotation.x=PI/2;orbit.rotation.y=.3
  var globe=SphereMesh.new();globe.radius=.55;globe.height=1.1
  var core=material(Color("f8cd7e") if kind=="engine" else Color("5b859c")).duplicate()
  if kind=="engine":core.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  mesh(parent,globe,p+Vector3(0,1.5,0),Vector3.ONE,core)
 elif kind=="furnace":
  cylinder(parent,p+Vector3(0,1,0),2,.65,Color("595b5b"))
  for y in [.5,1.3]:cylinder(parent,p+Vector3(0,y,0),.12,.72,gold)
  var glow=block(parent,p+Vector3(0,.7,.66),Vector3(.45,.55,.025),Color("e7a16b"))
  glow.material_override=glow.material_override.duplicate();glow.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 elif kind=="ruin":
  for i in range(3):cylinder(parent,p+Vector3(i*.6,.4+i*.2,0),.8+i*.4,.22,stone)

func combat_context(game,a,b) -> Dictionary:
 var midpoint=Vector2(a.x+b.x,a.y+b.y)*.5
 var axis=Vector2(b.x-a.x,b.y-a.y).normalized()
 if axis.is_zero_approx():axis=Vector2.RIGHT
 var depth=Vector2(-axis.y,axis.x)
 var candidates=[]
 for item in game.info().get("landmarks",[]):
  var delta=Vector2(item.position[0],item.position[1])-midpoint
  if delta.length()>8:continue
  candidates.append({"kind":item.kind,"roof_variant":Architecture.variant_at(Vector3(item.position[0],0,item.position[1])),"distance":delta.length(),"x":clampf(delta.dot(axis)*2.2,-11,11),"z":-7-clampf(absf(delta.dot(depth))*1.8,0,10)})
 candidates.sort_custom(func(left,right):return left.distance<right.distance)
 return {"chapter":game.chapter,"environment":game.info().get("environment","village"),"terrain":game.terrain(game.pos(b)),"landmarks":candidates.slice(0,2)}

func battle_tree(parent,point,seed_value,scale_value):
 var group=Node3D.new();group.name="ArenaTree";group.position=point;group.scale=Vector3.ONE*scale_value;parent.add_child(group)
 tree(group,Vector3.ZERO,seed_value)

func battle_landscape(parent,center,context={}):
 var theme=context.get("environment","village")
 parent.set_meta("environment",theme)
 var tile=context.get("terrain","p")
 parent.set_meta("terrain",tile)
 var stone=theme in ["abbey","aqueduct","observatory","castle","engine","furnace"]
 var wooden_floor=theme=="harbor" or tile=="="
 var surface=3 if stone else 2 if tile=="h" else 1 if tile in ["p","o","+"] else 0
 parent.set_meta("arena_surface",surface)
 ground(parent,center-Vector3(0,.06,0),Vector2(70,70),3 if stone else 0)
 if not wooden_floor:ground(parent,center,Vector2(24,6),surface)
 if theme in ["river","harbor","aqueduct"] or context.get("terrain")=="=":
  var water=water_material()
  var plane=PlaneMesh.new();plane.size=Vector2(60,60 if wooden_floor else 40)
  var water_surface=mesh(parent,plane,center+Vector3(0,-.055 if wooden_floor else -.025,-12 if wooden_floor else -22),Vector3.ONE,water);water_surface.name="ArenaWater"
  if wooden_floor:
   for x in range(-10,11):
    for z in range(-2,3):
     var plank=block(parent,center+Vector3(x,-.025,z),Vector3(.98,.05,.98),Color("877560").lightened((x+z+30)%3*.02));plank.name="ArenaDeck"
  for x in range(-10,11,2):
   block(parent,center+Vector3(x,.55,-3),Vector3(.13,1.1,.13),Color("72624f"))
  block(parent,center+Vector3(0,.7,-3),Vector3(22,.12,.10),Color("8e7c60"))
 if theme in ["village","river","road","forest","harbor"]:
  for i in range(28 if theme=="forest" or tile=="f" else 17):
   battle_tree(parent,center+Vector3(-20+(i*11)%41,0,-8-(i%4)*3),i*83,2.6+(i%3)*.25)
  if theme!="forest" and context.get("landmarks",[]).is_empty():
   for i in range(3):house(parent,center+Vector3(-12+i*11,0,-17),2.0+i*.2)
 var backdrop=context.get("landmarks",[])
 parent.set_meta("backdrop_count",backdrop.size())
 for item in backdrop:
  var group=Node3D.new();group.name="ArenaLandmark";parent.add_child(group);group.position=center+Vector3(item.x,0,item.z)
  group.scale=Vector3.ONE*(2.1 if item.kind in ["house","warehouse","tower","spire","arch"] else 1.4)
  landmark(group,Vector3.ZERO,item.kind,item.get("roof_variant",0))
 if theme in ["village","road"]:
  cart(parent,center+Vector3(-6,0,-3.8));fence(parent,center+Vector3(3,0,-4),5.0)
  for i in range(3):barrel(parent,center+Vector3(6+i*.4,0,-4.3),1.0)
 if theme in ["abbey","aqueduct","observatory","castle"]:
  for x in range(-12,13,4):
   cylinder(parent,center+Vector3(x,1.8,-5),3.6,.32,Color("9e9d8d"))
   cylinder(parent,center+Vector3(x,.12,-5),.24,.5,Color("7f8178"))
   cylinder(parent,center+Vector3(x,3.5,-5),.3,.48,Color("c2bea7"))
   if theme in ["aqueduct","abbey"] and x<12:
    arch_span(parent,center+Vector3(x+2,3.55,-5),1.65,.35,.8)
  if theme=="castle":
   block(parent,center+Vector3(0,2,-9),Vector3(35,4,.7),Color("858b88"))
   for x in range(-16,17,2):block(parent,center+Vector3(x,4.2,-9),Vector3(.8,.8,.9),Color("9a9d91"))
  elif theme=="observatory":
   var ring=TorusMesh.new();ring.inner_radius=1.5;ring.outer_radius=1.58
   var orbit=mesh(parent,ring,center+Vector3(0,2.6,-10),Vector3.ONE,material(Color("b9a46f")))
   orbit.rotation.z=.7
 if theme in ["mountain","road","forest","river","village"]:
  for i in range(9):
   var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=18;shape.rings=8
   mesh(parent,shape,center+Vector3(-45+i*11,-1,-35-(i%3)*4),Vector3(13,(9 if theme=="mountain" else 4)+i%3,9),material(Color("586c69").lightened(i%3*.035)))
  if theme=="mountain":
   for i in range(16):boulder(parent,center+Vector3(-12+(i*7)%25,.4,-4-i%3),1.0+i%3*.3)
 if theme in ["engine","furnace"]:
  for x in [-8,-4,0,4,8]:
   cylinder(parent,center+Vector3(x,2,-7),4,.4,Color("494d51"))
   cylinder(parent,center+Vector3(x,3.5,-7),.12,.6,Color("bb9a64"))
   var core_material=material(Color("fbb56c")).duplicate();core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   var core=SphereMesh.new();core.radius=.24;core.height=.48
   mesh(parent,core,center+Vector3(x,2.5,-6.6),Vector3.ONE,core_material)
  if theme=="engine":
   var ring=TorusMesh.new();ring.inner_radius=1.75;ring.outer_radius=2
   var outer=mesh(parent,ring,center+Vector3(0,4,-12),Vector3.ONE,material(Color("c6ad71")))
   outer.rotation.x=PI/2
   var shape=SphereMesh.new();shape.radius=1.2;shape.height=2.4
   var glow=material(Color("ffe3a0")).duplicate();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   mesh(parent,shape,center+Vector3(0,4,-12),Vector3.ONE,glow)
 ground_cover.add_arena(parent,center,context)
 if batching_enabled:batcher.combine(parent)
 var atmosphere=AmbientDrift.new();parent.add_child(atmosphere);atmosphere.position=center+Vector3(0,0,-3)
 atmosphere.configure(theme,Vector3(28,4,14),true)
 return theme

func barrel(parent,p,scale_value=1.0):
 var root=Node3D.new();parent.add_child(root);root.position=p;root.scale=Vector3.ONE*scale_value
 cylinder(root,Vector3(0,.20,0),.40,.16,Color("77634a"),.16)
 for y in [.06,.32]:cylinder(root,Vector3(0,y,0),.035,.168,Color("515754"))
 cylinder(root,Vector3(0,.405,0),.015,.145,Color("a08a66"))
 for x in [-.07,0,.07]:block(root,Vector3(x,.415,0),Vector3(.008,.008,.26),Color("695940"))

func fence(parent,p,length=3.0):
 for i in range(int(length)+1):
  cylinder(parent,p+Vector3(i,.36,0),.72,.045,Color("6e604d"),.025)
 for y in [.25,.55]:block(parent,p+Vector3(length*.5,y,0),Vector3(length,.07,.04),Color("897659"))

func cart(parent,p):
 var root=Node3D.new();parent.add_child(root);root.position=p
 block(root,Vector3(0,.4,0),Vector3(.9,.10,1.3),Color("816b4f"))
 for x in [-.44,.44]:
  block(root,Vector3(x,.63,0),Vector3(.045,.4,1.3),Color("927e5e"))
  for z in [-.42,.42]:
   var wheel=cylinder(root,Vector3(x*1.22,.27,z),.06,.25,Color("544d41"));wheel.rotation.z=PI/2
   var hub=cylinder(root,Vector3(x*1.3,.27,z),.07,.075,Color("a08a62"));hub.rotation.z=PI/2
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
