extends SceneTree
## Verify actual bound fabric/outline materials, isolated clocks, hit-stop
## behavior and culling bounds. This does not substitute for rendered review.
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
func _initialize():call_deferred("run")
func verify_marks():
 for texture in [Fighters.COMPANY_CAPE,Fighters.IMPERIAL_CAPE]:
  var picture=texture.get_image();var coverage=0.0
  assert(picture.get_size()==Vector2i(256,384) and picture.has_mipmaps(),"Cape embroidery has a bounded atlas with mipmaps for perspective views")
  for y in range(picture.get_height()):
   for x in range(picture.get_width()):coverage+=picture.get_pixel(x,y).a
  coverage/=picture.get_width()*picture.get_height()
  assert(coverage>.04 and coverage<.12,"Sparse thread leaves the original cape color dominant")
  for x in range(picture.get_width()):assert(picture.get_pixel(x,0).a==0 and picture.get_pixel(x,383).a==0,"Embroidery stays inside the fabric UV edges")
  for y in range(picture.get_height()):assert(picture.get_pixel(0,y).a==0 and picture.get_pixel(255,y).a==0,"Side edging has a transparent margin")
 assert(Fighters.COMPANY_CAPE.get_image().get_data()!=Fighters.IMPERIAL_CAPE.get_image().get_data(),"Company and imperial marks retain different original designs")

func verify_trim(actor,company: bool):
 var cloth=actor.cape_motion.surfaces[0]
 assert(cloth.get_shader_parameter("cape_mark")== (Fighters.COMPANY_CAPE if company else Fighters.IMPERIAL_CAPE),"Actor team selects the embroidered mark through batching and outline setup")
 var color=cloth.get_shader_parameter("tint");var trim=cloth.get_shader_parameter("cape_trim")
 assert(absf(color.get_luminance()-trim.get_luminance())>.1,"Thread has contrast on both ivory and dark capes")

func run():
 verify_marks()
 verify_cuts()
 var painter=Fighters.new();var game=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var actors=[]
 for recruit in game.roster:
  var unit=recruit.duplicate(true);unit.team="player"
  var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose_tween.kill()
  assert(actor.bones.Cape.get_meta("cape_cut")==Fighters.Capes.cut_for(unit.job),"The actual recruit uses its class-specific cloak silhouette")
  assert(actor.cape_motion.surfaces.size()==2,"Each cape binds fabric and outline after batching")
  var cloth=actor.cape_motion.surfaces[0];var ink=actor.cape_motion.surfaces[1]
  assert(cloth.next_pass==ink and ink!=painter.Outline.material())
  verify_trim(actor,true)
  assert(cloth.get_shader_parameter("tint")==Color(painter.profiles[unit.id].appearance.cape))
  for other in actors:
   assert(other.cape_motion.surfaces[0]!=cloth and other.cape_motion.surfaces[1]!=ink,"Cloth clocks cannot leak between actors sharing a palette")
  for mesh in actor.bone("Cape").find_children("*","MeshInstance3D",true,false):
   assert(mesh.extra_cull_margin>=.10,"Maximum hem deformation and outline remain in culling bounds")
   var points=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var anchors=0
   for point in points:
    assert(point.y>=-1.0 and point.y<=.001,"Cape stays in the shader's shoulder-to-hem coordinate range")
    if is_zero_approx(point.y):anchors+=1
   assert(anchors>=7,"Cape has a continuous fixed shoulder edge")
  actor.elapsed=.25;actor.pose_name="advance";actor._process(.2)
  assert(cloth.get_shader_parameter("cloth_clock")==actor.elapsed and ink.get_shader_parameter("cloth_clock")==actor.elapsed)
  var moving=actor.cape_motion.drive
  assert(moving>.5 and moving<.9,"Approach smoothly increases fabric motion")
  actor.pose_name="idle";actor._process(.8)
  assert(actor.cape_motion.drive<moving and actor.cape_motion.drive>.12,"Ready stance settles gradually")
  assert(cloth.get_shader_parameter("cloth_drive")==ink.get_shader_parameter("cloth_drive"))
  actor.pose_name="hit";actor._process(1.0);var recoil=actor.cape_motion.drive
  actor.pose_name="critical_hit";actor._process(.3)
  assert(actor.cape_motion.drive>recoil and actor.cape_motion.drive<=.9,"Critical recoil drives a stronger bounded cloth response")
  actors.append(actor)
 for recruit in game.roster:
  for path in game.promotion_options(recruit):
   var unit=recruit.duplicate(true);unit.team="player";unit.promotion=path.id
   var promoted=painter.build(stage,unit,Vector3.ZERO);verify_trim(promoted,true);promoted.queue_free();await process_frame
 for job in game.content.classes:
  var unit=game.roster.filter(func(value):return value.job==job)[0].duplicate(true);unit.id="enemy_cape_"+job;unit.team="enemy"
  var enemy=painter.build(stage,unit,Vector3.ZERO);verify_trim(enemy,false);enemy.queue_free();await process_frame
 for material in painter.surface_cache.values():
  assert(material.get_shader_parameter("cloth_amount")!=1.0 and material.get_shader_parameter("cape_mark")==null,"Shared body fabrics never inherit cape motion or embroidery")
 assert(painter.Outline.material().get_shader_parameter("cloth_amount")!=1.0,"Shared armor/weapon outline never opts into cloth deformation")
 var held=actors[0];var other=actors[1];held.set_process(true);other.set_process(true)
 var hold=HitStop.new();root.add_child(hold);hold.play([held],.2);hold.motion.pause()
 var frozen=held.cape_motion.surfaces[0].get_shader_parameter("cloth_clock")
 var free_clock=other.elapsed
 for frame in range(3):await process_frame
 assert(held.cape_motion.surfaces[0].get_shader_parameter("cloth_clock")==frozen and held.cape_motion.surfaces[1].get_shader_parameter("cloth_clock")==frozen,"Local hit stop freezes both fabric passes")
 assert(other.elapsed>free_clock,"Another actor's cape clock keeps running")
 hold.queue_free();await process_frame
 for frame in range(3):await process_frame
 assert(held.cape_motion.surfaces[0].get_shader_parameter("cloth_clock")>frozen,"Cloth resumes with the restored actor")
 stage.queue_free();await process_frame
 print("PASS: five distinct shared cloak cuts, exposed ranger quivers, 24 independently animated cape pairs, 48 promoted and eight enemy embroidery bindings, transparent sparse mipmapped marks, contrasting thread, anchored geometry, bounded motion, matching fabric/outline clocks, idle settling and local hit-stop restoration")
 quit()

func verify_cuts():
 var shapes=[]
 for cut in Fighters.Capes.CUTS:
  var mesh=Fighters.Capes.mesh(cut);assert(mesh==Fighters.Capes.mesh(cut),"Each original cut shares immutable geometry across the roster")
  var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uv=arrays[Mesh.ARRAY_TEX_UV]
  assert(vertices.size()==216,"Distinct cape cuts retain the existing 72-triangle budget")
  assert(vertices.to_byte_array() not in shapes,"Class cuts differ in geometry rather than only metadata or palette");shapes.append(vertices.to_byte_array())
  for i in range(0,vertices.size(),3):
   var cross=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
   assert(cross.length()>.000001 and cross.dot(normals[i])<0,"Each cut retains nondegenerate outward-lit fabric")
  for index in range(vertices.size()):
   assert(Rect2(Vector2.ZERO,Vector2.ONE).grow(.00001).has_point(uv[index]),"Embroidered fabric keeps its complete 0–1 UV layout")
   assert(vertices[index].y>=-1 and vertices[index].y<=0,"All cuts remain inside the existing bounded cloth domain")
   if is_zero_approx(uv[index].y):assert(is_zero_approx(vertices[index].y),"Every cut retains the fixed shoulder attachment")
 assert(Fighters.Capes.mesh("mantle").get_aabb().size.y<.6 and Fighters.Capes.mesh("riding").get_aabb().size.y<.8,"Mantles and riding cloaks shorten the silhouette")
 assert(Fighters.Capes.point("forked",.5,1).y>Fighters.Capes.point("forked",1.0/3,1).y+.20,"Duelist hem has an actual open V between its tails")
 var painter=Fighters.new();painter.batching_enabled=false;var rules=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var paths=[""];paths.append_array(rules.promotions.filter(func(path):return path.base=="Ranger").map(func(path):return path.id))
 for source in rules.roster.filter(func(unit):return unit.job=="Ranger"):
  for promotion in paths:
   var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion
   var actor=painter.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.pose("idle",1).custom_step(1);actor.apply_constraints()
   var cape=actor.bones.Cape;var torso=cape.get_parent();var furthest=-INF
   for mesh in cape.find_children("*","MeshInstance3D",true,false):
    for point in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:furthest=maxf(furthest,torso.to_local(mesh.to_global(point)).x)
   var quiver=actor.find_child("Quiver",true,false);var closest=INF
   for mesh in quiver.find_children("*","MeshInstance3D",true,false):
    for point in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:closest=minf(closest,torso.to_local(mesh.to_global(point)).x)
   assert(closest-furthest>.025,"Ranger cloak clears every actual quiver part, including lateral cloth motion and outline width")
   actor.free()
 stage.free()
