extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Rules=preload("res://scripts/rules.gd")
const Commanders=preload("res://scripts/commanders.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var seen=[]
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-enemy-campaign.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";var rules=Rules.new();var count=0;var bosses=0;var fallbacks=0;var all_classes=[]
 for chapter in range(12):
  rules.chapter=chapter;rules.start_battle();var saved=rules.save_data("battle").duplicate(true);var rng=rules.rng.state
  for enemy in rules.living("enemy"):
   var actor=app.make_fighter(enemy,Vector3.ZERO)
   if enemy.get("boss",false):assert(actor is Actor and actor.get_meta("commander")==Commanders.profile(enemy).id);bosses+=1
   elif enemy.item not in app.revised_enemies.models.catalog.enemy_classes[enemy.job].supported_items:
    assert(actor is Actor and enemy.item=="estoc","Unsupported thrust swords retain their fitted original presentation");fallbacks+=1
   else:
    assert(actor is Imported and actor.model.get_meta("enemy_appearance")==enemy.job,"Every authored campaign loadout selects its revised anonymous class")
    if enemy.job not in all_classes:all_classes.append(enemy.job)
    count+=1
   actor.queue_free();await process_frame
  assert(rules.save_data("battle")==saved and rules.rng.state==rng)
 assert(bosses==12 and fallbacks==3 and all_classes.size()==7)
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(func(node):
  if node is Imported:seen.append(node.model.get_meta("enemy_appearance",node.model.get_meta("character_identity",""))))
 var before=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 var ally=app.game.roster[0].duplicate(true);ally.team="player";ally.x=8;ally.y=4
 for spec in studies.values():
  if not spec.has("study_enemy_class"):continue
  var enemy=app.game.roster.filter(func(unit):return unit.id==spec.study_character)[0].duplicate(true);enemy.id="campaign_enemy";enemy.team="enemy";enemy.job=spec.study_enemy_class;enemy.item=spec.supported_items[0];enemy.x=9;enemy.y=4
  var target=ally.duplicate(true);var event={"actor":enemy.id,"target":target.id,"damage":3,"remaining":target.hp-3,"hit":true,"crit":true}
  if enemy.weapon=="staff":target.id="patient";target.team="enemy";event={"actor":enemy.id,"target":target.id,"healing":3}
  var start=seen.size()
  await app.cinematic(enemy,target,[event],{enemy.id:enemy.hp,target.id:target.hp-3 if enemy.weapon=="staff" else target.hp})
  assert(seen.slice(start)==[enemy.job,"Vanguard" if enemy.weapon=="staff" else ally.id],"Normal cinematic builder selects both revised actors")
  assert(app.game.save_data("battle")==before and app.game.rng.state==rng and app.world.visible and app.pieces.visible and not app.stage.visible)
 app.busy=false;await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," revised anonymous campaign enemy loadouts across twelve chapters, three original estoc fallbacks, twelve original commanders, eight real mixed revised enemy exchanges including critical/healing, normal map restoration and exact campaign/RNG isolation")
 quit()
