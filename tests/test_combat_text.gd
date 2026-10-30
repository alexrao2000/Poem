extends SceneTree
# Project actual text quads and their outlines through moving combat shots.
# Billboard AABBs deliberately overestimate the text, so they are not used here.

const Impact=preload("res://scripts/combat_impact.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Director=preload("res://scripts/combat_camera.gd")

func _initialize():call_deferred("run")

func text_bounds(label: Label3D,camera: Camera3D) -> Rect2:
 var points=label.generate_triangle_mesh().get_faces();var bounds=Rect2();var first=true
 var outline=label.outline_size*label.pixel_size
 for point in points:
  for offset in [Vector3(-outline,-outline,0),Vector3(outline,-outline,0),Vector3(outline,outline,0),Vector3(-outline,outline,0)]:
   var world=label.global_position+camera.global_basis*((point+offset)*label.scale)
   var screen=camera.unproject_position(world)
   if first:bounds=Rect2(screen,Vector2.ZERO);first=false
   else:bounds=bounds.expand(screen)
 return bounds

func run():
 var samples=0;var adjusted=0;var unchanged=0
 var viewport=SubViewport.new();viewport.size=Vector2i(1024,640);root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var camera=Camera3D.new();world.add_child(camera);camera.current=true
 var director=Director.new();world.add_child(director);director.configure(camera)
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions
  var safe=Rect2(Vector2(24,24),Vector2(dimensions)-Vector2(48,184))
  for recipient_mounted in [false,true]:
   for attacker_mounted in [false,true]:
    for side in [-1,1]:
     for gap in [1.3,4.0]:
      var recipient=Vector3(side*gap*.5,0,0);var attacker=-recipient
      var contact=recipient+Vector3.UP*(1.85 if recipient_mounted else 1.1)
      for event in [{"hit":true,"crit":false,"damage":999},{"hit":true,"crit":true,"damage":999},{"hit":false,"crit":false,"damage":0},{"hit":true,"crit":false,"damage":0},{"healing":999}]:
       director.establish(attacker,recipient,gap>2,recipient_mounted or attacker_mounted)
       var pan=director.shot(attacker,recipient,"impact",gap>2,recipient_mounted or attacker_mounted,.3);pan.pause()
       var healing=event.has("healing")
       var effect=Heal.new() if healing else Impact.new();world.add_child(effect)
       if healing:effect.play(attacker+Vector3.UP*1.2,contact,recipient,999)
       else:effect.configure(contact,event,camera)
       effect.motion.pause();await process_frame;await process_frame
       var source=effect.position
       for step in range(6):
        if pan.is_valid():pan.custom_step(.05)
        if healing:effect.bloom(step*.18)
        else:effect.motion.custom_step(.1)
        await process_frame
        var label=effect.amount;var bounds=text_bounds(label,camera)
        assert(safe.grow(.01).encloses(bounds),"Entire damage/miss/guard/healing label and outline stay above HUD and inside the shot: "+str(event)+" "+str(dimensions)+" "+str(bounds))
        var intended=contact+Vector3.UP*label.rise
        assert(is_equal_approx(camera.to_local(label.global_position).z,camera.to_local(intended).z),"Screen correction preserves text depth and perspective size")
        if label.global_position.distance_to(intended)>.001:adjusted+=1
        else:unchanged+=1
        assert(effect.position==source,"Text correction never moves the contact effect")
        if healing:assert(effect.glow.global_position.is_equal_approx(contact),"Recovery bloom remains attached to the recipient")
        elif effect.glow!=null:assert(effect.glow.global_position.is_equal_approx(contact),"Damage and guard glows remain at actual contact")
        samples+=1
       effect.queue_free();await process_frame
 assert(adjusted>0 and unchanged>adjusted,"Only edge cases move the text; ordinary floating trajectories remain intact")
 director.stop();viewport.queue_free();await process_frame
 print("PASS: ",samples," outlined combat text layouts through moving shots, both sides, mixed mounts, three viewport sizes, misses/guards/healing, fixed contacts and retained perspective; ",adjusted," bounded corrections")
 quit()
