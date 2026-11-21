extends SceneTree
const Cutin=preload("res://scripts/critical_cutin.gd")
const Shutdown=preload("res://tests/helpers/game_shutdown.gd")
var watched_app
var actual_resizes=0
func _initialize():call_deferred("run")
func resize_actual(node):
 if not node is Cutin:return
 await process_frame
 for dimensions in [Vector2i(1024,640),Vector2i(1440,900)]:
  root.size=dimensions;watched_app.ui.size=Vector2(dimensions)
  await process_frame;check_layout(node,watched_app.ui);actual_resizes+=1
  await create_timer(.10).timeout
func check_layout(cutin,host):
 assert(is_equal_approx(cutin.size.x,host.size.x) and cutin.streaks.size.is_equal_approx(cutin.size),"Portrait strip and streaks follow viewport: strip %s streaks %s host %s"%[cutin.size,cutin.streaks.size,host.size])
 assert(is_equal_approx(cutin.position.x,cutin.slide_offset*host.size.x),"Travel keeps its normalized position after resizing")
 assert(cutin.position.y+cutin.size.y<host.size.y-140,"Portrait strip stays above the combat HP area")
 for child in cutin.get_children():assert(Rect2(Vector2.ZERO,cutin.size).grow(.01).encloses(child.get_rect()),"Resized portrait and labels stay inside the strip")
 var line=cutin.get_node("Quote")
 assert(line.get_visible_line_count()==line.get_line_count() and line.get_line_count()<=2,"Complete call remains readable after resizing")
 var face=cutin.get_node_or_null("Portrait")
 if face!=null:
  assert(face.material.get_shader_parameter("panel_size")==face.size,"Portrait mask follows the new dimensions")
  assert(not face.get_rect().intersects(line.get_rect()),"Portrait and quote remain separate")
func animate(cutin,enemy,stop,done):
 await cutin.play(func():return stop[0],enemy);done[0]=true
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-cutin-resize.json";root.add_child(app);await process_frame
 var saved=app.game.save_data("camp").duplicate(true);var rng=app.game.rng.state
 var host=Control.new();root.add_child(host);host.theme=app.ui.theme
 var units=[]
 for recruit in app.game.roster:
  var unit=recruit.duplicate(true);unit.team="player";units.append(unit)
 for job in app.Portraits.ENEMY_CLASSES:units.append({"id":"enemy_"+job,"job":job,"name":job,"team":"enemy"})
 var count=0
 for unit in units:
  host.size=Vector2(1440,900)
  var quote=app.fighters.profiles.get(unit.id,{}).get("critical_quote","Stand aside!")
  var cutin=Cutin.new();cutin.configure(host,unit,app.portraits.get_critical_portrait(unit),quote)
  for size_value in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
   host.size=size_value;await process_frame;await process_frame;check_layout(cutin,host);count+=1
  cutin.queue_free();await process_frame
 var phases=0
 for enemy in [false,true]:
  for skip in [false,true]:
   host.size=Vector2(1280,720)
   var unit=units[-1] if enemy else units[0]
   var cutin=Cutin.new();cutin.configure(host,unit,null if skip else app.portraits.get_critical_portrait(unit),"Stand aside!" if enemy else "For everyone behind me!")
   var stop=[false];var done=[false];var seen=[false,false,false];var previous=1.0;var direction=1 if enemy else -1
   animate(cutin,enemy,stop,done);var motion=cutin.slide
   while not done[0]:
    await process_frame
    var phase=0 if cutin.streaks.phase<.15 else 1 if cutin.streaks.phase<.70 else 2
    if not seen[phase] and cutin.visible:
     seen[phase]=true;phases+=1
     var before=cutin.slide_offset;host.size=[Vector2(1440,900),Vector2(1024,640),Vector2(1280,720)][phase]
     assert(cutin.slide==motion and cutin.slide_offset==before,"Resize preserves the active tween and its exact progress")
     if skip and phase==1:stop[0]=true
    check_layout(cutin,host)
    var current=cutin.slide_offset*direction
    assert(current<=previous+.001,"Resizing cannot reverse entrance or exit travel");previous=current
   assert(not cutin.visible and not motion.is_running())
   assert(seen[0] and seen[1] and (skip or seen[2]),"Actual playback covers entrance, readable hold and exit, or cancellation during hold")
   cutin.queue_free();await process_frame
 assert(app.game.save_data("camp")==saved and app.game.rng.state==rng and not FileAccess.file_exists(app.save_path))
 host.queue_free();await process_frame
 watched_app=app;app.preferences.values.combat="all";app.game.start_battle();app.make_map();app.show_battle()
 app.ui.child_entered_tree.connect(resize_actual)
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var initial_hp={a.id:a.hp,b.id:b.hp};b.hp-=1
 var event={"actor":a.id,"target":b.id,"hit":true,"crit":true,"damage":1,"remaining":b.hp}
 var battle=app.game.save_data("battle").duplicate(true);var before=app.map_navigation.capture_view()
 await app.cinematic(a,b,[event],initial_hp);await process_frame
 assert(actual_resizes==2 and app.ui.get_node_or_null("CriticalCutin")==null)
 assert(app.world.visible and not app.stage.visible and app.map_navigation.capture_view()==before,"Actual resized critical combat restores its tactical view and removes the accent")
 assert(app.game.save_data("battle")==battle and app.game.rng.state==rng,"Actual resize leaves resolved combat and RNG untouched")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," live roster/enemy portrait resizes, ",phases," resized animation phases, both travel directions, text-only fallback, mask/quote/HP bounds, hold cancellation, two actual cinematic resizes, exact map restoration and unchanged campaign/RNG")
 quit()
