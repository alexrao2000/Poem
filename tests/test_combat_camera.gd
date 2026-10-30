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
     assert(frame.anchor.z>0 and frame.anchor.y>frame.focus.y,"Every shot keeps the horizon and same side of the combat axis")
     assert(frame.focus.x>=a.x and frame.focus.x<=b.x,"Camera tracks within combat pair")
     assert(frame.lens>=45 and frame.lens<=50,"Controlled lens avoids wide-angle distortion")
 var wide=Director.frame_pair(a,b,"wide",true,false)
 var entrance=director.enter(a,b,true,false,1);entrance.pause()
 var start=camera.position
 assert(start.is_equal_approx(Director.entrance_frame(wide,0).anchor),"Arena reveal begins slightly higher and wider than the combat composition")
 entrance.custom_step(.5);var middle=camera.position
 assert(middle.distance_to(wide.anchor)<start.distance_to(wide.anchor) and middle!=wide.anchor,"Camera keeps advancing while the arena is revealed")
 entrance.custom_step(.5)
 assert(camera.position.is_equal_approx(wide.anchor) and director.focus.is_equal_approx(wide.focus),"Entry settles into the exact normal composition without changing its focus or lens")
 director.enter(a,b,true,false,1).pause();director.stop();var cancelled=camera.transform
 await process_frame
 assert(camera.transform==cancelled,"Stopping the entrance releases camera ownership")
 director.establish(a,b,true)
 await director.shot(a,b,"windup",true,false,.02).finished
 director.apply_frame();assert(camera.position.is_equal_approx(director.anchor))
 director.impact(true);await create_timer(.2).timeout
 assert(director.shake_offset.is_zero_approx(),"Impact settles without permanent camera drift")
 for direction in [-1,1]:
  director.impact(false,direction);director.impact_motion.custom_step(.035)
  assert(signf(director.shake_offset.x)==direction and is_equal_approx(absf(director.shake_offset.x),.032),"Contact kick follows either attack direction, including counters")
  director.impact_motion.custom_step(.045)
  assert(signf(director.shake_offset.x)==-direction,"The smaller rebound opposes the initial kick")
  director.impact_motion.custom_step(.08)
  assert(director.shake_offset.is_zero_approx(),"Both directions settle exactly without drift")
 director.shot(b,a,"impact",false,false,.1);director.stop()
 var stopped=camera.transform;await create_timer(.12).timeout
 assert(camera.transform==stopped,"Stopped director cannot overwrite tactical camera restoration")
 director.queue_free();camera.queue_free();await process_frame
 await verify_roster_framing()
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

func bounds_points(mesh: MeshInstance3D) -> Array:
 var points=[];var box=mesh.get_aabb()
 for i in range(8):points.append(mesh.to_global(box.get_endpoint(i)))
 return points

func verify_roster_framing():
 var viewport=SubViewport.new();viewport.size=Vector2i(1280,720);root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var view=Camera3D.new();world.add_child(view);view.current=true
 var painter=preload("res://scripts/fighters.gd").new();painter.batching_enabled=false
 var rules=preload("res://scripts/rules.gd").new();var samples=0;var entrance_samples=0
 var subjects=rules.roster.duplicate(true)
 for unit in subjects:unit.team="player"
 for job in painter.enemy_looks:
  var unit=rules.roster.filter(func(recruit):return recruit.job==job)[0].duplicate(true)
  unit.team="enemy";unit.id="enemy_camera_"+job;subjects.append(unit)
 for chapter in range(12):
  rules.chapter=chapter;rules.start_battle();subjects.append(rules.units.filter(func(unit):return unit.get("boss",false))[0].duplicate(true))
 for source in subjects:
  var unit=source.duplicate(true)
  var actor=painter.build(world,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
  for side in [-1,1]:
   actor.rotation.y=side*PI/2
   for separation in [1.3,4.0]:
    actor.position=Vector3(side*separation*.5,0,0)
    var other=Vector3(-side*separation*.5,0,0)
    for phase in ["wide","windup","critical_windup","impact","critical_hit"]:
     actor.pose({"wide":"idle","windup":"windup","critical_windup":"critical_windup","impact":"strike","critical_hit":"critical_hit"}[phase],1).custom_step(1);actor.apply_constraints()
     var points=[]
     for gaze in [Vector2.ZERO,Vector2(-.32,-.45),Vector2(-.32,.45),Vector2(.32,-.45),Vector2(.32,.45)]:
      actor.bones.Gaze.rotation=Vector3(gaze.x,gaze.y,0)
      for mesh in actor.bones.Head.find_children("*","MeshInstance3D",true,false):points.append_array(bounds_points(mesh))
     actor.bones.Gaze.rotation=Vector3.ZERO
     for mesh in actor.find_children("Hoof" if actor.mounted else "Boot","MeshInstance3D",true,false):points.append_array(bounds_points(mesh))
     if phase=="wide":
      for partner_mounted in [false,true]:
       var final_frame=Director.frame_pair(actor.position,other,"wide",separation==4,actor.mounted or partner_mounted)
       for step in range(5):
        var entrance_frame=Director.entrance_frame(final_frame,step*.25)
        view.position=entrance_frame.anchor;view.look_at(entrance_frame.focus);view.fov=entrance_frame.lens
        for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
         viewport.size=size_value
         for point in points:
          var screen=view.unproject_position(point)
          assert(screen.x>24 and screen.x<size_value.x-24 and screen.y>88 and screen.y<size_value.y-160,"Arena entrance keeps heads and soles clear across its full descending push")
         entrance_samples+=1
     for partner_mounted in [false,true]:
      var frame=Director.frame_pair(actor.position,other,"windup" if phase=="critical_windup" else "impact" if phase=="critical_hit" else phase,separation==4,actor.mounted or partner_mounted)
      view.position=frame.anchor;view.look_at(frame.focus);view.fov=frame.lens
      for size_value in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
       viewport.size=size_value
       assert(viewport.get_visible_rect().size==Vector2(size_value),"Projection uses actual test viewport dimensions")
       for point in points:
        var screen=view.unproject_position(point)
        assert(screen.x>24 and screen.x<size_value.x-24 and screen.y>88 and screen.y<size_value.y-160,"Live head/sole geometry clears screen edges, caption and HUD: "+unit.name+" "+phase+" "+str(side)+" "+str(separation)+" "+str(partner_mounted)+" "+str(size_value)+" "+str(screen))
       samples+=1
  actor.queue_free();await process_frame
 viewport.size=Vector2i(1280,720)
 var frame=Director.frame_pair(Vector3(-2,0,0),Vector3(2,0,0),"wide",true,false)
 view.position=frame.anchor;view.look_at(frame.focus);view.fov=frame.lens
 var near_height=view.unproject_position(Vector3(2,0,0)).y-view.unproject_position(Vector3(2,1.8,0)).y
 var far_height=view.unproject_position(Vector3(-2,0,0)).y-view.unproject_position(Vector3(-2,1.8,0)).y
 assert(near_height/720>.45 and near_height/720<.55 and near_height/far_height>1.4,"Ranged composition has a larger foreground silhouette and visible perspective depth")
 viewport.queue_free();await process_frame
 print("PASS: ",samples," recruit/enemy/commander head/sole layouts with five gaze orientations and ",entrance_samples," descending entrance layouts, both sides, mixed mounts, melee/ranged gaps and stronger foreground framing")
