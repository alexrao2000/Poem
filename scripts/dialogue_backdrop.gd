extends "res://scripts/painted_backdrop.gd"
## Chapter locations and two resolved-story variants share unchanged original
## atlas artwork. Cached regions keep adjacent panels out of filtered samples.
static var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_scenery.json"))
static var textures={}
var context_id=""
var artwork: AtlasTexture

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

func begin(host: Control,scene_nodes: Array,chapter: int,kind="opening"):
 name="DialogueBackdrop";context_id=kind+"_"+str(chapter);artwork=texture_for(chapter,kind)
 super.configure(host,scene_nodes)

static func framing(dimensions: Vector2,source: Vector2) -> Rect2:
 var scale_value=maxf(dimensions.x/source.x,dimensions.y/source.y)
 var extent=source*scale_value
 return Rect2((dimensions-extent)*.5,extent)

func _draw():
 if artwork!=null:draw_texture_rect(artwork,framing(size,artwork.get_size()),false)
