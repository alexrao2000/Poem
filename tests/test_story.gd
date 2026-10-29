extends SceneTree
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
 assert(g.save_game("/private/tmp/ashen-story-save.json","camp"))
 var restored=Rules.new();assert(restored.load_game("/private/tmp/ashen-story-save.json")=="camp")
 assert(restored.story_seen==g.story_seen,"Read scenes persist")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-test_story-ui-save.json";root.add_child(app);await process_frame
 app.game.new_campaign();app.show_camp();await process_frame
 assert(app.screen=="dialogue","New chapter begins with dialogue")
 app.advance_dialogue();assert(app.dialogue_index==0,"First press completes typewriter text")
 app.advance_dialogue();assert(app.dialogue_index==1,"Second press advances scene")
 app.finish_dialogue();assert(app.screen=="camp","Skip returns to preparation")
 app.show_camp();assert(app.screen=="camp","Reopening camp does not replay introduction")
 app.show_dossier(app.game.roster[0]);assert(app.screen=="dossier")
 app.show_camp();assert(app.screen=="camp")
 app.queue_free();await process_frame
 print("PASS: ",lines," dialogue lines, 24 portraits/dossiers/epilogues, scene controls and persistence")
 quit()
