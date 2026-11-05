extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Dust=preload("res://scripts/combat_dust.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var events=[]
var live_steps=0
var live_dust=0
func _initialize():call_deferred("run")
func watch(node):
 if node is Imported:node.travel_contact.connect(func(_index):live_steps+=1)
 if node is Dust:
  live_dust+=1
  assert(absf(node.position.y)<.001,"Authored footfall accents start at the arena floor")
func run():
 var world=Node3D.new();root.add_child(world);var rules=Rules.new();rules.start_battle()
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var samples=0;var max_slip=0.0
 for gender in ["female","male"]:
  var library=Models.new("");library.catalog={"characters":{"lyra":studies[gender]}}
  var actor=library.build(world,rules.units[0],Vector3.ZERO);assert(actor!=null and library.issues.is_empty());await process_frame
  actor.set_process(false);actor.travel_contact.connect(func(index):events.append(index))
  for scale_value in [.75,1.0,1.4]:
   actor.scale=Vector3.ONE*scale_value
   for turn in [0.0,PI*.5,PI]:
    actor.rotation.y=turn
    for steps in [12,30,60]:
     actor.position=Vector3.ZERO;actor.pose("advance",.01);events.clear()
     var direction=-actor.global_basis.z.normalized();var distance=actor.stride_length*1.5*scale_value
     for index in range(steps):
      var progress=float(index+1)/steps
      actor.position=direction*distance*(.5-.5*cos(PI*progress));actor.update_locomotion()
     assert(is_equal_approx(actor.stride_phase,.5),"Equal ground travel gives equal clip phase across frame rates, scale and heading")
     assert(events.size()==3 and actor.travel_direction.dot(direction)>.999)
     var phase=actor.stride_phase;var position=actor.player.current_animation_position
     await create_timer(.015).timeout;actor.update_locomotion()
     assert(actor.stride_phase==phase and is_equal_approx(actor.player.current_animation_position,position),"Stationary advance does not keep running in place")
     var feet=actor.ground_contact_position();assert(feet.is_finite() and feet.y==actor.global_position.y)
     actor.position-=direction*distance;actor.update_locomotion()
     assert(minf(actor.stride_phase,1-actor.stride_phase)<.0001 and events.size()==6,"Reversed travel unwinds the clip and emits the crossed contacts")
     var before=events.size();actor.position+=direction*100;actor.update_locomotion()
     assert(events.size()==before,"Teleporting rebases without a footfall burst")
     samples+=1
  actor.scale=Vector3.ONE;actor.rotation=Vector3.ZERO
  # Compare the actual source toe during its planted interval, including root
  # travel. A wall-clock jog at another approach speed would visibly slide.
  for side in [0,1]:
   var first=Vector3.ZERO;var bone=actor.stride_feet[side]
   actor.position=Vector3.ZERO;actor.pose("advance",.01)
   for step in range(13):
    var phase=.06+side*.5+step*.01
    actor.position=Vector3(0,0,-actor.stride_length*phase);actor.update_locomotion()
    var point=actor.stride_skeleton.to_global(actor.stride_skeleton.get_bone_global_pose(bone).origin)
    if step==0:first=point
    max_slip=maxf(max_slip,Vector2(point.x-first.x,point.z-first.z).length())
   assert(max_slip<.025,"Measured source stance stays within 2.5 cm over the planted interval: "+str(max_slip)+" "+gender+" "+str(side))
  actor.pose("idle",.01);var clock=actor.stride_phase;actor.advance_stride(1);assert(actor.stride_phase==clock,"Nontravel poses own their animation")
  actor.queue_free();await process_frame
 for invalid in [null,{}, {"length":0}, {"length":INF}]:
  var spec=studies.female.duplicate(true);spec.stride=invalid
  var library=Models.new("");library.catalog={"characters":{"lyra":spec}};var count=world.get_child_count()
  assert(library.build(world,rules.units[0],Vector3.ZERO)==null and library.issues.size()==1 and world.get_child_count()==count)
 for override in [{"feet":["ball_l","Missing"]},{"contacts":[.6,.1]},{"contacts":[.1,.1]},{"contacts":[.1,1.0]},{"skeleton":"Missing"}]:
  var spec=studies.female.duplicate(true);spec.stride.merge(override,true)
  var library=Models.new("");library.catalog={"characters":{"lyra":spec}}
  assert(library.build(world,rules.units[0],Vector3.ZERO)==null and library.issues.size()==1,"Invalid stride configuration falls back cleanly")
 world.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-authored-stride-save.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true;app.stage.child_entered_tree.connect(watch)
 var ally=app.game.units[0];var enemy=app.game.living("enemy")[0];ally.x=8;ally.y=4;enemy.x=9;enemy.y=4
 for gender in ["female","male"]:
  for counter in [false,true]:
   var striker=enemy if counter else ally;var recipient=ally if counter else enemy
   striker.job="Duelist";striker.weapon="sword";striker.item="iron_sword"
   app.fighters.models.catalog={"characters":{striker.id:studies[gender]}}
   var state=app.game.save_data("battle").duplicate(true);var seed=app.game.rng.state;var before=live_steps
   await app.cinematic(ally,enemy,[{"actor":striker.id,"target":recipient.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{ally.id:20,enemy.id:20})
   assert(live_steps>before,"Real cinematic approach emits authored foot contacts in either direction")
   assert(app.game.save_data("battle")==state and app.game.rng.state==seed)
 assert(live_dust>0)
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",samples," eased authored approaches across rates/scales/headings, stationary/reverse/teleport behavior, measured stance slip ",max_slip," m, invalid stride fallback, four real cinematic foot/dust contacts and unchanged simulation")
 quit()
