extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Rules=preload("res://scripts/rules.gd")
class Journal extends RefCounted:
 var record=""
 var writable=false
 func read_record(_path: String) -> String:return record
 func write_record(_path: String,value: String) -> bool:
  if not writable:return false
  record=value;return true
func _initialize():call_deferred("run")
func run():
 var source=Rules.new();source.chapter=4;source.equip(source.roster[2],"longbow");source.story_seen=["opening_4"];source.start_battle()
 var code=source.export_code("battle");var copy=Rules.new()
 assert(code.begins_with("POEM1:"),"New transfer codes use the Poem name")
 assert(copy.import_code(code.replace("POEM1:","ASHEN1:"))=="battle","Earlier transfer codes still import")
 assert(copy.import_code(code)=="battle" and copy.chapter==4,"Battle transfers across fresh instances")
 assert(copy.roster[2].item=="longbow" and copy.rng.state==source.rng.state,"Gear and random sequence preserved")
 var before=copy.export_code("battle")
 assert(copy.import_code("POEM1:broken")=="" and copy.export_code("battle")==before,"Invalid code leaves campaign unchanged")
 assert(copy.import_code("POEM1:"+"A".repeat(1000000))=="","Oversized code rejected")
 for mutation in ["join","bio","color","deployed","move_origin"]:
  var data=source.save_data("battle").duplicate(true)
  match mutation:
   "join":data.roster[0].erase("join")
   "bio":data.roster[0].bio=123
   "color":data.roster[0].color="not a color"
   "deployed":data.deployed.append(data.deployed[0])
   "move_origin":data.units[0].move_origin=["bad",0]
  assert(copy.import_code("POEM1:"+Marshalls.utf8_to_base64(JSON.stringify(data)))=="","Malformed field rejected: "+mutation)
  assert(copy.export_code("battle")==before,"Rejected imports never mutate state")
 var legacy=source.save_data("battle").duplicate(true)
 for unit in legacy.roster+legacy.units:unit.erase("item")
 assert(copy.restore_save(legacy)=="battle" and copy.roster[2].item=="scout_bow","Older equipment-free saves receive defaults")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-transfer-ui-save-%d.json"%OS.get_process_id();root.add_child(app);await process_frame
 app.show_save_transfer("title");await process_frame
 assert(app.screen=="save_transfer" and is_instance_valid(app.transfer_text))
 assert(app.ui.find_child("TransferInstructions",true,false).text.contains("between browsers or the desktop app"))
 assert(app.ui.find_child("TransferBackupHint",true,false).text.contains("Copy its code first to keep a separate backup"))
 var title_chapter=app.game.chapter;var disk_before_return=FileAccess.get_file_as_string(app.save_path) if FileAccess.file_exists(app.save_path) else ""
 app.transfer_text.text=code;app.transfer_text.grab_focus();press_escape()
 assert(app.screen=="title" and app.game.chapter==title_chapter,"Title transfer Escape does not import the pasted campaign")
 assert((FileAccess.get_file_as_string(app.save_path) if FileAccess.file_exists(app.save_path) else "")==disk_before_return)
 app.show_save_transfer("title");await process_frame
 await verify_code_files(app,code)
 assert(app.game.chapter==title_chapter and (FileAccess.get_file_as_string(app.save_path) if FileAccess.file_exists(app.save_path) else "")==disk_before_return)
 await app.import_pasted_save();await process_frame
 assert(app.screen=="battle" and app.game.chapter==4,"File and Import restore the battle")
 var restored=Rules.new();assert(restored.load_game(app.save_path)=="battle" and restored.chapter==4,"Imported state is persisted")
 # Force a write failure using an existing file as the would-be parent directory.
 var working_path=app.save_path;var previous_file=FileAccess.get_file_as_string(working_path)
 app.save_path=working_path+"/unwritable.json";app.game.turn=7;app.preferences.values.auto_end=false
 await app.finish_action();await process_frame
 assert(app.save_failed and "SAVE FAILED" in app.status.text,"Autosave failure remains visible in phase status")
 assert(app.ui.find_child("Notice",true,false)!=null,"Failed autosave is reported")
 assert(FileAccess.get_file_as_string(working_path)==previous_file,"Failed write preserves existing campaign")
 var live_rng=app.game.rng.state
 app.show_save_transfer("battle");await process_frame
 var live_copy=Rules.new();assert(live_copy.import_code(app.transfer_text.text)=="battle" and live_copy.turn==7,"Transfer exports current unsaved battle, not the older file")
 app.transfer_text.text="POEM1:unimported-buffer";app.transfer_text.grab_focus()
 press_escape(true);assert(app.screen=="save_transfer","Held Escape cannot dismiss transfer")
 press_escape();assert(app.screen=="battle" and app.game.turn==7 and app.game.rng.state==live_rng,"Escape returns from focused transfer without importing its text or changing the live battle")
 assert(FileAccess.get_file_as_string(working_path)==previous_file,"Returning from transfer does not replace the campaign file")
 app.busy=true;app.show_save_transfer("battle");assert(app.screen=="battle","Busy battle cannot enter transfer")
 app.busy=false;app.save_path=working_path
 assert(app.persist_campaign("battle") and not app.save_failed and not "SAVE FAILED" in app.status.text,"Successful retry clears failure status")
 assert(restored.load_game(working_path)=="battle" and restored.turn==7)
 app.save_path=working_path+"/unwritable.json"
 for unit in app.game.living("player"):unit.hp=0
 app.game.action_saves=true;app.game.phase="enemy"
 assert(await app.check_result());await process_frame
 assert(app.screen=="result" and app.ui.find_child("Notice",true,false)!=null,"Result screen reset does not hide failed autosave")
 var terminal=JSON.stringify(app.game.save_data("battle"))
 var regroup=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Regroup and retry")[0]
 regroup.pressed.emit();await process_frame
 assert(app.screen=="result" and JSON.stringify(app.game.save_data("battle"))==terminal,"An unsaved terminal checkpoint cannot be discarded by retry")
 app.restart_campaign_attempt()
 assert(app.screen=="result" and JSON.stringify(app.game.save_data("battle"))==terminal,"A failed checkpoint also blocks manual retreat")
 var transfer=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Transfer code")[0]
 transfer.pressed.emit();await process_frame
 assert(app.screen=="save_transfer" and live_copy.import_code(app.transfer_text.text)=="battle" and live_copy.result()=="defeat" and live_copy.phase=="enemy","Result transfer exports the live terminal state even during enemy phase")
 press_escape();await process_frame
 assert(app.screen=="result" and JSON.stringify(app.game.save_data("battle"))==terminal)
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for button in app.ui.find_children("*","Button",true,false):assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(button.get_global_rect()),"Result recovery actions fit on screen")
 app.save_path=working_path
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Retry autosave")[0].pressed.emit()
 assert(not app.save_failed and restored.load_game(working_path)=="battle" and restored.result()=="defeat","Result save retry preserves the terminal checkpoint")
 # A browser can retain only the journal if it reloads before its first FS sync.
 app.save_path="/private/tmp/poem-journal-only-ui.json"
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(app.save_path+suffix):DirAccess.remove_absolute(app.save_path+suffix)
 var journal=Journal.new();app.game.browser_journal=journal
 source.action_saves=true;source.turn=11
 journal.record=JSON.stringify(source.save_data("battle"))
 app.show_title();await process_frame
 var continues=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Continue saved campaign")
 assert(continues.size()==1 and not continues[0].disabled,"Continue discovers journal-only progress")
 await app.load_campaign();await process_frame
 assert(app.screen=="battle" and app.game.turn==11,"Continue restores journal-only campaign")
 assert(not app.checkpoint_action() and app.save_failed,"Rejected browser writes use the normal checkpoint warning")
 var snapshot=JSON.stringify(app.game.save_data("battle"))
 app.click_tile(app.game.pos(app.game.living("player")[0]));await process_frame
 assert(app.selected==null and JSON.stringify(app.game.save_data("battle"))==snapshot,"Further actions stay blocked while browser storage fails")
 journal.writable=true
 assert(app.action_save_ready() and not app.save_failed,"A successful browser retry unlocks actions")
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(app.save_path+suffix):DirAccess.remove_absolute(app.save_path+suffix)
 app.score_director.stop();await create_timer(.2).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: local transfer, equipment/RNG continuity, bounded validation, legacy migration, failed autosave recovery and live battle export")
 quit()

func verify_code_files(app,code: String):
 var previous=app.transfer_text.text
 var prefix="/private/tmp/poem-code-picker-%d"%OS.get_process_id()
 var paths={
  prefix+"-valid.txt":"\uFEFF"+code+"\r\n",
  prefix+"-empty.txt":" \n",
  prefix+"-too-large.txt":"A".repeat(Rules.MAX_SAVE_CODE_LENGTH+1),
 }
 for path in paths:
  var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(paths[path]);file.close()
 var before=root.size;var old_scale=root.content_scale_size
 root.size=Vector2i(720,640);root.content_scale_size=root.size
 await process_frame;await process_frame
 var open_button=app.ui.find_child("OpenSaveCodeFile",true,false)
 assert(Rect2(Vector2.ZERO,Vector2(720,640)).encloses(open_button.get_global_rect()))
 for suffix in ["missing","empty","too-large","valid"]:
  open_button.pressed.emit()
  var picker=app.ui.get_node("SaveCodeFilePicker")
  assert(picker.visible and picker.file_mode==FileDialog.FILE_MODE_OPEN_FILE)
  picker.file_selected.emit(prefix+"-"+suffix+".txt")
  await process_frame
  assert(app.screen=="save_transfer" and app.transfer_text.text==(code if suffix=="valid" else previous))
 assert(app.transfer_text.has_focus())
 open_button.pressed.emit()
 app.ui.get_node("SaveCodeFilePicker").canceled.emit();await process_frame
 assert(app.transfer_text.text==code)
 root.size=before;root.content_scale_size=old_scale
 print("PASS: file picker stages valid save codes and preserves the previous text on missing, empty, oversized, or canceled files")

func press_escape(echo=false):
 var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;event.echo=echo;root.push_input(event,true)
 var release=InputEventKey.new();release.keycode=KEY_ESCAPE;root.push_input(release,true)
