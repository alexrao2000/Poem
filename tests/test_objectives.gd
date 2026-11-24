extends SceneTree
# Objective descriptions follow campaign data and existing victory rules.
# Live counters update after displayed actions without revealing future damage.

const Shutdown=preload("helpers/game_shutdown.gd")
class WaitingTactics extends "res://scripts/tactics.gd":
 func plan(game,unit):return {"position":game.pos(unit),"target":"","action":"wait"}
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))

func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-objectives-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 var layouts=0
 for dimensions in [Vector2i(720,640),Vector2i(768,900),Vector2i(900,640),Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  for chapter in range(12):
   app.game.new_campaign();app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle();await process_frame;await process_frame
   var before=canonical(app.game.save_data("battle"));var label=app.ui.find_child("BattleObjective",true,false)
   assert(label==app.objective_label and label.text==app.battle_objective_text())
   verify_header(app,dimensions)
   assert(label.get_line_count()<=label.get_visible_line_count(),"The full objective is legible")
   match app.game.info().objective:
    "rout":
     assert(label.text=="Defeat every enemy · %d remaining"%app.game.living("enemy").size())
    "seize":
     assert("any standing ally" in label.text and not "gate" in label.text)
     var ally=app.game.living("player")[0];var destination=app.game.objective_position()
     for enemy in app.game.living("enemy"):
      if app.game.pos(enemy)==destination:enemy.x=0;enemy.y=0
     ally.x=destination.x;ally.y=destination.y;assert(app.game.result()=="victory")
     assert(app.game.restore_save(before)=="battle")
    "boss":assert(label.text=="Defeat "+app.game.info().boss)
    "survive":
     assert("or defeat every enemy" in label.text and "0/6" in label.text)
     for turn in range(1,8):
      app.game.turn=turn
      for phase in ["player","enemy"]:
       app.game.phase=phase;app.update_side()
       assert("%d/6"%(turn-1) in label.text,"Only completed enemy phases count")
       assert(app.battle_header.phase_plate.fill==(app.battle_header.ENEMY_COLOR if phase=="enemy" else app.battle_header.PLAYER_COLOR))
     assert(app.game.restore_save(before)=="battle");app.update_side()
   assert(canonical(app.game.save_data("battle"))==before,"Objective inspection changes no campaign, countdown or RNG state")
   layouts+=1
  app.debug_session.begin(app.game,"battle")
  for turn in [1,12,50]:
   for phase in ["player","enemy"]:
    app.game.turn=turn;app.game.phase=phase
    for failing in [false,true]:
     app.save_failed=failing;app.update_side()
     await process_frame;await process_frame
     var status=app.battle_header.status
     assert(status.text=="TURN %d  /  %s\nDEBUG%s"%[turn,phase.to_upper()," · SAVE FAILED" if failing else ""])
     assert(status.get_line_count()==2 and status.get_visible_line_count()==2)
     verify_header(app,dimensions)
  app.debug_session.end(app.game);app.save_failed=false
 var custom=app.game.content.chapters[2].duplicate(true);custom.turn_limit=4
 assert(app.objective_text(custom)=="Survive 4 enemy phases or defeat every enemy")
 app.game.new_campaign();app.game.start_battle()
 var ally=app.game.units[0];var enemy=app.game.living("enemy")[0];var reserve=app.game.living("enemy")[-1]
 ally.x=8;ally.y=4;ally.pow=100;ally.speed=100;enemy.x=9;enemy.y=4;enemy.hp=1;enemy.speed=0;enemy.defense=0;reserve.x=12;reserve.y=7
 app.game.units=[ally,enemy,reserve];app.game.rng.seed=17;app.make_map();app.show_battle();await process_frame
 var initial=app.objective_label.text;app.selected=ally;app.click_tile(app.game.pos(enemy));app.player_attack()
 assert(app.busy and enemy.hp==0 and app.objective_label.text==initial,"Resolved damage does not reduce the objective count before contact")
 while app.busy:
  if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  await process_frame
 assert(app.objective_label.text=="Defeat every enemy · 1 remaining")
 for chapter in [2,6]:
  app.game.new_campaign();app.game.chapter=chapter;app.game.start_battle();app.game.turn=6
  ally=app.game.units[0];enemy=app.game.living("enemy")[0];ally.x=1;ally.y=1;enemy.x=12;enemy.y=7
  app.game.units=[ally,enemy];app.tactics=WaitingTactics.new();app.make_map();app.show_battle()
  assert("5/6" in app.objective_label.text and app.game.result()=="")
  await app.end_turn()
  assert(app.game.turn==7 and app.game.result()=="victory" and app.screen=="result" and "6/6" in app.battle_objective_text())
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d chapter layouts and 72 Debug status layouts, separate chapter and phase plates at 720 pixels, inset text and readable palette; exact objective descriptions, phase counters, attack contact ordering and both survival finishes"%layouts)
 quit()

func verify_header(app,dimensions: Vector2i):
 var header=app.battle_header;var chapter=header.chapter_plate;var phase=header.phase_plate
 var screen=Rect2(Vector2.ZERO,Vector2(dimensions))
 var gap=phase.get_global_rect().position.x-chapter.get_global_rect().end.x
 assert(screen.encloses(chapter.get_global_rect()) and screen.encloses(phase.get_global_rect()),
  "Chapter %d at %s must contain %s and %s"%[app.game.chapter+1,dimensions,chapter.get_global_rect(),phase.get_global_rect()])
 assert(gap>=39.99 and (dimensions.x<1024 or gap>180),"The middle of the tactical map stays exposed at every supported size")
 assert(is_equal_approx(dimensions.x-phase.get_global_rect().end.x,22),"Debug and save notices preserve the phase plate’s right inset")
 assert(chapter.get_global_rect().end.y+10<=app.terrain_card.get_global_rect().position.y)
 assert(phase.get_global_rect().end.y+10<=app.side.get_parent().get_global_rect().position.y)
 assert(header.heading.text.ends_with(app.game.info().title) and app.objective_label.tooltip_text==app.objective_text())
 for pair in [[header.heading,chapter],[app.objective_label,chapter],[app.status,phase]]:
  var label: Label=pair[0];var plate=pair[1]
  var rect=label.get_global_rect()
  for corner in [rect.position,rect.end,Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y)]:
   assert(Geometry2D.is_point_in_polygon(corner-plate.global_position,plate.outline()),"Text remains inside each trimmed corner")
  for line in label.text.split("\n"):
   var width=label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
   assert(width<=label.size.x,"The full header text fits without clipping")
  var lightest=plate.fill.lerp(Color(1,.88,.64),.09).srgb_to_linear().get_luminance()
  var ink=label.get_theme_color("font_color").srgb_to_linear().get_luminance()
  assert((ink+.05)/(lightest+.05)>4.5,"Text passes contrast over the brightest ornament")
