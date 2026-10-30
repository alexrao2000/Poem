extends SceneTree
# Exercise real atlas pixels and animation selection, including missing-art
# fallback. Army colors belong to the texture; only the spent state tints them.
const Catalog=preload("res://scripts/campaign_catalog.gd")
const Unit=preload("res://scripts/campaign_map_unit.gd")
const Rules=preload("res://scripts/rules.gd")
const Fighters=preload("res://scripts/fighters.gd")
const RigTest=preload("res://tests/test_rig_batching.gd")
func _initialize():call_deferred("run")
func run():
 var catalog=Catalog.new();assert(catalog.open("res://visuals/units.json") and catalog.enemy_errors.is_empty())
 var stage=Node3D.new();root.add_child(stage)
 var game=Rules.new();var seen={};var poses=0
 var painter=Fighters.new()
 for source in game.roster:
  if seen.has(source.job):continue
  seen[source.job]=true
  var unit=source.duplicate(true);unit.team="enemy";unit.acted=false
  var id="enemy."+unit.job.to_lower();var entry=catalog.assets[id]
  var actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  assert(actor.visual_id==id and entry.frames.size()==12)
  var pixels=catalog.textures[id].get_image()
  assert(pixels.get_pixel(0,0).a==0,"Enemy artwork retains alpha transparency")
  for frame in entry.frames:
   var r=frame.rect;var coverage=0
   for y in range(r[3]):
    for x in range(r[2]):
     if pixels.get_pixel(r[0]+x,r[1]+y).a>=.4:
      coverage+=1
      assert(x>0 and y>0 and x<r[2]-1 and y<r[3]-1,"Every pose has clear edges without a neighboring weapon or figure")
   assert(coverage>100);poses+=1
  for state in ["idle","move","act","hurt","defeated"]:
   for facing in ["north","south","east","west"]:
    actor.player.play(state,facing,true);actor._process(0)
    assert(actor.sprite.modulate==Color.WHITE,"Enemy skin, horses and steel keep authored colors")
    assert(actor.sprite.scale==Vector3(entry.source_pixel_scale,entry.source_pixel_scale,1),"Animation frames retain consistent source density")
    actor.spent=true;actor._process(0)
    assert(actor.sprite.modulate==Color(.78,.78,.78) and actor.sprite.texture==catalog.spent_frame_texture(id,actor.player.frame_index()),"Spent enemy uses the same grayscale treatment without an additional red tint")
    actor.spent=false
  actor.player.play("act","west",true);actor.player.advance(.13);actor.update_frame()
  assert(actor.sprite.flip_h,"West attack mirrors its directional strike")
  var frame=entry.frames[actor.player.frame_index()]
  assert(actor.sprite.offset.x==frame.pivot_px[0]-frame.rect[2])
  actor.queue_free()
  catalog.assets.erase(id)
  actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit);actor._process(0)
  assert(actor.visual_id=="unit."+unit.job.to_lower() and actor.sprite.modulate==Color(1,.72,.68),"Missing enemy art retains the compatible tinted class fallback")
  actor.spent=true;actor._process(0)
  assert(actor.sprite.modulate==Color(.78,.78,.78),"Missing enemy artwork also uses neutral grayscale after acting")
  actor.queue_free();catalog.assets[id]=entry
  # Reusing a recruit-like ID cannot leak goggles, hair, signature armor or a
  # pale named horse into an anonymous enemy class.
  unit.id="enemy_qa_"+unit.job
  var anonymous=painter.build(stage,unit,Vector3.ZERO);anonymous.set_process(false);anonymous.pose_tween.kill()
  var profile=painter.enemy_looks[unit.job]
  assert(anonymous.get_meta("costume_colors")=={"cloth":Color(profile.cloth),"cape":Color(profile.cape)})
  if unit.job!="Knight":
   assert(anonymous.bone("Head").get_meta("hair_style")==profile.hair_style and anonymous.bone("Head").get_meta("face_variant")==int(profile.face_variant),"Close-up hair and facial features follow the class portrait archetype")
  if unit.job=="Rider":assert(anonymous.get_meta("mount_appearance").coat=="77513a","Enemy cavalry retain natural brown horses")
  var reference=RigTest.signature(anonymous)
  for recruit_id in ["lyra","petra","una"]:
   unit.id=recruit_id
   var named=painter.build(stage,unit,Vector3.ZERO);named.set_process(false);named.pose_tween.kill()
   RigTest.equivalent(reference,RigTest.signature(named))
   named.queue_free()
  anonymous.queue_free()
 assert(poses==96 and seen.size()==8)
 var before=catalog.assets.keys()
 assert(not catalog.add_enemies("res://campaign_visuals.json") and catalog.assets.keys()==before,"Enemy supplements cannot inject recruit identities")
 assert(not catalog.add_enemies("res://visuals/units.json") and catalog.assets.keys()==before,"Enemy supplements cannot replace class art")
 assert(catalog.open("res://visuals/units.json") and catalog.enemy_errors.is_empty(),"Reopening clears supplemental errors")
 stage.queue_free();await process_frame
 print("PASS: 8 matching enemy archetypes, 96 isolated poses, authored colors, directional pivots, 24 recruit-ID collision checks, natural mounts and class fallback")
 quit()
