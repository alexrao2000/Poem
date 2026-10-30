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
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: phase ribbon layouts, deployment/turn ordering, input locks, skip isolation and cleanup")
 quit()
