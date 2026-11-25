extends SceneTree
const Card=preload("res://scripts/casualty_card.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var cards=0
var sequence_done=false
var observed_effects=""

func _initialize():call_deferred("run")
func watch(node):
 if node.name!="CasualtyCard":return
 cards+=1
 await process_frame
 var effects=node.get_node_or_null("Consequences")
 observed_effects=effects.text if effects!=null else ""

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-casualty-test.json";root.add_child(app);await process_frame
 var rules=Rules.new();var host=Control.new();host.theme=app.ui.theme;root.add_child(host)
 assert(Card.lines.size()==26 and Card.lines.has("maelin") and Card.lines.has("tovin"))
 for legacy in rules.content.legacy_recruits:rules.enlist_legacy_recruit(legacy.unit)
 var layouts=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  for recruit in rules.roster:
   var unit=recruit.duplicate(true);unit.team="player";unit.hp=0
   for kind in ["downed","retreat","death"]:
    assert(Card.lines[unit.id].has(kind) and Card.lines[unit.id][kind].length()>=15)
    rules.permadeath=kind=="death";unit.downed=kind=="downed"
    var mode=Card.mode_for(rules,unit);var quote=Card.quote_for(rules,unit)
    assert(mode==("retreat" if unit.id=="lyra" and kind=="death" else kind),"The lord never receives a permanent-death caption")
    var card=Card.new();card.configure(host,unit,app.portraits.get_portrait(unit.id),mode,quote)
    await process_frame;await process_frame
    var bounds=card.get_global_rect()
    assert(Rect2(Vector2.ZERO,dimensions).encloses(bounds) and bounds.end.x<dimensions.x-343 and bounds.end.y<=dimensions.y-82,"Card stays clear of the tactical sidebar and controls")
    for label in card.find_children("*","Label",true,false):
     assert(bounds.encloses(label.get_global_rect()),"All casualty text stays inside its panel")
     assert(label.get_line_count()<=label.get_visible_line_count(),"Every full line fits without clipping")
    assert(card.find_child("Portrait",true,false).texture!=null)
    if layouts==0:
     await card.play(func():return true)
     assert(not card.visible and not card.motion.is_running(),"Tab cancellation releases the held card")
    card.queue_free();layouts+=1
   unit.team="enemy";assert(Card.quote_for(rules,unit).is_empty(),"Enemy IDs cannot borrow recruit lines")
 assert(Card.quote_for(rules,{"team":"player","id":"unknown"}).is_empty(),"Unknown recruits skip unavailable dialogue")
 for dimensions in [Vector2(720,480),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  var unit=rules.roster[1]
  var card=Card.new()
  card.configure(host,unit,app.portraits.get_portrait(unit.id),"death",Card.lines[unit.id].death,
   {"legacy_credit":true,"volunteer":"Faye","replacement":"Maelin","opening":true})
  await process_frame;await process_frame
  assert(Rect2(Vector2.ZERO,dimensions).encloses(card.get_global_rect()))
  assert(card.consequences.get_line_count()<=card.consequences.get_visible_line_count())
  assert(card.consequences.get_global_rect().end.y<card.prompt.global_position.y)
  assert(card.get_global_rect().encloses(card.prompt.get_global_rect()))
  card.queue_free()
 host.queue_free()
 var vigil=app.sfx_streams["legacy-vigil"]
 assert(vigil is AudioStreamWAV and vigil.mix_rate==22050 and is_equal_approx(vigil.get_length(),1.52) and vigil.loop_mode==AudioStreamWAV.LOOP_DISABLED)
 for kind in ["death","warden","ranger","retreat","downed"]:
  for player in app.sfx_players:player.stop();player.stream=null
  app.game.new_campaign(kind!="retreat");app.game.death_door=kind=="downed"
  app.game.trials.flags.death_legacies=true;app.game.trials.flags.sacrifice_cost=kind in ["retreat","downed"]
  app.game.start_battle()
  app.preferences.values.combat="all" if kind=="retreat" else "map"
  var ally=app.game.units[{"warden":3,"ranger":2}.get(kind,1)];var enemy=app.game.living("enemy")[0]
  ally.x=8;ally.y=4;ally.hp=1;ally.defense=0;ally.speed=0;enemy.x=9;enemy.y=4;enemy.pow=255;enemy.speed=255
  app.game.phase="enemy";app.make_map();app.show_battle();app.busy=true
  app.ui.child_entered_tree.connect(watch);var before_cards=cards
  var events=app.game.combat(enemy,ally);assert(ally.hp==0)
  var actual=events[0].get("casualty_effects",{})
  if kind=="death":assert(actual=={"legacy_credit":true,"volunteer":"Faye"})
  elif kind=="warden":assert(actual=={"legacy_credit":true,"volunteer":"Faye","replacement":"Maelin"})
  elif kind=="ranger":assert(actual=={"legacy_credit":true,"volunteer":"Faye","replacement":"Tovin"})
  elif kind=="retreat":assert(actual=={"opening":true,"recovering":true})
  else:assert(actual.is_empty(),"A rescuable unit has not earned a loss reward")
  var snapshot=app.game.save_data("battle").duplicate(true)
  await app.cinematic(enemy,ally,events,{enemy.id:enemy.hp,ally.id:1});await process_frame
  assert(cards==before_cards+1 and app.ui.get_node_or_null("CasualtyCard")==null,"A real exchange presents one casualty card and releases it")
  assert(observed_effects=={"death":"Legacy credit +1 · Faye joins early","warden":"Legacy credit +1 · Faye joins early · Maelin joins","ranger":"Legacy credit +1 · Faye joins early · Tovin joins","retreat":"Allies gain +2 attack · Recovery on redeployment","downed":""}[kind])
  assert(app.game.save_data("battle")==snapshot,"Dialogue cannot alter casualties, actions or RNG")
  var cue_players=app.sfx_players.filter(func(player):return player.stream==vigil)
  assert(cue_players.size()==(1 if kind in ["death","warden","ranger"] else 0),"Only a committed loss calls the vigil cue")
  for player in app.sfx_players:player.stop();player.stream=null
  app.skip_combat=true;await app.present_casualties(events)
  assert(cards==before_cards+1,"Skipped exchanges cannot reintroduce casualty dialogue")
  assert(app.sfx_players.all(func(player):return player.stream!=vigil),"Skipped casualty dialogue never starts the cue")
  app.busy=false
 await verify_keyboard(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: 234 casualty portrait layouts, four consequence layouts, actual legacy/volunteer/replacement/opening feedback and downed exclusion, lord/enemy fallbacks, skip cleanup, quick/3D isolation and Enter/Space continuation")
 quit()

func run_sequence(app,events):
 await app.present_casualties(events);sequence_done=true

func press(key,echo=false):
 var event=InputEventKey.new();event.keycode=key;event.pressed=true;event.echo=echo;root.push_input(event,true)
 var release=InputEventKey.new();release.keycode=key;release.pressed=false;root.push_input(release,true)

func active_card(app):
 var visible=app.ui.get_children().filter(func(node):return node is Card and node.visible and not node.is_queued_for_deletion())
 return visible[0] if not visible.is_empty() else null

func verify_keyboard(app):
 app.game.new_campaign();app.game.death_door=true;app.game.start_battle()
 var events=[]
 for unit in [app.game.units[1],app.game.units[2]]:
  unit.hp=0;app.game.DeathDoor.fall(app.game,unit);events.append({"target":unit.id,"remaining":0,"hit":true})
 app.make_map();app.show_battle();app.busy=true;app.skip_combat=false
 var snapshot=app.game.save_data("battle").duplicate(true)
 run_sequence(app,events)
 var previous_id=0
 for key in [KEY_ENTER,KEY_SPACE]:
  var card=active_card(app);var deadline=Time.get_ticks_msec()+2000
  while card==null or card.get_instance_id()==previous_id:
   assert(Time.get_ticks_msec()<deadline,"The next visible casualty line arrives without waiting for automatic dismissal")
   await process_frame;card=active_card(app)
  previous_id=card.get_instance_id()
  press(key,true);await process_frame
  assert(not card.dismissed and not sequence_done,"Held key does not skip a new casualty line")
  press(key)
  assert(card.dismissed and not app.skip_combat,"Fresh Enter/Space advances only the current casualty, preserving Tab's wider skip")
  assert(app.game.save_data("battle")==snapshot,"Continuation cannot end the phase, select a unit or alter casualties")
 while not sequence_done:await process_frame
 await process_frame
 assert(active_card(app)==null and app.game.save_data("battle")==snapshot)
 app.busy=false
