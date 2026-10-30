extends SceneTree
# Validate supplemental identity sheets without changing the portable class
# catalog: complete clips, clear frame edges, stable density and enemy fallback.
const Catalog=preload("res://scripts/campaign_catalog.gd")
const Unit=preload("res://scripts/campaign_map_unit.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var catalog=Catalog.new();assert(catalog.open("res://visuals/units.json") and catalog.recruit_errors.is_empty())
 assert(catalog.assets.size()==40,"Full roster and enemy army extend eight base classes")
 var game=Rules.new();var stage=Node3D.new();root.add_child(stage)
 for source in game.roster:
  var unit=source.duplicate(true);unit.team="player";unit.acted=false
  var actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  var individual=catalog.assets.has("recruit."+unit.id)
  assert(individual and actor.visual_id=="recruit."+unit.id,"Every campaign recruit has its own animated identity")
  assert(actor.marker.mesh is PlaneMesh and actor.marker.material_override==Unit.shadow_material(),"Campaign units share a soft contact shadow instead of a solid team plate")
  assert(actor.health.visible and actor.health.texture.get_image().get_pixel(0,0).is_equal_approx(Color("6fb6d3")),"Player health remains visible at full HP with a blue team border")
  var extent=actor.sprite.texture.get_size()*Vector2(actor.sprite.scale.x,actor.sprite.scale.y)*actor.sprite.pixel_size
  assert(extent.y>=.8 and extent.y<=1.2 and extent.x<=1.15,"Idle recruit silhouettes stay near one tile tall without crowding adjacent tiles")
  if individual:
   var entry=catalog.assets[actor.visual_id]
   var image=catalog.textures[actor.visual_id].get_image()
   assert(image.get_pixel(0,0).a==0,"Original atlas retains transparent alpha")
   assert(entry.frames.size()==12 and entry.source_pixel_scale>0)
   for frame in entry.frames:
    var r=frame.rect;var coverage=0
    for y in range(r[3]):
     for x in range(r[2]):
      if image.get_pixel(r[0]+x,r[1]+y).a>.4:
       coverage+=1
       assert(x>0 and y>0 and x<r[2]-1 and y<r[3]-1,"No pose clips into an adjacent figure")
    assert(coverage>100,"Every pose has a full visible figure")
   for state in ["idle","move","act","hurt","defeated"]:
    for facing in ["north","south","east","west"]:
     actor.player.play(state,facing,true);actor.update_frame()
     assert(actor.sprite.scale==Vector3(entry.source_pixel_scale,entry.source_pixel_scale,1),"Variable frame crops retain one source-pixel density")
     var frame=entry.frames[actor.player.frame_index()]
     assert(actor.sprite.offset==Vector2(-frame.pivot_px[0],frame.pivot_px[1]-frame.rect[3]),"Pose retains its indexed foot pivot")
   actor.player.play("act","west",true);actor.player.advance(.13);actor.update_frame()
   var contact=entry.frames[actor.player.frame_index()]
   assert(actor.sprite.flip_h and actor.sprite.offset.x==contact.pivot_px[0]-contact.rect[2],"West attack mirrors the right-facing pose around its foot pivot")
   actor.player.play("act","east",true);actor.player.advance(.13);actor.update_frame()
   assert(not actor.sprite.flip_h and actor.sprite.offset.x==-contact.pivot_px[0],"Changing facing on the same frame restores the original pivot")
  actor.queue_free()
  var visual_id="recruit."+unit.id;var saved=catalog.assets[visual_id];catalog.assets.erase(visual_id)
  actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  assert(actor.visual_id=="unit."+unit.job.to_lower(),"Missing recruit artwork falls back to the correct class")
  actor.queue_free();catalog.assets[visual_id]=saved
  unit.team="enemy";actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  assert(actor.visual_id=="enemy."+unit.job.to_lower(),"Enemy figures use army class silhouettes even if an ID matches a recruit")
  for ratio in [1.0,.5,.25,0.0]:
   actor.hp_ratio=ratio;actor.refresh_health()
   var bar=actor.health.texture.get_image()
   assert(actor.health.visible and bar.get_pixel(0,0).is_equal_approx(Color("d77870")),"Enemy health keeps its red border at every HP level")
   var fill=Color("acd86b") if ratio>.5 else Color("f2c45e") if ratio>.25 else Color("e87c63")
   for x in range(1,23):assert(bar.get_pixel(x,1).is_equal_approx(fill if x<=roundi(22*ratio) else Color("172b30")),"HP fill and low-health colors match the displayed fraction")
  extent=actor.sprite.texture.get_size()*Vector2(actor.sprite.scale.x,actor.sprite.scale.y)*actor.sprite.pixel_size
  assert(extent.x<=1.15 and extent.y<=1.2,"Enemy fallback art shares the compact campaign scale")
  actor.queue_free()
 var keys=catalog.assets.keys();var textures=catalog.textures.keys()
 assert(not catalog.add_recruits("res://visuals/units.json"),"Supplemental catalog cannot overwrite base classes")
 assert(catalog.assets.keys()==keys and catalog.textures.keys()==textures,"Rejected supplement leaves the active catalog intact")
 assert(not catalog.add_recruits("res://data/campaign.json") and catalog.assets.keys()==keys,"Malformed supplement preserves class fallback")
 assert(catalog.open("res://visuals/units.json") and catalog.recruit_errors.is_empty(),"Reopening resets supplemental errors")
 stage.queue_free();await process_frame
 print("PASS: 24 original recruit identities, 288 isolated poses, stable density/pivots, directional attacks, class/enemy fallbacks and supplemental validation")
 quit()
