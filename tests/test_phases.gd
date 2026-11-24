extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Banner=preload("res://scripts/phase_banner.gd")
var observed: Array=[]
var app
var actual_resizes=0

func _initialize():call_deferred("run")

func watch(node):
 if node.name!="PhaseBanner":return
 observed.append(app.game.phase)
 await process_frame
 for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
  root.size=dimensions;app.ui.size=Vector2(dimensions);await process_frame
  assert(is_equal_approx(node.size.x,app.ui.size.x),"Actual phase ribbon follows window resizing")
  actual_resizes+=1

func animate(banner,done):
 await banner.play(func():return false);done[0]=true

class QuietTactics extends "res://scripts/tactics.gd":
 func plan(game,unit):return {"position":game.pos(unit),"target":"","action":"wait"}

func verify_terrain_recovery():
 root.size=Vector2i(1440,900)
 app.game.new_campaign();app.game.action_saves=true;app.game.start_battle()
 var first=app.game.living("player")[0];var second=app.game.living("player")[1]
 var foe=app.game.living("enemy")[0]
 first.x=3;first.y=3;first.hp=10
 second.x=10;second.y=7;second.hp=second.max_hp-2
 foe.x=12;foe.y=8
 app.game.units=[first,second,foe];app.tactics=QuietTactics.new()
 app.make_map();app.show_battle();await process_frame
 var rng=app.game.rng.state
 app.end_turn()
 var labels=[]
 var deadline=Time.get_ticks_msec()+10000
 while labels.size()<2 and Time.get_ticks_msec()<deadline and app.busy:
  await process_frame
  labels=app.ui.find_children("TerrainRecoveryCue*","Label",false,false)
 assert(labels.size()==2 and app.busy and app.game.phase=="player" and app.game.turn==2)
 var saved=load("res://scripts/rules.gd").new()
 assert(saved.load_game(app.save_path)=="battle" and saved.turn==2 and saved.phase=="player")
 assert(saved.rng.state==rng and saved.living("player")[0].hp==16 and saved.living("player")[1].hp==second.max_hp)
 var texts={}
 for label in labels:
  texts[label.get_meta("unit_id")]=label.text
  assert(app.map_navigation.safe_rect().encloses(label.get_global_rect()))
 assert(texts=={first.id:"+6",second.id:"+2"},"The committed, capped gains are the figures shown in the map")
 var camera=app.camera.transform
 var skip=InputEventKey.new();skip.pressed=true;skip.keycode=KEY_TAB;app._input(skip)
 while app.busy:await process_frame
 await process_frame
 assert(app.ui.find_children("TerrainRecoveryCue*","Label",false,false).is_empty())
 assert(app.pieces.find_children("MapHeal*","Node3D",false,false).is_empty())
 assert(app.camera.transform==camera and app.game.rng.state==rng,"Skipping passive recovery restores control without moving the camera or using RNG")
 print("PASS: simultaneous committed sanctuary gains, capped amounts, visible map cues, Skip and cleanup")

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
   for next_size in [Vector2(1440,900),Vector2(1024,640),Vector2(1280,720)]:
    host.size=next_size;await process_frame
    assert(is_equal_approx(banner.size.x,host.size.x) and is_equal_approx(banner.position.y,host.size.y*.42-72),"Existing ribbon reflows after both shrinking and growing")
    for label in [banner.heading,banner.detail]:assert(Rect2(Vector2.ZERO,banner.size).encloses(label.get_rect()),"Resized phase labels remain inside the ribbon")
   await banner.play(func():return true)
   assert(not banner.visible and not banner.motion.is_running(),"Skip stops and hides the ribbon")
   host.remove_child(banner);var retired_size=banner.size;host.size+=Vector2(1,1)
   assert(banner.size==retired_size,"A removed ribbon ignores a same-frame host resize")
   banner.queue_free();await process_frame
 var resized_phases=0
 for side in ["player","enemy"]:
  host.size=Vector2(1280,720);var banner=Banner.new();banner.configure(host,side,99)
  var done=[false];var seen=[false,false,false];var previous=1.0;var direction=1 if side=="enemy" else -1
  animate(banner,done);var active=banner.motion
  while not done[0]:
   await process_frame
   var elapsed=active.get_total_elapsed_time();var phase=0 if elapsed<.14 else 1 if elapsed<.5 else 2
   if not seen[phase] and banner.visible:
    seen[phase]=true;resized_phases+=1
    var offset=banner.slide_offset;host.size=[Vector2(1440,900),Vector2(1024,640),Vector2(1280,720)][phase]
    assert(banner.motion==active and banner.slide_offset==offset,"Resize preserves the existing phase animation and exact progress")
   assert(is_equal_approx(banner.position.x,banner.slide_offset*host.size.x))
   var current=banner.slide_offset*direction;assert(current<=previous+.001,"Resized entrance and exit keep their direction");previous=current
  assert(seen.all(func(value):return value) and not banner.visible and not active.is_running())
  banner.queue_free();await process_frame
 assert(resized_phases==6)
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
 assert(actual_resizes==8,"Live enemy/player ribbons and both terminal enemy phases reflow during their actual turn sequence")
 await verify_terrain_recovery()
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: phase ribbon layouts, 18 live size changes, six entrance/hold/exit resizes, eight actual turn resizes, deployment/terminal turn ordering, input locks, skip isolation and cleanup")
 quit()
