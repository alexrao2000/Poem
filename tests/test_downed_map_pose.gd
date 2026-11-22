extends SceneTree
const Catalog=preload("res://scripts/campaign_catalog.gd")
const Unit=preload("res://scripts/campaign_map_unit.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var catalog=Catalog.new();assert(catalog.open("res://visuals/units.json"))
 var world=Node3D.new();root.add_child(world);world.position=Vector3(3,0,2)
 var camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position=Vector3(5,12,11);camera.look_at(world.global_position,Vector3.UP);camera.current=true
 var rules=Rules.new();var actors=[];var poses=0;var bounds=0
 for source in rules.roster:
  var identity="recruit."+source.id;var saved=catalog.assets[identity]
  for fallback in [false,true]:
   if fallback:catalog.assets.erase(identity)
   for spent in [false,true]:
    for facing in ["north","east","south","west"]:
     var unit=source.duplicate(true);unit.team="player";unit.acted=spent;unit.hp=0;unit.downed=true;unit.bleed_turns=1 if spent else 2
     var actor=Unit.new();world.add_child(actor);actor.configure(catalog,unit,facing);actor.set_process(false)
     assert(actor.visual_id==("unit."+source.job.to_lower() if fallback else identity))
     var hurt=int(actor.player.asset.clips.hurt[facing].frames[-1])
     assert(hurt not in actor.player.asset.clips.idle[facing].frames,"Every downed silhouette uses artwork distinct from standing idle")
     var original=catalog.frame_texture(actor.visual_id,hurt);var original_data=original.get_image().get_data()
     for elapsed in [0.0,.2,1.0,10.0]:
      actor._process(elapsed)
      assert(actor.player.state=="hurt" and actor.player.complete and actor.player.frame_index()==hurt,"Wounded pose holds without restarting or cycling back to standing")
      assert(actor.sprite.texture==(catalog.spent_frame_texture(actor.visual_id,hurt) if spent else original) and actor.sprite.modulate.a==1,"The complete wounded frame stays fully visible, including spent variants")
      assert(actor.sprite.rotation==Vector3.ZERO and actor.sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED,"Wounded presentation uses the authored frame without ineffective billboard rotation")
     actor.face_toward(Vector2i.LEFT,Vector2i.ZERO);actor.finish_move();actor._process(.1)
     assert(actor.player.state=="hurt" and actor.player.complete and actor.player.facing=="west","Facing and movement cleanup retain the held wounded state")
     assert(original.get_image().get_data()==original_data,"Presentation leaves shared artwork intact")
     actor.selected=true;actor.set_tactical_details_visible(false);actor.refresh_health();actor._process(.2)
     assert(not actor.health.visible and not actor.ring.visible and not actor.rescue_marker.visible,"Enlarged cinematic handoffs suppress refreshed health, selection and rescue badges")
     assert(actor.sprite.visible and actor.marker.visible and actor.player.state=="hurt" and actor.rescue_marker.get_meta("turns")==unit.bleed_turns,"Hidden tactical details retain wounded artwork, shadow and countdown data")
     actor.set_tactical_details_visible(true);actor._process(0)
     assert(actor.health.visible and actor.ring.visible and actor.rescue_marker.visible,"Map control restores the same selection and patient countdown")
     actor.rest_pose(facing);actor._process(0)
     actors.append(actor);poses+=1
   catalog.assets[identity]=saved
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=dimensions;await process_frame;await process_frame
  for zoom in [10.0,18.0]:
   camera.size=zoom
   for actor in actors:
    var rect=actor.screen_bounds(camera);var texture_size=actor.sprite.texture.get_size();var scale=actor.sprite.scale*actor.sprite.pixel_size
    var anchor=actor.sprite.global_position
    # Reconstruct the camera-facing quad independently from the sprite's
    # authored pixel rectangle and transformed foot pivot.
    for x in [0.0,texture_size.x]:
     for y in [0.0,texture_size.y]:
      var point=anchor+camera.global_basis.x*(x+actor.sprite.offset.x)*scale.x+camera.global_basis.y*(y+actor.sprite.offset.y)*scale.y
      assert(rect.grow(.01).has_point(camera.unproject_position(point)),"Pointer bounds contain the complete held wounded quad")
    assert(rect.has_point(camera.unproject_position(actor.rescue_marker.global_position)),"The countdown badge stays in the same clickable unit bounds")
    bounds+=1
 for team in ["player","enemy"]:
  var unit=rules.roster[0].duplicate(true);unit.team=team;unit.acted=false;unit.boss=team=="enemy"
  var actor=Unit.new();world.add_child(actor);actor.configure(catalog,unit,"south","Oren",2);actor.set_process(false);actor.selected=true
  for visible in [false,true,false,true]:
   actor.set_tactical_details_visible(visible);actor._process(.1)
   assert(actor.health.visible==visible and actor.ring.visible==visible and actor.carry_marker.visible==visible and actor.shared_marker.visible==visible)
   if team=="enemy":assert(actor.commander_insignia.visible==visible)
   assert(actor.sprite.visible and actor.marker.visible and actor.carry_marker.get_meta("passenger")=="Oren" and actor.shared_marker.get_meta("count")==2,"Repeated handoffs preserve carrier, shared-tile and commander details")
 world.queue_free();await process_frame
 print("PASS: ",poses," wounded roster/class-fallback/facing/spent poses hold through time and facing cleanup; ",bounds," three-size/two-zoom quad and countdown bounds; full visibility, fixed foot anchors and unchanged shared art");quit()
