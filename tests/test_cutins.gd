extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Cutin=preload("res://scripts/critical_cutin.gd")
var observed=0
var critical_recoils=0
var watched_app
func _initialize():call_deferred("run")
func watch(node):
 if node.name=="CriticalCutin":
  observed+=1
  var app=watched_app
  if app.stage.visible:
   var prepared=app.stage.get_children().filter(func(actor):return actor is Actor and actor.pose_name in ["critical_windup","critical_throw_windup"])
   assert(prepared.size()==1,"Portrait appears after the active fighter adopts critical preparation")
   assert(prepared[0].face_blink.focused,"Actual critical cut-in keeps the 3D fighter in its focused expression")
func watch_contact(node):
 if not node is HitStop:return
 await process_frame
 var actors=watched_app.stage.get_children().filter(func(actor):return actor is Actor and actor.pose_name=="critical_hit")
 if not actors.is_empty():
  critical_recoils+=1
  assert(actors[0].face_blink.surface==null or actors[0].face_blink.closed,"Actual critical impact holds a brief eye flinch on visible defender faces")
  var attackers=watched_app.stage.get_children().filter(func(actor):return actor is Actor and actor.pose_name in ["strike","throw"])
  assert(attackers.size()==1 and attackers[0].face_blink.focused,"Critical focus remains on the attacking face during actual contact and hit-stop")

func check_layout(cutin,host):
 assert(cutin.get_global_rect().position.x>=0 and cutin.get_global_rect().end.x<=host.size.x and cutin.get_global_rect().end.y<host.size.y-140,"Cutin stays clear of combat HP")
 for child in cutin.get_children():
  assert(Rect2(Vector2.ZERO,cutin.size).encloses(child.get_rect()),"Portrait and quote fit the banner")
 var face=cutin.get_node("Portrait");var quote=cutin.get_node("Quote")
 assert(not face.get_rect().intersects(quote.get_rect()),"Close-up face and battle call remain separate")
 assert(quote.get_visible_line_count()==quote.get_line_count() and quote.get_line_count()<=2,"Full battle call remains readable")
 assert(face.material.get_shader_parameter("panel_size")==face.size,"Edge mask follows the real portrait bounds")
 var crop=face.texture
 assert(Rect2(Vector2.ZERO,crop.atlas.get_size()).encloses(crop.region),"Close-up stays inside its own portrait, without neighboring atlas cells")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-cutin-test.json";root.add_child(app);await process_frame
 var host=Control.new();root.add_child(host);host.theme=app.ui.theme
 for width in [1024,1280,1440]:
  host.size=Vector2(width,640 if width==1024 else 720 if width==1280 else 900)
  for unit in app.game.roster:
   var actor=unit.duplicate(true);actor.team="player"
   var quote=app.fighters.profiles[unit.id].critical_quote
   assert(quote.length()>0 and quote.length()<40,"Roster has concise original battle calls")
   var cutin=Cutin.new();cutin.configure(host,actor,app.portraits.get_critical_portrait(actor),quote)
   await process_frame;await process_frame
   check_layout(cutin,host)
   assert(cutin.get_node("Portrait").texture==app.portraits.get_critical_portrait(actor),"Repeated critical portraits share their cached crop")
   cutin.queue_free();await process_frame
  for job in app.Portraits.ENEMY_CLASSES:
   var enemy={"id":"test_enemy","name":"Imperial "+job,"job":job,"team":"enemy"}
   var cutin=Cutin.new();cutin.configure(host,enemy,app.portraits.get_critical_portrait(enemy),"Stand aside!")
   await process_frame;await process_frame;check_layout(cutin,host)
   assert(cutin.get_node("Portrait").flip_h and cutin.get_node("Portrait").position.x>cutin.get_node("Quote").position.x,"Enemy portrait and lettering mirror their screen positions")
   cutin.queue_free();await process_frame
 for reverse in [false,true]:
  var actor=app.game.roster[0].duplicate(true);actor.team="enemy" if reverse else "player"
  var cutin=Cutin.new();cutin.configure(host,actor,app.portraits.get_critical_portrait(actor),"For everyone behind me!")
  var completed=[false];finish_motion(cutin,reverse,completed)
  assert(cutin.get_rect().position.x>=host.size.x if reverse else cutin.get_rect().end.x<=0,"Entrance starts fully outside the window")
  var previous=cutin.position.x;var saw_hold=false
  while not completed[0]:
   await process_frame
   assert(cutin.position.x<=previous+.01 if reverse else cutin.position.x>=previous-.01,"Cut-in crosses the screen in one continuous direction")
   if is_zero_approx(cutin.position.x) and cutin.streaks.phase>.2:saw_hold=true
   previous=cutin.position.x
  assert(saw_hold and not cutin.visible,"Moving streaks continue while the readable portrait holds, then the strip exits")
  cutin.queue_free();await process_frame
 watched_app=app
 app.game.start_battle();app.make_map();app.show_battle();app.ui.child_entered_tree.connect(watch);app.stage.child_entered_tree.connect(watch_contact)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var events=app.game.combat(a,b);events[0].crit=true;events[0].hit=true;events[0].damage=maxi(1,events[0].damage)
 var rng=app.game.rng.state;var hp=b.hp
 await app.cinematic(a,b,events);await process_frame
 assert(observed>=1 and critical_recoils>=1 and app.ui.get_node_or_null("CriticalCutin")==null,"Critical animation inserts and removes portrait accent")
 assert(app.game.rng.state==rng and b.hp==hp,"Cutin never changes resolved combat")
 assert(app.world.visible and not app.stage.visible,"Cutin preserves return to map")
 app.skip_combat=false;app.critical_cutin(a);await process_frame
 assert(app.ui.get_node_or_null("CriticalCutin")!=null)
 assert(app.sfx_players.any(func(player):return player.playing and player.stream==app.sfx_streams.cutin),"Original sound cue begins with the portrait entrance")
 app.skip_combat=true;await process_frame;await process_frame;await process_frame
 assert(app.ui.get_node_or_null("CriticalCutin")==null,"Skip cancels the banner promptly")
 var count=observed;await app.critical_cutin(a);assert(observed==count,"Already-skipped combat creates no accent")
 var enemy_banner=Cutin.new();enemy_banner.configure(host,b,null,"Stand aside!")
 assert(enemy_banner.get_node_or_null("Portrait")==null,"Missing artwork retains a text-only accent")
 await enemy_banner.play(func():return true,true);assert(not enemy_banner.visible)
 enemy_banner.queue_free()
 for job in app.Portraits.ENEMY_CLASSES:
  var enemy=b.duplicate();enemy.job=job
  var banner=Cutin.new();banner.configure(host,enemy,app.portraits.get_critical_portrait(enemy),"Stand aside!")
  assert(banner.get_node("Portrait").flip_h,"Every enemy class has an inward-facing critical portrait")
  banner.queue_free()
 host.queue_free()
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: 32 focused critical portraits at three sizes, directional entrance/exit, moving streaks, sound cue, skip cleanup and unchanged outcomes")
 quit()

func finish_motion(cutin,reverse,completed):
 await cutin.play(func():return false,reverse)
 completed[0]=true
