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
 for dimensions in [Vector2(720,640),Vector2(768,900),Vector2(900,640),Vector2(959,640),Vector2(960,640),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
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
   var reading=app.ui.find_child("RouteObjective",true,false).get_parent().get_parent()
   assert(reading.size.x>=212 and reading.size.y>=160,"Compact briefing retains its reading area")
   for index in range(12):
    var marker=route.markers[index]
    assert(marker.size.x>=23.999 and marker.size.y>=23.999,"Chapter %d seal at %s retains a usable hit target, got %s"%[index+1,dimensions,marker.size])
    assert(marker.get_rect().get_center().is_equal_approx(route.point(index)),"The seal and its hit target share a center")
    assert(bounds.encloses(marker.get_rect()),"Chapter marker stays on the map control")
    for other in range(index):assert(not marker.get_rect().intersects(route.markers[other].get_rect()),"Neighboring chapter hit targets never overlap: viewport %s, control %s, map %s"%[dimensions,route.size,route.map_rect])
    if index==chapter:assert(bounds.encloses(Rect2(route.point(index)-Vector2(20,41),Vector2(40,61))),"Current standard and pulse stay inside the display")
    assert(marker.disabled==(index>chapter),"Future chapters remain unavailable")
    var prior=route.selected;route.select_chapter(index)
    assert(route.selected==(prior if index>chapter else index),"Locked chapter cannot reveal its briefing even through programmatic selection")
    assert(app.ui.find_child("RouteObjective",true,false).text=="OBJECTIVE / "+app.objective_text(app.game.content.chapters[route.selected]),"Historical objective follows the selected briefing without changing the current chapter")
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
 var completed_state=app.game.save_data("camp").duplicate(true)
 var viewport=app.get_viewport()
 viewport.size=Vector2i(1440,900)
 route.markers[0].grab_focus()
 app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=Vector2(720,640)
 await process_frame;await process_frame
 assert(viewport.gui_get_focus_owner()==route.markers[0] and route.markers[0].size.x<36,"Focused markers survive live shrink")
 for pressed in [true,false]:
  var key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=pressed;viewport.push_input(key,true)
 assert(route.selected==0,"Keyboard opens the focused compact briefing")
 for index in range(1,12):
  var click_point=route.markers[index].get_global_rect().get_center()
  for pressed in [true,false]:
   var mouse=InputEventMouseButton.new();mouse.position=click_point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed;viewport.push_input(mouse,true)
  assert(route.selected==index,"Pointer opens exactly the chosen compact briefing")
 app.ui.size=Vector2(1440,900)
 await process_frame;await process_frame
 assert(route.selected==11 and route.markers[11].size.x==36,"Live expansion retains the selected briefing")
 assert(app.game.save_data("camp")==completed_state,"Navigation never changes the completed campaign")
 app.game.completed=false;app.game.chapter=5
 app.game.trials.configure_section_starts([0,3,7],app.game.content.chapters.size())
 app.show_campaign_route();await process_frame;await process_frame
 route=app.ui.find_child("CampaignRoute",true,false)
 assert(route.retreat_chapter==3 and "Current retreat point" in route.markers[3].tooltip_text)
 assert(not "start" in route.markers[4].tooltip_text and route.markers[7].tooltip_text=="Unreached destination")
 assert("Chapter 04" in app.ui.find_child("RouteLegend",true,false).text)
 assert(app.ui.find_child("RouteSection",true,false).text=="SECTION 2 · CHAPTERS 04–07")
 route.select_chapter(2)
 assert(app.ui.find_child("RouteSection",true,false).text=="SECTION 1 · CHAPTERS 01–03")
 app.show_camp();await process_frame
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return label.text=="Section 2 · Rally point Chapter 04"))
 app.debug_session.begin(app.game,"camp")
 assert(app.debug_session.report(app.game,"camp").section==2)
 app.debug_session.end(app.game)
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," campaign route layouts, all twelve chapter markers selectable at 720, live focus and reflow, locked briefing protection, read-only campaign state and Escape return")
 print("PASS: unequal section ranges and reached rally points agree in the route, war council and Debug report")
 quit()
