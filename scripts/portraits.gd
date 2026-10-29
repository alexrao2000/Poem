extends RefCounted
const ORDER=["lyra","oren","sera","ivo","mara","tarin","nell","bram","esme","rook","faye","cassian","vela","dax","una","silas","petra","ari","noor","galen","yuna","hale","elian","rhea"]
var textures: Dictionary={}

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
