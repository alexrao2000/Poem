extends SceneTree
# Source-asset checks and actual conversation flows. No GPU capture is used.
const Portraits=preload("res://scripts/portraits.gd")
const Resolve=preload("res://scripts/story_survivors.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var faces=Portraits.new();var neutral=faces.get_dialogue_portrait("lyra")
 for expression in ["resolute","concerned","relieved"]:
  var face=faces.get_dialogue_portrait("lyra",expression)
  assert(face!=neutral and face==faces.get_dialogue_portrait("lyra",expression),"Expression cache is distinct and stable")
  assert(face.region.size==Vector2(724,724) and face.filter_clip)
  var source=face.atlas.get_image()
  if source.is_compressed():source.decompress()
  assert(Rect2(Vector2.ZERO,source.get_size()).encloses(face.region))
  for x in range(int(face.region.position.x),int(face.region.end.x)):
   assert(source.get_pixel(x,0).a<.13 and source.get_pixel(x,723).a<.13,"Transparent horizontal gutters isolate the crop")
  for y in range(724):
   assert(source.get_pixel(int(face.region.position.x),y).a<.13 and source.get_pixel(int(face.region.end.x)-1,y).a<.13,"Transparent vertical gutters keep adjacent expressions out")
 assert(faces.get_dialogue_portrait("lyra","missing")==neutral,"Unknown expressions use the original portrait")
 for id in Portraits.ORDER:
  if id!="lyra":assert(faces.get_dialogue_portrait(id,"resolute")==faces.get_dialogue_portrait(id),"Unpainted recruits retain their existing portrait")
 var story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"));var tagged=0
 for chapter in story.chapters:
  for kind in ["opening","closing"]:
   for line in chapter[kind]:
    if not line.has("expression"):continue
    assert(faces.dialogue_expressions.get(line.speaker,{}).has(line.expression),"Every authored expression has an asset")
    assert(Resolve.resolve([line],[])[0].expression==line.expression,"Loss-aware story copies retain expression metadata")
    tagged+=1
 assert(tagged==21)
 var viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-expressions-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.text_speed=0;app.settings_path=app.save_path+".settings";assert(app.preferences.save_file(app.settings_path))
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var before=JSON.stringify(app.game.save_data("camp"));var state=app.game.rng.state
 var disk=FileAccess.get_file_as_string(app.save_path);var settings=FileAccess.get_file_as_string(app.settings_path)
 var lines=[{"speaker":"lyra","text":"We will keep the road.","expression":"resolute"},{"speaker":"lyra","text":"And the people behind us?","expression":"concerned"},{"speaker":"oren","text":"They are across."},{"speaker":"lyra","text":"Then we can go home.","expression":"relieved"},{"speaker":"lyra","text":"Tell the others."},{"speaker":"lyra","text":"I will follow.","expression":"missing"},{"speaker":"sera","text":"The way is clear."},{"speaker":"lyra","text":"Stay together.","expression":"resolute"}]
 var transitions=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  viewport.size=dimensions;app.show_dialogue(lines,func():app.show_dossier(app.game.roster[0]),"support");await process_frame;await process_frame
  var stage=app.dialogue_stage
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
 assert(JSON.stringify(app.game.save_data("camp"))==before and app.game.rng.state==state)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and FileAccess.get_file_as_string(app.settings_path)==settings,"Portrait changes leave campaign and preference files byte-identical")
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: three transparent expression regions, 21 authored lines, 24 actual dialogue transitions across three sizes, neutral/unknown/full-roster fallback, same-speaker slot/entrance stability, history and exact state/file isolation")
 quit()
