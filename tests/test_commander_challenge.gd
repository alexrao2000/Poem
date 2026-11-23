extends SceneTree
const Commanders=preload("res://scripts/commanders.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")

func _initialize():call_deferred("run")

func wait_for_caption(app) -> Control:
 for frame in range(240):
  var caption=app.ui.get_node_or_null("CommanderChallenge")
  if caption!=null:return caption
  await process_frame
 assert(false,"The real commander's first committed action opens its caption")
 return null

func prepare(app,enemy_turn: bool) -> Array:
 app.game.new_campaign(true)
 app.game.action_saves=true
 app.game.start_battle()
 var ally=app.game.living("player")[0]
 var boss=app.game.living("enemy")[0]
 ally.x=10;ally.y=4;ally.pow=2;ally.defense=20
 boss.x=11;boss.y=4;boss.pow=2;boss.defense=20
 app.game.units=[ally,boss]
 if enemy_turn:app.game.begin_enemy_phase()
 app.make_map();app.show_battle()
 return [ally,boss]

func verify_commit(app,normal_disk: String,enemy_turn: bool):
 var destination=app.save_path+(".debug" if app.debug_session.active else "")
 var paused=Rules.new()
 assert(paused.load_game(destination)=="battle")
 assert(paused.story_seen.count("challenge_voss")==1 and app.game.story_seen==paused.story_seen)
 assert(paused.phase==("enemy" if enemy_turn else "player") and paused.units[1 if enemy_turn else 0].acted,"The line and resolved action are both durable before the pause")
 assert(paused.rng.state==app.game.rng.state)
 if app.debug_session.active:assert(FileAccess.get_file_as_string(app.save_path)==normal_disk)

func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 root.add_child(viewport)
 var app=load("res://main.tscn").instantiate()
 app.settings_path="";app.save_path="/private/tmp/poem-commander-challenge-%d.json"%Time.get_ticks_usec()
 viewport.add_child(app);await process_frame
 var rules=Rules.new()
 var utterances=[]
 for chapter in rules.content.chapters.size():
  rules.chapter=chapter;rules.start_battle()
  var boss=rules.living("enemy")[0]
  var record=Commanders.profile(boss)
  var opponents=record.challenge.opponents
  var named={"team":"player","id":opponents.keys()[0]}
  var other={"team":"player","id":"oren"}
  var seen=[]
  var personalized=Commanders.take_challenge(named,boss,rules.info().boss,seen)
  assert(personalized.line==opponents[named.id] and personalized.unit==boss)
  assert(Commanders.take_challenge(boss,named,rules.info().boss,seen).is_empty() and seen==["challenge_"+record.id])
  var ordinary=Commanders.take_challenge(boss,other,rules.info().boss,[])
  assert(ordinary.line==record.challenge.default and ordinary.line!=personalized.line)
  utterances.append_array([personalized,ordinary])
  var decoy=boss.duplicate();decoy.boss=false
  assert(Commanders.take_challenge(named,decoy,rules.info().boss,[]).is_empty())
  assert(Commanders.take_challenge(named,boss,"Different commander",[]).is_empty())
  assert(Commanders.take_challenge(boss,decoy,rules.info().boss,[]).is_empty())
 var layouts=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;await process_frame
  for utterance in utterances:
   for on_map in [false,true]:
    var caption=app.commander_caption(utterance,on_map)
    await process_frame;await process_frame
    var speech=caption.find_child("ChallengeLine",true,false)
    assert(speech.text==utterance.line and speech.get_visible_line_count()==speech.get_line_count())
    assert(caption.find_child("Speaker",true,false).text==utterance.unit.name)
    assert(caption.find_child("CommanderPortrait",true,false).texture==app.portraits.get_unit_portrait(utterance.unit))
    var safe_region=Rect2(22,110 if on_map else 22,dimensions.x-(365 if on_map else 44),140)
    assert(safe_region.encloses(caption.get_child(0).get_global_rect()),"Both modes fit the whole card without covering the tactical unit panel")
    caption.free();layouts+=1

 app.preferences.values.combat="all";app.preferences.values.auto_end=false
 var fighters=prepare(app,false)
 var normal_save=app.game.save_data("battle").duplicate(true)
 assert(app.persist_campaign("battle"))
 var normal_disk=FileAccess.get_file_as_string(app.save_path)
 assert(app.commander_challenge(fighters[0],fighters[1],[]).is_empty())
 assert(app.commander_challenge(fighters[0],fighters[1],[{"healing":1}]).is_empty())
 app.selected=fighters[0];app.target=fighters[1]
 app.player_attack()
 var caption=await wait_for_caption(app)
 assert(app.stage.visible and caption.find_child("ChallengeLine",true,false).text==Commanders.profile(fighters[1]).challenge.opponents.lyra)
 verify_commit(app,normal_disk,false)
 var tab=InputEventKey.new();tab.pressed=true;tab.keycode=KEY_TAB
 app._input(tab)
 while app.busy:await process_frame
 await process_frame
 assert(not app.ui.has_node("CommanderChallenge") and app.world.visible and not app.stage.visible)
 var resumed=Rules.new()
 assert(resumed.load_game(app.save_path)=="battle")
 assert(Commanders.take_challenge(resumed.units[0],resumed.units[1],resumed.info().boss,resumed.story_seen).is_empty(),"Loading the committed exchange keeps the line seen")

 assert(app.game.restore_save(normal_save)=="battle")
 assert(app.persist_campaign("battle"))
 normal_disk=FileAccess.get_file_as_string(app.save_path)
 app.debug_session.begin(app.game,"battle")
 fighters=prepare(app,true)
 app.preferences.values.combat="map"
 app.end_turn(true)
 caption=await wait_for_caption(app)
 assert(not app.stage.visible and app.world.visible and caption.find_child("ChallengeLine",true,false).text==Commanders.profile(fighters[1]).challenge.opponents.lyra)
 verify_commit(app,normal_disk,true)
 app._input(tab)
 while app.busy:await process_frame
 await process_frame
 assert(not app.ui.has_node("CommanderChallenge") and app.game.phase=="player")
 app.debug_session.end(app.game)
 assert(app.game.story_seen==normal_save.story_seen and FileAccess.get_file_as_string(app.save_path)==normal_disk)
 await Shutdown.dispose(app)
 viewport.queue_free();await process_frame
 print("PASS: 24 commander lines, 144 mode/viewport captions, genuine player 3D and enemy Quick battles, durable before presentation, skip/restore and Debug isolation")
 quit()
