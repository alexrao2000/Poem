extends SceneTree
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
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-test_progress-ui-save.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.game.units[0].xp=90;before=app.game.progress_snapshot();app.game.award_xp(app.game.units[0],45)
 app.show_progress(before);await process_frame
 assert(is_instance_valid(app.reward_panel),"Growth panel is visible")
 await process_frame
 assert(app.reward_panel.get_global_rect().end.y<app.ui.size.y,"Growth fits viewport")
 app.reward_skip=true;await process_frame;await process_frame
 assert(not is_instance_valid(app.reward_panel),"Continue dismisses reward")
 for enemy in app.game.living("enemy"):enemy.hp=0
 assert(await app.check_result(),"Victory creates chapter report")
 assert(app.screen=="result")
 var loaded=Rules.new();assert(loaded.load_game(app.save_path)=="battle" and loaded.result()=="victory","Victory is resumable before chapter continuation")
 app.queue_free();await process_frame
 print("PASS: XP rollover, stat gains, growth overlay, dismissal and resumable chapter results")
 quit()
