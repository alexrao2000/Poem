extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const PATH="/private/tmp/ashen-save-recovery-test.json"
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
 print("PASS: atomic save replacement, backup recovery, malformed data and old-layout migration")
 quit()
