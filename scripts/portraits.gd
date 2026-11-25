extends RefCounted
# Keep expression textures separate so a closed conversation can release its
# sheets while forecast, reward and neutral portraits stay available.
const Commanders=preload("res://scripts/commanders.gd")
const ORDER=["lyra","oren","sera","ivo","mara","tarin","nell","bram","esme","rook","faye","cassian","vela","dax","una","silas","petra","ari","noor","galen","yuna","hale","elian","rhea"]
const ENEMY_CLASSES=["Vanguard","Knight","Ranger","Arcanist","Warden","Rider","Corsair","Duelist"]
const INDIVIDUAL_PORTRAITS={"maelin":"res://assets/portraits/maelin-v1.png","tovin":"res://assets/portraits/tovin-v1.png"}
var textures: Dictionary={}
var expression_textures: Dictionary={}
var dialogue_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_portraits.json"))
var dialogue_expressions=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_expressions.json"))
var critical_focus=JSON.parse_string(FileAccess.get_file_as_string("res://data/critical_portraits.json"))

func get_critical_portrait(unit: Dictionary) -> Texture2D:
 var identity="enemy."+unit.job if unit.get("team","player")=="enemy" else unit.get("art_id",unit.id)
 var commander=Commanders.profile(unit)
 if not commander.is_empty():identity="commander."+commander.id
 var key="critical."+identity
 if textures.has(key):return textures[key]
 var portrait=get_unit_portrait(unit)
 if portrait==null:return null
 var focus=commander.critical_focus if not commander.is_empty() else critical_focus.get(identity,[.66,.28]);var dimensions=portrait.get_size()
 var extent=dimensions*Vector2(.60,.22)
 var point=Vector2(focus[0],focus[1])*dimensions
 var corner=(point-extent*.5).clamp(Vector2.ZERO,dimensions-extent)
 var texture=AtlasTexture.new();texture.atlas=portrait;texture.region=Rect2(corner,extent);texture.filter_clip=true
 textures[key]=texture;return texture

func get_dialogue_portrait(id: String,expression="") -> Texture2D:
 var variants=dialogue_expressions.get(id,{})
 var expressive=variants.has(expression)
 var key="dialogue."+id+("."+expression if expressive else "")
 var cache=expression_textures if expressive else textures
 if cache.has(key):return cache[key]
 if not expressive and not dialogue_regions.has(id):return get_portrait(id)
 var entry=variants[expression] if expressive else dialogue_regions[id]
 var texture=AtlasTexture.new();texture.atlas=load(entry.path);texture.filter_clip=true
 texture.region=Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
 cache[key]=texture;return texture

func get_forecast_portrait(unit: Dictionary) -> Texture2D:
 return get_unit_portrait(unit) if unit.get("team","player")=="enemy" else get_dialogue_portrait(unit.get("art_id",unit.id))

func get_unit_portrait(unit: Dictionary) -> Texture2D:
 if unit.get("team","player")!="enemy":return get_portrait(unit.get("art_id",unit.id))
 var commander=Commanders.profile(unit)
 if not commander.is_empty():
  var identity="commander."+commander.id
  if not textures.has(identity):
   var entry=commander.portrait;var picture=AtlasTexture.new();picture.atlas=load(entry.path);picture.filter_clip=true
   picture.region=Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3]);textures[identity]=picture
  return textures[identity]
 var index=ENEMY_CLASSES.find(unit.job)
 if index<0:return null
 var key="enemy."+unit.job
 if textures.has(key):return textures[key]
 var path="res://assets/portraits/enemy-classes-v1.png"
 if not ResourceLoader.exists(path):return null
 var atlas=load(path) as Texture2D;var cell=Vector2(atlas.get_width()/4.0,atlas.get_height()/2.0)
 var texture=AtlasTexture.new();texture.atlas=atlas;texture.filter_clip=true
 texture.region=Rect2(Vector2(index%4,index/4)*cell+Vector2(8,8),cell-Vector2(16,16))
 textures[key]=texture;return texture

func get_portrait(id: String) -> Texture2D:
 if textures.has(id):return textures[id]
 if INDIVIDUAL_PORTRAITS.has(id):
  textures[id]=load(INDIVIDUAL_PORTRAITS[id])
  return textures[id]
 var index=ORDER.find(id)
 if index<0:return null
 var path="res://assets/portraits/company-"+["a","b","c","d"][index/6]+".png"
 if not ResourceLoader.exists(path):return null
 var atlas=load(path) as Texture2D
 var cell=Vector2(atlas.get_width()/3.0,atlas.get_height()/2.0)
 var texture=AtlasTexture.new();texture.atlas=atlas
 var local=index%6
 texture.region=Rect2(Vector2(local%3,local/3)*cell+Vector2(6,6),cell-Vector2(12,12))
 texture.filter_clip=true
 textures[id]=texture
 return texture
