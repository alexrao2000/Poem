extends SceneTree
## Measure every roster menu, fixed action area and scrollable reading region.
var layouts=0
var scrolled={}

func _initialize():call_deferred("run")

func inspect(app,dimensions: Vector2):
	app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
	await process_frame;await process_frame
	var frame=Rect2(Vector2.ZERO,dimensions)
	for node in app.ui.find_children("*","Control",true,false):
		if not node.is_visible_in_tree():continue
		var parent=node.get_parent();var clip: ScrollContainer
		while parent!=app.ui:
			if parent is ScrollContainer:clip=parent;break
			parent=parent.get_parent()
		var rect=node.get_global_rect()
		if clip!=null:
			var region=clip.get_global_rect()
			assert(rect.position.x>=region.position.x-1 and rect.end.x<=region.end.x+1,"Reading content never requires sideways scrolling: "+app.screen)
		else:
			assert(frame.grow(1).encloses(rect),"Menu and fixed actions stay on screen: %s / %s / %s"%[app.screen,dimensions,node.get_class()])
			if node is Label:assert(node.get_line_count()<=node.get_visible_line_count(),"Fixed menu text remains readable")
	for scroll in app.ui.find_children("*","ScrollContainer",true,false):
		if not scroll.is_visible_in_tree():continue
		assert(scroll.size.y>=80,"Reading area retains useful height: "+app.screen)
		assert(scroll.follow_focus,"Keyboard focus follows off-screen choices")
	if app.screen=="save_transfer":assert(app.transfer_text.size.y>=160,"Save-code editor stays usable in a short window")
	var key=app.screen+str(dimensions)
	if not scrolled.has(key):
		scrolled[key]=true
		for scroll in app.ui.find_children("*","ScrollContainer",true,false):
			if not scroll.is_visible_in_tree():continue
			assert(scroll.get_child_count()>0,"Visible reading areas contain authored content")
			scroll.scroll_vertical=100000
			await process_frame;await process_frame
			var entries=scroll.get_child(0).find_children("*","Button",true,false)
			if entries.is_empty():entries=scroll.get_child(0).find_children("*","Label",true,false)
			if not entries.is_empty():assert(scroll.get_global_rect().grow(2).intersects(entries[-1].get_global_rect()),"Last action or reading line can be reached: "+app.screen)
	layouts+=1

func run():
	var app=load("res://main.tscn").instantiate();app.settings_path="/private/tmp/poem-menu-preferences.json";app.save_path="/private/tmp/poem-menu-campaign.json"
	root.add_child(app);await process_frame
	for chapter in range(12):app.game.story_seen.append("opening_"+str(chapter))
	var roster=app.game.roster.duplicate(true)
	for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
		for screen in ["title","credits","options","save_transfer","ending"]:
			match screen:
				"title":app.show_title()
				"credits":app.show_credits()
				"options":app.show_options("camp")
				"save_transfer":app.show_save_transfer("camp")
				"ending":app.show_ending()
			await inspect(app,dimensions)
		for chapter in range(12):
			app.game.chapter=chapter;app.show_camp();await inspect(app,dimensions)
		for unit in app.game.roster:
			for screen in ["dossier","equipment","promotions","supports"]:
				app.call("show_"+screen,unit);await inspect(app,dimensions)
			for path in app.game.promotion_options(unit):
				app.confirm_promotion(unit,path);await inspect(app,dimensions)
		app.show_model_view(app.game.roster[0]);await inspect(app,dimensions)
		app.close_model_view()
		app.game.chapter=0;app.game.start_battle()
		for unit in app.game.living("enemy"):unit.hp=0
		assert(await app.check_result());await inspect(app,dimensions)
		app.game.start_battle()
		for unit in app.game.living("player"):unit.hp=0
		assert(await app.check_result());await inspect(app,dimensions)
	assert(app.game.roster==roster,"Browsing and sizing menus never changes roster progression")
	app.game.chapter=11;app.show_dossier(app.game.roster[0]);await process_frame
	var back=app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Return to war council")[0]
	back.pressed.emit();assert(app.screen=="camp","Pinned dossier back action uses the existing route")
	for player in app.sfx_players:player.stop()
	app.music.stop();await create_timer(.15).timeout;app.queue_free();await process_frame
	print("PASS: ",layouts," campaign menu layouts, all 24 dossiers/equipment/supports/training choices, scrolling, fixed actions and roster isolation")
	quit()
