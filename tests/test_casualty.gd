extends SceneTree
const Card=preload("res://scripts/casualty_card.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var cards=0

func _initialize():call_deferred("run")
func watch(node):
 if node.name=="CasualtyCard":cards+=1

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-casualty-test.json";root.add_child(app);await process_frame
 var rules=Rules.new();var host=Control.new();host.theme=app.ui.theme;root.add_child(host)
 assert(Card.lines.size()==24)
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
 host.queue_free()
 for kind in ["death","retreat","downed"]:
  app.game.new_campaign(kind!="retreat");app.game.death_door=kind=="downed";app.game.start_battle()
  app.preferences.values.combat="all" if kind=="retreat" else "map"
  var ally=app.game.units[1];var enemy=app.game.living("enemy")[0]
  ally.x=8;ally.y=4;ally.hp=1;ally.defense=0;ally.speed=0;enemy.x=9;enemy.y=4;enemy.pow=255;enemy.speed=255
  app.game.phase="enemy";app.make_map();app.show_battle();app.busy=true
  app.ui.child_entered_tree.connect(watch);var before_cards=cards
  var events=app.game.combat(enemy,ally);assert(ally.hp==0)
  var snapshot=app.game.save_data("battle").duplicate(true)
  await app.cinematic(enemy,ally,events,{enemy.id:enemy.hp,ally.id:1});await process_frame
  assert(cards==before_cards+1 and app.ui.get_node_or_null("CasualtyCard")==null,"A real exchange presents one casualty card and releases it")
  assert(app.game.save_data("battle")==snapshot,"Dialogue cannot alter casualties, actions or RNG")
  app.skip_combat=true;await app.present_casualties(events)
  assert(cards==before_cards+1,"Skipped exchanges cannot reintroduce casualty dialogue")
  app.busy=false
 await Shutdown.dispose(app);await process_frame
 print("PASS: 216 casualty portrait layouts, all roster outcome lines, lord/enemy fallbacks, skip cleanup and real quick/3D exchange isolation")
 quit()
