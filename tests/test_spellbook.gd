extends SceneTree
const Book=preload("res://scripts/spellbook.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Hands=preload("res://scripts/casting_hand.gd")
func _initialize():call_deferred("run")

func run():
 await verify_gloves()
 for side in [-1,1]:
  var shape=Hands.mesh(side);assert(shape==Hands.mesh(side),"Open hand meshes are cached by handedness")
  var arrays=shape.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={}
  assert(indices.size()/3==276 and shape.get_aabb().size.x<.14 and shape.get_aabb().size.y<.16,"Detailed hands stay inside the former glove envelope with bounded geometry")
  for i in range(0,indices.size(),3):
   var a=vertices[indices[i]];var b=vertices[indices[i+1]];var c=vertices[indices[i+2]]
   var normal=(c-a).cross(b-a)
   assert(normal.length()>.000000001 and normal.normalized().dot(normals[indices[i]]+normals[indices[i+1]]+normals[indices[i+2]])>0,"Fingers, thumbs and palm retain outward winding")
   for j in range(3):
    var x=str(vertices[indices[i+j]].snapped(Vector3.ONE*.000001));var y=str(vertices[indices[i+(j+1)%3]].snapped(Vector3.ONE*.000001))
    var edge=x+":"+y if x<y else y+":"+x;edges[edge]=edges.get(edge,0)+1
  for count in edges.values():assert(count==2,"Each palm/digit surface is closed")
 var left=Hands.mesh(-1).get_aabb();var right=Hands.mesh(1).get_aabb()
 assert(is_equal_approx(left.position.x,-right.end.x) and is_equal_approx(left.end.x,-right.position.x),"The two thumbs occupy opposite sides")
 var fighters=Fighters.new();var rules=Rules.new();var stage=Node3D.new();root.add_child(stage)
 stage.position=Vector3(35,0,3);stage.rotation.y=.4
 var paper=Book.page_material();assert(paper==Book.page_material(),"Printed pages share one original generated texture")
 var image=paper.albedo_texture.get_image()
 assert(image.get_width()==128 and image.get_height()==192 and image.has_mipmaps())
 var units=[]
 for source in rules.roster.filter(func(u):return u.weapon=="magic"):
  for promotion in [""]+rules.promotions.filter(func(p):return p.base==source.job).map(func(p):return p.id):
   var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion;units.append(unit)
 var foe=units[0].duplicate(true);foe.team="enemy";foe.id="folio_test";foe.promotion="";units.append(foe)
 var poses=0
 for unit in units:
  for direction in [-1,1]:
   var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false);actor.rotation.y=direction*PI/2
   actor.pose("idle",1).custom_step(1)
   assert(actor.bones.Weapon.get_parent()==actor.bones.LeftElbow,"Open folio belongs to the left hand")
   var book=actor.bones.Weapon.get_node("Spellbook")
   for hand_key in ["LeftHand","RightHand"]:
    var skin=actor.bones[hand_key].find_children("*","MeshInstance3D",true,false)[0].material_override
    assert(skin.next_pass!=fighters.Outline.material() and skin.next_pass.get_shader_parameter("width")<=.0015,"Finger outlines remain thinner than the gaps between digits")
   assert(book.has_node("LeftLeaf") and book.has_node("RightLeaf"),"Both splayed page groups retain their authored transforms after batching")
   var printed=actor.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return mesh.material_override.get_meta("no_character_outline",false))
   assert(printed.size()==1 and printed[0].material_override.next_pass==null,"Printed pages batch together without an opaque outline shell")
   assert(printed[0].material_override.albedo_texture==paper.albedo_texture,"Every costume retains the original page texture")
   for key in ["idle","advance","windup","critical_windup","strike","recover","guard","hit","evade"]:
    var motion=actor.pose(key,1)
    for frame in range(5):
     motion.custom_step(0 if frame==0 else .25);actor.apply_constraints()
     var palm=actor.bones.LeftElbow.to_global(Vector3(0,-.29,-.04))
     assert(actor.bones.Weapon.global_position.distance_to(palm)<.0001,"Folio remains attached to its holding palm through every pose")
     var page_normal=-actor.bones.Weapon.global_basis.z.normalized()
     assert(page_normal.dot(Vector3.UP)>.97,"Book remains tilted upward for reading while arms/torso animate")
     var normals=printed[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
     var normal_basis=printed[0].global_basis.inverse().transposed()
     for normal in normals:assert((normal_basis*normal).normalized().dot(Vector3.UP)>.9,"Actual printed page faces remain visible from above")
     var socket=actor.socket_position("projectile")
     var hand=actor.bones.RightHand.to_global(Vector3(0,0,-.10))
     assert(socket.distance_to(hand)<.0001,"Spell releases from the free hand rather than the book")
     for hand_key in ["LeftHand","RightHand"]:
      assert((-actor.bones[hand_key].global_basis.z).normalized().dot(Vector3.UP)>.97,"Both open palms face upward through the casting poses")
     for mesh in actor.bones.Weapon.find_children("*","MeshInstance3D",true,false):
      for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
       assert(actor.bones.LeftHand.to_local(mesh.to_global(vertex)).z<-.026,"Held folio stays above the open palm instead of cutting through it")
     if key in ["windup","critical_windup","strike"]:
      assert(socket.distance_to(palm)>.33,"The casting hand stays clear of the folio through anticipation and release")
     poses+=1
   actor.pose("down",1).custom_step(1)
   assert(actor.bones.Weapon.global_position.distance_to(actor.bones.LeftElbow.to_global(Vector3(0,-.29,-.04)))<.0001,"Fallen caster keeps its folio attached")
   actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: mirrored closed gloves, grip clearance and wrist poses; %d caster pose samples, left-hand open folios, shared original printed pages, free-hand spell sockets, facing/costume isolation and batching-safe materials"%poses)
 quit()

func verify_gloves():
 var gloves=preload("res://scripts/grip_hand.gd")
 for side in [-1,1]:
  var shape=gloves.mesh(side);assert(shape==gloves.mesh(side))
  var arrays=shape.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL];var edges={}
  assert(indices.size()/3<=420,"Detailed gloves keep a bounded triangle budget")
  for point in points:assert(absf(point.x)<.075 and absf(point.y)<.085 and absf(point.z)<.065,"Curled fingers remain inside the previous glove envelope")
  for i in range(0,indices.size(),3):
   var a=points[indices[i]];var b=points[indices[i+1]];var c=points[indices[i+2]]
   assert(Geometry3D.ray_intersects_triangle(Vector3(0,0,.2),Vector3.FORWARD,a,b,c)==null,"Curled fingers leave an actual central channel for the weapon grip")
   var normal=(c-a).cross(b-a)
   assert(normal.length_squared()>1e-18 and normal.dot(normals[indices[i]]+normals[indices[i+1]]+normals[indices[i+2]])>0,"Curled fingertips and mirrored thumbs retain outward nondegenerate faces")
   for j in range(3):
    var x=str(points[indices[i+j]].snapped(Vector3.ONE*.000001));var y=str(points[indices[i+(j+1)%3]].snapped(Vector3.ONE*.000001))
    var edge=x+":"+y if x<y else y+":"+x;edges[edge]=edges.get(edge,0)+1
  for count in edges.values():assert(count==2,"Every curled digit and palm has a closed surface")
 var left=gloves.mesh(-1).get_aabb();var right=gloves.mesh(1).get_aabb()
 assert(is_equal_approx(left.position.x,-right.end.x) and is_equal_approx(left.end.x,-right.position.x))
 var fighters=Fighters.new();fighters.batching_enabled=false;var rules=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var units=[]
 for source in rules.roster.filter(func(unit):return unit.weapon!="magic"):
  var unit=source.duplicate(true);unit.team="player";units.append(unit)
 for job in ["Vanguard","Knight","Ranger","Warden","Rider","Corsair","Duelist"]:
  var unit=rules.roster.filter(func(entry):return entry.job==job)[0].duplicate(true);unit.id="glove_foe";unit.team="enemy";units.append(unit)
 for unit in units:
  var actor=fighters.build(stage,unit,Vector3.ZERO);actor.set_process(false)
  var hands=actor.find_children("GripHand","MeshInstance3D",true,false);assert(hands.size()==2,"All non-casters receive two mirrored curled gloves")
  for hand in hands:
   assert(hand.material_override.next_pass.get_shader_parameter("width")<=.0015,"Fine glove silhouettes keep a restrained finger outline")
   assert(hand.get_parent() in [actor.bones.Elbow,actor.bones.LeftElbow],"Gloves preserve existing arm articulation")
  for pose in ["idle","advance","windup","strike","recover","guard"]:
   var motion=actor.pose(pose,1);motion.custom_step(1)
   for hand in hands:
    var wrist=hand.get_parent().to_global(Vector3(0,-.29,0))
    assert(hand.global_position.distance_to(wrist)<.0001,"Glove attachment stays at the animated wrist across combat poses")
  actor.queue_free();await process_frame
 stage.queue_free();await process_frame
