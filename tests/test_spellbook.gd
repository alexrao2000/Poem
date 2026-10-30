extends SceneTree
const Book=preload("res://scripts/spellbook.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")

func run():
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
     var hand=actor.bones.Elbow.to_global(Vector3(0,-.29,-.08))
     assert(socket.distance_to(hand)<.0001,"Spell releases from the free hand rather than the book")
     if key in ["windup","critical_windup","strike"]:
      assert(socket.distance_to(palm)>.33,"The casting hand stays clear of the folio through anticipation and release")
     poses+=1
   actor.pose("down",1).custom_step(1)
   assert(actor.bones.Weapon.global_position.distance_to(actor.bones.LeftElbow.to_global(Vector3(0,-.29,-.04)))<.0001,"Fallen caster keeps its folio attached")
   actor.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: %d caster pose samples, left-hand open folios, shared original printed pages, free-hand spell sockets, facing/costume isolation and batching-safe materials"%poses)
 quit()
