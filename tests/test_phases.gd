extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Banner=preload("res://scripts/phase_banner.gd")
var observed: Array=[]
var app

func _initialize():call_deferred("run")

func watch(node):
 if node.name=="PhaseBanner":observed.append(app.game.phase)

func run():
 var host=Control.new();root.add_child(host)
 for viewport_size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=viewport_size
  for side in ["player","enemy"]:
   var banner=Banner.new();banner.configure(host,side,99)
   await process_frame
   assert(banner.get_rect().end.y<=host.size.y,"Phase ribbon stays inside the viewport")
   for label in [banner.heading,banner.detail]:
    assert(label.position.x>=0 and label.get_rect().end.x<=banner.size.x and label.get_rect().end.y<=banner.size.y,"Phase text fits the ribbon")
   assert(banner.heading.text==(side.to_upper()+" PHASE") and banner.detail.text=="TURN 99")
   await banner.play(func():return true)
   assert(not banner.visible and not banner.motion.is_running(),"Skip stops and hides the ribbon")
   banner.queue_free();await process_frame
 host.queue_free()
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-phases.json";root.add_child(app);await process_frame
 app.deploy_company();await process_frame
 assert(app.busy and app.chapter_card_active and not app.phase_banner_active and app.game.turn==1,"Deployment starts with its locked chapter card")
 var before=app.cursor_tile;app.move_map_cursor(Vector2i.RIGHT);assert(app.cursor_tile==before,"Ribbon prevents tactical input")
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_TAB;app.skip_combat=false;app._input(key)
 while app.chapter_card_active:await process_frame
 assert(app.phase_banner_active and not app.phase_skip and not app.skip_combat,"Chapter skip does not carry into the player phase or combat")
 app._input(key)
 while app.busy:await process_frame
 assert(not app.phase_banner_active and not app.skip_combat,"Skipping the ribbon does not skip the next combat")
 var ally=app.game.living("player")[0];var enemy=app.game.living("enemy")[0]
 ally.x=0;ally.y=0;enemy.x=13;enemy.y=9;enemy.ai="guard"
 app.game.units=[ally,enemy];app.refresh_pieces();app.preferences.values.combat="map"
 app.ui.child_entered_tree.connect(watch)
 var turn=app.game.turn;app.end_turn();await process_frame
 assert(app.busy and app.game.phase=="enemy","Enemy ribbon begins after the phase changes")
 while app.busy:await process_frame
 assert(app.game.phase=="player" and app.game.turn==turn+1,"Turn changes exactly once")
 assert(observed==["enemy","player"],"Both phase ribbons follow the actual turn state")
 assert(app.ui.get_node_or_null("PhaseBanner")==null,"Phase overlays release their nodes")
 for outcome in ["defeat","victory"]:
  app.game.new_campaign(true);app.game.action_saves=true;app.game.start_battle()
  ally=app.game.units[0];enemy=app.game.living("enemy")[0]
  ally.x=8;ally.y=4;enemy.x=9;enemy.y=4;enemy.ai="guard"
  if outcome=="defeat":
   ally.hp=1;ally.defense=0;ally.speed=0;enemy.pow=255;enemy.speed=255
  else:
   ally.hp=255;ally.max_hp=255;ally.pow=255;ally.speed=255;ally.defense=255;enemy.hp=1
  app.game.units=[ally,enemy];app.make_map();app.show_battle();observed.clear();app.ui.child_entered_tree.connect(watch)
  await app.end_turn()
  assert(app.game.result()==outcome and app.screen=="result" and not app.busy)
  assert(app.game.turn==1 and app.game.phase=="enemy" and observed==["enemy"],"A decisive enemy exchange ends before a phantom player phase")
  var state=app.game.rng.state;var health=app.game.units.map(func(unit):return unit.hp)
  var saved=load("res://scripts/rules.gd").new();assert(saved.load_game(app.save_path)=="battle","Terminal fixture produces a valid checkpoint")
  app.game.turn=99
  await app.load_campaign()
  assert(app.screen=="result" and app.game.turn==1 and app.game.phase=="enemy" and app.game.rng.state==state,"Terminal checkpoint resumes exactly without rerolling or advancing turns")
  for index in range(health.size()):assert(app.game.units[index].hp==health[index],"Reload cannot add terrain healing after the terminal action")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: phase ribbon layouts, deployment/turn ordering, input locks, skip isolation and cleanup")
 quit()
