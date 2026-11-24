extends RefCounted

const Masonry=preload("res://scripts/architecture.gd")
const PLATE=Vector3(0,1.27,-.14)
const INCLINATION=-.66
const PLANISPHERE=Vector2(-.24,.032)
const STAR_SITES=[
 Vector2(-.66,.136),Vector2(-.46,.26),Vector2(-.28,.123),Vector2(-.19,-.133),
 Vector2(-.06,-.205),Vector2(.025,.258),Vector2(.145,.136),Vector2(.09,-.026),
 Vector2(.33,.074),Vector2(.575,.236),Vector2(.677,.001),Vector2(.48,-.18),
 Vector2(.268,-.258),Vector2(-.55,-.24),Vector2(-.39,-.173),Vector2(.72,-.27),
]
const CONSTELLATIONS=[[0,1,2,3,4], [5,6,7,8], [9,10,11,12]]
static var engravings: ArrayMesh

static func build(scenery,parent: Node3D,point: Vector3,size: float):
 var lectern=Node3D.new();lectern.name="StarfallChartLectern";lectern.position=point;lectern.scale=Vector3.ONE*size
 parent.add_child(lectern)
 var stone=scenery.detail_material(3)
 var oak=scenery.building_material(scenery.BuildingFinish.DECK_WOOD)
 var brass=scenery.material(Color("aa9063"))
 var table=Node3D.new();table.name="InclinedChart";table.position=PLATE;table.rotation.x=INCLINATION;lectern.add_child(table)
 for side in [-1,1]:
  var x=.58*side
  scenery.block(lectern,Vector3(x,.012,-.05),Vector3(.38,.16,.58),stone).name="ChartFooting"
  var foot=Vector3(x,.08,-.01)
  var top=table.transform*Vector3(x,-.39,-.047)
  var brace=table.transform*Vector3(x,.33,-.052)
  scenery.timber_span(lectern,foot,top,Vector2(.145,.145),oak).name="ChartPost"
  scenery.timber_span(lectern,Vector3(x,.082,-.26),brace,Vector2(.092,.092),oak).name="ChartBrace"
  scenery.block(table,Vector3(.848*side,0,.031),Vector3(.065,.938,.11),brass).name="ChartRail"
  scenery.block(table,Vector3(0,.503*side,.031),Vector3(1.761,.068,.11),brass).name="ChartRail"
 scenery.block(table,Vector3.ZERO,Vector3(1.69,.97,.113),Color("243641")).name="SlateChart"
 scenery.mesh(table,star_chart(),Vector3.BACK*.06,Vector3.ONE,Masonry.material()).name="EngravedStars"
 scenery.block(lectern,Vector3(0,.34,-.02),Vector3(1.18,.10,.11),oak).name="ChartCrossbar"

static func star_chart() -> ArrayMesh:
 if engravings!=null:return engravings
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for radius in [.265,.349]:
  for segment in 36:
   var begin=segment*TAU/36
   var end=(segment+.93)*TAU/36
   line(tool,PLANISPHERE+Vector2.from_angle(begin)*radius,PLANISPHERE+Vector2.from_angle(end)*radius,.009,Color("647470"))
 for constellation in CONSTELLATIONS:
  for index in range(constellation.size()-1):
   line(tool,STAR_SITES[constellation[index]],STAR_SITES[constellation[index+1]],.014,Color("a99570"),.001)
 for index in STAR_SITES.size():
  var p=STAR_SITES[index];var radius=.031 if index in [1,6,10,12] else .017
  face(tool,[p-Vector2(0,radius),p+Vector2(-radius*.73,0),p+Vector2(0,radius),p+Vector2(radius*.73,0)],Color("e2cc91"),.002)
 for index in range(-7,8):
  var p=Vector2(index*.104,-.385)
  line(tool,p,p+Vector2.UP*(.06 if index%3==0 else .032),.015,Color("b5a478"))
 line(tool,Vector2(-.744,-.385),Vector2(.744,-.385),.012,Color("b5a478"))
 engravings=tool.commit()
 return engravings

static func line(tool: SurfaceTool,first: Vector2,last: Vector2,width: float,paint: Color,depth=0.0):
 var half=(last-first).orthogonal().normalized()*width*.5
 face(tool,[first-half,last-half,last+half,first+half],paint,depth)

static func face(tool: SurfaceTool,points: Array,color: Color,depth=0.0):
 var corners=points.map(func(p):return Vector3(p.x,p.y,depth))
 Masonry.quad(tool,corners,Vector3.BACK,color)
