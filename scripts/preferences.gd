extends RefCounted
const DEFAULTS={"combat":"all","music":1.0,"effects":1.0,"text_speed":55,"auto_end":true}
var values=DEFAULTS.duplicate()

func reset():values=DEFAULTS.duplicate()

func valid(data) -> bool:
 if not data is Dictionary or data.get("combat") not in ["all","player","map"]:return false
 if not (data.get("text_speed") is int or data.get("text_speed") is float):return false
 if not is_finite(float(data.text_speed)) or data.text_speed!=int(data.text_speed) or int(data.text_speed) not in [0,55,90] or not data.get("auto_end") is bool:return false
 for key in ["music","effects"]:
  if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or data[key]<0 or data[key]>1:return false
 return true

func load_file(path: String) -> bool:
 if path.is_empty() or not FileAccess.file_exists(path):return false
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>4096:return false
 var parser=JSON.new()
 if parser.parse(file.get_as_text())!=OK or not valid(parser.data):return false
 values=parser.data;values.text_speed=int(values.text_speed)
 return true

func save_file(path: String) -> bool:
 if path.is_empty() or not valid(values):return false
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify(values));file.close()
 return DirAccess.rename_absolute(path+".tmp",path)==OK

func show_cinematic(team: String) -> bool:
 return values.combat=="all" or (values.combat=="player" and team=="player")

func volume_db(key: String) -> float:
 return -80.0 if values[key]<=0 else linear_to_db(float(values[key]))-12.0
