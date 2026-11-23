extends RefCounted
## Three crossed textured cards share the trunk attachment and bend at their tips.
const ATLAS=Vector2(1254,1254)
const REGIONS=[Rect2i(97,18,423,596),Rect2i(666,26,547,587),Rect2i(90,647,471,584),Rect2i(739,652,402,581)]
const ATTACHMENTS=[Vector2(310,606),Vector2(937,605),Vector2(330,1223),Vector2(949,1225)]
const BASE=.22

var shapes={}
var paint: ShaderMaterial

func material() -> ShaderMaterial:
 if paint==null:
  paint=ShaderMaterial.new()
  paint.shader=preload("res://assets/shaders/ground_cover.gdshader")
  paint.set_shader_parameter("plant_atlas",load("res://assets/art/conifer-crowns-v1.png"))
 return paint

func shape(variant: int) -> ArrayMesh:
 if shapes.has(variant):return shapes[variant]
 var rect=REGIONS[variant]
 var attachment=ATTACHMENTS[variant]
 var scale_value=(1.0-BASE)/(attachment.y-rect.position.y)
 var pixels=[Vector2(rect.position.x,rect.end.y),Vector2(rect.end),Vector2(rect.end.x,rect.position.y),Vector2(rect.position)]
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for angle in [0.0,PI/3.0,2.0*PI/3.0]:
  var basis=Basis(Vector3.UP,angle)
  for index in [0,2,1,0,3,2]:
   var pixel=pixels[index]
   var offset=Vector2(pixel.x-attachment.x,attachment.y-pixel.y)*scale_value
   surface.set_normal(basis*Vector3.BACK)
   surface.set_uv(pixel/ATLAS)
   surface.set_uv2(Vector2(0,clampf(offset.y/(1.0-BASE),0,1)))
   surface.add_vertex(basis*Vector3(offset.x,BASE+offset.y,0))
 shapes[variant]=surface.commit()
 return shapes[variant]
