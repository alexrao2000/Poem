extends SceneTree
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var source=Rules.new();source.chapter=4;source.equip(source.roster[2],"longbow");source.story_seen=["opening_4"];source.start_battle()
 var code=source.export_code("battle");var copy=Rules.new()
 assert(copy.import_code(code)=="battle" and copy.chapter==4,"Battle transfers across fresh instances")
 assert(copy.roster[2].item=="longbow" and copy.rng.state==source.rng.state,"Gear and random sequence preserved")
 var before=copy.export_code("battle")
 assert(copy.import_code("ASHEN1:broken")=="" and copy.export_code("battle")==before,"Invalid code leaves campaign unchanged")
 assert(copy.import_code("ASHEN1:"+"A".repeat(1000000))=="","Oversized code rejected")
 for mutation in ["join","bio","color","deployed","move_origin"]:
  var data=source.save_data("battle").duplicate(true)
  match mutation:
   "join":data.roster[0].erase("join")
   "bio":data.roster[0].bio=123
   "color":data.roster[0].color="not a color"
   "deployed":data.deployed.append(data.deployed[0])
   "move_origin":data.units[0].move_origin=["bad",0]
  assert(copy.import_code("ASHEN1:"+Marshalls.utf8_to_base64(JSON.stringify(data)))=="","Malformed field rejected: "+mutation)
  assert(copy.export_code("battle")==before,"Rejected imports never mutate state")
 var legacy=source.save_data("battle").duplicate(true)
 for unit in legacy.roster+legacy.units:unit.erase("item")
 assert(copy.restore_save(legacy)=="battle" and copy.roster[2].item=="scout_bow","Older equipment-free saves receive defaults")
 var app=load("res://main.tscn").instantiate();app.save_path="/private/tmp/ashen-transfer-ui-save.json";root.add_child(app);await process_frame
 app.show_save_transfer("title");await process_frame
 assert(app.screen=="save_transfer" and is_instance_valid(app.transfer_text))
 app.transfer_text.text=code;await app.import_pasted_save();await process_frame
 assert(app.screen=="battle" and app.game.chapter==4,"Paste/import flow restores the battle")
 var restored=Rules.new();assert(restored.load_game(app.save_path)=="battle" and restored.chapter==4,"Imported state is persisted")
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: local transfer, equipment/RNG continuity, bounded validation, legacy migration and import UI")
 quit()
