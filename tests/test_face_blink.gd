extends SceneTree
## Test atlas isolation and actual actor clocks/materials, including hit stop.
## No rendered scene is captured; eyelid appearance still needs visual review.
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Blink=preload("res://scripts/face_blink.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")
func run():
 var painter=Fighters.new();var game=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var source=painter.face_atlas.get_image();var lids=Blink.CLOSED.get_image()
 assert(lids.get_size()==source.get_size(),"Both unchanged atlases use identical pixel coordinates")
 var focus=Blink.FOCUSED.get_image()
 assert(focus.get_size()==source.get_size(),"Critical expression preserves the existing eight-cell UV layout")
 verify_focused_pixels(source,focus)
 var counts=[0,0,0,0,0,0,0,0];var open_counts=counts.duplicate()
 for y in range(lids.get_height()):
  var v=float(y)/lids.get_height()*2;var local_v=fposmod(v,1)
  if local_v<.34 or local_v>.55:continue
  for x in range(lids.get_width()):
   var u=float(x)/lids.get_width()*4;var index=int(v)*4+int(u)
   if source.get_pixel(x,y).a>=.22:open_counts[index]+=1
   var ink=lids.get_pixel(x,y)
   if ink.a<.22:continue
   assert(fposmod(u,1)>.03 and fposmod(u,1)<.97,"Closed eyelids remain inside each face cell")
   assert(ink.r<.7 and ink.g<.4 and ink.b<.4,"Closed eyes contain dark lids without white/colored irises or bright mask fringes")
   counts[index]+=1
 for i in range(8):assert(counts[i]>1000 and counts[i]<open_counts[i]*.3,"All eight eye pairs close to narrow eyelid strokes")
 var actors=[];var offsets={};var saved_rng=game.rng.state;var enemy_jobs={}
 var units=[]
 for recruit in game.roster:
  var unit=recruit.duplicate(true);unit.team="player";units.append(unit)
  if not enemy_jobs.has(unit.job):
   enemy_jobs[unit.job]=true;var enemy=unit.duplicate(true);enemy.team="enemy";units.append(enemy)
 for unit in units:
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill();actors.append(actor)
  var blink=actor.face_blink;var face=actor.find_child("PaintedFace",true,false)
  if unit.team=="enemy" and unit.job=="Knight":
   assert(face==null and blink.surface==null,"Closed helmet remains opaque without a hidden face layer")
   continue
  assert(face.material_override==blink.surface and blink.surface.next_pass==null,"Blink binds the actual unbatched face without an outline")
  assert(blink.surface.get_shader_parameter("open_face")==painter.face_atlas and blink.surface.get_shader_parameter("closed_face")==Blink.CLOSED)
  assert(not blink.closed and blink.interval>=3.1 and blink.interval<4.8)
  offsets[blink.clock]=true
  for other in actors:
   if other!=actor:assert(other.face_blink.surface!=blink.surface,"Two characters never share expression state")
  blink.clock=blink.interval-.02;actor._process(.03)
  assert(blink.closed and blink.surface.get_shader_parameter("eyes_closed"),"An idle actor reaches its closed-eye interval")
  actor._process(Blink.DURATION)
  assert(not blink.closed,"A blink releases after about a tenth of a second")
  for pose in ["advance","windup","critical_windup","strike","recover","hit","critical_hit","evade","guard","down","cast_windup","cast","throw_windup","critical_throw_windup","throw"]:
   blink.clock=0;blink.update(0,"idle");assert(blink.closed)
   actor.pose(pose,.01);actor.pose_tween.kill()
   assert(blink.closed==(pose=="down"),"Defeat closes the eyes; living action and reaction poses reopen them immediately")
   actor._process(.5);assert(blink.closed==(pose=="down"))
  actor.pose("down",.01);actor.pose_tween.kill();actor._process(10)
  assert(blink.closed,"A defeated figure cannot resume idle blinking during the survivor's finish")
  actor.pose("victory",.01);actor.pose_tween.kill()
  assert(not blink.closed,"Returning to a living preview pose restores an attentive expression")
  for preparation in ["critical_windup","critical_throw_windup"]:
   actor.pose(preparation,.01);actor.pose_tween.kill()
   assert(blink.focused and blink.surface.get_shader_parameter("focused") and not blink.closed,"Critical preparation selects the actor's focused upper-face artwork")
   actor.pose("throw" if preparation=="critical_throw_windup" else "strike",.01);actor.pose_tween.kill()
   assert(blink.focused,"Critical expression persists through weapon release")
   actor.pose("recover",.01);actor.pose_tween.kill()
   assert(not blink.focused,"Recovery restores the ordinary expression")
  actor.pose("critical_windup",.01);actor.pose_tween.kill();actor.pose("down",.01);actor.pose_tween.kill()
  assert(not blink.focused and blink.closed,"Defeat replaces critical focus with the existing closed eyelids")
  actor.pose("idle",.01);actor.pose_tween.kill()
 assert(offsets.size()>=20 and game.rng.state==saved_rng,"Presentation timing is staggered without consuming campaign RNG")
 var held=actors[0];var other=actors[2]
 held.set_process(true);other.set_process(true)
 held.face_blink.clock=held.face_blink.interval*.5;other.face_blink.clock=other.face_blink.interval*.5
 var freeze=HitStop.new();root.add_child(freeze);freeze.play([held],.2);freeze.motion.pause()
 var held_clock=held.face_blink.clock;var other_clock=other.face_blink.clock
 for frame in range(3):await process_frame
 assert(held.face_blink.clock==held_clock and other.face_blink.clock!=other_clock,"Hit stop freezes only the participating actor's eyelid clock")
 freeze.queue_free();await process_frame
 held.hide();held_clock=held.face_blink.clock;var body_clock=held.elapsed
 for frame in range(3):await process_frame
 assert(held.face_blink.clock==held_clock and held.elapsed==body_clock,"Hidden character previews suspend idle motion")
 held.show()
 for frame in range(3):await process_frame
 assert(held.face_blink.clock!=held_clock,"Visibility restores idle animation")
 stage.queue_free();await process_frame
 print("PASS: eight isolated eyelid regions, 24 recruits/seven visible enemy faces, registered critical expressions through release, independent idle blinks, immediate action reopening, sustained defeated eyelids, hidden suspension and local hit-stop restoration")
 quit()

func verify_focused_pixels(source: Image,focus: Image):
 var changed=[0,0,0,0,0,0,0,0];var eye_error=[0.,0.,0.,0.,0.,0.,0.,0.];var eye_samples=[0,0,0,0,0,0,0,0]
 for y in range(source.get_height()):
  var v=y*2.0/source.get_height();var local_v=fposmod(v,1)
  if local_v>.57:continue
  for x in range(source.get_width()):
   var u=x*4.0/source.get_width();var local_u=fposmod(u,1);var cell=int(v)*4+int(u)
   var original=source.get_pixel(x,y);var focused_pixel=focus.get_pixel(x,y)
   if local_v<.34 and (original.a>=.22 or focused_pixel.a>=.22) and original!=focused_pixel:changed[cell]+=1
   if local_v>=.535 and local_v<=.565:assert(focused_pixel.a<.22 and original.a<.22,"Expression boundary lies in transparent space between eyes and nose")
   if focused_pixel.a>=.22:assert(local_u>.03 and local_u<.97 and local_v>.20,"Focused features stay isolated inside each face cell")
   if local_v>.38 and local_v<.50 and ((local_u>.2 and local_u<.34) or (local_u>.66 and local_u<.8)):
    eye_error[cell]+=Vector3(original.r-focused_pixel.r,original.g-focused_pixel.g,original.b-focused_pixel.b).length();eye_samples[cell]+=1
 for cell in range(8):
  assert(changed[cell]>500,"All eight identities have an authored focused brow variant")
  assert(eye_samples[cell]>100 and eye_error[cell]/eye_samples[cell]<.15,"Critical artwork retains each identity's iris colors and registration")
