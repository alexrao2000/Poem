extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Rules=preload("res://scripts/rules.gd")
const Portraits=preload("res://scripts/portraits.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new()
 var story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
 var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
 var portraits=Portraits.new()
 var people={};var lines=0
 for u in g.roster:
  people[u.id]=u
  assert(profiles.has(u.id),"Every recruit has a dossier")
  assert(profiles[u.id].biography.length()>100,"Dossier contains an individual biography")
  assert(profiles[u.id].ending.length()>40,"Individual epilogue")
  assert(portraits.get_portrait(u.id)!=null,"Individual portrait available")
  var cutout=portraits.get_dialogue_portrait(u.id)
  assert(cutout!=null and cutout.region.size.x>450,"Dialogue portrait has an individual measured region")
  var image=cutout.atlas.get_image()
  if image.is_compressed():image.decompress()
  assert(image.get_pixel(int(cutout.region.position.x+2),int(cutout.region.position.y+2)).a<.13,"Transparent portrait corners reveal the map")
  assert(portraits.get_map_sprite(u.id)!=null,"Individual map sprite available")
 assert(story.chapters.size()==12)
 for chapter in range(12):
  for section in ["opening","closing"]:
   assert(story.chapters[chapter][section].size()>=3)
   for line in story.chapters[chapter][section]:
    assert(people.has(line.speaker),"Speaker belongs to roster")
    assert(people[line.speaker].join<=chapter,"Speaker is already recruited")
    assert(not line.text.is_empty());lines+=1
 g.story_seen=["opening_0","opening_1"]
 assert(g.save_game("/private/tmp/poem-story-save.json","camp"))
 var restored=Rules.new();assert(restored.load_game("/private/tmp/poem-story-save.json")=="camp")
 assert(restored.story_seen==g.story_seen,"Read scenes persist")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-test_story-ui-save.json";root.add_child(app);await process_frame
 app.game.new_campaign();app.show_camp();await process_frame
 assert(app.screen=="dialogue","New chapter begins with dialogue")
 assert(not app.dialogue_stage.ready_indicator.visible and app.dialogue_stage.next_button.text=="Reveal text","Typing line offers reveal and hides the ready diamond")
 app.dialogue_stage.next_button.pressed.emit();assert(app.dialogue_index==0,"First press completes typewriter text")
 assert(app.dialogue_stage.ready_indicator.visible and app.dialogue_stage.next_button.text=="Continue  >","Completed line offers continuation immediately")
 var pulse=app.dialogue_stage;var before_clock=pulse.ready_clock
 pulse._process(.1);assert(pulse.ready_clock>before_clock and pulse.ready_indicator.modulate.a>=.4 and pulse.ready_indicator.modulate.a<=.9,"Completed-line diamond pulses within bounded opacity")
 pulse.hide();before_clock=pulse.ready_clock;pulse._process(.2);assert(pulse.ready_clock==before_clock,"Hidden dialogue suspends prompt motion");pulse.show()
 app.dialogue_stage.next_button.pressed.emit();assert(app.dialogue_index==1,"Second press advances scene")
 assert(not app.dialogue_stage.ready_indicator.visible,"Next typing line resets the ready prompt")
 app.finish_dialogue();assert(app.screen=="camp","Skip returns to preparation")
 app.show_camp();assert(app.screen=="camp","Reopening camp does not replay introduction")
 app.show_dossier(app.game.roster[0]);assert(app.screen=="dossier")
 app.show_camp();assert(app.screen=="camp")
 var scenes=[]
 for chapter in story.chapters:
  scenes.append(chapter.opening);scenes.append(chapter.closing)
 var supports=JSON.parse_string(FileAccess.get_file_as_string("res://data/supports.json"))
 for pair in supports:
  for scene in pair.scenes:scenes.append(scene.lines)
 var checked=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  for scene in scenes:
   app.show_dialogue(scene,app.show_camp)
   app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
   for index in range(scene.size()):
    app.dialogue_index=index;app.refresh_dialogue();app.dialogue_stage.arrange()
    await process_frame;await process_frame
    var stage=app.dialogue_stage;var frame=Rect2(Vector2.ZERO,dimensions)
    assert(frame.encloses(stage.panel.get_global_rect()),"Dialogue frame stays in the viewport")
    for portrait in stage.portraits:
     assert(frame.encloses(portrait.get_global_rect()),"Portrait hair and shoulders stay on screen")
    for child in stage.panel.find_children("*","Control",true,false):
     assert(stage.panel.get_global_rect().grow(1).encloses(child.get_global_rect()),"Every line and control fits the dialogue panel")
    assert(stage.speech.get_line_count()<=stage.speech.get_visible_line_count(),"Long dialogue never clips its last line")
    assert(stage.identities[stage.active]==scene[index].speaker,"Current speaker owns the highlighted portrait")
    assert(stage.portraits[0].flip_h==false and stage.portraits[1].flip_h,"Portraits face into the conversation")
    assert(stage.portraits[stage.active].modulate==Color.WHITE,"Active speaker remains fully lit")
    checked+=1
 app.show_dialogue(story.chapters[0].opening,app.show_camp)
 var stage=app.dialogue_stage
 stage.show_speaker("lyra","Lyra",portraits.get_dialogue_portrait("lyra"))
 stage.show_speaker("oren","Oren",portraits.get_dialogue_portrait("oren"))
 var oren_side=stage.active
 stage.show_speaker("sera","Sera",portraits.get_dialogue_portrait("sera"))
 assert(stage.identities[oren_side]=="oren" and stage.identities[1-oren_side]=="sera","Third speaker replaces the listener, preserving the previous speaker")
 stage.show_speaker("oren","Oren",portraits.get_dialogue_portrait("oren"))
 assert(stage.active==oren_side and stage.portraits[1-oren_side].modulate.r<1,"Returning speaker reuses the same side")
 app.finish_dialogue();await process_frame
 assert(app.screen=="camp","Skipping during an entrance cleans up the stage")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",lines," story lines, 24 transparent dialogue portraits, ",checked," story/support layouts, speaker continuity, scene controls and persistence")
 quit()
