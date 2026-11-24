extends RefCounted
# Deterministic day clouds and a faint Starfall sky cover fade before the horizon.

const Chart=preload("res://scripts/starfall_chart.gd")
const SIZE=Vector2i(1024,512)
const CHART_ANCHOR=Vector2(922,233)
const CHART_CENTER=Vector2(-.36,0)
const CHART_SCALE=Vector2(89,-32)
static var cover: ImageTexture
static var night_cover: ImageTexture

static func image(night=false) -> Image:
 var noise=FastNoiseLite.new();noise.seed=7139;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 noise.frequency=.85;noise.fractal_octaves=4;noise.fractal_gain=.5
 var result=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
 var opacity=.18 if night else 1.0
 for y in range(SIZE.y/2):
  var elevation=cos(float(y)/(SIZE.y-1)*PI)
  var radius=sqrt(maxf(0,1-elevation*elevation))/maxf(elevation,.08)
  var fade=smoothstep(.035,.18,elevation)
  for x in range(SIZE.x):
   var angle=float(x)/(SIZE.x-1)*TAU
   var value=noise.get_noise_2d(cos(angle)*radius*1.7,sin(angle)*radius*1.7)
   var density=smoothstep(-.04,.32,value)*fade
   result.set_pixel(x,y,Color(1,1,1,density*opacity))
 if night:
  paint_stars(result)
  paint_chart_stars(result)
 result.generate_mipmaps();return result

static func paint_stars(panorama: Image):
 var random=RandomNumberGenerator.new();random.seed=17205
 for index in range(164):
  var center=Vector2i(random.randi_range(4,SIZE.x-5),random.randi_range(15,SIZE.y/2-17))
  var radius=random.randf_range(1.4,2.0) if index<12 else random.randf_range(.8,1.44)
  var clarity=random.randf_range(.84,1) if index<12 else random.randf_range(.44,.79)
  var pigment=Color("f8e9cd") if index%9==0 else Color("d3e7f7").lerp(Color.WHITE,random.randf_range(.25,.70))
  paint_star(panorama,center,radius,clarity,pigment)

# Place the first engraved group just above the observatory horizon.
static func chart_star_pixel(index: int) -> Vector2i:
 var site: Vector2=Chart.STAR_SITES[index]
 return Vector2i((CHART_ANCHOR+(site-CHART_CENTER)*CHART_SCALE).round())

static func paint_chart_stars(panorama: Image):
 for index in Chart.CONSTELLATIONS[0]:
  var center=chart_star_pixel(index)
  var brightest=index==1
  var pigment=Color("f2e4c6") if brightest else Color("d5e3f7")
  paint_star(panorama,center,3.0,.31,pigment)
  paint_star(panorama,center,1.74 if brightest else 1.50,1.0 if brightest else .91,pigment)

static func paint_star(panorama: Image,center: Vector2i,radius: float,clarity: float,pigment: Color):
 var reach=ceili(radius)
 for y in range(-reach,reach+1):
  for x in range(-reach,reach+1):
   var light=clarity*(1-smoothstep(0.0,radius,Vector2(x,y).length()))
   var pixel=center+Vector2i(x,y)
   if light>panorama.get_pixelv(pixel).a:panorama.set_pixelv(pixel,Color(pigment,light))

static func texture(night=false) -> ImageTexture:
 if night:
  if night_cover==null:night_cover=ImageTexture.create_from_image(image(true))
  return night_cover
 if cover==null:cover=ImageTexture.create_from_image(image())
 return cover

static func tint(theme: String) -> Color:
 if theme in ["engine","furnace"]:return Color(0,0,0,0)
 if theme=="observatory":return Color(.84,.91,1,.32)
 if theme in ["forest","mountain"]:return Color(.78,.82,.85,.30)
 return Color(.96,.95,.91,.38)
