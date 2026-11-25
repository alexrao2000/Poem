extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Valley=preload("res://scripts/world_map_battle.gd")
const Route=preload("res://scripts/campaign_route.gd")
## Read-only route navigation preserves the campaign, prevents locked briefing
## access, and keeps fitted markers/standard inside the display at every size.
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-route-test-%d.json"%OS.get_process_id();root.add_child(app);await process_frame
 for chapter in range(12):app.game.story_seen.append("opening_"+str(chapter))
 app.game.permadeath=true;app.game.trials.flags.section_restarts=true
 assert(app.game.content.chapters.filter(func(chapter):return chapter.has("route_note")).map(
  func(chapter):return chapter.place)==["Reed Crossing","Hallow Abbey","Old Aqueduct","Starfall"])
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
   assert(not app.ui.find_child("ReachedChapters",true,false).visible,"The illustrated route is enough when every seal has room")
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
    var active_pin=app.game.content.chapters[route.selected].route_position
    var active_mark=Valley.survey_mark(Valley.route_tile(active_pin))
    assert(app.ui.find_child("RouteSurveyMark",true,false).text==active_mark)
    var note=app.ui.find_child("RouteNote",true,false)
    assert(note.text==app.game.content.chapters[route.selected].get("route_note","") and note.visible==not note.text.is_empty())
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
 assert(app.ui.find_child("RouteSurveyMark",true,false).text=="V-2")
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
 await verify_longer_route(app)
 await verify_retreat_route(app)
 await verify_atlas_draws(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," campaign route layouts, all twelve chapter markers selectable at 720, live focus and reflow, locked briefing protection, read-only campaign state and Escape return")
 print("PASS: unequal section ranges and reached rally points agree in the route, war council and Debug report")
 print("PASS: four stock survey notes stay with their reached briefings at all eight viewport sizes")
 quit()

func observe_atlas_draws(route,frames: int) -> Array:
 var counts=[0,0]
 var atlas=func():counts[0]+=1
 var pulse=func():counts[1]+=1
 var active=route.markers[route.current]
 route.draw.connect(atlas);active.draw.connect(pulse)
 for _frame in frames:await process_frame
 route.draw.disconnect(atlas);active.draw.disconnect(pulse)
 return counts

func verify_atlas_draws(app):
 app.show_campaign_route();await process_frame;await process_frame
 var reading=app.ui.find_child("CampaignRoute",true,false)
 var live=await observe_atlas_draws(reading,12)
 assert(live[0]==0 and live[1]>0,"The current seal animates separately from the atlas")
 reading.select_chapter(0)
 var changed=await observe_atlas_draws(reading,4)
 assert(changed[0]>0,"Selecting a chapter redraws the atlas")
 var editor=Route.new();root.add_child(editor);editor.size=Vector2(640,420)
 editor.configure(app.game.content.chapters,3,true);editor.enable_pin_editor()
 await process_frame;await process_frame
 assert(await observe_atlas_draws(editor,12)==[0,0],"An idle authoring chart is static")
 editor.place_pin(Vector2(.37,.48))
 changed=await observe_atlas_draws(editor,4)
 assert(changed[0]>0,"Placing an authored pin redraws the chart")
 editor.queue_free();await process_frame
 print("PASS: the active seal animates without redrawing the atlas, and authored pins redraw only when changed")

func verify_retreat_route(app):
 app.game.chapter=11
 app.game.trials.flags.reset_pressure=true
 app.game.start_battle();app.make_map();app.show_battle()
 var leader=app.game.living("player").filter(func(unit):return unit.id=="lyra")[0]
 leader.hp=0
 assert(await app.check_result() and app.game.result()=="defeat")
 var before=app.game.save_data("battle").duplicate(true)
 var disk=FileAccess.get_file_as_string(app.save_path)
 for dimensions in [Vector2(720,640),Vector2(1440,900)]:
  app.ui.find_child("ViewRallyOnAtlas",true,false).pressed.emit()
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  var route=app.ui.find_child("CampaignRoute",true,false)
  assert(app.screen=="retreat_route" and route.current==11 and route.selected==8 and route.show_retreat_path)
  assert(route.retreat_chapter==8 and "Current retreat point" in route.markers[8].tooltip_text)
  assert(Rect2(Vector2.ZERO,dimensions).encloses(route.get_global_rect()))
  assert(app.ui.find_child("RouteLegend",true,false).text.begins_with("Arrows point back to the rally"))
  route.markers[0].pressed.emit()
  assert(route.selected==0 and route.retreat_chapter==8)
  if dimensions.x==720:
   var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE
   app._unhandled_input(escape)
  else:
   var back=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to result")[0]
   back.pressed.emit()
  assert(app.screen=="result" and app.ui.find_child("ViewRallyOnAtlas",true,false).has_focus())
  assert(app.game.save_data("battle")==before and FileAccess.get_file_as_string(app.save_path)==disk)
  app.ui.find_child("PreviewRallyCompany",true,false).pressed.emit()
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  var roster=app.ui.find_child("RallyCompanyRoster",true,false)
  assert(app.screen=="rally_company" and "Chapter 09 · Starfall" in app.ui.find_child("RallyCompanyLocation",true,false).text)
  assert(Rect2(Vector2.ZERO,dimensions).encloses(roster.get_global_rect()))
  assert(roster.find_child("RallyRoster_lyra",true,false)!=null)
  app.ui.find_child("PreviewRallyEnemies",true,false).pressed.emit()
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  var table=app.ui.find_child("DebugRetryEnemies",true,false)
  assert(app.screen=="rally_enemies" and app.ui.find_child("DebugRetryPressure",true,false).text=="Chapter 09 · Pressure 0 → 1")
  assert(Rect2(Vector2.ZERO,dimensions).encloses(table.get_parent().get_global_rect()))
  var return_to_company=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to rally company [Esc]")[0]
  return_to_company.pressed.emit()
  assert(app.screen=="rally_company" and app.ui.find_child("PreviewRallyEnemies",true,false).has_focus())
  if dimensions.x==720:
   var retreat_escape=InputEventKey.new();retreat_escape.pressed=true;retreat_escape.keycode=KEY_ESCAPE
   app._unhandled_input(retreat_escape)
  else:
   var roster_back=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to result [Esc]")[0]
   roster_back.pressed.emit()
  assert(app.screen=="result" and app.ui.find_child("PreviewRallyCompany",true,false).has_focus())
  assert(app.game.save_data("battle")==before and FileAccess.get_file_as_string(app.save_path)==disk)
 app.game.trials.flags.section_restarts=false
 app.show_battle_result("defeat")
 assert(app.ui.find_child("ViewRallyOnAtlas",true,false)==null)
 assert(app.ui.find_child("PreviewRallyCompany",true,false)==null)
 print("PASS: defeat previews the actual rally on the atlas and returns read-only by button or Escape")
 print("PASS: defeat previews the rally roster at narrow and desktop sizes and returns to the unchanged result")
 print("PASS: the actual rally compares prepared enemies before committing and leaves the result save unchanged")

func verify_longer_route(app):
 var original=app.game.content.chapters.duplicate(true)
 for sample in [["Across the Ridge",Vector2.ZERO],["The Eastern Road",Vector2(.90,.76)]]:
  var chapter=original[0].duplicate(true)
  chapter.title=sample[0]
  chapter.route_position=[sample[1].x,sample[1].y]
  app.game.content.chapters.append(chapter)
 app.game.trials.configure_section_starts([0,3,7,12],app.game.content.chapters.size())
 app.game.chapter=12
 for dimensions in [Vector2(720,640),Vector2(1024,640),Vector2(1440,900)]:
  app.show_campaign_route()
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  var route=app.ui.find_child("CampaignRoute",true,false)
  assert(route.markers.size()==14 and route.selected==12 and route.markers[13].disabled)
  assert(route.point(12).is_equal_approx(route.map_rect.position),"A seal can sit on the authored map corner")
  assert(app.ui.find_child("RouteSurveyMark",true,false).text=="A-1")
  var bounds=Rect2(Vector2.ZERO,route.size).grow(.001)
  assert(bounds.encloses(Rect2(route.point(12)-Vector2(20,41),Vector2(40,61))),"Even a corner seal keeps its standard inside the route")
  assert(app.ui.find_child("RouteSection",true,false).text=="SECTION 4 · CHAPTERS 13–14")
  for index in range(route.markers.size()):
   var hit=route.markers[index].get_rect()
   assert(bounds.encloses(hit))
   for earlier in range(index):
    assert(not hit.intersects(route.markers[earlier].get_rect()),"Each seal has a separate hit target in the larger authored route")
  route.select_chapter(13);assert(route.selected==12)
  route.markers[12].pressed.emit()
  assert("Across the Ridge" in route.markers[12].tooltip_text)
 app.game.chapter=13;app.show_campaign_route();await process_frame
 var finished=app.ui.find_child("CampaignRoute",true,false)
 assert(not finished.markers[13].disabled and finished.selected==13 and "The Eastern Road" in finished.markers[13].tooltip_text)
 app.game.content.chapters[13].route_position=app.game.content.chapters[12].route_position.duplicate()
 app.game.chapter=12;app.show_campaign_route();await process_frame;await process_frame
 var chooser=app.ui.find_child("ReachedChapters",true,false)
 var crowded=app.ui.find_child("CampaignRoute",true,false)
 assert(chooser.visible and chooser.item_count==13 and crowded.markers[13].disabled,"Overlapping seals offer a list of only reached chapters")
 chooser.select(0);chooser.item_selected.emit(0)
 assert(crowded.selected==0 and "OBJECTIVE / " in app.ui.find_child("RouteObjective",true,false).text)
 crowded.select_chapter(12);assert(chooser.selected==12)
 app.game.chapter=13;app.show_campaign_route();await process_frame;await process_frame
 chooser=app.ui.find_child("ReachedChapters",true,false)
 assert(chooser.visible and chooser.item_count==14 and chooser.get_item_text(13)=="14 · The Eastern Road")
 app.game.content.chapters[13].route_position=[.13,.64]
 app.show_campaign_route()
 app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=Vector2(720,640)
 await process_frame;await process_frame
 chooser=app.ui.find_child("ReachedChapters",true,false)
 var reflow=app.ui.find_child("CampaignRoute",true,false)
 assert(chooser.visible)
 chooser.grab_focus()
 app.ui.size=Vector2(1440,900)
 await process_frame;await process_frame
 assert(not chooser.visible and app.get_viewport().gui_get_focus_owner()==reflow.markers[13],"When seals separate, focus follows the selected chapter")
 app.game.content.chapters[13].route_position=[1.0/3.0-.000000000001,.125-.000000000001]
 app.show_campaign_route();await process_frame
 assert(app.ui.find_child("RouteSurveyMark",true,false).text=="H-2","Pins immediately before a tile edge retain the authored survey cell")
 app.game.content.chapters=original
 app.game.trials.configure_section_starts(app.game.content.section_starts,original.size())
 app.game.chapter=11
 print("PASS: a fourteen-chapter authored route keeps every seal selectable through three sizes and lets players review overlapping reached seals")
