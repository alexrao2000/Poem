extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
const Rules=preload("res://scripts/rules.gd")
const Outline=preload("res://scripts/authored_outline.gd")
const Defeat=preload("res://scripts/combat_defeat.gd")
func _initialize():call_deferred("run")
func assert_cloth(driver):
 for pair in driver.pairs:
  assert(pair.material.next_pass==pair.shell,"The controller follows the pass actually bound to the visible material")
  if not pair.cloth:continue
  for key in Outline.CLOTH:
   var value=pair.material.get_shader_parameter(key)
   assert(pair.shell.get_shader_parameter(key)==(Outline.CLOTH[key] if value==null else value),"Cloth and ink use exactly the same frame and floor plane")
func run():
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"));var rules=Rules.new();var stage=Node3D.new();root.add_child(stage);var surfaces=0;var rotated=0
 assert(Outline.SHADER.code.contains("vec3 direction = NORMAL;") and not Outline.SHADER.code.contains("COLOR"),"Skinned shells use transformed native normals, not unskinned vertex colors")
 var transparent=StandardMaterial3D.new();transparent.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 var glowing=StandardMaterial3D.new();glowing.emission_enabled=true
 assert(not Outline.eligible(transparent) and not Outline.eligible(glowing))
 for pair in [["vanguard","lyra"],["female","nell"],["male","silas"],["caster","tarin"],["caster_female","vela"]]:
  var spec=studies[pair[0]].duplicate(true);spec.appearance="Identity";var models=Models.new("");models.catalog={"characters":{pair[1]:spec}}
  var unit=rules.roster.filter(func(value):return value.id==pair[1])[0].duplicate(true);unit.team="player"
  var actor=models.build(stage,unit,Vector3(35,0,0));var other=models.build(stage,unit,Vector3(40,0,0));await process_frame
  var identity=actor.model.get_node("Identity");var driver=identity.outline;var second=other.model.get_node("Identity").outline
  assert(driver.pairs.size()>10 and driver.process_priority>identity.cloak.process_priority and driver.process_priority>identity.process_priority)
  var plain_models=Models.new("");plain_models.catalog={"characters":{pair[1]:studies[pair[0]]}};var plain=plain_models.build(stage,unit,Vector3(45,0,0));await process_frame
  var original=[]
  for mesh in plain.model.get_node("Rig/Armature/Skeleton3D").get_children():
   if not mesh is MeshInstance3D:continue
   var styled=actor.model.get_node(NodePath(str(plain.model.get_path_to(mesh))))
   assert(styled.mesh==mesh.mesh and styled.skin==mesh.skin,"Authored outlines never rewrite source geometry, weights or inverse binds")
   for index in range(mesh.mesh.get_surface_count()):
    var material=mesh.get_active_material(index);assert(material.next_pass==null,"Source materials stay unchanged across styled instances");original.append(material)
    if not styled.visible:assert(styled.get_active_material(index)==material,"Hidden source faces and hair are excluded")
    else:assert(styled.get_active_material(index).next_pass!=null,"Every opaque surface, including both male arm slots, gets its own actor's outline")
  for mesh in actor.find_children("*","MeshInstance3D",true,false):
   if not mesh.is_visible_in_tree():continue
   for index in range(mesh.mesh.get_surface_count()):
    var material=mesh.get_active_material(index)
    if mesh.name in ["PaintedFace","PrintedPage"]:assert(material.next_pass==null,"Painted expression and page cards remain free of ink shells")
  for index in range(driver.pairs.size()):
   var first=driver.pairs[index];var next=second.pairs[index]
   assert(first.material!=next.material and first.shell!=next.shell and first.material not in original)
   assert(first.shell.shader==Outline.SHADER and first.shell.get_shader_parameter("width")>0 and first.shell.get_shader_parameter("width")<=.0025)
   surfaces+=1
  # Measure a real source normal after a strongly rotated reaction pose. Its
  # shell direction must turn with the same skin transforms as the surface.
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var arm=rig.get_node("Female_Peasant_Arms" if pair[0] in ["vanguard","female","caster_female"] else "Male_Peasant_Arms")
  actor.pose("down",.01);actor.pose_tween.kill();actor.player.play(actor.poses.down.clip,0);actor.player.seek(actor.poses.down.to,true,true);actor.player.pause();actor.refresh_skeleton()
  var arrays=arm.mesh.surface_get_arrays(0);var normals=arrays[Mesh.ARRAY_NORMAL];var weights=arrays[Mesh.ARRAY_WEIGHTS];var bones=arrays[Mesh.ARRAY_BONES];var binds=[]
  for bind in range(arm.skin.get_bind_count()):
   var bone=rig.find_bone(arm.skin.get_bind_name(bind))
   if bone<0:bone=arm.skin.get_bind_bone(bind)
   binds.append(rig.get_bone_global_pose(bone)*arm.skin.get_bind_pose(bind))
  var influences=bones.size()/normals.size();var maximum=0.0
  for index in range(0,normals.size(),7):
   var direction=Vector3.ZERO
   for influence in range(influences):
    var at=index*influences+influence;direction+=binds[bones[at]].basis*normals[index]*weights[at]
   assert(direction.is_finite() and direction.length()>.01)
   maximum=maxf(maximum,direction.normalized().distance_to(normals[index]));rotated+=1
  assert(maximum>.5,"This sample actually exercises skin rotation rather than a rest-pose-only shell")
  actor.pose("idle",.01)
  for frame in range(3):await process_frame
  assert_cloth(driver)
  var stop=load("res://scripts/combat_hit_stop.gd").new();stage.add_child(stop);var pause=stop.play([actor],.1);pause.pause()
  var clock=identity.cloak.elapsed;var other_clock=other.model.get_node("Identity").cloak.elapsed
  for frame in range(3):await process_frame
  assert(identity.cloak.elapsed==clock and other.model.get_node("Identity").cloak.elapsed>other_clock);assert_cloth(driver)
  pause.play();await pause.finished
  actor.hide();clock=identity.cloak.elapsed
  for frame in range(3):await process_frame
  assert(identity.cloak.elapsed==clock);assert_cloth(driver);actor.show()
  var old_shells=driver.pairs.map(func(value):return value.shell)
  var fade=Defeat.new();stage.add_child(fade);fade.begin(actor);fade.motion.pause();fade.apply_visibility(.35)
  actor.position.y=.65
  for frame in range(3):await process_frame
  assert_cloth(driver)
  for entry in driver.pairs:
   assert(entry.shell not in old_shells and is_equal_approx(entry.shell.get_shader_parameter("defeat_visibility"),.35),"Defeat clones and fades every shell without leaving an opaque silhouette")
   if entry.cloth and entry.material.get_shader_parameter("cloth_floor_enabled"):assert(is_equal_approx(entry.shell.get_shader_parameter("cloth_floor_y"),.668))
  for entry in second.pairs:assert(entry.shell.shader==Outline.SHADER,"A nearby survivor keeps its unfaded outline")
  fade.finish();assert(not actor.visible)
  fade.queue_free();actor.queue_free();other.queue_free();plain.queue_free();await process_frame
 stage.queue_free();await process_frame
 print("PASS: ",surfaces," private authored outline pairs, ",rotated," animated source-normal samples, untouched meshes/skins/materials, multiple surfaces, card exclusions, same-frame cloth, hidden/hit-stop clocks and defeat ownership")
 quit()
