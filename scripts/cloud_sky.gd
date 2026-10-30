extends RefCounted
# One deterministic cloud panorama extends the existing lightweight sky.
# A horizontal noise field is projected onto the upper hemisphere, fading
# before the horizon. No scene geometry, animation clock or gameplay RNG.

const SIZE=Vector2i(1024,512)
static var cover: ImageTexture

static func image() -> Image:
 var noise=FastNoiseLite.new();noise.seed=7139;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 noise.frequency=.85;noise.fractal_octaves=4;noise.fractal_gain=.5
 var result=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
 for y in range(SIZE.y/2):
  var elevation=cos(float(y)/(SIZE.y-1)*PI)
  var radius=sqrt(maxf(0,1-elevation*elevation))/maxf(elevation,.08)
  var fade=smoothstep(.035,.18,elevation)
  for x in range(SIZE.x):
   var angle=float(x)/(SIZE.x-1)*TAU
   var value=noise.get_noise_2d(cos(angle)*radius*1.7,sin(angle)*radius*1.7)
   var density=smoothstep(-.04,.32,value)*fade
   result.set_pixel(x,y,Color(1,1,1,density))
 result.generate_mipmaps();return result

static func texture() -> ImageTexture:
 if cover==null:cover=ImageTexture.create_from_image(image())
 return cover

static func tint(theme: String) -> Color:
 if theme in ["engine","furnace"]:return Color(0,0,0,0)
 if theme=="observatory":return Color(.45,.52,.70,.08)
 if theme in ["forest","mountain"]:return Color(.78,.82,.85,.30)
 return Color(.96,.95,.91,.38)
