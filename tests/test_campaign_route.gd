extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
## Read-only route navigation preserves the campaign, prevents locked briefing
## access, and keeps fitted markers/standard inside the display at every size.
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-route-test.json";root.add_child(app);await process_frame
 for chapter in range(12):app.game.story_seen.append("opening_"+str(chapter))
 app.game.permadeath=true;app.game.trials.flags.section_restarts=true
 var count=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  for chapter in range(12):
   app.game.chapter=chapter
   var roster=app.game.roster.duplicate(true);var deployed=app.game.deployed.duplicate();var seen=app.game.story_seen.duplicate()
   app.show_campaign_route()
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
   await process_frame;await process_frame
   assert(app.ui.size==dimensions)
   var route=app.ui.find_child("CampaignRoute",true,false)
   assert(route!=null and route.markers.size()==12 and route.selected==chapter and route.section_starts)
   assert("Chapter %02d"%(int(chapter/4)*4+1) in app.ui.find_child("RouteLegend",true,false).text,"The legend identifies the actual retreat point")
   assert(Rect2(Vector2.ZERO,dimensions).encloses(route.get_global_rect()),"The complete route control fits the requested viewport")
   for node in app.ui.find_children("*","Control",true,false):
    var parent=node.get_parent();var clipped=false
    while parent!=app.ui:
     if parent is ScrollContainer:clipped=true;break
     parent=parent.get_parent()
    if node.is_visible_in_tree() and not clipped:assert(Rect2(Vector2.ZERO,dimensions).grow(1).encloses(node.get_global_rect()),"Route details, legend and return control fit the requested viewport")
   var bounds=Rect2(Vector2.ZERO,route.size)
   assert(bounds.encloses(route.map_rect) and absf(route.map_rect.size.x/route.map_rect.size.y-1.5)<.001,"Map fits without stretching or cropping")
   for index in range(12):
    var marker=route.markers[index]
    assert(bounds.encloses(marker.get_rect()),"Chapter marker stays on the map control")
    for other in range(index):assert(not marker.get_rect().intersects(route.markers[other].get_rect()),"Neighboring chapter hit targets never overlap: viewport %s, control %s, map %s"%[dimensions,route.size,route.map_rect])
    if index==chapter:assert(bounds.encloses(Rect2(route.point(index)-Vector2(20,41),Vector2(40,61))),"Current standard and pulse stay inside the display")
    assert(marker.disabled==(index>chapter),"Future chapters remain unavailable")
    var prior=route.selected;route.select_chapter(index)
    assert(route.selected==(prior if index>chapter else index),"Locked chapter cannot reveal its briefing even through programmatic selection")
    if index>chapter:assert(marker.tooltip_text=="Unreached destination")
    elif index%4==0:
     assert("Section %d start"%(int(index/4)+1) in marker.tooltip_text)
     assert(("Current retreat point" in marker.tooltip_text)==(index==int(chapter/4)*4))
     assert(bounds.encloses(Rect2(route.point(index)-Vector2(20,20),Vector2(40,40))),"Section diamonds stay inside the route display")
   route.markers[0].pressed.emit();assert(app.ui.find_child("RouteSection",true,false).text=="SECTION 1 · CHAPTERS 01–04","Historical selections show their own section without changing the current retreat point")
   assert(route.selected==0,"Real marker button selects the reached briefing")
   assert(app.game.chapter==chapter and app.game.roster==roster and app.game.deployed==deployed and app.game.story_seen==seen,"Route browsing never mutates campaign progression, deployment or story flags")
   var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;app._unhandled_input(escape)
   assert(app.screen=="camp","Escape returns to the war council")
   count+=1
 app.show_camp();await process_frame
 var entry=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Route")[0]
 entry.pressed.emit();assert(app.screen=="campaign_route","War council exposes the route through its real button")
 for mode in ["permadeath_off","sections_off"]:
  app.game.permadeath=mode!="permadeath_off";app.game.trials.flags.section_restarts=mode!="sections_off"
  app.show_campaign_route();await process_frame
  var plain=app.ui.find_child("CampaignRoute",true,false)
  assert(not plain.section_starts and not app.ui.find_child("RouteSection",true,false).visible and not "retreat point" in app.ui.find_child("RouteLegend",true,false).text,"Route section aids follow the active rule combination")
 app.game.permadeath=true;app.game.trials.flags.section_restarts=true
 app.game.completed=true;app.show_campaign_route();await process_frame
 var route=app.ui.find_child("CampaignRoute",true,false)
 assert(not "Current retreat point" in route.markers[8].tooltip_text and "complete" in app.ui.find_child("RouteLegend",true,false).text)
 assert(route.markers.all(func(marker):return not marker.disabled),"Completed campaign can review every briefing")
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," campaign route layouts, all twelve chapter markers, locked briefing protection, real button selection, read-only campaign state and Escape return")
 quit()
