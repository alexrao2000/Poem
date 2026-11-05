extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Door=preload("res://scripts/death_door.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func setup(game,permanent=true) -> Dictionary:
 game.new_campaign(permanent);game.death_door=true;game.action_saves=true;game.start_battle()
 var carrier=game.units.filter(func(unit):return unit.id=="oren")[0]
 var patient=game.units.filter(func(unit):return unit.id=="sera")[0]
 carrier.x=3;carrier.y=3;patient.x=2;patient.y=3;patient.hp=0;Door.fall(game,patient)
 assert(Door.rescue(game,carrier,patient))
 var blockers=game.units.filter(func(unit):return unit.id not in [carrier.id,patient.id]).slice(0,4)
 for i in range(4):
  var tile=Vector2i(3,3)+[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][i]
  blockers[i].x=tile.x;blockers[i].y=tile.y
 assert(Door.drop_positions(game,carrier).is_empty())
 carrier.hp=0;Door.fall(game,carrier);game.commit_casualties()
 var healer=game.units.filter(func(unit):return unit.weapon=="staff" and unit.team=="player")[0]
 assert(game.distance(healer,carrier)==1 and game.occupants(Vector2i(3,3)).size()==2)
 return {"carrier":carrier,"patient":patient,"healer":healer,"blockers":blockers}
func run():
 for permanent in [false,true]:
  var game=Rules.new();var sample=setup(game,permanent);var point=Vector2i(3,3)
  assert(Door.downed(sample.carrier) and Door.downed(sample.patient) and sample.patient.get("carried_by","").is_empty())
  var restored=Rules.new();assert(restored.import_code(game.export_code("battle"))=="battle" and restored.occupants(point).size()==2,"A surrounded carrier fall remains a recoverable exact save")
  assert(game.heal(sample.healer,sample.patient) and game.at(point)==sample.patient,"Standing occupant takes precedence over an earlier-listed downed ally")
  sample.healer.acted=false
  var before=game.save_data("battle").duplicate(true);var seed=game.rng.state
  assert(not game.can_heal(sample.healer,sample.carrier) and not game.heal(sample.healer,sample.carrier))
  assert(game.save_data("battle")==before and game.rng.state==seed,"Blocked revival consumes neither healing nor the healer's action")
  assert(Door.can_rescue(game,sample.healer,sample.carrier))
  sample.patient.acted=false
  assert(Door.can_rescue(game,sample.patient,sample.carrier),"A recovered ally can reach a patient sharing their own position")
  sample.patient.acted=true
  sample.blockers[0].x=10;sample.blockers[0].y=7
  assert(game.can_heal(sample.healer,sample.carrier) and game.heal(sample.healer,sample.carrier))
  assert(game.pos(sample.carrier)==point+Vector2i.LEFT and game.at(point)==sample.patient and sample.carrier.acted,"Second revival stands on the adjacent tile that was cleared")
  assert(game.occupants(point).size()==1 and restored.import_code(game.export_code("battle"))=="battle")
  sample=setup(game,permanent);game.heal(sample.healer,sample.patient);sample.patient.acted=false
  assert(Door.rescue(game,sample.patient,sample.carrier) and sample.carrier.carried_by==sample.patient.id)
  assert(game.occupants(point).size()==1 and game.at(point)==sample.patient)
  sample.healer.acted=false
  assert(game.heal(sample.healer,sample.carrier) and sample.carrier.hp>0 and sample.carrier.get("carried_by","")==sample.patient.id,"A surrounded carried patient can still recover safely while remaining carried")
  assert(game.valid_save(game.save_data("battle")))
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-crowded-rescue-save.json";root.add_child(app);await process_frame
 var sample=setup(app.game);app.preferences.values.combat="map";app.preferences.values.auto_end=false;app.make_map();app.show_battle();app.selected=sample.healer;app.update_side()
 var point=Vector2i(3,3);var before=app.game.save_data("battle").duplicate(true);var seed=app.game.rng.state
 var badge=app.unit_nodes[sample.carrier.id].shared_marker
 assert(badge!=null and badge.get_meta("count")==2 and badge.texture.get_size()==Vector2(64,36),"The shared position has one visible chooser badge")
 var badge_point=app.camera.unproject_position(badge.global_position)
 assert(app.pick_map_unit(badge_point)!=null and app.unit_nodes[sample.carrier.id].screen_bounds(app.camera).has_point(badge_point),"The shared-position badge is included in pointer bounds")
 app.click_tile(point);await process_frame
 assert(app.screen=="tile_units" and app.ui.find_child("TileUnit_"+sample.carrier.id,true,false)!=null and app.ui.find_child("TileUnit_"+sample.patient.id,true,false)!=null)
 for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=size_value;app.ui.size=size_value;await process_frame;await process_frame
  for button in app.ui.find_children("*","Button",true,false):assert(Rect2(Vector2.ZERO,app.ui.size).grow(.1).encloses(button.get_global_rect()),"Both patient choices and the return button stay visible")
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;app._unhandled_input(escape)
 assert(app.screen=="battle" and app.selected==sample.healer and app.game.save_data("battle")==before and app.game.rng.state==seed,"Cancelling the chooser preserves selection, turn and RNG")
 app.click_tile(point);app.ui.find_child("TileUnit_"+sample.patient.id,true,false).pressed.emit();await process_frame
 var disk=Rules.new();assert(disk.load_game(app.save_path)=="battle" and disk.at(point).id==sample.patient.id,"The chosen patient's revival commits before visual feedback")
 while app.busy:await process_frame
 assert(sample.patient.hp>0 and Door.downed(sample.carrier) and app.game.at(point)==sample.patient)
 assert(app.unit_nodes[sample.patient.id].shared_marker!=null and app.unit_nodes[sample.carrier.id].shared_marker==null,"The badge follows the standing occupant after revival")
 sample.healer.acted=false;app.selected=sample.healer;app.update_side();app.click_tile(point)
 assert(app.ui.find_child("TileUnit_"+sample.patient.id,true,false).text.contains("HP ") and app.ui.find_child("TileUnit_"+sample.carrier.id,true,false).text.contains("Downed"))
 app.ui.find_child("TileUnit_"+sample.carrier.id,true,false).pressed.emit();await process_frame
 assert(app.screen=="triage" and app.selected==sample.healer)
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("No adjacent tile is free for ")))
 var rescue=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Rescue "+sample.carrier.name)
 assert(rescue.size()==1 and not rescue[0].disabled);rescue[0].pressed.emit();await process_frame
 while app.busy:await process_frame
 assert(sample.carrier.carried_by==sample.healer.id and sample.carrier.hp==0 and app.game.occupants(point).size()==1)
 assert(app.unit_nodes[sample.patient.id].shared_marker==null,"The chooser badge clears after the last shared patient is rescued")
 assert(disk.load_game(app.save_path)=="battle" and disk.units.filter(func(unit):return unit.id==sample.carrier.id)[0].carried_by==sample.healer.id)
 sample=setup(app.game);assert(app.game.heal(sample.healer,sample.patient));sample.healer.acted=false
 sample.blockers[0].x=10;sample.blockers[0].y=7
 app.make_map();app.show_battle();app.selected=sample.healer;app.update_side();app.click_tile(point)
 app.ui.find_child("TileUnit_"+sample.carrier.id,true,false).pressed.emit();await process_frame
 assert(app.unit_nodes[sample.carrier.id].position.is_equal_approx(app.map_position(app.game.pos(sample.carrier))),"The relocated revival sprite is at its saved position before healing feedback")
 assert(app.game.pos(sample.carrier)==point+Vector2i.LEFT and disk.load_game(app.save_path)=="battle" and disk.units.filter(func(unit):return unit.id==sample.carrier.id)[0].x==2)
 while app.busy:await process_frame
 await Shutdown.dispose(app);await process_frame
 print("PASS: surrounded carrier release, shared-tile chooser, standing occupancy priority, blocked revival without action loss, adjacent recovery, same-tile rescue, safe carried healing, exact checkpoints and compact keyboard/click flows with permadeath on/off")
 quit()
