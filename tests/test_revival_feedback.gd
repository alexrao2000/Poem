extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Door=preload("res://scripts/death_door.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func unit(game,id):return game.units.filter(func(u):return u.id==id)[0]
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-revival-feedback-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.auto_end=false
 var cases=[
  ["field","current","all",Vector2i(1024,640)],
  ["field","revised","all",Vector2i(1440,900)],
  ["carried","current","all",Vector2i(1280,720)],
  ["carried","revised","all",Vector2i(1024,640)],
  ["field","current","map",Vector2i(1024,640)],
  ["carried","current","map",Vector2i(1280,720)],
  ["surrounded","current","map",Vector2i(1440,900)],
  ["normal","current","map",Vector2i(1024,640)],
  ["skip_windup","revised","all",Vector2i(1440,900)],
  ["skip_arrival","revised","all",Vector2i(1280,720)]
 ]
 for sample in cases:
  viewport.size=sample[3];await process_frame
  app.preferences.values.combat=sample[2];app.preferences.values.character_models=sample[1]
  app.game.new_campaign(true);app.game.death_door=true;app.game.action_saves=true;app.game.start_battle()
  var carrier=unit(app.game,"oren");var patient=unit(app.game,"sera");var healer=unit(app.game,"ivo")
  carrier.x=3;carrier.y=3;patient.x=2;patient.y=3;healer.x=2;healer.y=4
  patient.hp=patient.max_hp-6 if sample[0]=="normal" else 0
  if sample[0]!="normal":Door.fall(app.game,patient)
  var carried=sample[0] in ["carried","surrounded"]
  if carried:
   assert(Door.rescue(app.game,carrier,patient));healer.x=2;healer.y=3
   if sample[0]=="surrounded":
    var blockers=app.game.units.filter(func(u):return u.id not in [carrier.id,patient.id]).slice(0,4)
    for i in range(4):
     var tile=Vector2i(3,3)+[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][i];blockers[i].x=tile.x;blockers[i].y=tile.y
    assert(Door.drop_positions(app.game,carrier).is_empty())
  app.make_map();app.show_battle();app.selected=healer;app.update_side();await process_frame;await process_frame
  assert(app.game.can_heal(healer,patient))
  var rng=app.game.rng.state;var before_camera=app.map_navigation.capture_view()
  if carried:app.heal_carried_ally(patient)
  else:app.click_tile(app.game.pos(patient))
  assert(app.busy and patient.hp>0 and not Door.downed(patient) and healer.acted)
  if sample[0]!="normal":assert(patient.acted)
  if sample[0]=="surrounded":assert(patient.get("carried_by","")==carrier.id)
  var resolved=canonical(app.game.save_data("battle"));var saved=Rules.new()
  assert(saved.load_game(app.save_path)=="battle" and canonical(saved.save_data("battle"))==resolved,"Recovery commits before its presentation")
  var saw_caption=false;var saw_map=false;var skipped=false;var arrived=false;var saw_zero=false;var saw_map_flight=false;var deadline=Time.get_ticks_msec()+15000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   var caption=app.ui.get_node_or_null("CombatCaption");var effect=app.stage.get_node_or_null("CombatHeal")
   if effect!=null and effect.has_arrived:arrived=true
   var hud=app.ui.get_node_or_null("CombatHUD")
   if hud!=null and sample[0]!="normal" and is_zero_approx(hud.records[patient.id].meter.value):saw_zero=true
   if caption!=null and caption.visible:
    assert(arrived and caption.text=="REVIVED · ACTION SPENT","Revival is announced only after staff light arrives")
    assert(Rect2(Vector2.ZERO,Vector2(sample[3])).encloses(caption.get_global_rect()))
    assert(caption.size.x>=caption.get_minimum_size().x)
    if hud!=null:assert(not caption.get_global_rect().intersects(hud.records[patient.id].plate.get_global_rect()))
    saw_caption=true
   var map_effect=app.pieces.get_node_or_null("MapHeal")
   if map_effect!=null and not map_effect.has_arrived:
    saw_map_flight=true
    assert(not map_effect.rings[0].visible and app.ui.get_node_or_null("MapRecoveryCue")==null,"Map recovery waits for staff light to arrive")
    if app.unit_nodes.has(patient.id) and sample[0]!="normal":assert(app.unit_nodes[patient.id].hp_ratio==0)
   var cue=app.ui.get_node_or_null("MapRecoveryCue")
   if cue!=null:
    if map_effect!=null:assert(map_effect.has_arrived)
    if app.unit_nodes.has(patient.id):
     var recovered=app.unit_nodes[patient.id]
     assert(is_equal_approx(recovered.hp_ratio,float(patient.hp)/patient.max_hp) and not recovered.downed and recovered.rescue_marker==null,"Map revival clears the wounded pose/countdown and restores health at contact")
    assert(cue.text.begins_with("+" if sample[0]=="normal" else "Revived · +"))
    var bounds=cue.get_global_rect();assert(Rect2(Vector2.ZERO,Vector2(sample[3])).encloses(bounds))
    if is_instance_valid(app.terrain_card):assert(not bounds.intersects(app.terrain_card.get_global_rect()))
    saw_map=true
   var playback=app.ui.get_node_or_null("CombatPlayback")
   if playback!=null and not skipped:
    if sample[0]=="skip_windup" and caption!=null and not arrived:playback.request_skip();skipped=true
    elif sample[0]=="skip_arrival" and saw_caption:playback.request_skip();skipped=true
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  assert(not app.busy and canonical(app.game.save_data("battle"))==resolved and app.game.rng.state==rng)
  if sample[2]=="map":assert(saw_map and saw_map_flight and not saw_caption and app.pieces.get_node_or_null("MapHeal")==null)
  elif sample[0]=="skip_windup":assert(skipped and not saw_caption)
  else:assert(saw_caption and saw_zero)
  if sample[0]=="skip_arrival":assert(skipped)
  if sample[2]!="map":assert(app.map_navigation.capture_view()==before_camera)
  assert(app.ui.get_node_or_null("CombatCaption")==null and app.ui.get_node_or_null("MapRecoveryCue")==null and app.stage.get_node_or_null("CombatHeal")==null)
  assert(saved.load_game(app.save_path)=="battle" and canonical(saved.save_data("battle"))==resolved)
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: ten real field/carried/surrounded/ordinary/skip healing flows, current/revised revival captions at contact, three-size actual viewport cue bounds, committed health/spent actions, unchanged RNG/checkpoints and cleanup")
 quit()
