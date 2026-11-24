extends SceneTree
# Phase-boundary losses are committed before a brief map departure. The camera
# and fade only explain the resolved loss; reload and Skip never repeat it.

const Card=preload("res://scripts/casualty_card.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
class WaitingTactics extends "res://scripts/tactics.gd":
 func plan(game,unit):return {"position":game.pos(unit),"target":"","action":"wait"}

func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func down(game,unit,turns=1):
 unit.hp=0;game.DeathDoor.fall(game,unit);unit.bleed_turns=turns;game.commit_casualties()

func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-bleedout-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.tactics=WaitingTactics.new();app.preferences.values.auto_end=false
 var cases=["permanent","recoverable","lord","multiple","carried","next_phase","skip","save_failure"];var count=0
 for kind in cases:
  viewport.size=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)][count%3];await process_frame
  app.game.new_campaign(kind!="recoverable");app.game.death_door=true;app.game.action_saves=true
  app.game.trials.flags.death_legacies=kind in ["permanent","multiple"]
  app.game.trials.flags.sacrifice_cost=kind in ["recoverable","multiple"]
  app.game.start_battle()
  var lord=app.game.units.filter(func(u):return u.id=="lyra")[0];var patient=app.game.units.filter(func(u):return u.id=="oren")[0];var second=app.game.units.filter(func(u):return u.id=="ivo")[0];var enemy=app.game.living("enemy")[0]
  lord.x=2;lord.y=3;patient.x=3;patient.y=3;second.x=4;second.y=3;enemy.x=12;enemy.y=7
  if kind=="lord":patient=lord
  down(app.game,patient,2 if kind=="next_phase" else 1)
  if kind=="multiple":down(app.game,second)
  if kind=="carried":assert(app.game.DeathDoor.rescue(app.game,lord,patient))
  app.game.units=[lord,second,enemy] if kind=="lord" else [lord,patient,second,enemy]
  app.make_map();app.show_battle();assert(app.persist_campaign("battle"));await process_frame
  var figures=[]
  for unit in [patient,second]:
   if app.game.DeathDoor.downed(unit) and unit.get("carried_by","").is_empty():figures.append({"id":unit.id,"ref":weakref(app.unit_nodes[unit.id])})
  var rng=app.game.rng.state;var saved_path=app.save_path;var will_fall=kind not in ["carried","next_phase"];var expected_count=2 if kind=="multiple" else 1 if will_fall else 0
  if kind=="save_failure":app.save_path=saved_path+"/missing/save.json"
  app.end_turn()
  if kind=="save_failure":
   assert(app.save_failed and not app.busy and not app.game.DeathDoor.downed(patient))
   assert(figures.all(func(entry):return entry.ref.get_ref()==null or not entry.ref.get_ref().departing),"Failed save starts no departure")
   app.save_path=saved_path;await app.retry_action_save();assert(not app.save_failed and app.game.phase=="player")
   count+=1;continue
  var observed={};var cards={};var skipped=false;var interrupted={};var deadline=Time.get_ticks_msec()+10000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   for entry in figures:
    var figure=app.unit_nodes.get(entry.id)
    if figure!=null and figure.departing:
     entry.ref=weakref(figure)
     observed[entry.id]=true
     assert(not app.game.DeathDoor.downed(patient) and app.game.rng.state==rng)
     var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle")
     assert(canonical(loaded.save_data("battle"))==canonical(app.game.save_data("battle")),"Loss is durable before map departure")
     if interrupted.is_empty():interrupted=loaded.save_data("battle").duplicate(true)
     assert(figure.player.state=="hurt","Bleed-out fades the held wounded pose without another attack")
     var point=app.camera.unproject_position(figure.global_position+Vector3.UP*.55)
     assert(not app.camera.is_position_behind(figure.global_position) and Rect2(Vector2.ONE*16,Vector2(viewport.size)-Vector2.ONE*32).has_point(point),"Departing patient is framed inside the viewport")
     if kind=="skip" and not skipped:
      var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true;app._input(key);skipped=true
   for card in app.ui.get_children().filter(func(node):return node is Card and node.visible):
    cards[card.heading.text]=card.consequences.text if card.consequences!=null else ""
    card.dismissed=true
  assert(not app.busy and observed.size()==expected_count,"Every expired patient gets one map departure: "+kind)
  assert(cards.size()==(0 if skipped else expected_count),"Casualty captions: "+str([kind,cards,expected_count,skipped]))
  if kind=="permanent":assert(cards["Oren · LAST WORDS"]=="Legacy credit +1 · Faye joins early")
  elif kind=="recoverable":assert(cards["Oren · WITHDRAWING"]=="Allies gain +2 attack · Recovery on redeployment")
  elif kind=="multiple":
   assert(cards["Oren · LAST WORDS"]=="Legacy credit +1 · Faye joins early · Allies gain +2 attack")
   assert(cards["Ivo · LAST WORDS"]=="Legacy credit +1 · Maelin joins","Ivo's card names his replacement and omits the attack boost already announced")
   assert(app.game.trials.volunteers==["faye","maelin"],"Both loss rewards are recorded once")
  assert(app.game.rng.state==rng and not app.stage.visible)
  if not will_fall:
   assert(app.game.DeathDoor.downed(patient) and patient.bleed_turns==1 and not app.game.roster.filter(func(u):return u.id==patient.id)[0].fallen)
  else:
   assert(figures.all(func(entry):return entry.ref.get_ref()==null),"Map refresh releases expired figures")
   var outcome=canonical(app.game.save_data("battle"));assert(not interrupted.is_empty())
   assert(app.game.restore_save(interrupted)=="battle");await app.resume_saved_battle()
   assert(canonical(app.game.save_data("battle"))==outcome,"Interrupted departure resumes without repeated countdown or casualty")
  count+=1
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d actual phase endings across three viewports, exact credit and sacrifice feedback, permanent/recoverable/lord/multiple losses, carried and next-phase exclusions, durable-before-fade state, keyboard Skip, interrupted reload and failed-save retry"%count)
 quit()
