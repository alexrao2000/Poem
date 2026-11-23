extends SceneTree
# Source-asset checks and actual conversation flows. No GPU capture is used.
const Portraits=preload("res://scripts/portraits.gd")
const Resolve=preload("res://scripts/story_survivors.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func loaded_sheets(faces) -> Array:
 var result=[]
 for id in faces.dialogue_expressions:
  var entry=faces.dialogue_expressions[id].values()[0]
  if ResourceLoader.has_cached(entry.path):result.append(id)
 return result

func _initialize():call_deferred("run")
func run():
 var faces=Portraits.new()
 var regions=0
 for id in Portraits.ORDER:
  var original=faces.get_dialogue_portrait(id)
  var expressions=faces.dialogue_expressions.get(id,{})
  assert(faces.get_dialogue_portrait(id,"missing")==original,"Unknown expressions use the original portrait")
  assert(expressions.size()==3,"All recruits have a complete expression sheet")
  var atlas=faces.get_dialogue_portrait(id,expressions.keys()[0]).atlas
  var source=atlas.get_image()
  if source.is_compressed():source.decompress()
  var previous_regions=[]
  for expression in expressions:
   var face=faces.get_dialogue_portrait(id,expression)
   assert(face!=original and face==faces.get_dialogue_portrait(id,expression),"Expression cache is distinct and stable")
   var crop=Rect2i(face.region)
   assert(face.atlas==atlas and crop.size.x==crop.size.y and crop.size.x>=723 and face.filter_clip)
   assert(Rect2(Vector2.ZERO,source.get_size()).encloses(face.region))
   for previous in previous_regions:
    assert(not previous.intersects(face.region),"Expression cells do not overlap")
   previous_regions.append(face.region)
   for x in range(crop.position.x,crop.end.x):
    assert(source.get_pixel(x,crop.position.y).a<.13 and source.get_pixel(x,crop.end.y-1).a<.13,"Transparent horizontal gutters isolate the crop")
   for y in range(crop.position.y,crop.end.y):
    assert(source.get_pixel(crop.position.x,y).a<.13 and source.get_pixel(crop.end.x-1,y).a<.13,"Transparent vertical gutters keep adjacent expressions out")
   regions+=1
 assert(regions==72)
 faces.expression_textures.clear()
 assert(loaded_sheets(faces).is_empty(),"Assets checked in isolation release before testing actual scenes")
 var story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
 var campaign_tags=0
 var alternate_tags=0
 for chapter in story.chapters:
  for kind in ["opening","closing"]:
   for line in chapter[kind]:
    if line.has("expression"):
     assert(faces.dialogue_expressions.get(line.speaker,{}).has(line.expression),"Every authored campaign expression has an asset")
     assert(Resolve.resolve([line],[])[0].expression==line.expression,"Loss-aware story copies retain expression metadata")
     campaign_tags+=1
    for alternate in line.get("when_absent",[]):
     if not alternate.has("expression"):continue
     assert(faces.dialogue_expressions.get(alternate.speaker,{}).has(alternate.expression),"A loss alternate has its own expression asset")
     var absent=[line.speaker] if line.speaker!=alternate.speaker else line.get("requires",[])
     assert(Resolve.resolve([line],absent)==[alternate],"An actual loss selects the authored alternate expression")
     alternate_tags+=1
 assert(campaign_tags==103 and alternate_tags==10)
 var viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-expressions-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.text_speed=0;app.settings_path=app.save_path+".settings";assert(app.preferences.save_file(app.settings_path))
 app.game.chapter=11
 app.game.story_seen=["opening_11"];app.show_camp()
 var expressed_supports=[]
 for entry in app.game.supports.entries:
  if not entry.scenes.any(func(scene):return scene.lines.any(func(line):return line.has("expression"))):continue
  expressed_supports.append(entry)
  app.game.supports.state[entry.id]={"points":18,"rank":3,"chapter":11,"earned":0,"turn":-1}
 assert(expressed_supports.size()==12)
 assert(app.persist_campaign("camp"))
 var before=JSON.stringify(app.game.save_data("camp"));var state=app.game.rng.state
 var disk=FileAccess.get_file_as_string(app.save_path);var settings=FileAccess.get_file_as_string(app.settings_path)
 var lines=[{"speaker":"lyra","text":"We will keep the road.","expression":"resolute"},{"speaker":"lyra","text":"And the people behind us?","expression":"concerned"},{"speaker":"oren","text":"They are across."},{"speaker":"lyra","text":"Then we can go home.","expression":"relieved"},{"speaker":"lyra","text":"Tell the others."},{"speaker":"lyra","text":"I will follow.","expression":"missing"},{"speaker":"sera","text":"The way is clear."},{"speaker":"lyra","text":"Stay together.","expression":"resolute"}]
 var transitions=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;app.show_dialogue(lines,func():app.show_dossier(app.game.roster[0]),"support");await process_frame;await process_frame
  var stage=app.dialogue_stage
  assert(loaded_sheets(app.portraits)==["lyra"],"The first line loads only the requested expression sheet")
  for i in range(lines.size()):
   var line=lines[i];var slot=stage.active;var portrait=stage.portraits[slot]
   assert(app.dialogue_index==i and stage.identities[slot]==line.speaker)
   assert(portrait.texture==app.portraits.get_dialogue_portrait(line.speaker,line.get("expression","")),"Actual refresh binds the current expression or resets to neutral")
   stage.arrange();assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(portrait.get_rect()))
   var texture=portrait.texture;var position=portrait.position
   app.show_dialogue_history();await process_frame
   assert(stage.history!=null and portrait.texture==texture,"History preserves the speaking expression")
   stage.close_history();await process_frame
   assert(stage.portraits[slot]==portrait and portrait.texture==texture and portrait.position==position)
   var entrance=stage.entrances[slot]
   stage.next_button.pressed.emit();transitions+=1
   if i+1<lines.size() and lines[i+1].speaker==line.speaker:
    assert(stage.active==slot and stage.portraits[slot]==portrait and portrait.position==position and stage.entrances[slot]==entrance,"A new expression on the same speaker cannot slide or replace the portrait control")
   await process_frame
  assert(app.screen=="dossier","The final Continue still completes the scene")
  assert(loaded_sheets(app.portraits).is_empty(),"A finished scene releases its expression sheets")
 var support_tags=0
 for entry in expressed_supports:
  var unit=app.game.roster.filter(func(recruit):return recruit.id==entry.members[0])[0]
  for index in range(entry.scenes.size()):
   app.read_support(unit,entry,index)
   assert(app.screen=="dialogue")
   for line in entry.scenes[index].lines:
    var expression=line.get("expression","")
    if not expression.is_empty():
     assert(faces.dialogue_expressions.get(line.speaker,{}).has(expression))
     support_tags+=1
    assert(app.dialogue_portrait.texture==app.portraits.get_dialogue_portrait(line.speaker,expression),"The support replay reads expressions through its ordinary entry point")
    app.advance_dialogue()
   assert(app.screen=="supports","Replay returns to the company bonds menu")
   await process_frame;await process_frame
   assert(loaded_sheets(app.portraits).is_empty(),"Replayed scenes release both partners’ sheets")
 assert(support_tags==191)
 var neutral=app.portraits.get_dialogue_portrait("lyra")
 app.show_dialogue(story.chapters[0].opening,func():app.show_dossier(app.game.roster[0]))
 assert(loaded_sheets(app.portraits)==["oren"],"Campaign openings load the first speaker only")
 app.advance_dialogue()
 assert(loaded_sheets(app.portraits).size()==2)
 app.finish_dialogue()
 await process_frame;await process_frame
 assert(loaded_sheets(app.portraits).is_empty() and app.portraits.get_dialogue_portrait("lyra")==neutral,"Skip releases expressions and retains the shared neutral portrait")

 assert(JSON.stringify(app.game.save_data("camp"))==before and app.game.rng.state==state)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and FileAccess.get_file_as_string(app.settings_path)==settings,"Portrait changes leave campaign and preference files byte-identical")
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: 72 transparent expression regions, 103 campaign, ten alternate and 191 support tags, 36 support replays, 24 actual dialogue transitions across three sizes, neutral and unknown fallback across the full roster, same-speaker slot/entrance stability, history, lazy sheet loading and release on Continue/Skip, exact state/file isolation")
 quit()
