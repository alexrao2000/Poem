extends SceneTree
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new();var original=g.roster[0]
 assert(g.promotions.size()==16)
 assert(not g.promote(original,"dawnblade"),"Training requires level ten")
 original.level=10;var before=original.duplicate(true);var rng=g.rng.state
 assert(not g.promote(original,"bastion"),"Cannot choose another base class's path")
 assert(g.promote(original,"dawnblade"),"Eligible recruit promotes")
 assert(original.level==10 and original.xp==before.xp and original.item==before.item,"Promotion retains experience and equipment")
 assert(original.speed==before.speed+3 and original.max_hp==before.max_hp+2 and original.hp==before.hp+2)
 assert(g.class_name_for(original)=="Dawnblade" and original.job=="Vanguard","Presentation title retains base job identity")
 assert(not g.promote(original,"standard_bearer"),"Cannot repeat or switch a chosen path")
 assert(g.rng.state==rng,"Training never consumes combat randomness")
 for path in g.promotions:
  var campaign=Rules.new();campaign.chapter=11
  var unit=campaign.roster.filter(func(u):return u.job==path.base)[0];unit.level=10
  var previous=unit.duplicate(true)
  assert(campaign.promotion_options(unit).size()==2)
  assert(campaign.promote(unit,path.id))
  for key in ["max_hp","pow","defense","speed","move"]:
   assert(unit[key]==previous[key]+path.bonuses.get(key,0),"Data-driven gain applies exactly once")
  campaign.deployed=[unit.id];campaign.start_battle()
  var battle=campaign.living("player")[0]
  assert(battle.promotion==path.id and battle.move==unit.move,"Deployment preserves promoted attributes")
  assert(campaign.valid_save(campaign.save_data("battle")),"Every promoted path creates a valid save")
  var restored=Rules.new();assert(restored.import_code(campaign.export_code("battle"))=="battle")
  assert(restored.living("player")[0].promotion==path.id,"Promotion survives portable save")
  campaign.finish_chapter();assert(unit.promotion==path.id,"Chapter progression retains selected path")
 var capped_game=Rules.new();var capped_unit=capped_game.roster[0];capped_unit.level=99
 for key in Rules.STAT_CAPS:capped_unit[key]=Rules.STAT_CAPS[key]
 capped_unit.hp=900
 var preview=capped_game.promotion_gains(capped_unit,"standard_bearer")
 assert(preview.max_hp==0 and preview.pow==0 and preview.defense==0)
 assert(capped_game.promote(capped_unit,"standard_bearer") and capped_unit.hp==900,"Training only grants actual capped stat gains")
 assert(capped_game.valid_save(capped_game.save_data("camp")),"Capped promotion remains loadable")
 var legacy=Rules.new();assert(legacy.restore_save(legacy.save_data("camp"))=="camp","Legacy saves without a promotion remain valid")
 var malformed=legacy.save_data("camp").duplicate(true);malformed.roster[0].promotion="bastion"
 assert(not legacy.valid_save(malformed),"Reject incompatible path in imported save")
 malformed.roster[0].promotion=42;assert(not legacy.valid_save(malformed),"Reject non-string path")
 g.start_battle();var hero=g.units[0];var foe=g.living("enemy")[0]
 var promoted=g.forecast(hero,foe);hero.erase("promotion");var base=g.forecast(hero,foe)
 assert(promoted.crit==base.crit+5,"Promotion critical bonus reaches actual combat forecast")
 var medic=g.roster[3];medic.level=10;assert(g.promote(medic,"luminary"));g.start_battle()
 medic=g.units.filter(func(u):return u.id=="ivo")[0];hero=g.units[0]
 medic.x=2;medic.y=3;hero.x=3;hero.y=3;hero.hp=hero.max_hp-20
 var hp=hero.hp;assert(g.heal(medic,hero) and hero.hp==hp+16,"Luminary staff bonus changes actual healing")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test-promotions-ui.json";root.add_child(app);await process_frame
 var unit=app.game.roster[0];unit.level=10
 app.show_promotions(unit);await process_frame;await process_frame
 assert(app.screen=="promotions")
 var buttons=app.ui.find_children("*","Button",true,false)
 assert(buttons.size()==3 and not buttons[0].disabled and not buttons[1].disabled)
 for control in buttons:assert(control.get_global_rect().end.y<=app.ui.size.y,"Training controls fit viewport")
 buttons[0].pressed.emit();await process_frame
 assert(app.screen=="promotion_confirm" and unit.get("promotion","")=="","Choice preview does not commit")
 app.ui.find_children("*","Button",true,false)[1].pressed.emit();await process_frame
 assert(app.screen=="promotions","Cancel preserves choice")
 app.confirm_promotion(unit,app.game.promotions[0]);await process_frame
 app.ui.find_children("*","Button",true,false)[0].pressed.emit();await process_frame
 assert(unit.promotion=="standard_bearer")
 var saved=Rules.new();assert(saved.load_game(app.save_path)=="camp" and saved.roster[0].promotion==unit.promotion,"UI commits and saves the selected path")
 app.show_dossier(unit);await process_frame;await process_frame
 for control in app.ui.find_children("*","Button",true,false):assert(control.get_global_rect().end.y<=app.ui.size.y,"Dossier controls fit after adding training")
 app.queue_free();await process_frame
 print("PASS: 16 promotion paths, eligibility, stat and combat bonuses, persistence and confirmation flow")
 quit()
