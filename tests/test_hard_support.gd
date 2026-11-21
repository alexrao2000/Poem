extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const CHAPTERS=[4,8,11]
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))
func fresh(chapter,hard,pressure=-1):
 var game=Rules.new();game.new_campaign();game.chapter=chapter;game.trials.flags.hard_campaign=hard
 game.trials.flags.reset_pressure=pressure>=0;game.trials.pressure=maxi(0,pressure);game.rng.seed=472019
 game.start_battle();return game
func run():
 var count=0;var planner=Tactics.new()
 for chapter in range(12):
  for hard in [false,true]:
   for pressure in [-1,0,2,10]:
    var game=fresh(chapter,hard,pressure);var base=game.info().enemies.size();var extra=1 if hard and chapter in CHAPTERS else 0
    assert(game.living("enemy").size()==base+extra,"Only the three selected Hard garrisons gain one staff unit")
    var occupied={};var ids={}
    for unit in game.units:
     assert(not occupied.has(game.pos(unit)) and not ids.has(unit.id),"Pressure movement and optional support keep unique legal deployments")
     assert(game.terrain(game.pos(unit)) not in ["#","~"]);occupied[game.pos(unit)]=true;ids[unit.id]=true
    assert(game.units.filter(func(unit):return unit.get("boss",false)).size()==1 and game.living("enemy")[0].name==game.info().boss)
    var snapshot=game.save_data("battle").duplicate(true);var source=game.content.duplicate(true)
    var formation=game.enemy_formation();assert(formation.size()==base+extra)
    assert(game.save_data("battle")==snapshot and game.content==source,"Formation inspection changes neither source content nor live state/RNG")
    if extra:
     var medic=game.living("enemy")[-1]
     assert(medic.id=="enemy_"+str(base) and medic.name=="Field Warden" and medic.job=="Warden" and medic.item=="field_staff" and not medic.boss)
     assert(medic.max_hp==game.content.classes.Warden.hp+chapter*2+game.trials.enemy_modifiers(chapter).max_hp)
     assert(planner.threatened_tiles(game,medic).is_empty(),"Staff support creates no invented attack range")
     if pressure>=0:assert(medic.held_tonics==maxi(0,2-pressure) and not medic.get("raider",false))
     var patient=game.living("enemy")[0];patient.hp-=10;medic.xp=90;game.begin_enemy_phase()
     var before=game.save_data("battle").duplicate(true);var choice=planner.plan(game,medic)
     assert(choice.action=="heal" and choice.target==patient.id,"Each authored support position can tend its wounded commander")
     assert(game.save_data("battle")==before)
     var expected=mini(patient.max_hp,patient.hp+game.healing_power(medic));var rng=game.rng.state
     planner.apply_plan(game,medic,choice)
     assert(patient.hp==expected and medic.acted and medic.xp==90 and game.rng.state==rng)
     var resumed=Rules.new();assert(resumed.restore_save(game.save_data("battle"))=="battle")
     assert(canonical(resumed.save_data("battle"))==canonical(game.save_data("battle")),"New support actions round-trip without regeneration")
    count+=1
 for chapter in CHAPTERS:
  var game=fresh(chapter,true);var signature=game.layout_signature();var base=game.info().enemies.size()
  # Earlier version-6 Hard saves contain only the base garrison.
  var earlier=game.save_data("battle").duplicate(true);earlier.units.pop_back();earlier.units[0].acted=true;earlier.units[-1].hp-=3
  assert(game.restore_save(earlier)=="battle" and game.units.size()==earlier.units.size())
  assert(canonical(game.save_data("battle"))==canonical(earlier),"Earlier Hard battles retain their exact units instead of gaining a healer on reload")
  game.start_battle();assert(game.living("enemy").size()==base+1)
  game.trials.flags.hard_campaign=false;assert(game.living("enemy").size()==base+1,"Changing Hard during a battle does not remove a live enemy")
  game.start_battle();assert(game.living("enemy").size()==base and game.layout_signature()==signature,"The next ordinary deployment restores the base formation without changing layout compatibility")
 await verify_campaign_playback()
 print("PASS: ",count," formation/pressure cases, three older-save shapes, legal unique spawns, real staff planning, zero enemy XP/RNG use, actual revised campaign healing, three-size briefs/inspection and committed save restoration")
 quit()

func verify_campaign_playback():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-hard-support-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.auto_end=false
 for chapter in CHAPTERS:
  app.game.new_campaign(true);app.game.chapter=chapter;app.game.action_saves=true;app.game.story_seen=["opening_"+str(chapter)]
  app.game.trials.flags.hard_campaign=true;app.game.trials.flags.reset_pressure=true;app.game.trials.pressure=2
  app.show_camp();await process_frame
  assert(app.ui.find_child("HardFormationBrief",true,false).text==app.game.info().hard_brief,"Camp explains the active support formation")
  for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
   await process_frame;await process_frame
   var brief=app.ui.find_child("HardFormationBrief",true,false);var scroll=brief.get_parent().get_parent()
   assert(scroll is ScrollContainer);scroll.ensure_control_visible(brief);await process_frame;await process_frame
   assert(Rect2(Vector2.ZERO,dimensions).encloses(scroll.get_global_rect()) and scroll.get_global_rect().intersects(brief.get_global_rect()),"Hard formation briefing remains reachable at every supported size")
   assert(brief.get_line_count()<=brief.get_visible_line_count())
  app.game.start_battle();app.make_map();app.show_battle();var medic=app.game.living("enemy")[-1];var patient=app.game.living("enemy")[0]
  assert(medic.job=="Warden" and app.unit_nodes[medic.id].visual_id=="enemy.warden")
  var actor=app.make_fighter(medic,Vector3(35,0,0));assert(actor is Imported and actor.kind=="staff" and actor.model.get_meta("enemy_appearance")=="Warden","Natural campaign support uses the existing revised enemy staff body")
  actor.queue_free();await process_frame
  for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
   app.selected=medic;app.update_side();await process_frame;await process_frame
   var bounds=app.side.get_parent().get_global_rect()
   if not Rect2(Vector2.ZERO,dimensions).encloses(bounds):print("Support sidebar ",bounds," at ",dimensions)
   assert(Rect2(Vector2.ZERO,dimensions).encloses(bounds))
   var labels=app.side.find_children("*","Label",true,false)
   assert(labels.any(func(label):return label.text=="HEAL %d"%app.game.healing_power(medic)))
   assert(labels.any(func(label):return "cannot attack" in label.text),"Inspection explains enemy staff support instead of claiming attack reach")
   for child in app.side.get_children():assert(bounds.grow(1).encloses(child.get_global_rect()))
  app.selected=null;app.target=null;app.preferences.values.combat="all" if chapter==11 else "map"
  patient.hp=1;app.game.begin_enemy_phase()
  for enemy in app.game.living("enemy"):enemy.acted=enemy!=medic
  app.show_battle();assert(app.persist_campaign("battle"));var rng=app.game.rng.state
  app.end_turn(true)
  assert(app.busy and medic.acted and patient.hp>1,"Actual support turn resolves before presentation")
  var saved=Rules.new();assert(saved.load_game(app.save_path)=="battle");saved.next_player_turn()
  var saw_staff=false
  while app.busy:
   await process_frame
   for node in app.stage.get_children():
    if node is Imported and node.kind=="staff":saw_staff=true
  assert(app.game.rng.state==rng and canonical(app.game.save_data("battle"))==canonical(saved.save_data("battle")),"Campaign healer presentation preserves the written checkpoint and resumed result")
  if chapter==11:assert(saw_staff,"Finale support plays the actual revised staff encounter")
  app.game.trials.flags.hard_campaign=false;app.show_camp();await process_frame
  assert(app.ui.find_child("HardFormationBrief",true,false)==null)
 await Shutdown.dispose(app);await process_frame
