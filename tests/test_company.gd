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
   assert(entry.deploy_button.disabled==(not available or (app.game.deployed.size()>=6 and unit.id not in app.game.deployed)))
   if unit.id in app.game.deployed:assert(entry.state_label.text=="IN COMPANY")
   elif available:assert(entry.state_label.text=="RESERVE")
 app.game.chapter=11;app.game.deployed=[]
 for index in range(18,24):app.game.deployed.append(app.game.roster[index].id)
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
 print("PASS: all twelve roster states, locked recruits, six-slot capacity, real add/remove actions, retained scroll/focus, dossier navigation and progression isolation")
 call_deferred("quit")
