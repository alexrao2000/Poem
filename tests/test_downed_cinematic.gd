extends SceneTree
## A rescuable fall remains visibly distinct from a terminal defeat during the
## full 3D finish. Actual actions retain their committed casualty and RNG state.
const Rules=preload("res://scripts/rules.gd")
const Director=preload("res://scripts/combat_camera.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-downed-cinematic-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.combat="all";app.preferences.values.auto_end=false
 var cases=[["enemy","current"],["enemy","revised"],["counter","current"],["counter","revised"],["mounted","current"],["mounted","revised"],["skip","revised"],["terminal","revised"]]
 var count=0;var all_figures=[]
 for sample in cases:
  viewport.size=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)][count%3];await process_frame
  var counter=sample[0]=="counter";var mounted=sample[0]=="mounted";var terminal=sample[0]=="terminal"
  app.preferences.values.character_models=sample[1]
  app.game.new_campaign(true);app.game.death_door=not terminal;app.game.action_saves=true
  if mounted:app.game.chapter=2;app.game.deployed.erase("oren");app.game.deployed.append("bram")
  app.game.start_battle()
  var lord=app.game.units.filter(func(u):return u.id=="lyra")[0];var patient=app.game.units.filter(func(u):return u.id==("bram" if mounted else "oren"))[0];var healer=app.game.units.filter(func(u):return u.id=="ivo")[0];var enemy=app.game.living("enemy")[0]
  lord.x=9;lord.y=5;patient.x=9;patient.y=4;patient.hp=1;patient.speed=0;healer.x=10;healer.y=5
  enemy.x=8;enemy.y=4;enemy.ai="guard";enemy.job="Vanguard";enemy.weapon="sword";enemy.item="iron_sword";enemy.reach=1;enemy.pow=100;enemy.speed=50;enemy.defense=100;enemy.hp=enemy.max_hp;enemy.held_tonics=0
  app.game.units=[lord,patient,healer,enemy];app.game.rng.seed=309 if counter else 17
  app.make_map();app.show_battle();await process_frame;await process_frame
  assert(all_figures.all(func(ref):return ref.get_ref()==null),"Rebuilding the next map releases the suspended figures from the previous exchange")
  if counter:app.selected=patient;app.click_tile(app.game.pos(enemy));app.player_attack()
  else:app.end_turn()
  assert(app.busy)
  var saw_finish=false;var saw_departure=false;var saw_card=false;var saved_checked=false;var skipped=false;var saw_wide=false;var figures=[];var deadline=Time.get_ticks_msec()+15000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   var actors=app.stage.get_children().filter(func(node):return node.has_method("socket_position"))
   if actors.size()==2 and app.stage.visible:
    var figure=actors[0 if counter else 1]
    if figures.is_empty():figures.append(weakref(figure));all_figures.append(figures[0])
    var hud=app.ui.get_node_or_null("CombatHUD")
    if hud!=null and hud.records[patient.id].meter.value>0:assert(figure.pose_name!="down","A future wounded outcome does not appear before contact")
    var finish=app.stage.get_node_or_null("CombatFinish");var departure=app.stage.get_node_or_null("CombatDefeat")
    if finish!=null:
     saw_finish=true;saw_departure=saw_departure or departure!=null
     if not terminal:
      assert(departure==null and figure.visible and figure.pose_name=="down","Rescuable bodies remain visible through the finish without the defeat fade")
      var caption=app.ui.get_node("CombatCaption")
      assert(caption.visible and caption.text==patient.name+" · NEEDS RESCUE")
      assert(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(caption.get_global_rect()))
      var director=app.stage.get_children().filter(func(node):return node is Director)[0]
      if not director.movement.is_running():
       var safe=Rect2(Vector2.ONE*16,Vector2(viewport.size)-Vector2.ONE*32)
       for point in [figure.global_position,figure.socket_position("recovery")]:
        assert(not app.camera.is_position_behind(point) and safe.has_point(app.camera.unproject_position(point)),"The wounded recipient stays in the wider finishing shot")
       saw_wide=true
     if not saved_checked:
      var loaded=Rules.new();var loaded_stage=loaded.load_game(app.save_path)
      var disk=canonical(loaded.save_data("battle"));var live=canonical(app.game.save_data("battle"))
      if disk!=live:
       for key in live:
        if disk.get(key)!=live[key]:print("SAVE DIFF ",sample," ",key," disk=",disk.get(key)," live=",live[key])
      assert(loaded_stage=="battle" and disk==live,"Committed fall matches presentation: "+str(sample));saved_checked=true
     if sample[0]=="skip" and not skipped:app.ui.get_node("CombatPlayback").request_skip();skipped=true
   var card=app.ui.get_node_or_null("CasualtyCard")
   if card!=null:assert(card.heading.text.ends_with("LAST WORDS" if terminal else "NEEDS RESCUE"));saw_card=true;card.dismissed=true
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  assert(not app.busy and saw_finish and saved_checked and saw_card==not skipped)
  assert(app.stage.process_mode==Node.PROCESS_MODE_DISABLED and app.stage.get_node_or_null("CombatDefeat")==null and app.stage.get_node_or_null("CombatFinish")==null,"Return suspends the figures and releases temporary finish effects")
  assert(saw_departure==terminal and skipped==(sample[0]=="skip"))
  if not terminal and not skipped:assert(saw_wide)
  assert(app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
  if terminal:assert(patient.hp==0 and not app.unit_nodes.has(patient.id) and app.game.roster.filter(func(u):return u.id==patient.id)[0].fallen)
  else:assert(app.game.DeathDoor.downed(patient) and patient.bleed_turns==2 and app.unit_nodes[patient.id].downed and app.unit_nodes[patient.id].visible and not app.game.roster.filter(func(u):return u.id==patient.id)[0].fallen)
  count+=1
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 assert(all_figures.all(func(ref):return ref.get_ref()==null))
 print("PASS: %d actual current/revised enemy/counter/mounted/finish-Skip/terminal falls at three sizes; visible rescuable finishes, rescue captions, committed saves, true defeat fade and exact map-return cleanup"%count)
 quit()
