extends SceneTree
const Cutin=preload("res://scripts/critical_cutin.gd")
var observed=0
func _initialize():call_deferred("run")
func watch(node):
 if node.name=="CriticalCutin":observed+=1
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-cutin-test.json";root.add_child(app);await process_frame
 var host=Control.new();root.add_child(host);host.theme=app.ui.theme
 for width in [1280,1440]:
  host.size=Vector2(width,720 if width==1280 else 900)
  for unit in app.game.roster:
   var actor=unit.duplicate(true);actor.team="player"
   var quote=app.fighters.profiles[unit.id].critical_quote
   assert(quote.length()>0 and quote.length()<40,"Roster has concise original battle calls")
   var cutin=Cutin.new();cutin.configure(host,actor,app.portraits.get_portrait(unit.id),quote)
   await process_frame;await process_frame
   assert(cutin.get_global_rect().end.x<=host.size.x and cutin.get_global_rect().end.y<host.size.y-140,"Cutin stays clear of combat HP")
   for child in cutin.get_children():
    if child.get_rect().end.x>cutin.size.x or child.get_rect().end.y>cutin.size.y:print(unit.id," ",width," ",child.name," ",child.get_rect()," ",cutin.size)
    assert(child.position.x>=0 and child.position.y>=0 and child.get_rect().end.x<=cutin.size.x and child.get_rect().end.y<=cutin.size.y,"Portrait and quote fit the banner")
   assert(cutin.get_node("Quote").get_line_count()<=2,"Calls stay readable")
   cutin.queue_free();await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.ui.child_entered_tree.connect(watch)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var events=app.game.combat(a,b);events[0].crit=true
 var rng=app.game.rng.state;var hp=b.hp
 await app.cinematic(a,b,events);await process_frame
 assert(observed>=1 and app.ui.get_node_or_null("CriticalCutin")==null,"Critical animation inserts and removes portrait accent")
 assert(app.game.rng.state==rng and b.hp==hp,"Cutin never changes resolved combat")
 assert(app.world.visible and not app.stage.visible,"Cutin preserves return to map")
 app.skip_combat=false;app.critical_cutin(a);await process_frame
 assert(app.ui.get_node_or_null("CriticalCutin")!=null)
 app.skip_combat=true;await process_frame;await process_frame;await process_frame
 assert(app.ui.get_node_or_null("CriticalCutin")==null,"Skip cancels the banner promptly")
 var count=observed;await app.critical_cutin(a);assert(observed==count,"Already-skipped combat creates no accent")
 var enemy_banner=Cutin.new();enemy_banner.configure(host,b,null,"Stand aside!")
 assert(enemy_banner.get_node_or_null("Portrait")==null,"Missing artwork retains a text-only accent")
 await enemy_banner.play(func():return true,true);assert(not enemy_banner.visible)
 enemy_banner.queue_free()
 for job in app.Portraits.ENEMY_CLASSES:
  var enemy=b.duplicate();enemy.job=job
  var banner=Cutin.new();banner.configure(host,enemy,app.portraits.get_unit_portrait(enemy),"Stand aside!")
  assert(banner.get_node("Portrait").flip_h,"Every enemy class has an inward-facing critical portrait")
  banner.queue_free()
 host.queue_free()
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: 24 critical calls at two viewport sizes, battle integration, skip cleanup and unchanged outcomes")
 quit()
