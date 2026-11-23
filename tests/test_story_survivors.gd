extends SceneTree
const Resolve=preload("res://scripts/story_survivors.gd")
const Rules=preload("res://scripts/rules.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"));var original=data.duplicate(true)
 var rules=Rules.new();var people={};var variants=[];var combinations=0
 for unit in rules.roster:people[unit.id]=unit
 for chapter in range(12):
  for section in ["opening","closing"]:
   var lines=data.chapters[chapter][section];var ids=[]
   assert(Resolve.resolve(lines,[])==lines,"Intact company keeps every original line and its order")
   for line in lines:
    var choices=[line];choices.append_array(line.get("when_absent",[]))
    for choice in choices:
     assert(not choice.text.is_empty())
     var required=[choice.speaker];required.append_array(choice.get("requires",[]))
     for id in required:
      assert(people.has(id) and people[id].join<=chapter,"Every possible speaker/dependency is recruited by this chapter")
      if id!="lyra" and id not in ids:ids.append(id)
     variants.append(choice)
   for mask in range(1<<ids.size()):
    var losses=[]
    for at in range(ids.size()):
     if mask&(1<<at):losses.append(ids[at])
    var selected=Resolve.resolve(lines,losses)
    assert(not selected.is_empty(),"Every chapter retains its mission or aftermath with only Lyra left")
    for line in selected:assert(Resolve.available(line,losses),"No dead speaker or absent addressee survives resolution")
    combinations+=1
 assert(data==original,"Resolving any loss combination leaves authored story data unchanged")
 var first=Resolve.resolve(data.chapters[0].closing,["oren"])
 assert(not first.any(func(line):return "go home now" in line.text) and first.any(func(line):return "carry his name" in line.text),"Oren's death receives a memorial instead of a request addressed to him")
 var abbey=Resolve.resolve(data.chapters[3].opening,["rook"])
 assert(not abbey.any(func(line):return "trust you" in line.text or "have to earn" in line.text),"A dead Rook cannot be accused or offered a second chance")
 var last=Resolve.resolve(data.chapters[11].closing,["rhea","noor","cassian","oren"])
 assert(last.size()==2 and last.all(func(line):return line.speaker=="lyra") and last[0].text.contains("still light"),"Even severe attrition retains the engine's aftermath and the company's decision")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-story-survivors.json";root.add_child(app);await process_frame
 app.game.new_campaign(true);app.game.start_battle()
 var oren=app.game.units.filter(func(unit):return unit.id=="oren")[0];oren.hp=0
 var checkpoint=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 app.show_dialogue(data.chapters[0].closing,Callable(),"closing");await process_frame
 assert(app.dialogue_lines==first and not app.game.roster[1].fallen,"Closing scenes see this battle's loss before chapter memorials are committed")
 assert(app.game.save_data("battle")==checkpoint and app.game.rng.state==rng)
 app.game.permadeath=false;app.show_dialogue(data.chapters[0].closing,Callable(),"closing")
 assert(app.dialogue_lines==data.chapters[0].closing,"Recoverable casual knockouts retain their ordinary conversations")
 app.game.permadeath=true;oren.downed=true;oren.bleed_turns=2
 app.show_dialogue(data.chapters[0].closing,Callable(),"closing")
 assert(app.dialogue_lines==data.chapters[0].closing,"A rescued or evacuated downed ally is not treated as permanently lost")
 oren.erase("downed");oren.erase("bleed_turns");app.game.trials.flags.section_restarts=true;app.game.commit_casualties();app.game.units[0].hp=0
 assert(app.game.retry_battle() and "oren" in app.game.lost_ids())
 checkpoint=app.game.save_data("camp").duplicate(true);rng=app.game.rng.state
 app.show_dialogue(data.chapters[0].opening,Callable(),"opening")
 assert(app.dialogue_lines==Resolve.resolve(data.chapters[0].opening,["oren"]),"A section rewind retains survivor dialogue for committed casualties")
 var memory=[{"speaker":"oren","text":"We kept the road open together."}]
 app.show_dialogue(memory,Callable(),"support");assert(app.dialogue_lines==memory,"Read support replays remain memories of the original speakers")
 assert(app.game.save_data("camp")==checkpoint and app.game.rng.state==rng)
 app.game.new_campaign();var layout_count=0
 for dimensions in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
  app.show_dialogue(variants,Callable(),"opening")
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  for at in range(variants.size()):
   app.dialogue_index=at;app.refresh_dialogue();app.dialogue_stage.arrange();await process_frame;await process_frame
   var stage=app.dialogue_stage;var frame=Rect2(Vector2.ZERO,Vector2(dimensions))
   assert(frame.encloses(stage.panel.get_global_rect()),str([dimensions,at,stage.panel.get_global_rect()]))
   for portrait in stage.portraits:assert(frame.encloses(portrait.get_global_rect()))
   for child in stage.panel.find_children("*","Control",true,false):assert(stage.panel.get_global_rect().grow(1).encloses(child.get_global_rect()))
   assert(stage.speech.get_line_count()<=stage.speech.get_visible_line_count(),"Survivor lines fit the actual dialogue panel")
   assert(stage.identities[stage.active]==variants[at].speaker)
   var choice=variants[at]
   assert(stage.portraits[stage.active].texture==app.portraits.get_dialogue_portrait(choice.speaker,choice.get("expression","")),"Loss alternate lines can use their own expression")
   layout_count+=1
 assert(not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",combinations," campaign loss subsets, unchanged intact scenes/source data, current casualties, downed/casual recovery, section restarts, support memories, ",layout_count," dialogue layouts and unchanged save/RNG state")
 quit()
