extends SceneTree
## Read-only route navigation preserves the campaign, prevents locked briefing
## access, and keeps fitted markers/standard inside the display at every size.
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-route-test.json";root.add_child(app);await process_frame
 for chapter in range(12):app.game.story_seen.append("opening_"+str(chapter))
 var count=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  for chapter in range(12):
   app.game.chapter=chapter
   var roster=app.game.roster.duplicate(true);var deployed=app.game.deployed.duplicate();var seen=app.game.story_seen.duplicate()
   app.show_campaign_route();await process_frame;await process_frame
   var route=app.ui.find_child("CampaignRoute",true,false)
   assert(route!=null and route.markers.size()==12 and route.selected==chapter)
   var bounds=Rect2(Vector2.ZERO,route.size)
   assert(bounds.encloses(route.map_rect) and absf(route.map_rect.size.x/route.map_rect.size.y-1.5)<.001,"Map fits without stretching or cropping")
   for index in range(12):
    var marker=route.markers[index]
    assert(bounds.encloses(marker.get_rect()),"Chapter marker stays on the map control")
    for other in range(index):assert(not marker.get_rect().intersects(route.markers[other].get_rect()),"Neighboring chapter hit targets never overlap")
    if index==chapter:assert(bounds.encloses(Rect2(route.point(index)-Vector2(20,41),Vector2(40,61))),"Current standard and pulse stay inside the display")
    assert(marker.disabled==(index>chapter),"Future chapters remain unavailable")
    var prior=route.selected;route.select_chapter(index)
    assert(route.selected==(prior if index>chapter else index),"Locked chapter cannot reveal its briefing even through programmatic selection")
    if index>chapter:assert(marker.tooltip_text=="Unreached destination")
   route.markers[0].pressed.emit();assert(route.selected==0,"Real marker button selects the reached briefing")
   assert(app.game.chapter==chapter and app.game.roster==roster and app.game.deployed==deployed and app.game.story_seen==seen,"Route browsing never mutates campaign progression, deployment or story flags")
   var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;app._unhandled_input(escape)
   assert(app.screen=="camp","Escape returns to the war council")
   count+=1
 app.show_camp();await process_frame
 var entry=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Route")[0]
 entry.pressed.emit();assert(app.screen=="campaign_route","War council exposes the route through its real button")
 app.game.completed=true;app.show_campaign_route();await process_frame
 var route=app.ui.find_child("CampaignRoute",true,false)
 assert(route.markers.all(func(marker):return not marker.disabled),"Completed campaign can review every briefing")
 app.queue_free();await process_frame
 print("PASS: ",count," campaign route layouts, all twelve chapter markers, locked briefing protection, real button selection, read-only campaign state and Escape return")
 quit()
