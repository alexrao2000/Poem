extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")

func settle():
 for index in range(4):await process_frame

func card(app,id: String):return app.ui.find_child("Company_"+id,true,false)

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-company-test.json"
 root.add_child(app);await process_frame
 for chapter in range(12):app.game.story_seen.append("opening_"+str(chapter))
 var original=app.game.roster.duplicate(true);var rng=app.game.rng.state
 for chapter in range(12):
  app.game.chapter=chapter;app.show_camp();await settle()
  for node in [app.world,app.pieces,app.markers]:assert(not node.visible and node.process_mode==Node.PROCESS_MODE_DISABLED,"Opaque council suspends covered map rendering and animation")
  var cards=app.ui.find_child("CompanyCards",true,false)
  assert(cards.columns==2 and cards.get_child_count()==24,"The full roster uses a compact two-column grid")
  for unit in app.game.roster:
   var entry=card(app,unit.id);var available=unit.join<=chapter
   assert(entry.portrait_button.disabled==not available,"Future recruits stay unavailable")
   var expected_art=app.portraits.get_portrait(unit.id) if available else app.map_catalog.preview_sprite(unit)
   assert(entry.portrait_button.icon==expected_art,"Locked recruit cards use the same frames as the battlefield")
   assert(entry.find_child("WeaponIcon",true,false).texture.resource_path=="res://assets/ui/items/"+app.game.item_for(unit).id+".svg","Company card art matches its actual equipped item")
   var supplies=entry.find_child("DeploymentSupplies",true,false)
   if available:assert(supplies!=null and supplies.text=="2 field tonics","Available recruits preview their ordinary starting supplies")
   else:assert(supplies==null,"Locked recruits do not advertise usable supplies")
   assert(entry.deploy_button.disabled==(not available or (app.game.deployed.size()>=6 and unit.id not in app.game.deployed)))
   if unit.id in app.game.deployed:assert(entry.state_label.text=="IN COMPANY")
   elif available:assert(entry.state_label.text=="RESERVE")
 app.game.chapter=11;app.game.deployed=[]
 for index in range(18,24):app.game.deployed.append(app.game.roster[index].id)
 var patient=app.game.roster[-1];app.game.trials.flags.sacrifice_cost=true;app.game.trials.injuries[patient.id]=11
 app.game.start_battle()
 var returning=app.game.units.filter(func(unit):return unit.id==patient.id)[0]
 var layouts=[Vector2(720,640),Vector2(768,900),Vector2(959,640),Vector2(960,640),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]
 for dimensions in layouts:
  app.show_camp();app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;await settle()
  var grid=app.ui.find_child("CompanyCards",true,false)
  var viewport=Rect2(Vector2.ZERO,dimensions)
  var roster_scroll=app.ui.find_child("CompanyScroll",true,false)
  assert(grid.columns==(1 if dimensions.x<960 else 2) and grid.get_child_count()==24)
  assert(viewport.encloses(roster_scroll.get_global_rect()))
  var position_button=app.ui.find_child("OpenFormation",true,false)
  var deploy_button=position_button.get_parent().get_child(0)
  assert(viewport.encloses(position_button.get_global_rect()) and viewport.encloses(deploy_button.get_global_rect()))
  for entry in grid.get_children():
   assert(entry.get_global_rect().end.x<=roster_scroll.get_global_rect().end.x,"Every recruit remains horizontally visible in the roster column")
  var preview=card(app,patient.id)
  assert("RECOVERING" in preview.state_label.text and "%d/%d"%[returning.hp,returning.max_hp] in preview.find_child("DeploymentHealth",true,false).text,"Preparation previews actual reduced starting HP")
  assert("%d tonic"%returning.potions in preview.state_label.tooltip_text and preview.state_label.mouse_filter!=Control.MOUSE_FILTER_IGNORE)
  assert(preview.find_child("DeploymentSupplies",true,false).text=="1 field tonic" and returning.potions==1,"Visible recovery supplies match actual deployment")
  for label in preview.find_children("*","Label",true,false):assert(preview.get_global_rect().grow(1).encloses(label.get_global_rect()),"Recovery information fits the company card at every supported size")
 var focused=card(app,patient.id).deploy_button
 focused.grab_focus();await settle()
 var deployment=app.game.deployed.duplicate()
 for dimensions in [Vector2(720,640),Vector2(960,640)]:
  app.ui.size=dimensions;await settle()
  var roster_scroll=app.ui.find_child("CompanyScroll",true,false)
  assert(focused.has_focus() and roster_scroll.get_global_rect().grow(1).encloses(focused.get_global_rect()),
   "The current recruit stays focused and visible when the roster reflows")
 assert(app.game.deployed==deployment)
 app.show_dossier(patient);await settle()
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("RECOVERY · Next deployment")),"Dossiers explain the same deployment penalty")
 app.game.trials.injuries[patient.id]=10;app.show_camp();await settle()
 assert(not "RECOVERING" in card(app,patient.id).state_label.text,"Expired recovery disappears before deployment")
 assert(card(app,patient.id).find_child("DeploymentSupplies",true,false).text=="2 field tonics")
 app.game.trials.injuries[patient.id]=11;app.game.trials.flags.sacrifice_cost=false;app.show_camp();await settle()
 assert(not "RECOVERING" in card(app,patient.id).state_label.text,"Disabling sacrifice costs removes the next-deployment penalty preview")
 assert(card(app,patient.id).find_child("DeploymentSupplies",true,false).text=="2 field tonics")
 var patient_before=patient.duplicate(true)
 patient.fallen=true;patient.fallen_chapter=10;app.show_camp();await settle()
 assert(card(app,patient.id).find_child("DeploymentSupplies",true,false)==null,"Memorial cards do not advertise deployable supplies")
 patient.clear();patient.merge(patient_before,true)
 app.show_camp();await settle()
 var scroll=app.ui.find_child("CompanyScroll",true,false);scroll.scroll_vertical=100000;await settle()
 var before=scroll.scroll_vertical;assert(before>300)
 var last=app.game.roster[-1];var entry=card(app,last.id)
 assert(not entry.deploy_button.disabled and card(app,app.game.roster[0].id).deploy_button.disabled,"At capacity, removal is possible but a seventh ally cannot be added")
 entry.deploy_button.grab_focus();entry.deploy_button.pressed.emit();await settle()
 assert(app.game.deployed.size()==5 and last.id not in app.game.deployed)
 assert(card(app,last.id).deploy_button.has_focus(),"The equivalent control retains keyboard focus after rebuilding the grid")
 assert(absi(app.ui.find_child("CompanyScroll",true,false).scroll_vertical-before)<=2,"Selecting a late-roster unit preserves reading position")
 assert(not card(app,app.game.roster[0].id).deploy_button.disabled,"Freeing a place re-enables reserve choices")
 card(app,last.id).deploy_button.pressed.emit();await settle()
 assert(app.game.deployed.size()==6 and last.id in app.game.deployed)
 card(app,last.id).portrait_button.pressed.emit();await settle()
 assert(app.screen=="dossier","Portrait activation opens the existing dossier route")
 assert(app.world.visible and app.pieces.visible and app.pieces.process_mode==Node.PROCESS_MODE_INHERIT,"Leaving council restores the previous map state")
 assert(app.game.roster==original and app.game.rng.state==rng,"Preparation presentation never changes progression or combat randomness")
 await Shutdown.dispose(app);await process_frame
 print("PASS: all twelve roster states, seven council layouts, focus and scroll through reflow, deployment/recovery supplies, locked and fallen recruits, six-slot capacity, real add/remove actions, dossier navigation and progression isolation")
 call_deferred("quit")
