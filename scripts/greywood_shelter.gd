extends RefCounted
# The pitched canvas shelters the Greywood refugees. The open side faces the
# road. A low foot rail and two upright poles hold the cloth above damp ground.
const Roof=preload("res://scripts/architecture.gd")
const HALF_WIDTH=.66
const HALF_LENGTH=.72
const TOP=1.08
const EAVE=.045
const CLOTH=Color("bfb28d")
const HEM=Color("8a795c")
const WOOD=Color("66513c")
static var folded_canvas: ArrayMesh
static var canvas_paint: StandardMaterial3D

static func build(scenery,parent: Node3D,position: Vector3,extent: float) -> void:
 var shelter=Node3D.new()
 shelter.name="GreywoodShelter"
 shelter.position=position
 shelter.scale=Vector3.ONE*extent
 parent.add_child(shelter)
 scenery.mesh(shelter,canvas_shape(),Vector3.ZERO,Vector3.ONE,paint()).name="Canvas"
 scenery.block(shelter,Vector3(0,TOP-.036,0),Vector3(.065,.058,HALF_LENGTH*2+.11),WOOD).name="RidgePole"
 for end in [-1,1]:
  var pole=scenery.block(shelter,Vector3(0,(TOP-.036)*.5,end*(HALF_LENGTH-.06)),Vector3(.064,TOP-.036,.064),WOOD)
  pole.name="Upright"
 for side in [-1,1]:
  var rail=scenery.block(shelter,Vector3(side*(HALF_WIDTH-.018),.04,0),Vector3(.067,.08,HALF_LENGTH*2+.06),WOOD)
  rail.name="EaveRail"

static func paint() -> StandardMaterial3D:
 if canvas_paint==null:
  canvas_paint=StandardMaterial3D.new()
  canvas_paint.vertex_color_use_as_albedo=true
  canvas_paint.vertex_color_is_srgb=true
  canvas_paint.cull_mode=BaseMaterial3D.CULL_DISABLED
  canvas_paint.roughness=.94
 return canvas_paint

static func panel_point(side: int,t: float,depth: float) -> Vector3:
 return Vector3(side*HALF_WIDTH*t,lerpf(TOP,EAVE,t),depth)

static func canvas_shape() -> ArrayMesh:
 if folded_canvas!=null:return folded_canvas
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var bands=[0.0,.06,.43,.47,.94,1.0]
 var shades=[CLOTH.lightened(.11),CLOTH,CLOTH.darkened(.075),CLOTH.lightened(.035),HEM]
 for side in [-1,1]:
  var normal=Vector3(side*(TOP-EAVE),HALF_WIDTH,0).normalized()
  for index in shades.size():
   var inner=bands[index];var outer=bands[index+1]
   var corners=[
    panel_point(side,inner,-HALF_LENGTH),panel_point(side,outer,-HALF_LENGTH),
    panel_point(side,outer,HALF_LENGTH),panel_point(side,inner,HALF_LENGTH),
   ]
   Roof.quad(surface,corners,normal,shades[index])
  var rear=-HALF_LENGTH+.015
  triangle(surface,[Vector3(0,TOP-.035,rear),Vector3(side*(HALF_WIDTH-.006),EAVE,rear),Vector3(0,EAVE,rear)],Vector3.FORWARD,CLOTH.darkened(.24))
  var front=HALF_LENGTH-.012
  var peak=Vector3(0,TOP-.015,front)
  var edge=Vector3(side*(HALF_WIDTH-.006),EAVE,front)
  var tie=Vector3(side*.25,.082,front+.07)
  var fold=Vector3(side*.13,.48,front+.025)
  triangle(surface,[peak,edge,fold],Vector3.BACK,CLOTH.darkened(.17))
  triangle(surface,[edge,tie,fold],Vector3.BACK,CLOTH.darkened(.23))
 folded_canvas=surface.commit()
 return folded_canvas

static func triangle(surface: SurfaceTool,points: Array,outward: Vector3,color: Color):
 var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 var order=[0,1,2]
 if normal.dot(outward)<0:
  normal=-normal
  order=[0,2,1]
 var uv=[Vector2(.5,0),Vector2(1,1),Vector2(0,1)]
 for index in order:
  surface.set_normal(normal);surface.set_color(color);surface.set_uv(uv[index]);surface.add_vertex(points[index])
