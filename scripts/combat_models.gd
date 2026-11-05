extends RefCounted
# Optional authored assets selected independently of campaign rules and save files.
const ImportedFighter=preload("res://scripts/imported_fighter.gd")
const ImportedRider=preload("res://scripts/imported_rider.gd")
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
 if spec.has("equipment") and not spec.equipment is String:return "Invalid equipment attachment path"
 if spec.has("mount") and (not spec.mount is String or spec.mount.is_empty()):return "Invalid mount path"
 if spec.has("appearance") and not spec.appearance is String:return "Invalid appearance adapter path"
 if spec.has("supported_items"):
  if not spec.supported_items is Array or spec.supported_items.is_empty() or not spec.supported_items.all(func(item):return item is String):return "Supported equipment must be a nonempty list of item IDs"
 return ""

func build(parent: Node3D,unit: Dictionary,position: Vector3) -> Node3D:
 for spec in candidates(unit):
  var error=specification_error(spec)
  if not error.is_empty():report(error);continue
  if spec.has("supported_items") and unit.get("item","") not in spec.supported_items:continue
  var packed=load(spec.scene) as PackedScene
  if packed==null:report("Not a model scene: "+spec.scene);continue
  var scene=packed.instantiate()
  if not scene is Node3D:report("Model root must be Node3D: "+spec.scene);scene.free();continue
  if spec.has("equipment"):
   var attachment=scene.get_node_or_null(NodePath(spec.equipment))
   if attachment==null or not attachment.has_method("configure_equipment"):report(spec.scene+": Missing equipment attachment");scene.free();continue
   error=attachment.configure_equipment(unit.weapon,str(unit.get("item","")))
   if not error.is_empty():report(spec.scene+": "+error);scene.free();continue
  if spec.has("mount"):
   var mount=scene.get_node_or_null(NodePath(spec.mount))
   if mount==null or not mount.has_method("configure_mount"):report(spec.scene+": Missing mount adapter");scene.free();continue
   error=mount.configure_mount(str(unit.id))
   if not error.is_empty():report(spec.scene+": "+error);scene.free();continue
  if spec.has("appearance"):
   var appearance=scene.get_node_or_null(NodePath(spec.appearance))
   if appearance==null or not appearance.has_method("configure_identity"):report(spec.scene+": Missing appearance adapter");scene.free();continue
   error=appearance.configure_identity(str(unit.id))
   if not error.is_empty():report(spec.scene+": "+error);scene.free();continue
  var actor=ImportedRider.new() if spec.has("mount") else ImportedFighter.new()
  error=actor.configure(scene,spec)
  if not error.is_empty():report(spec.scene+": "+error);actor.free();continue
  parent.add_child(actor);actor.position=position;actor.kind=unit.weapon
  error=actor.prepare_contact(spec)
  if not error.is_empty():report(spec.scene+": "+error);actor.free();continue
  actor.set_meta("source_model",spec.scene);actor.pose("idle",.01)
  return actor
 return null
