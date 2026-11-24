extends RefCounted
## Slate below the observatory terrace and the broken banks of its summit.

const APRON_SIZE = Vector2(196, 144)
const RockForms = preload("res://scripts/rock_forms.gd")
const RIM_WIDTH = 48.0
const RIM_DEPTH = [0.0, 1.0, 2.15, 3.1, 4.85, 6.6, 9.4, 12.8]
const RIM_HEIGHT = [0.0, .24, .9, 1.02, 2.18, 1.97, .83, 0.0]
const STRATA = [
 Color("4a5264"), Color("606578"), Color("454c61"), Color("555d71"),
 Color("65687a"), Color("4c5569"), Color("434b60"),
]

static var scree: ArrayMesh
static var broken_slate: ArrayMesh
static var paint: StandardMaterial3D

static func material() -> StandardMaterial3D:
 if paint == null:
  paint = StandardMaterial3D.new()
  paint.vertex_color_use_as_albedo = true
  paint.vertex_color_is_srgb = true
  paint.roughness = 1.0
 return paint

static func apron() -> ArrayMesh:
 if scree != null:return scree
 var surface = SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in 16:
  for column in 24:
   var corner = Vector3((float(column)/24 - .5)*APRON_SIZE.x, 0, (.5 - float(row)/16)*APRON_SIZE.y)
   var across = Vector3.RIGHT * APRON_SIZE.x / 24.0
   var down = Vector3.FORWARD * APRON_SIZE.y / 16.0
   for point in [corner, corner+across+down, corner+across, corner, corner+down, corner+across+down]:
    var shade = .5 + .22*sin(point.x*.15 + point.z*.11) + .11*sin(point.x*.29 - point.z*.08)
    surface.set_normal(Vector3.UP)
    surface.set_color(Color("383e50").lerp(Color("555a69"),shade))
    surface.add_vertex(point)
 scree = surface.commit()
 return scree

static func rim_point(column: int, row: int) -> Vector3:
 var x = (float(column)/28 - .5) * RIM_WIDTH
 var width_fade = smoothstep(0.0, 6.0, RIM_WIDTH*.5 - absf(x))
 var ridge = .84 + .25*cos(x*.29 - .45) + .19*sin(x*.56 + row*.8)
 var cut = .72 + .28*smoothstep(1.2, 5.4, absf(x+1.7))
 var stagger = .29*sin(x*.69 + row*.54)
 return Vector3(x, RIM_HEIGHT[row]*width_fade*ridge*cut, -RIM_DEPTH[row]+stagger)

static func rim() -> ArrayMesh:
 if broken_slate != null:return broken_slate
 var surface = SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in STRATA.size():
  for column in 28:
   var a = rim_point(column, row)
   var b = rim_point(column+1, row)
   var c = rim_point(column+1, row+1)
   var d = rim_point(column, row+1)
   var variation = .5 + .5*sin(column*1.76 + row*.61)
   var stone = STRATA[row].lerp(Color("8a8897"), variation*.18)
   face(surface, a, b, c, stone)
   face(surface, a, c, d, stone.darkened(.08))
 broken_slate = surface.commit()
 return broken_slate

static func face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, stone: Color):
 var normal = (b-a).cross(c-a).normalized()
 for corner in [a, c, b]:
  surface.set_normal(normal)
  surface.set_color(stone)
  surface.add_vertex(corner)

static func place_apron(scenery, parent: Node3D, center: Vector3):
 var floor = scenery.mesh(parent, apron(), center, Vector3.ONE, material())
 floor.name = "StarfallSlateApron"
 floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build_map(scenery, parent: Node3D, center: Vector3, board: Vector2i):
 place_apron(scenery, parent, center)
 scenery.block(parent,center+Vector3(-.5,.015,-.5),Vector3(board.x+.20,.24,board.y+.20),Color("545b65")).name = "ObservatoryFoundations"
 place_rim(scenery, parent, Vector3(center.x-.5,center.y,-1.55), Vector3(.82,.64,.77), 0)
 place_rim(scenery, parent, Vector3(-1.65,center.y,center.z-.5), Vector3(.57,.43,.53), PI*.5)
 place_rim(scenery, parent, Vector3(board.x+.65,center.y,center.z-.5), Vector3(.57,.52,.54), -PI*.5)
 for site in [Vector3(-1.1,.42,1.7),Vector3(-.94,.27,5.5),Vector3(2.1,.42,10.45),Vector3(2.78,.25,10.7),
   Vector3(8.3,.32,10.3),Vector3(13.95,.37,7.15),Vector3(5.1,.36,-1.17),Vector3(5.57,.23,-1.36)]:
  place_rock(scenery, parent, Vector3(site.x,center.y,site.z), site.y)

static func build_arena(scenery, parent: Node3D, center: Vector3):
 place_apron(scenery, parent, center)
 place_rim(scenery, parent, center+Vector3(-2,0,-16.2), Vector3(1.42,1.85,1.35), 0)
 for site in [Vector3(-14.1,.86,-11.3),Vector3(-12.9,.48,-11.5),Vector3(-7.7,.66,-13.8),
   Vector3(-2.3,.33,-14.3),Vector3(7.7,.67,-12.4),Vector3(8.6,.47,-12.95),Vector3(14.2,.8,-10.35)]:
  place_rock(scenery, parent, center+Vector3(site.x,0,site.z), site.y)

static func place_rim(scenery, parent: Node3D, origin: Vector3, size: Vector3, yaw: float):
 var rock = scenery.mesh(parent, rim(), origin, size, material())
 rock.name = "StarfallBrokenSlate"
 rock.rotation.y = yaw
 rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func place_rock(scenery, parent: Node3D, origin: Vector3, radius: float):
 var variant = RockForms.variant_at(origin)
 var stone = Color("656977") if variant == 1 else Color("585e70")
 var rock = scenery.mesh(parent, RockForms.mesh(variant), origin+Vector3.UP*radius*.38,
  Vector3(1,.65,.81)*radius, scenery.material(stone))
 rock.name = "StarfallScree"
