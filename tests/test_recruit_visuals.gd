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
 var shared_shadow: PlaneMesh
 var full_health: Texture2D
 var enemy_bars={}
 for source in game.roster:
  var unit=source.duplicate(true);unit.team="player";unit.acted=false
  var actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  var individual=catalog.assets.has("recruit."+unit.id)
  assert(individual and actor.visual_id=="recruit."+unit.id,"Every campaign recruit has its own animated identity")
  assert(actor.marker.mesh is PlaneMesh and actor.marker.material_override==Unit.shadow_material(),"Campaign units share a soft contact shadow instead of a solid team plate")
  assert(actor.health.visible and actor.health.texture.get_image().get_pixel(0,0).is_equal_approx(Color("6fb6d3")),"Player health remains visible at full HP with a blue team border")
  if shared_shadow==null:shared_shadow=actor.marker.mesh;full_health=actor.health.texture
  assert(actor.marker.mesh==shared_shadow and actor.health.texture==full_health,"Full health and contact shadows share their resources across the company")
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
  var original=catalog.frame_texture(actor.visual_id,actor.player.frame_index())
  var original_pixels=original.get_image().get_data();var offset=actor.sprite.offset;var scale_value=actor.sprite.scale
  actor.spent=true;actor._process(0)
  var gray=actor.sprite.texture;var image=gray.get_image();var source_image=original.get_image()
  assert(gray==catalog.spent_frame_texture(actor.visual_id,actor.player.frame_index()),"Spent frames reuse their cached grayscale texture")
  assert(not actor.spent_tick.visible and actor.sprite.modulate.r==actor.sprite.modulate.g and actor.sprite.modulate.g==actor.sprite.modulate.b,"Campaign spent state uses an evenly dimmed sprite without a ground check mark")
  assert(actor.sprite.offset==offset and actor.sprite.scale==scale_value and image.get_size()==source_image.get_size(),"Spent state preserves the exact frame size, pivot and facing")
  for y in range(image.get_height()):
   for x in range(image.get_width()):
    var pixel=image.get_pixel(x,y)
    assert(pixel.r==pixel.g and pixel.g==pixel.b and pixel.a==source_image.get_pixel(x,y).a,"Spent pixels are actually grayscale and preserve source transparency")
  assert(original.get_image().get_data()==original_pixels,"Runtime variant cannot alter the source artwork")
  actor.spent=false;actor._process(0)
  assert(actor.sprite.texture==original and actor.sprite.modulate==Color.WHITE,"A fresh turn restores full-color artwork on the same animation frame")
  actor.queue_free()
  var visual_id="recruit."+unit.id;var saved=catalog.assets[visual_id];catalog.assets.erase(visual_id)
  actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  assert(actor.visual_id=="unit."+unit.job.to_lower(),"Missing recruit artwork falls back to the correct class")
  assert(actor.marker.position==Vector3.UP*.03 and actor.marker.scale==Vector3.ONE,"Legacy class sprites use the original radial shadow")
  actor.queue_free();catalog.assets[visual_id]=saved
  unit.team="enemy";actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  assert(actor.visual_id=="enemy."+unit.job.to_lower(),"Enemy figures use army class silhouettes even if an ID matches a recruit")
  for ratio in [1.0,.5,.25,0.0]:
   actor.hp_ratio=ratio;actor.refresh_health()
   if not enemy_bars.has(ratio):enemy_bars[ratio]=actor.health.texture
   assert(actor.health.texture==enemy_bars[ratio] and actor.marker.mesh==shared_shadow)
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
 assert(catalog.open("res://visuals/units.json") and catalog.recruit_errors.is_empty() and catalog.spent_textures.is_empty(),"Reopening resets supplemental errors and presentation cache")
 verify_hoof_shadows(catalog,stage,game)
 stage.queue_free();await process_frame
 print("PASS: 24 original recruit identities, 288 isolated poses, stable density/pivots, directional attacks, shared health bars and shadows, cached grayscale states, class/enemy fallbacks and supplemental validation")
 quit()

func verify_hoof_shadows(catalog,stage: Node3D,game):
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true
 var count=0;var previously_outside=0
 var gradient=Unit.shadow_material().albedo_texture.gradient
 for id in ["bram","una","elian","enemy.rider"]:
  var rider=game.roster.filter(func(unit):return unit.id==("bram" if id=="enemy.rider" else id))[0].duplicate(true)
  rider.team="enemy" if id=="enemy.rider" else "player"
  rider.acted=false
  var actor=Unit.new();stage.add_child(actor);actor.configure(catalog,rider)
  var authored=actor.player.asset.duplicate(true)
  actor.player.asset=authored
  authored.clips.idle.south.frames=range(authored.frames.size())
  actor.player.play("idle","south",true)
  for rotation in [.55,.65]:
   camera.rotation=Vector3(-.8,rotation,0)
   var right=camera.global_basis.x
   for i in range(authored.frames.size()):
    actor.player.index=i;actor.update_frame()
    var frame=authored.frames[i]
    assert(frame.has("hoof_span_px"))
    var original_radius=Vector2(right.x*Unit.CONTACT_SIZE.x,right.z*Unit.CONTACT_SIZE.y).length()*.5
    for edge in frame.hoof_span_px:
     var hoof=(edge-frame.pivot_px[0])*authored.source_pixel_scale*actor.sprite.pixel_size
     var under_hoof=actor.marker.to_local(right*hoof+Vector3.UP*.03)
     assert(gradient.sample(absf(under_hoof.x)/(Unit.CONTACT_SIZE.x*.5)).a>.07,
      "Each measured hoof receives the soft part of the mounted shadow")
     assert(absf(under_hoof.z)<.00001)
     if absf(hoof)>original_radius:previously_outside+=1
    assert(actor.marker.mesh==Unit.contact_mesh and actor.marker.material_override==Unit.shadow_material())
    count+=1
  actor.player.play("act","east",true);actor.player.advance(.13);actor.update_frame()
  var side=actor.marker.position
  actor.player.play("act","west",true);actor.player.advance(.13);actor.update_frame()
  assert(actor.sprite.flip_h and (side+actor.marker.position).is_equal_approx(Vector3.UP*.06))
  actor.queue_free()
 assert(count==96 and previously_outside>0)
 print("PASS: %d mounted shadow poses at two camera headings, a mirrored strike and %d formerly unsupported hoof samples"%[count,previously_outside])
