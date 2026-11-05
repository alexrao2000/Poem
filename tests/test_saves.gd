extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const PATH="/private/tmp/poem-save-recovery-test.json"
class Journal extends RefCounted:
 var records={}
 var writable=true
 func read_record(path: String) -> String:return records.get(path,"")
 func write_record(path: String,record: String) -> bool:
  if not writable:return false
  records[path]=record;return true

func clear_files():
 for suffix in ["",".bak",".tmp",".bak.tmp",".debug",".debug.bak",".debug.tmp"]:
  if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(PATH+suffix)

func test_browser_recovery():
 clear_files()
 var journal=Journal.new()
 var g=Rules.new();g.browser_journal=journal;g.action_saves=true;g.start_battle()
 assert(g.save_game(PATH,"battle"));var old=FileAccess.get_file_as_string(PATH)
 g.turn=2;g.units[1].hp=0;g.permadeath=true;g.commit_casualties()
 assert(g.save_game(PATH,"battle"));var latest=journal.read_record(PATH)
 # Simulate a reload before the engine's asynchronous filesystem sync finishes.
 clear_files();write_data(PATH,JSON.parse_string(old))
 var restored=Rules.new();restored.browser_journal=journal
 assert(restored.load_game(PATH)=="battle" and restored.turn==2)
 assert(restored.units[1].hp==0 and restored.roster[1].fallen,"Journal recovery must not resurrect the lost recruit")
 assert(restored.rng.state==g.rng.state,"Recovery retains the exact next roll")
 clear_files()
 assert(not restored.read_saved_data(PATH).is_empty(),"A journal-only campaign remains discoverable")
 assert(restored.load_game(PATH)=="battle")
 restored.turn=3;assert(restored.save_game(PATH,"battle"))
 assert(JSON.parse_string(journal.read_record(PATH)).save_sequence==3,"Revision advances from the journal, not the stale filesystem")
 journal.records[PATH]=latest
 assert(restored.load_game(PATH)=="battle" and restored.turn==3,"A newer file wins over an older journal")
 journal.records[PATH]="{truncated"
 assert(restored.load_game(PATH)=="battle" and restored.turn==3,"Malformed journal falls back to validated files")
 journal.records[PATH]=FileAccess.get_file_as_string(PATH)
 var original_journal=journal.read_record(PATH)
 journal.writable=false;restored.turn=4
 assert(not restored.save_game(PATH,"battle"),"Denied/quota-limited browser storage reports failure")
 assert(journal.read_record(PATH)==original_journal,"Failed writes preserve the prior browser checkpoint")
 journal.writable=true;assert(restored.save_game(PATH,"battle"))
 var campaign=journal.read_record(PATH)
 restored.turn=5;assert(restored.save_game(PATH+".debug","battle"))
 assert(journal.read_record(PATH)==campaign,"Debug journal cannot overwrite the campaign")
 assert(JSON.parse_string(journal.read_record(PATH+".debug")).turn==5)
 clear_files()
func write_data(path,data):
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
func _initialize():
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(PATH+suffix)
 var g=Rules.new();g.start_battle();g.story_seen=["opening_0"]
 assert(g.save_game(PATH,"battle"));var original=FileAccess.get_file_as_string(PATH)
 g.turn=2;assert(g.save_game(PATH,"battle"))
 assert(FileAccess.get_file_as_string(PATH+".bak")==original,"Previous save retained")
 var fresh=Rules.new();assert(fresh.load_game(PATH)=="battle" and fresh.turn==2,"Newest save loads")
 var bad=FileAccess.open(PATH,FileAccess.WRITE);bad.store_string("{truncated");bad.close()
 assert(fresh.load_game(PATH)=="battle" and fresh.turn==1,"Corrupted newest save recovers backup")
 DirAccess.remove_absolute(PATH+".bak")
 var before=fresh.rng.state
 write_data(PATH,{"version":3,"chapter":900})
 assert(fresh.load_game(PATH)=="" and fresh.chapter==0 and fresh.rng.state==before,"Malformed save leaves current state unchanged")
 var old=JSON.parse_string(original);old.version=1;old.erase("layout_signature");old.erase("story_seen")
 write_data(PATH,old)
 assert(fresh.load_game(PATH)=="camp" and fresh.units.is_empty(),"Old battle layout returns safely to preparation")
 assert(fresh.deployed==g.deployed,"Layout migration preserves recruitment and deployment")
 var invalid=JSON.parse_string(original);invalid.roster[0].max_hp="bad";write_data(PATH,invalid)
 assert(fresh.load_game(PATH)=="","Invalid unit stats rejected")
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(PATH+suffix)
 test_browser_recovery()
 print("PASS: atomic saves, journal/file recovery, browser write failure, debug isolation and old-layout migration")
 quit()
