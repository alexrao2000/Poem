extends SceneTree
const Director=preload("res://scripts/combat_camera.gd")
const Transition=preload("res://scripts/combat_transition.gd")
func _initialize():call_deferred("run")
func run():
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(35,10,10)
 var director=Director.new();root.add_child(director);director.configure(camera)
 var a=Vector3(33,0,0);var b=Vector3(37,0,0)
 for phase in ["wide","windup","impact"]:
  for ranged in [false,true]:
   for mounted in [false,true]:
    for reverse in [false,true]:
     var frame=Director.frame_pair(b if reverse else a,a if reverse else b,phase,ranged,mounted)
     assert(frame.anchor.z>5 and frame.anchor.y>frame.focus.y,"Every shot keeps the horizon and same side of the combat axis")
     assert(frame.focus.x>=a.x and frame.focus.x<=b.x,"Camera tracks within combat pair")
     assert(frame.lens>=45 and frame.lens<=50,"Controlled lens avoids wide-angle distortion")
 director.establish(a,b,true)
 await director.shot(a,b,"windup",true,false,.02).finished
 director.apply_frame();assert(camera.position.is_equal_approx(director.anchor))
 director.impact(true);await create_timer(.2).timeout
 assert(director.shake_offset.is_zero_approx(),"Impact settles without permanent camera drift")
 director.shot(b,a,"impact",false,false,.1);director.stop()
 var stopped=camera.transform;await create_timer(.12).timeout
 assert(camera.transform==stopped,"Stopped director cannot overwrite tactical camera restoration")
 director.queue_free();camera.queue_free();await process_frame
 var host=Control.new();root.add_child(host);host.size=Vector2(1440,900)
 var veil=Transition.new();veil.configure(host)
 var previous=0.0
 for step in range(21):
  veil.progress=step/20.0
  assert(veil.cover_alpha()>=previous,"Concealment is monotonic")
  previous=veil.cover_alpha()
 await veil.conceal(.02).finished
 assert(is_equal_approx(veil.cover_alpha(),1),"Arena swap happens behind an opaque veil")
 await veil.reveal(.02).finished
 assert(veil.progress==0 and veil.cover_alpha()==0,"Reveal leaves no opaque overlay")
 veil.conceal(.2);await create_timer(.03).timeout
 await veil.reveal(.02).finished
 assert(veil.progress==0,"Interrupted transition cancels earlier movement")
 host.queue_free();await process_frame
 print("PASS: camera framing, axis continuity, mounted framing, impact settling, transition coverage and cleanup")
 quit()
