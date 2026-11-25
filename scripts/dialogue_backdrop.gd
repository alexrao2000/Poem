extends "res://scripts/painted_backdrop.gd"
## Chapter locations and two resolved-story variants share unchanged original
## atlas artwork. Cached regions keep adjacent panels out of filtered samples.
const VALLEY_ATLAS=preload("res://assets/art/campaign-valley-v1.png")
const LOCATION_INDEX={
 "village":0,"river":1,"forest":2,"abbey":3,"road":4,"harbor":5,
 "mountain":6,"aqueduct":7,"observatory":8,"furnace":9,"castle":10,"engine":11,
}
static var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_scenery.json"))
static var textures={}
var context_id=""
var artwork: Texture2D

static func entry(chapter: int,kind: String) -> Dictionary:
 chapter=clampi(chapter,0,profiles.chapters.size()-1)
 return profiles.closing[str(chapter)] if kind=="closing" and profiles.closing.has(str(chapter)) else profiles.chapters[chapter]

static func texture_for(chapter: int,kind: String) -> AtlasTexture:
 var profile=entry(chapter,kind);var key=profile.asset+str(profile.region)
 if not textures.has(key):
  var texture=AtlasTexture.new();texture.atlas=load(profile.asset)
  texture.region=Rect2(profile.region[0],profile.region[1],profile.region[2],profile.region[3]);texture.filter_clip=true
  textures[key]=texture
 return textures[key]

static func location_texture(location: Dictionary,chapter: int,kind: String,atlas: Texture2D=null) -> Texture2D:
 if location.get("presentation","")=="valley_table":return atlas if atlas!=null else VALLEY_ATLAS
 return texture_for(LOCATION_INDEX.get(location.get("environment",""),chapter),kind)

func begin(host: Control,scene_nodes: Array,chapter: int,kind: String,painting: Texture2D):
 name="DialogueBackdrop";context_id=kind+"_"+str(chapter);artwork=painting
 super.configure(host,scene_nodes)

static func framing(dimensions: Vector2,source: Vector2) -> Rect2:
 var scale_value=maxf(dimensions.x/source.x,dimensions.y/source.y)
 var extent=source*scale_value
 return Rect2((dimensions-extent)*.5,extent)

func _draw():
 if artwork!=null:draw_texture_rect(artwork,framing(size,artwork.get_size()),false)
