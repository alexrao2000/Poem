extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Source=preload("res://scripts/debug_source_models.gd")
const Enemies=preload("res://scripts/revised_enemy_models.gd")
func _initialize():call_deferred("run")
func builders(app) -> Array:
 return [app.debug_vanguard,app.debug_duelists,app.debug_caster,app.debug_warden,app.debug_corsair,app.debug_ranger,app.debug_knight,app.debug_rider,app.revised_enemies]
func clear_caches(app):
 for builder in builders(app):builder.models.scene_cache.clear()
func cache_count(app) -> int:
 var count=0
 for builder in builders(app):count+=builder.models.scene_cache.size()
 return count
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-prefetch-test-unused.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle()
 assert(cache_count(app)==8,"A fresh profile prepares the opening chapter’s revised models")
 clear_caches(app);app.preferences.values.character_models="current";app.show_battle()
 assert(cache_count(app)==0,"Original models do not load revised source scenes")
 app.preferences.values.character_models="revised";app.preferences.values.combat="map";app.show_battle()
 assert(cache_count(app)==0,"Map-only battles do not reserve cinematic resources")
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var stage_children=app.stage.get_children()
 app.preferences.values.combat="all";app.show_battle()
 assert(cache_count(app)==8,"Opening chapter prepares four company rigs and four enemy families")
 assert(app.debug_vanguard.models.scene_cache.size()==1 and app.debug_knight.models.scene_cache.size()==1 and app.debug_ranger.models.scene_cache.size()==1 and app.debug_warden.models.scene_cache.size()==1)
 assert(app.revised_enemies.models.scene_cache.size()==4 and app.debug_caster.models.scene_cache.is_empty() and app.debug_corsair.models.scene_cache.is_empty() and app.debug_rider.models.scene_cache.is_empty() and app.debug_duelists.models.scene_cache.is_empty(),"Undeployed recruits and unused classes stay unloaded")
 assert(app.stage.get_children()==stage_children,"Preparing resources never constructs actors or changes the arena")
 var caches=builders(app).map(func(builder):return builder.models.scene_cache.duplicate())
 app.show_battle()
 for index in builders(app).size():assert(builders(app)[index].models.scene_cache==caches[index],"Returning from a menu reuses the same resources")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Loading source scenes never changes simulation or random state")
 # A restored battle uses the same setup path without chapter-announcement timing.
 clear_caches(app);assert(app.game.restore_save(saved)=="battle")
 saved=app.game.save_data("battle").duplicate(true)
 app.make_map();app.show_battle()
 assert(cache_count(app)==8 and app.game.save_data("battle")==saved and app.game.rng.state==rng)
 # Debug's independent comparisons take precedence over the campaign preference.
 clear_caches(app);app.debug_session.begin(app.game,"battle",false);app.debug_session.set_revised_knight(true)
 app.show_battle();assert(cache_count(app)==1 and app.debug_knight.models.scene_cache.size()==1)
 assert(app.debug_session.end(app.game)=="battle" and app.game.save_data("battle")==saved)
 # Unknown identities, mismatched classes, equipment and promotions remain fallbacks.
 var source=Source.new(["vanguard"]);var lyra=app.game.units[0].duplicate(true)
 for change in [{"id":"unknown"},{"job":"Rider"},{"weapon":"axe"},{"promotion":"unknown"},{"item":"unknown"},{"team":"enemy"}]:
  var invalid=lyra.duplicate(true);invalid.merge(change,true);source.prefetch(invalid)
 assert(source.models.scene_cache.is_empty())
 var enemies=Enemies.new();var enemy=app.game.living("enemy")[0].duplicate(true)
 for change in [{"team":"player"},{"promotion":"unknown"},{"boss":true,"name":"Unknown commander"},{"weapon":"staff"},{"item":"unknown"}]:
  var invalid=enemy.duplicate(true);invalid.merge(change,true);enemies.prefetch(invalid)
 assert(enemies.models.scene_cache.is_empty())
 # Actual deployment has resources ready before the first announcement frame.
 clear_caches(app);app.game.story_seen=["opening_0"];var announced=[false]
 var observer=func():
  if app.chapter_card_active or app.phase_banner_active:
   announced[0]=true;assert(cache_count(app)==8,"Loading finishes before animated battle announcements")
 process_frame.connect(observer);await app.deploy_company();process_frame.disconnect(observer)
 assert(announced[0] and not app.busy and app.screen=="battle")
 await Shutdown.dispose(app);await process_frame
 print("PASS: chapter-scoped source loading before announcements, restored battles/menu reuse, original/map-only exclusions, independent debug selection, unsupported fallbacks and unchanged campaign/RNG/arena")
 quit()
