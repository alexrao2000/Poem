extends SceneTree
const Director=preload("res://scripts/combat_camera.gd")
const Transition=preload("res://scripts/combat_transition.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
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
 var blade_a=Vector3(33.4,0,0);var blade_b=Vector3(36.6,0,0)
 var melee=Director.frame_pair(blade_a,blade_b,"wide",false,false,"sword",true)
 var ranged_pair=Director.frame_pair(blade_a,blade_b,"wide",true)
 var mounted_pose=Director.frame_pair(blade_a,blade_b,"wide",false,true)
 assert(melee.lens==ranged_pair.lens and melee.anchor.distance_to(melee.focus)<ranged_pair.anchor.distance_to(ranged_pair.focus))
 assert(mounted_pose==Director.frame_pair(blade_a,blade_b,"wide",false,true,"sword",true))
 assert(Director.frame_pair(blade_a,blade_b,"windup",false,false,"sword",true)==Director.frame_pair(blade_a,blade_b,"windup",true))
 var heights=[]
 for pair_frame in [ranged_pair,melee]:
  camera.position=pair_frame.anchor;camera.look_at(pair_frame.focus);camera.fov=pair_frame.lens
  heights.append(camera.unproject_position(blade_b).distance_to(camera.unproject_position(blade_b+Vector3.UP)))
 assert(heights[1]>heights[0]*1.10,"The closer shot makes infantry melee players larger without changing the lens")
 print("PASS: grounded melee reads at a larger scale while mounted and ranged framing retain their clearance")
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
 await verify_live_portrait()
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
 var framed=veil.conceal_framed();framed.pause()
 framed.custom_step(Transition.APPROACH_SECONDS+Transition.FRAMED_HOLD_SECONDS*.25)
 assert(veil.progress==Transition.FRAMED_APERTURE and veil.cover_alpha()<.07 and veil.streaks)
 framed.custom_step(Transition.FRAMED_HOLD_SECONDS*.50)
 assert(veil.progress==Transition.FRAMED_APERTURE,"The framed map sprites have a clear beat before the full cover")
 framed.custom_step(Transition.FRAMED_HOLD_SECONDS*.25+Transition.APPROACH_COVER_SECONDS+.001)
 assert(veil.progress==1 and veil.cover_alpha()==1)
 print("PASS: the framed combat approach holds the aperture before the arena swap")
 verify_focused_reveal(host,veil)
 host.queue_free();await process_frame
 print("PASS: camera framing, axis continuity, mounted framing, impact settling, transition coverage and cleanup")
 quit()

func verify_focused_reveal(host: Control,veil: Control):
 var target=[Vector2.ZERO]
 var gradient=Transition.aperture_mask().gradient
 var layouts=0
 for dimensions in [Vector2(720,640),Vector2(720,960),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  for position in [Vector2(.50,.5),Vector2(.28,.44),Vector2(.72,.57),Vector2(-.2,1.3)]:
   target[0]=dimensions*position
   var motion=veil.reveal(1,func():return target[0]);motion.pause()
   assert(veil.revealing and veil.cover_alpha()==1 and veil.shade_alpha()==0)
   var expected=target[0].clamp(dimensions*.10,dimensions*.90)
   assert(veil.projected_focus().is_equal_approx(expected))
   var prior_center=1.0;var prior_corner=1.0
   for i in range(21):
    if i>0:motion.custom_step(.05)
    var aperture=veil.aperture_rect(veil.projected_focus())
    assert(aperture.encloses(Rect2(Vector2.ZERO,dimensions)))
    var radius=aperture.size.x*.5;var center=aperture.get_center()
    var corners=[Vector2.ZERO,dimensions,Vector2(0,dimensions.y),Vector2(dimensions.x,0)]
    var farthest: float=corners.map(func(corner):return corner.distance_to(center)).max()
    var foreground=veil.cover_alpha()
    var periphery=foreground+(1-foreground)*veil.shade_alpha()*gradient.sample(farthest/radius).a
    assert(foreground<=prior_center+.00001 and periphery<=prior_corner+.00001,"Fighters and far corners brighten steadily")
    if i==10:assert(foreground==0 and periphery>.10,"The combatants appear while the scene edges still carry the veil")
    prior_center=foreground;prior_corner=periphery
   assert(prior_center<.00001 and prior_corner<.00001)
   layouts+=1
 print("PASS: %s focused reveal layouts, bounded offscreen focus, opaque cuts and monotonic foreground and edge fades"%layouts)

func bounds_points(mesh: MeshInstance3D) -> Array:
 var points=[];var box=mesh.get_aabb()
 for i in range(8):points.append(mesh.to_global(box.get_endpoint(i)))
 return points

func verify_roster_framing():
 var viewport=SubViewport.new();viewport.size=Vector2i(1280,720);root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var view=Camera3D.new();world.add_child(view);view.current=true
 var host=Control.new();viewport.add_child(host)
 var veil=Transition.new();veil.configure(host)
 var gradient=Transition.aperture_mask().gradient;var strongest_subject_shade=0.0
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
        for size_value in [Vector2i(720,640),Vector2i(720,960),Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
         viewport.size=size_value
         view.position=Director.anchor_for_view(entrance_frame.anchor,entrance_frame.focus,Vector2(size_value))
         view.look_at(entrance_frame.focus);view.fov=entrance_frame.lens
         host.size=Vector2(size_value)
         var height=1.25 if actor.mounted or partner_mounted else .95
         var pair=(actor.position+other)*.5+Vector3.UP*height
         var aperture=veil.aperture_rect(view.unproject_position(pair))
         for point in points:
          var screen=view.unproject_position(point)
          assert(screen.x>24 and screen.x<size_value.x-24 and screen.y>88 and screen.y<size_value.y-160,"Arena entrance keeps heads and soles clear across its full descending push")
          var alpha=gradient.sample(screen.distance_to(aperture.get_center())/(aperture.size.x*.5)).a
          strongest_subject_shade=maxf(strongest_subject_shade,alpha)
         entrance_samples+=1
     for partner_mounted in [false,true]:
      var frame=Director.frame_pair(actor.position,other,"windup" if phase=="critical_windup" else "impact" if phase=="critical_hit" else phase,separation==4,actor.mounted or partner_mounted)
      for size_value in [Vector2i(720,640),Vector2i(720,960),Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
       viewport.size=size_value
       view.position=Director.anchor_for_view(frame.anchor,frame.focus,Vector2(size_value))
       view.look_at(frame.focus);view.fov=frame.lens
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
 assert(strongest_subject_shade<=.18,"At its strongest the vignette keeps the roster’s heads and soles in its clear area: %s"%strongest_subject_shade)
 viewport.queue_free();await process_frame
 print("PASS: ",samples," recruit/enemy/commander head/sole layouts with five gaze orientations and ",entrance_samples," descending entrance layouts, both sides, mixed mounts, melee/ranged gaps and stronger foreground framing")

func verify_live_portrait():
 var viewport=SubViewport.new();viewport.size=Vector2i(1024,640);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-portrait-combat-%d.json"%Time.get_ticks_usec()
 viewport.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle()
 var attacker=app.game.living("player").filter(func(unit):return unit.id=="sera")[0]
 var target=app.game.living("enemy")[0]
 attacker.x=6;attacker.y=4;target.x=8;target.y=4
 app.refresh_pieces()
 var events=app.game.combat(attacker,target);assert(not events.is_empty())
 var tactical=app.map_navigation.capture_view()
 var saved=app.game.save_data("battle").duplicate(true)
 var rng=app.game.rng.state
 var reached=[0]
 var verify_resize=func():
  while not app.ui.has_node("CombatHUD"):await process_frame
  var director=app.stage.get_children().filter(func(child):return child is Director)[0]
  for size_value in [Vector2i(720,960),Vector2i(720,640),Vector2i(1440,900)]:
   viewport.size=size_value;await process_frame;await process_frame
   var expected=Director.anchor_for_view(director.anchor,director.focus,Vector2(size_value))+Vector3(director.shake_offset.x,director.shake_offset.y,0)
   assert(app.camera.position.is_equal_approx(expected) and is_equal_approx(app.camera.fov,director.lens))
   if size_value.x>=size_value.y*Director.MIN_SHOT_ASPECT:
    assert(Director.anchor_for_view(director.anchor,director.focus,Vector2(size_value))==director.anchor,"Wide displays retain the original authored shot")
   else:
    assert(expected.distance_to(director.focus)>director.anchor.distance_to(director.focus),"Narrow views pull back along the lens while retaining its field of view")
    for fighter in director.subjects:
     var plain=Rect2(Vector2(24,88),Vector2(size_value.x-48,size_value.y-248))
     assert(plain.has_point(app.camera.unproject_position(fighter.socket_position("gaze"))),"Both actual faces stay inside the clear portrait frame")
   reached[0]+=1
 verify_resize.call()
 await app.cinematic(attacker,target,events)
 assert(reached[0]==3 and app.map_navigation.capture_view()==tactical,"Resizing an active arena preserves the exact saved tactical camera")
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Camera resize cannot change campaign state")
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: narrow arena framing updates during a real ranged exchange and restores the exact tactical camera")
