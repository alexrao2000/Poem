extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Reward=preload("res://scripts/progress_reward.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new();g.start_battle();var unit=g.units[0];unit.xp=90
 var before=g.progress_snapshot();var state=g.rng.state;g.award_xp(unit,45)
 var changes=g.progress_since(before)
 assert(changes.size()==1 and changes[0].xp_gain==45,"XP includes level rollover")
 assert(changes[0].gains.max_hp==2 and changes[0].gains.pow==1,"Growth records actual stat gains")
 assert(g.rng.state==state,"Progress inspection never consumes RNG")
 assert(g.progress_since(g.progress_snapshot()).is_empty(),"No duplicate gains after fresh snapshot")
 # Valid high-level saves remain loadable after growth, including large rewards.
 unit.level=98;unit.xp=90;unit.max_hp=998;unit.hp=900
 for key in ["pow","defense","resistance","speed"]:unit[key]=255
 before=g.progress_snapshot();g.award_xp(unit,1000000)
 assert(unit.level==99 and unit.xp==0 and unit.max_hp==999 and unit.hp==901)
 changes=g.progress_since(before);assert(changes[0].xp_gain==10 and changes[0].gains.max_hp==1 and changes[0].gains.pow==0,"Feedback reports only retained gains")
 assert(g.valid_save(g.save_data("battle")),"Capped growth preserves save validity")
 var capped=unit.duplicate(true);g.award_xp(unit,45);assert(unit==capped and g.progress_since(g.progress_snapshot()).is_empty())
 unit.level=1;unit.xp=20;g.award_xp(unit,-10);assert(unit.xp==20,"Negative rewards do not reduce progress")
 unit.hp=0;g.award_xp(unit,100);assert(unit.level==1 and unit.hp==0,"Growth cannot revive a fallen unit")
 var malformed=g.save_data("battle").duplicate(true);malformed.roster[0].level=2.5
 assert(not g.valid_save(malformed),"Fractional progression fields are invalid")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test_progress-ui-save.json";root.add_child(app);await process_frame
 await verify_rewards(app)
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.game.units[0].xp=90;before=app.game.progress_snapshot();app.game.award_xp(app.game.units[0],45)
 app.show_progress(before);await process_frame
 assert(is_instance_valid(app.reward_panel),"Growth panel is visible")
 assert(app.reward_panel.quote.text.contains(app.profiles[app.game.units[0].id].growth_quote),"Real progression uses the recruit’s authored reaction")
 await process_frame
 assert(app.reward_panel.get_global_rect().end.y<app.ui.size.y,"Growth fits viewport")
 app.reward_skip=true;await process_frame;await process_frame
 assert(not is_instance_valid(app.reward_panel),"Continue dismisses reward")
 for enemy in app.game.living("enemy"):enemy.hp=0
 assert(await app.check_result(),"Victory creates chapter report")
 assert(app.screen=="result")
 var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle" and loaded.result()=="victory","Victory is resumable before chapter continuation")
 await Shutdown.dispose(app);await process_frame
 print("PASS: XP rollover/caps, 144 roster reward layouts, sequential actual stat gains, cue timing, dismissal and resumable results")
 quit()

func change_for(source,leveled):
 var unit=source.duplicate(true);unit.level=2 if leveled else 1;unit.xp=35
 var previous={"level":1,"xp":90 if leveled else 5};var gains={}
 for stat in Reward.STATS:
  var key=stat[0];gains[key]=1 if leveled and key in ["max_hp","pow","speed"] else 0
  previous[key]=int(unit[key])-gains[key]
 return {"unit":unit,"before":previous,"gains":gains,"xp_gain":45 if leveled else 30}

func verify_rewards(app):
 var host=Control.new();root.add_child(host);host.theme=app.ui.theme
 var original=app.game.roster.duplicate(true);var rng=app.game.rng.state;var layouts=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  for unit in app.game.roster:
   for leveled in [false,true]:
    var reward=Reward.new();reward.configure(host,change_for(unit,leveled),app.portraits.get_dialogue_portrait(unit.id),app.game.class_name_for(unit),app.game.MAX_LEVEL,app.profiles[unit.id].growth_quote)
    await process_frame;await process_frame
    assert(Rect2(Vector2.ZERO,host.size).encloses(reward.get_rect()),"Reward stays within every tested viewport")
    for child in reward.content.get_children():
     assert(Rect2(Vector2.ZERO,reward.content.size).encloses(child.get_rect()),"Portrait, values and controls fit the reward panel")
     if child is Label:assert(child.get_visible_line_count()==child.get_line_count() and child.size.x>=child.get_minimum_size().x,"Names, classes and numeric stats remain readable")
    assert(reward.quote!=null if leveled else reward.quote==null,"Personal growth line appears only on a level increase")
    if leveled:
     assert(reward.quote.text=="“"+app.profiles[unit.id].growth_quote+"”" and reward.quote.get_line_count()<=2,"All 24 original lines remain legible beside their own portrait")
    assert(reward.rows.size()==(5 if leveled else 0),"Ordinary experience uses a compact panel without stat rows")
    reward.queue_free();await process_frame;layouts+=1
 for case in ["normal","level","limit","multiple"]:
  var change=change_for(app.game.roster[0],case!="normal")
  if case=="limit":change.unit.level=99;change.unit.xp=0;change.before.level=98;change.xp_gain=10
  elif case=="multiple":change.unit.level=4;change.xp_gain=245
  var reward=Reward.new();reward.configure(host,change,app.portraits.get_dialogue_portrait(change.unit.id),"Vanguard")
  var initial_position=reward.position
  var cues=[0];reward.begin(func():cues[0]+=1)
  reward.appearance.custom_step(.08)
  assert(reward.entrance>0 and reward.entrance<1 and reward.position.y<initial_position.y,"Reward settles upward with a short fade")
  host.size+=Vector2(40,20);reward.arrange()
  assert(Rect2(Vector2.ZERO,host.size).encloses(reward.get_rect()),"Resize preserves the animated reward bounds")
  if reward.leveled:
   for row in reward.rows.values():assert(row.gain.modulate.a==0,"Stat gains wait for the experience rollover")
  await reward.motion.finished;await create_timer(.2).timeout
  assert(is_equal_approx(reward.entrance,1) and is_equal_approx(reward.modulate.a,1),"Card finishes entering independently of the XP count")
  assert(cues[0]==(1 if reward.leveled else 0),"Only a level rollover plays the growth cue")
  assert(reward.meter.value==(100 if case=="limit" else change.unit.xp),"Meter settles on resolved XP, including the level limit")
  if case=="limit":assert(reward.experience.text=="LEVEL LIMIT REACHED")
  for key in reward.rows:
   var row=reward.rows[key]
   assert(row.value.text==str(int(change.unit[key])) and is_equal_approx(row.gain.modulate.a,1),"Each revealed row shows the resolved stat")
   assert(row.gain.text==("+%d"%change.gains[key] if change.gains[key]>0 else "—"),"Zero growth never displays a misleading plus")
  reward.close_button.pressed.emit();assert(reward.requested_close,"Mouse dismissal is available alongside keyboard skip")
  reward.queue_free();await process_frame
 var interrupted=Reward.new();interrupted.configure(host,change_for(app.game.roster[0],true),app.portraits.get_dialogue_portrait("lyra"),"Vanguard")
 interrupted.begin(func():assert(false,"Dismissal before rollover cannot play a delayed level-up cue"))
 var weak=weakref(interrupted);interrupted.queue_free();await process_frame;await create_timer(.3).timeout
 assert(weak.get_ref()==null,"Early dismissal releases entrance and reveal animation together")
 assert(layouts==144 and app.game.roster==original and app.game.rng.state==rng,"Reward presentation preserves roster and RNG")
 host.queue_free();await process_frame
