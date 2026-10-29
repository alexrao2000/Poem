extends SceneTree
# Validate supplemental identity sheets without changing the portable class
# catalog: complete clips, clear frame edges, stable density and enemy fallback.
const Catalog=preload("res://scripts/campaign_catalog.gd")
const Unit=preload("res://scripts/campaign_map_unit.gd")
const Rules=preload("res://scripts/rules.gd")
const OPENING=["lyra","oren","sera","ivo","mara","tarin","nell","bram"]
func _initialize():call_deferred("run")
func run():
 var catalog=Catalog.new();assert(catalog.open("res://visuals/units.json") and catalog.recruit_errors.is_empty())
 assert(catalog.assets.size()==16,"Opening roster extends eight base classes")
 var game=Rules.new();var stage=Node3D.new();root.add_child(stage)
 var image=load("res://assets/sprites/opening-animated-v1.png").get_image()
 assert(image.get_pixel(0,0).a==0,"Original atlas retains transparent alpha")
 for source in game.roster:
  var unit=source.duplicate(true);unit.team="player";unit.acted=false
  var actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  var individual=unit.id in OPENING
  assert(actor.visual_id==("recruit."+unit.id if individual else "unit."+unit.job.to_lower()),"Named identity or matching class fallback selected")
  if individual:
   var entry=catalog.assets[actor.visual_id]
   assert(entry.frames.size()==12 and entry.source_pixel_scale==.5)
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
     assert(actor.sprite.scale==Vector3(.5,.5,1),"Variable frame crops retain one source-pixel density")
     var frame=entry.frames[actor.player.frame_index()]
     assert(actor.sprite.offset==Vector2(-frame.pivot_px[0],frame.pivot_px[1]-frame.rect[3]),"Pose retains its indexed foot pivot")
  actor.queue_free()
  unit.team="enemy";actor=Unit.new();stage.add_child(actor);actor.configure(catalog,unit)
  assert(actor.visual_id=="unit."+unit.job.to_lower(),"Enemy figures retain class silhouettes even if an ID matches a recruit")
  actor.queue_free()
 var keys=catalog.assets.keys();var textures=catalog.textures.keys()
 assert(not catalog.add_recruits("res://visuals/units.json"),"Supplemental catalog cannot overwrite base classes")
 assert(catalog.assets.keys()==keys and catalog.textures.keys()==textures,"Rejected supplement leaves the active catalog intact")
 assert(not catalog.add_recruits("res://data/campaign.json") and catalog.assets.keys()==keys,"Malformed supplement preserves class fallback")
 assert(catalog.open("res://visuals/units.json") and catalog.recruit_errors.is_empty(),"Reopening resets supplemental errors")
 stage.queue_free();await process_frame
 print("PASS: eight original recruit identities, 96 isolated poses, stable density/pivots, all class/enemy fallbacks and supplemental validation")
 quit()
