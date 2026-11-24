extends RefCounted

const Architecture=preload("res://scripts/architecture.gd")
const FRONT=.61
const EAVE=1.71
const ROOF_WIDTH=1.19
const RIDGE=EAVE+.96*Architecture.SLOPE/ROOF_WIDTH
const ROOF_SCALE=Vector3(ROOF_WIDTH,1,.92)
const ROOF_OFFSET=Vector3(0,RIDGE-Architecture.RIDGE+Architecture.THICKNESS,0)
static var gables: ArrayMesh
static var spandrels: ArrayMesh

static func build(scenery,parent: Node3D,site: Vector3,size: float):
 var house=Node3D.new();house.name="ReedTollhouse";house.position=site
 house.scale=Vector3.ONE*size;parent.add_child(house)
 var stone=scenery.detail_material(3)
 var plaster=scenery.building_material(scenery.BuildingFinish.OCHRE_PLASTER)
 var oak=scenery.building_material(scenery.BuildingFinish.OAK)
 for side in [-1,1]:
  var pier=.735*side
  scenery.block(house,Vector3(pier,.07,0),Vector3(.53,.18,1.34),stone).name="TollFooting"
  for course in 4:
   var shift=.018*(1 if course%2 else -1)*side
   scenery.block(house,Vector3(pier+shift,.23+course*.18,0),Vector3(.45,.178,1.22),stone).name="TollPierCourse"
  scenery.block(house,Vector3(pier,.83,0),Vector3(.54,.13,1.28),stone).name="TollImpost"
  scenery.block(house,Vector3(side*.865,1.13,0),Vector3(.19,.55,1.22),stone).name="TollSpandrel"
 scenery.arch_span(house,Vector3(0,.84,0),.51,.255,1.22).name="TollPassage"
 scenery.mesh(house,spandrel_mesh(),Vector3.ZERO,Vector3.ONE,stone).name="ArchBacking"
 scenery.block(house,Vector3(0,1.47,0),Vector3(1.91,.24,1.244),plaster).name="TollOffice"
 scenery.block(house,Vector3(0,1.365,0),Vector3(1.98,.074,1.29),oak).name="OfficeSill"
 scenery.block(house,Vector3(0,1.68,0),Vector3(1.94,.09,1.25),oak).name="OfficeWallPlate"
 scenery.mesh(house,gable_mesh(),Vector3.ZERO,Vector3.ONE,plaster).name="OfficeGables"
 var roof=scenery.mesh(house,Architecture.roof(),ROOF_OFFSET,ROOF_SCALE,Architecture.material())
 roof.name="TollSlateRoof"
 for face in [-1,1]:
  var z=face*FRONT
  for x in [-.90,0,.90]:
   var timber_height=.27 if x!=0 else .79
   scenery.block(house,Vector3(x,1.39+timber_height*.5,z),Vector3(.058,timber_height,.064),oak).name="OfficeUpright"
  for side in [-1,1]:
   var brace=scenery.block(house,Vector3(side*.40,1.81,z),Vector3(.58,.052,.052),oak)
   brace.rotation.z=-side*.39;brace.name="GableBrace"
 scenery.block(house,Vector3(0,1.58,FRONT+.04),Vector3(.39,.24,.054),oak).name="TollWindowFrame"
 scenery.block(house,Vector3(0,1.58,FRONT+.071),Vector3(.30,.16,.018),Color("374b50")).name="TollWindow"
 scenery.block(house,Vector3(0,1.58,FRONT+.085),Vector3(.028,.17,.023),Color("b59a69")).name="WindowMullion"
 scenery.block(house,Vector3(0,1.94,FRONT+.050),Vector3(.43,.20,.042),oak).name="TollSign"
 var brass=Color("be9d64")
 scenery.block(house,Vector3(0,1.967,FRONT+.074),Vector3(.21,.017,.009),brass).name="SignBeam"
 scenery.block(house,Vector3(0,1.951,FRONT+.074),Vector3(.016,.063,.009),brass).name="SignPivot"
 for x in [-.079,.079]:
  scenery.block(house,Vector3(x,1.944,FRONT+.074),Vector3(.010,.045,.009),brass).name="SignLink"
  scenery.block(house,Vector3(x,1.921,FRONT+.074),Vector3(.078,.018,.009),brass).name="SignPan"
 return house

static func gable_mesh() -> ArrayMesh:
 if gables!=null:return gables
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[Vector2(.96,EAVE),Vector2(-.96,EAVE),Vector2(0,RIDGE)]
 for side in [-1,1]:
  for corner in ([0,1,2] if side==1 else [1,0,2]):
   var point=points[corner]
   tool.set_normal(Vector3.BACK*side);tool.set_uv(Vector2(point.x/1.92+.5,1.0-(point.y-EAVE)/(RIDGE-EAVE)))
   tool.add_vertex(Vector3(point.x,point.y,side*FRONT))
 gables=tool.commit()
 return gables

static func spandrel_mesh() -> ArrayMesh:
 if spandrels!=null:return spandrels
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  var last=Vector3(.865,.84,side*(FRONT-.012))
  for index in 12:
   var angle=index*PI/11
   var next=Vector3(cos(angle)*.75,minf(.84+sin(angle)*.75,1.392),last.z)
   Architecture.quad(tool,[last,next,Vector3(next.x,1.40,next.z),Vector3(last.x,1.40,last.z)],Vector3.BACK*side,Color.WHITE)
   last=next
  Architecture.quad(tool,[last,Vector3(-.865,.84,last.z),Vector3(-.865,1.40,last.z),Vector3(last.x,1.40,last.z)],Vector3.BACK*side,Color.WHITE)
 spandrels=tool.commit()
 return spandrels
