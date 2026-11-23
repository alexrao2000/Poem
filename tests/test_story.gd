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
 for scene in g.trials.scenes.values():scenes.append(scene)
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
    var line=scene[index]
    assert(stage.portraits[stage.active].texture==app.portraits.get_dialogue_portrait(line.speaker,line.get("expression","")),"Campaign and support lines bind their authored expression")
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
 await verify_keyboard(app)
 await verify_history(app)
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",lines," story lines, 24 transparent dialogue portraits, ",checked," story/support/trial layouts, speaker continuity, one-action keyboard/pointer controls, held-key suppression, chained scenes, revealed-only history/pause/scroll/teardown and persistence")
 quit()

func key_event(code,echo=false):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;event.echo=echo;root.push_input(event,true)
 var release=InputEventKey.new();release.keycode=code;release.pressed=false;root.push_input(release,true)

func click_button(button):
 var point=button.get_global_rect().get_center()
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event,true)

func verify_keyboard(app):
 var lines=[{"speaker":"lyra","text":"The first line must be revealed before the company moves to the next speaker."},{"speaker":"oren","text":"The second line remains here until another deliberate press."},{"speaker":"lyra","text":"The final line closes this conversation only once."}]
 var snapshot=app.game.save_data("camp").duplicate(true)
 for speed in [55,0]:
  app.preferences.values.text_speed=speed
  for focus in ["none","continue","skip"]:
   for code in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]:
    var calls={"finished":0}
    app.show_dialogue(lines,func():calls.finished+=1;app.show_camp())
    await process_frame;await process_frame
    if root.gui_get_focus_owner()!=null:root.gui_get_focus_owner().release_focus()
    if focus=="continue":app.dialogue_stage.next_button.grab_focus()
    elif focus=="skip":app.dialogue_stage.skip_button.grab_focus()
    if speed>0:app.dialogue_label.visible_characters=0;app.dialogue_reveal=0.0
    var visible=app.dialogue_label.visible_characters
    for repeat in range(3):key_event(code,true)
    assert(app.screen=="dialogue" and app.dialogue_index==0 and app.dialogue_label.visible_characters==visible and calls.finished==0,"Held dialogue keys cannot reveal, advance or skip, even with a focused button")
    key_event(code)
    if code==KEY_ESCAPE or focus=="skip":
     assert(app.screen=="camp" and app.dialogue_index==0 and calls.finished==1,"Fresh skip invokes exactly one callback without advancing a line first")
    else:
     assert(app.screen=="dialogue" and calls.finished==0)
     assert(app.dialogue_index==(0 if speed>0 else 1),"One fresh press performs exactly one reveal or advance, including focused Continue")
     if speed>0:assert(app.dialogue_label.visible_characters==lines[0].text.length())
     var index=app.dialogue_index
     key_event(code,true);assert(app.dialogue_index==index,"Repeat after a fresh press cannot advance a following line")
     key_event(code);assert(app.dialogue_index==index+1,"A second deliberate press advances once")
     app.finish_dialogue();assert(calls.finished==1)
 # Closing a scene may synchronously open the next chapter's introduction.
 app.preferences.values.text_speed=0
 for code in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]:
  var calls={"first":0,"second":0}
  app.show_dialogue([lines[0]],func():
   calls.first+=1
   app.show_dialogue(lines,func():calls.second+=1;app.show_camp()))
  await process_frame;await process_frame
  app.dialogue_stage.next_button.grab_focus()
  key_event(code)
  assert(calls.first==1 and calls.second==0 and app.screen=="dialogue" and app.dialogue_index==0,"Key release does not advance the scene opened by the completion callback")
  for repeat in range(3):key_event(code,true)
  assert(calls.first==1 and calls.second==0 and app.dialogue_index==0,"A held key cannot dismiss a newly opened scene")
  key_event(KEY_ENTER);assert(app.dialogue_index==1)
  app.finish_dialogue();assert(calls.second==1)
 # Pointer actions still follow the same reveal/advance and skip callbacks.
 app.preferences.values.text_speed=55
 var calls={"finished":0}
 app.show_dialogue(lines,func():calls.finished+=1;app.show_camp())
 await process_frame;await process_frame
 app.skip_combat=false;key_event(KEY_TAB)
 assert(not app.skip_combat and app.dialogue_index==0,"Dialogue focus navigation cannot arm combat skipping")
 app.dialogue_label.visible_characters=0;app.dialogue_reveal=0.0
 click_button(app.dialogue_stage.next_button)
 assert(app.dialogue_index==0 and app.dialogue_label.visible_characters==lines[0].text.length())
 click_button(app.dialogue_stage.next_button);assert(app.dialogue_index==1)
 click_button(app.dialogue_stage.skip_button);assert(app.screen=="camp" and calls.finished==1)
 assert(app.game.save_data("camp")==snapshot,"Dialogue input leaves campaign, roster and RNG unchanged")

func verify_history(app):
 var lines=[]
 for index in range(32):lines.append({"speaker":"lyra" if index%2==0 else "oren","text":"Line %02d begins here, then continues with the private remainder secret_%02d."%[index,index]})
 var calls={"finished":0};app.preferences.values.text_speed=0
 app.show_dialogue(lines,func():calls.finished+=1;app.show_camp())
 for index in range(21):app.advance_dialogue()
 app.preferences.values.text_speed=55;app.refresh_dialogue()
 var snapshot=app.game.save_data("camp").duplicate(true);var count=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  for closing in [KEY_ESCAPE,KEY_H,KEY_ENTER,KEY_SPACE,0]:
   await process_frame;await process_frame
   app.dialogue_label.visible_characters=17;app.dialogue_reveal=17.0
   if count%3==0:key_event(KEY_H)
   elif count%3==1:click_button(app.dialogue_stage.history_button)
   else:app.dialogue_stage.history_button.grab_focus();key_event(KEY_ENTER)
   var history=app.dialogue_stage.history;assert(history!=null)
   var retained=weakref(history)
   assert(not app.dialogue_stage.panel.visible and history.entries.size()==22,"History hides underlying actions and includes only already visited lines")
   for index in range(21):
    assert(history.entries[index].text==lines[index].text and history.entries[index].speaker==("Lyra" if index%2==0 else "Oren"))
   assert(history.entries[-1].text==lines[21].text.left(17),"The current line contributes only its revealed prefix")
   for label in history.find_children("*","Label",true,false):
    assert(not "secret_21" in label.text and not "secret_22" in label.text,"Actual transcript labels cannot expose unrevealed or future lines")
   var clock=app.dialogue_reveal;app._process(1.0)
   for frame in range(4):await process_frame
   assert(app.dialogue_reveal==clock and app.dialogue_label.visible_characters==17 and app.dialogue_index==21 and calls.finished==0,"Reading history pauses typewriter progression and scene callbacks")
   var bounds=history.frame.get_global_rect()
   if not Rect2(Vector2.ZERO,dimensions).encloses(bounds):print("History bounds ",bounds," host ",history.size," stage ",app.dialogue_stage.size," minimum ",history.frame.get_combined_minimum_size()," expected ",dimensions)
   assert(Rect2(Vector2.ZERO,dimensions).encloses(bounds))
   assert(bounds.grow(1).encloses(history.scroll.get_global_rect()) and bounds.grow(1).encloses(history.return_button.get_global_rect()),"History scrolling and return control fit all supported sizes")
   assert(history.return_button.has_focus() and history.scroll.scroll_vertical>0,"Long history opens at its newest line with a visible return focus")
   for label in history.find_children("*","Label",true,false):
    assert(label.get_global_rect().position.x>=bounds.position.x and label.get_global_rect().end.x<=bounds.end.x)
    assert(label.get_line_count()<=label.get_visible_line_count(),"Transcript lines wrap fully inside the scroll column")
   for code in [KEY_H,KEY_ESCAPE,KEY_ENTER,KEY_SPACE]:
    key_event(code,true);assert(app.dialogue_stage.history==history,"Held keys cannot close history or advance the underlying story")
   key_event(KEY_HOME);assert(history.scroll.scroll_vertical==0)
   key_event(KEY_END);var bottom=history.scroll.scroll_vertical;assert(bottom>0)
   key_event(KEY_UP,true);assert(history.scroll.scroll_vertical<bottom,"Scrolling retains held-arrow repetition")
   key_event(KEY_HOME);key_event(KEY_PAGEDOWN);assert(history.scroll.scroll_vertical>0)
   key_event(KEY_PAGEUP);assert(history.scroll.scroll_vertical==0)
   if closing==0:click_button(history.return_button)
   else:key_event(closing)
   assert(app.dialogue_stage.history==null and app.dialogue_stage.panel.visible and app.dialogue_stage.next_button.has_focus())
   assert(app.dialogue_index==21 and app.dialogue_label.visible_characters==17 and calls.finished==0,"Returning from history neither reveals nor advances a line")
   app._process(.1);assert(app.dialogue_reveal>clock and app.dialogue_index==21,"Typewriter resumes from its retained position")
   await process_frame;await process_frame
   assert(retained.get_ref()==null,"Closed transcript nodes are released")
   assert(app.game.save_data("camp")==snapshot,"History navigation never changes campaign data or RNG")
   count+=1
 # Empty histories and immediate scene replacement must not retain deferred focus.
 app.show_dialogue(lines,func():calls.finished+=1;app.show_camp())
 app.dialogue_label.visible_characters=0;app.dialogue_reveal=0.0
 key_event(KEY_H);var empty=weakref(app.dialogue_stage.history)
 assert(app.dialogue_stage.history.entries.is_empty())
 app.show_dialogue([lines[31]],func():calls.finished+=1;app.show_camp())
 for frame in range(4):await process_frame
 assert(empty.get_ref()==null and app.dialogue_stage.history==null and app.dialogue_index==0,"A new scene starts with no retained transcript or deferred focus")
 key_event(KEY_H);key_event(KEY_ESCAPE)
 key_event(KEY_ESCAPE,true);assert(app.screen=="dialogue" and calls.finished==0,"Held history-close Escape cannot skip the resumed conversation")
 key_event(KEY_ESCAPE);assert(app.screen=="camp" and calls.finished==1)
 assert(app.game.save_data("camp")==snapshot)
