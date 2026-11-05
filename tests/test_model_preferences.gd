extends SceneTree
const Preferences=preload("res://scripts/preferences.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var seen=[]
var enemy_seen=[]
func _initialize():call_deferred("run")
func run():
 var prefs=Preferences.new();assert(prefs.values.character_models=="current")
 var path="/private/tmp/poem-model-preferences.json";var old=prefs.values.duplicate();old.erase("character_models")
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(old));file.close()
 assert(prefs.load_file(path) and prefs.values.character_models=="current","Older preference files migrate without changing their presentation")
 for value in [null,true,"unknown",1]:
  var invalid=prefs.values.duplicate();invalid.character_models=value;assert(not prefs.valid(invalid))
 prefs.values.character_models="revised";assert(prefs.save_file(path));var loaded=Preferences.new();assert(loaded.load_file(path) and loaded.values.character_models=="revised")
 root.size=Vector2i(1024,640)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-model-preference-campaign.json";root.add_child(app);await process_frame
 app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 app.settings_path=path;app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var original=app.game.save_data("camp").duplicate(true);var disk=FileAccess.get_file_as_string(app.save_path);var catalog=app.fighters.models.catalog.duplicate(true)
 for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=size_value;app.show_options("camp");app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=size_value;await process_frame;await process_frame
  var choice=app.ui.find_child("CharacterModels",true,false);assert(choice.selected==0 and not choice.disabled)
  var scroller=app.ui.find_children("*","ScrollContainer",true,false)[0];scroller.ensure_control_visible(choice);await process_frame;await process_frame
  assert(scroller.get_global_rect().grow(.1).encloses(choice.get_global_rect()),"Character presentation option is reachable in every supported window size")
 var choice=app.ui.find_child("CharacterModels",true,false);choice.select(1);choice.item_selected.emit(1);app.close_options();await process_frame
 assert(not app.debug_session.active and loaded.load_file(path) and loaded.values.character_models=="revised")
 var before_save=JSON.parse_string(disk);disk=FileAccess.get_file_as_string(app.save_path);var after_save=JSON.parse_string(disk)
 assert(after_save.save_sequence==before_save.save_sequence+1,"Applying Options keeps the existing ordered campaign checkpoint")
 before_save.erase("save_sequence");after_save.erase("save_sequence")
 assert(app.game.save_data("camp")==original and before_save==after_save,"Applying visual preferences preserves the campaign payload")
 var units=[]
 for id in ["lyra","nell","silas","tarin","vela","yuna","noor","cassian","rhea","ivo","esme","galen","mara","dax","hale","sera","ari","faye","oren","petra","rook","bram","una","elian"]:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.item="iron_sword" if unit.weapon=="sword" else "iron_axe" if unit.weapon=="axe" else "javelin" if unit.weapon=="lance" else "scout_bow" if unit.weapon=="bow" else "field_staff" if unit.weapon=="staff" else "ember";units.append(unit)
  var actor=app.make_fighter(unit,Vector3.ZERO);assert(actor is Imported and actor.model.get_meta("character_identity")==id);actor.queue_free();await process_frame
  app.show_model_view(unit);await process_frame;assert(app.preview_actor is Imported and app.preview_actor.model.get_meta("character_identity")==id)
  app.close_model_view();await process_frame
  var promoted=unit.duplicate(true);promoted.promotion=app.game.promotions.filter(func(value):return value.base==unit.job)[0].id
  actor=app.make_fighter(promoted,Vector3.ZERO);assert(actor is Actor and actor.get_meta("promotion_look")==promoted.promotion);actor.queue_free();await process_frame
 assert(app.game.save_data("camp")==original and app.fighters.models.catalog==catalog)
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 app.stage.child_entered_tree.connect(func(node):
  if node is Imported:
   if node.model.has_meta("enemy_appearance"):enemy_seen.append(node.model.get_meta("enemy_appearance"))
   else:seen.append(node.model.get_meta("character_identity")))
 var enemy=app.game.living("enemy").filter(func(unit):return not unit.get("boss",false))[0];enemy.x=9;enemy.y=4
 var battle=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 for unit in units:
  unit.x=8 if unit.weapon in ["sword","axe"] else 7;unit.y=4
  if unit.weapon=="staff":
   var patient=enemy.duplicate(true);patient.team="player"
   await app.cinematic(unit,patient,[{"actor":unit.id,"target":patient.id,"healing":3}],{unit.id:unit.hp,patient.id:patient.hp-3})
  else:await app.cinematic(unit,enemy,[{"actor":unit.id,"target":enemy.id,"damage":3,"remaining":17,"hit":true,"crit":false}],{unit.id:unit.hp,enemy.id:20})
 assert(seen==["lyra","nell","silas","tarin","vela","yuna","noor","cassian","rhea","ivo","esme","galen","mara","dax","hale","sera","ari","faye","oren","petra","rook","bram","una","elian"] and enemy_seen.size()==21 and app.game.save_data("battle")==battle and app.game.rng.state==rng,"The ordinary campaign builder uses revised actors without rerolling or mutating battle state")
 app.busy=false;app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=true
 assert(app.debug_session.active and app.debug_session.revised_duelists and app.debug_session.revised_caster and app.debug_session.revised_vanguard and app.debug_session.revised_warden and app.debug_session.revised_corsair and app.debug_session.revised_ranger and app.debug_session.revised_knight and app.debug_session.revised_rider and app.debug_session.revised_enemies,"New debug comparisons inherit the campaign's selected appearance")
 assert(app.ui.find_child("CharacterModels",true,false).disabled)
 app.debug_session.set_revised_duelists(false)
 var plain=app.make_fighter(units[1],Vector3.ZERO);assert(plain is Actor);plain.queue_free();await process_frame
 var styled=app.make_fighter(units[3],Vector3.ZERO);assert(styled is Imported);styled.queue_free();await process_frame
 app.show_debug_report();await process_frame
 var report=JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).presentation
 assert(report.campaign_models=="revised" and not report.revised_duelists and report.revised_caster)
 app.show_options("battle");app.ui.find_child("DebugMode",true,false).button_pressed=false
 assert(not app.debug_session.active and not app.debug_session.revised_ranger and not app.debug_session.revised_knight and not app.debug_session.revised_rider and not app.debug_session.revised_enemies and app.game.save_data("battle")==battle and app.preferences.values.character_models=="revised")
 styled=app.make_fighter(units[0],Vector3.ZERO);assert(styled is Imported);styled.queue_free();await process_frame
 app.show_options("battle");app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Restore defaults")[0].pressed.emit();await process_frame
 assert(app.preferences.values.character_models=="current" and app.ui.find_child("CharacterModels",true,false).selected==0)
 plain=app.make_fighter(units[1],Vector3.ZERO);assert(plain is Actor);plain.queue_free();await process_frame
 assert(app.game.save_data("battle")==battle and FileAccess.get_file_as_string(app.save_path)==disk and app.fighters.models.catalog==catalog)
 await Shutdown.dispose(app);await process_frame
 print("PASS: old preference migration, enum validation/persistence, three-size UI, twenty-four real campaign model/preview/exchange selections, promotion fallback, inherited independent debug overrides, exact campaign/save/RNG isolation and default restoration")
 quit()
