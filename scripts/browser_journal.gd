extends RefCounted
# A browser-owned copy survives a reload while Godot's IndexedDB sync is pending.
# Native saves use only the existing atomic file path.
var bridge

func connect_browser() -> bool:
	if not OS.has_feature("web"):return false
	if bridge==null:
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/browser_journal.js"),true)
		bridge=JavaScriptBridge.get_interface("poemSaveJournal")
	return bridge!=null

func read_record(path: String) -> String:
	if not connect_browser():return ""
	var value=bridge.read(path)
	return value if value is String else ""

func write_record(path: String,record: String) -> bool:
	if not OS.has_feature("web"):return true
	if not connect_browser():return false
	return bridge.write(path,record)==true
