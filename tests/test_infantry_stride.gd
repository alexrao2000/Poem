extends SceneTree
# Inspect actual world-space soles, every infantry outfit and the real approach
# tween. Sampling full-weight strides distinguishes planted travel from entry.

const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Stride=preload("res://scripts/infantry_stride.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var observing=false
var live_samples=0
func _initialize():call_deferred("run")

func run():
 var painter=Fighters.new();painter.batching_enabled=false
 var rules=Rules.new();var rng=rules.rng.state;var stage=Node3D.new();root.add_child(stage)
 stage.position=Vector3(35,2,-8);stage.rotation.y=.37;stage.scale=Vector3.ONE*1.15
 var samples=0;var maximum_drift=0.0
 for kind in ["sword","magic","staff"]:
  var unit=rules.roster.filter(func(unit):return unit.weapon==kind)[0].duplicate(true);unit.team="player"
  for direction in [-1,1]:
   for facing in [-PI/2,PI/2]:
    for size_value in [1.0,1.25]:
     var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.rotation.y=facing;actor.scale=Vector3.ONE*size_value
     actor.pose("advance",1).custom_step(1)
     var prior={};var stride=Stride.ROBE_LENGTH if kind in ["magic","staff"] else Stride.LENGTH
     for step in range(160):
      actor.global_position+=-actor.global_basis.z.normalized()*direction*(stride*actor.global_basis.z.length()/80)
      actor._process(.016)
      for side in range(2):
       var key="Left" if side==0 else "Right";var foot=actor.bones[key+"Foot"]
       var phase=Stride.phase_for(actor.gait_phase,side);var point=foot.to_global(Vector3(0,-.075,-.07))
       assert(foot.global_basis.is_equal_approx(actor.global_basis),"Actual soles retain scale and facing through the stride")
       assert(foot.position==Vector3(0,-.38,0) and actor.bones[key+"Knee"].position==Vector3(0,-.36,0),"Solving the stride never stretches either leg segment")
       if phase>.015 and phase<.485:
        assert(absf(point.y-actor.global_position.y)<.0001,"Planted sole stays at the translated floor")
        if prior.has(key):
         var drift=point.distance_to(prior[key]);maximum_drift=maxf(maximum_drift,drift)
         assert(drift<.0001,"Planted foot remains fixed in world space under forward/reverse travel and scaled parents")
        prior[key]=point;samples+=1
       else:prior.erase(key)
       if phase>.55 and phase<.95:assert(point.y>actor.global_position.y+.01,"Returning foot lifts above the ground")
     actor.free()
 stage.transform=Transform3D.IDENTITY
 var outfits=verify_outfits(painter,rules,stage)
 verify_upper_body(painter,rules,stage)
 assert(rules.rng.state==rng,"Stride and clothing checks consume no campaign randomness")
 stage.free()
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-stride-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.busy=true
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var saved=app.game.save_data("battle").duplicate(true);rng=app.game.rng.state;var view=app.camera.transform
 observing=true;observe_approach(app)
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"hit":true,"crit":false,"damage":1,"remaining":19}],{a.id:20,b.id:20})
 observing=false;await process_frame
 assert(live_samples>2,"A real approach supplies consecutive planted frames after its entry blend")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and app.camera.transform.is_equal_approx(view),"New gait preserves resolved combat and tactical restoration")
 await Shutdown.dispose(app)
 print("PASS: ",samples," transformed world-plant samples (max drift ",maximum_drift," m), ",outfits," full-mesh outfit samples, robe clearance and ",live_samples," actual tween-synchronized planted frames")
 quit()

func verify_outfits(painter,rules,stage):
 var candidates=[]
 for recruit in rules.roster:
  if recruit.job=="Rider":continue
  var paths=[""]
  for promotion in rules.promotion_options(recruit):paths.append(promotion.id)
  for path in paths:
   var unit=recruit.duplicate(true);unit.team="player";unit.promotion=path;candidates.append(unit)
 for job in ["Vanguard","Knight","Ranger","Arcanist","Warden","Corsair","Duelist"]:
  var unit=rules.roster.filter(func(unit):return unit.job==job)[0].duplicate(true);unit.team="enemy";unit.id="gait_enemy_"+job;candidates.append(unit)
 var samples=0
 for unit in candidates:
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose("advance",1).custom_step(1)
  var geometry=[]
  for mesh in actor.find_children("*","MeshInstance3D",true,false):geometry.append([mesh,mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]])
  var stride=Stride.ROBE_LENGTH if unit.weapon in ["magic","staff"] else Stride.LENGTH
  for step in range(40):
   actor.position.z-=stride/40;actor._process(.016)
   for entry in geometry:
    for point in entry[1]:
     var height=entry[0].to_global(point).y
     assert(height>=-.001,"Full outfit and held gear stay above the floor throughout the moving gait: "+unit.id)
     if entry[0].name=="RobeHem":assert(height>.01,"Shorter caster strides keep robe trim clear without moving the waist attachment")
   samples+=1
  actor.free()
 assert(candidates.size()==70,"All base/promoted infantry and seven enemy classes are covered")
 return samples

func observe_approach(app):
 var prior={}
 while observing:
  await process_frame
  if not observing:return
  var current={}
  if app.stage.visible:
   for actor in app.stage.get_children():
    if not actor is Fighters.Actor or actor.mounted or actor.pose_name!="advance" or actor.infantry_gait_weight<.999:continue
    assert(actor.travel_previous.distance_to(actor.global_position)<.0001,"Gait is updated after this frame's root tween, avoiding a one-frame sliding lag")
    for side in range(2):
     var phase=Stride.phase_for(actor.gait_phase,side)
     if phase<=.015 or phase>=.485:continue
     var foot=actor.bones[("Left" if side==0 else "Right")+"Foot"];var key=str(actor.get_instance_id())+str(side)
     var point=foot.to_global(Vector3(0,-.075,-.07));current[key]=point
     if prior.has(key):assert(point.distance_to(prior[key])<.0001,"The real accelerating approach preserves its planted foot");live_samples+=1
  prior=current

func verify_upper_body(painter,rules,stage):
 for source in rules.roster:
  var unit=source.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose("critical_windup",1).custom_step(1)
  var active=not actor.mounted and actor.kind in ["sword","axe","lance"]
  var before={"Body":actor.bones.Body.rotation,"LeftArm":actor.bones.LeftArm.rotation}
  var entry=actor.pose("advance",.2);actor._process(0)
  if active:
   for key in before:assert(actor.bones[key].rotation.is_equal_approx(before[key]),"Running counterbalance starts from the current pose without snapping")
  entry.custom_step(.05);actor._process(0)
  if active:
   for key in before:assert(actor.bones[key].rotation.distance_to(before[key])<.16,"Torso and free arm ease into the stride during the first quarter of entry")
  entry.custom_step(.15);actor._process(0)
  var settled={"Body":actor.bones.Body.rotation,"LeftArm":actor.bones.LeftArm.rotation}
  var low=INF;var high=-INF
  var stride=2.8 if actor.mounted else Stride.ROBE_LENGTH if actor.kind in ["magic","staff"] else Stride.LENGTH
  for step in range(32):
   actor.position.z-=stride/32;actor._process(.016)
   if active:
    assert(absf(actor.bones.Body.rotation.y)<.046 and is_equal_approx(actor.bones.Body.rotation.x,-.06),"Melee posture uses restrained shoulder rotation and forward lean")
    low=minf(low,actor.bones.LeftArm.rotation.x);high=maxf(high,actor.bones.LeftArm.rotation.x)
   else:
    for key in settled:assert(actor.bones[key].rotation.is_equal_approx(settled[key]),"Seated, bow and book/staff arm ownership remains intact")
  if active:
   assert(high-low>.19 and high-low<.45,"Free-arm counterbalance follows the full step cycle")
   if actor.bones.has("Shield"):assert(high-low<.21,"Shield carriers retain a smaller protected arm swing")
  for key in settled:settled[key]=actor.bones[key].rotation
  actor._process(1)
  for key in settled:assert(actor.bones[key].rotation.is_equal_approx(settled[key]),"A stationary actor cannot pump its arms in place")
  actor.pose("windup",1).custom_step(1)
  for key in settled:settled[key]=actor.bones[key].rotation
  actor._process(.1)
  for key in settled:assert(actor.bones[key].rotation.is_equal_approx(settled[key]),"Weapon preparation reclaims torso and arm ownership after running")
  actor.free()
