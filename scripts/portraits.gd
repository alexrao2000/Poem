extends RefCounted
const Commanders=preload("res://scripts/commanders.gd")
const ORDER=["lyra","oren","sera","ivo","mara","tarin","nell","bram","esme","rook","faye","cassian","vela","dax","una","silas","petra","ari","noor","galen","yuna","hale","elian","rhea"]
const ENEMY_CLASSES=["Vanguard","Knight","Ranger","Arcanist","Warden","Rider","Corsair","Duelist"]
var textures: Dictionary={}
var sprite_textures: Dictionary={}
var dialogue_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_portraits.json"))
var critical_focus=JSON.parse_string(FileAccess.get_file_as_string("res://data/critical_portraits.json"))
var regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/sprite_regions.json"))

func get_critical_portrait(unit: Dictionary) -> Texture2D:
 var identity="enemy."+unit.job if unit.get("team","player")=="enemy" else unit.id
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

func get_dialogue_portrait(id: String) -> Texture2D:
 var key="dialogue."+id
 if textures.has(key):return textures[key]
 if not dialogue_regions.has(id):return get_portrait(id)
 var entry=dialogue_regions[id]
 var texture=AtlasTexture.new();texture.atlas=load(entry.path);texture.filter_clip=true
 texture.region=Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
 textures[key]=texture;return texture

func get_forecast_portrait(unit: Dictionary) -> Texture2D:
 return get_unit_portrait(unit) if unit.get("team","player")=="enemy" else get_dialogue_portrait(unit.id)

func get_unit_portrait(unit: Dictionary) -> Texture2D:
 if unit.get("team","player")!="enemy":return get_portrait(unit.id)
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

func get_map_sprite(id: String) -> Texture2D:
 if sprite_textures.has(id):return sprite_textures[id]
 if not regions.has(id):return null
 var entry=regions[id]
 var texture=AtlasTexture.new();texture.atlas=load("res://assets/sprites/"+entry.sheet+".png")
 texture.region=Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3]);texture.filter_clip=true
 sprite_textures[id]=texture;return texture

func get_portrait(id: String) -> Texture2D:
 if textures.has(id):return textures[id]
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
