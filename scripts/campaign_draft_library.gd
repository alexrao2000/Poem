extends RefCounted
## Draft documents and their playtest checkpoints have separate files.
const LIMIT=12
var path="user://campaign-drafts.json"
var browser=preload("res://scripts/browser_journal.gd").new()

func list_drafts() -> Array:
 var options=[browser.read_record(path)]
 for candidate in [path,path+".bak"]:
  if FileAccess.file_exists(candidate):options.append(FileAccess.get_file_as_string(candidate))
 for option in options:
  if option.is_empty():continue
  var data=JSON.parse_string(option)
  if not data is Array or data.size()>LIMIT:continue
  if data.all(func(item):
   return item is Dictionary and item.get("key") is String and item.get("document") is Dictionary):
   return data
 return []

func save(key: String,document: Dictionary) -> String:
 var records=list_drafts()
 if key.is_empty():key=str(Time.get_unix_time_from_system()).sha256_text()
 var index=records.find_custom(func(item):return item.key==key)
 if index>=0:records.remove_at(index)
 elif records.size()>=LIMIT:return ""
 records.push_front({"key":key,"document":document})
 return key if write_records(records) else ""

func remove(key: String) -> bool:
 var records=list_drafts()
 var index=records.find_custom(func(item):return item.key==key)
 if index<0:return false
 records.remove_at(index)
 return write_records(records)

func write_records(records: Array) -> bool:
 var encoded=JSON.stringify(records,"",true,true)
 var temporary=path+".tmp"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return false
 file.store_string(encoded);file.flush()
 var prepared=file.get_error()==OK
 file.close()
 if prepared and FileAccess.file_exists(path):prepared=DirAccess.copy_absolute(path,path+".bak")==OK
 if prepared and browser.write_record(path,encoded):
  if DirAccess.rename_absolute(temporary,path)==OK:return true
  DirAccess.remove_absolute(temporary)
  return OS.has_feature("web")
 DirAccess.remove_absolute(temporary)
 return false
