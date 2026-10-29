extends RefCounted
# Optional authored assets selected independently of campaign rules and save files.
const ImportedFighter=preload("res://scripts/imported_fighter.gd")
var catalog: Dictionary={}
var issues: PackedStringArray=[]

func _init(path="res://data/combat_models.json"):
 if path.is_empty():return
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
 if parsed is Dictionary and parsed.get("version")==1:catalog=parsed
 else:report("Invalid combat model catalog")

func report(message: String):
 if not issues.has(message):issues.append(message)

func candidates(unit: Dictionary) -> Array:
 var result=[]
 for pair in [["characters",unit.id],["promotions",unit.get("promotion","")],["classes" if unit.team=="player" else "enemy_classes",unit.job]]:
  var group=catalog.get(pair[0],{})
  if group is Dictionary and group.has(pair[1]):result.append(group[pair[1]])
 return result

func specification_error(spec) -> String:
 if not spec is Dictionary:return "Model entry must be an object"
 var path=spec.get("scene","")
 if not path is String or not path.begins_with("res://assets/models/") or path.contains("..") or not path.get_extension() in ["glb","gltf","tscn","scn"]:return "Scene must be a local asset under assets/models"
 if not ResourceLoader.exists(path):return "Model scene does not exist: "+path
 for key in ["scale","yaw"]:
  var value=spec.get(key,1.0 if key=="scale" else 0.0)
  if not (value is int or value is float) or not is_finite(float(value)):return "Invalid model "+key
 if spec.get("scale",1.0)<=0:return "Model scale must be positive"
 var offset=spec.get("offset",[0,0,0])
 if not offset is Array or offset.size()!=3:return "Model offset needs three coordinates"
 for value in offset:
  if not (value is int or value is float) or not is_finite(float(value)):return "Invalid model offset"
 if not spec.get("player","AnimationPlayer") is String:return "Invalid animation player path"
 if not spec.get("poses",{}) is Dictionary or not spec.get("sockets",{}) is Dictionary:return "Poses and sockets must be objects"
 for value in spec.get("sockets",{}).values():
  if not value is String:return "Socket paths must be strings"
 return ""

func build(parent: Node3D,unit: Dictionary,position: Vector3) -> Node3D:
 for spec in candidates(unit):
  var error=specification_error(spec)
  if not error.is_empty():report(error);continue
  var packed=load(spec.scene) as PackedScene
  if packed==null:report("Not a model scene: "+spec.scene);continue
  var scene=packed.instantiate()
  if not scene is Node3D:report("Model root must be Node3D: "+spec.scene);scene.free();continue
  var actor=ImportedFighter.new()
  error=actor.configure(scene,spec)
  if not error.is_empty():report(spec.scene+": "+error);actor.free();continue
  parent.add_child(actor);actor.position=position;actor.kind=unit.weapon
  actor.set_meta("source_model",spec.scene);actor.pose("idle",.01)
  return actor
 return null
