extends SceneTree
# Exercise real atlas pixels and animation selection, including missing-art
# fallback. Army colors belong to the texture; only the spent state tints them.
const Catalog=preload("res://scripts/campaign_catalog.gd")
const Unit=preload("res://scripts/campaign_map_unit.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var catalog=Catalog.new();assert(catalog.open("res://visuals/units.json") and catalog.enemy_errors.is_empty())
 var stage=Node3D.new();root.add_child(stage)
 var game=Rules.new();var seen={};var poses=0
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
    assert(actor.sprite.scale==Vector3(.46,.46,1),"Animation frames retain consistent source density")
    actor.spent=true;actor._process(0)
    assert(actor.sprite.modulate==Color(.70,.72,.73),"Spent enemy remains legible without an additional red tint")
    actor.spent=false
  actor.player.play("act","west",true);actor.player.advance(.13);actor.update_frame()
  assert(actor.sprite.flip_h,"West attack mirrors its directional strike")
  var frame=entry.frames[actor.player.frame_index()]
  assert(actor.sprite.offset.x==frame.pivot_px[0]-frame.rect[2])
  actor.queue_free()
  catalog.assets.erase(id)
  actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit);actor._process(0)
  assert(actor.visual_id=="unit."+unit.job.to_lower() and actor.sprite.modulate==Color(1,.72,.68),"Missing enemy art retains the compatible tinted class fallback")
  actor.queue_free();catalog.assets[id]=entry
 assert(poses==96 and seen.size()==8)
 var before=catalog.assets.keys()
 assert(not catalog.add_enemies("res://campaign_visuals.json") and catalog.assets.keys()==before,"Enemy supplements cannot inject recruit identities")
 assert(not catalog.add_enemies("res://visuals/units.json") and catalog.assets.keys()==before,"Enemy supplements cannot replace class art")
 assert(catalog.open("res://visuals/units.json") and catalog.enemy_errors.is_empty(),"Reopening clears supplemental errors")
 stage.queue_free();await process_frame
 print("PASS: 8 original enemy classes, 96 isolated poses, un-tinted authored colors, spent-state contrast, directional pivots and class fallback")
 quit()
