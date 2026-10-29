extends SceneTree
const Preferences=preload("res://scripts/preferences.gd")
func _initialize():call_deferred("run")
func run():
 var prefs=Preferences.new()
 assert(prefs.show_cinematic("player") and prefs.show_cinematic("enemy"),"Default retains full 3D combat")
 prefs.values.combat="player";assert(prefs.show_cinematic("player") and not prefs.show_cinematic("enemy"))
 prefs.values.combat="map";assert(not prefs.show_cinematic("player"))
 prefs.values.music=0;assert(prefs.volume_db("music")==-80)
 assert(prefs.save_file("/private/tmp/ashen-preferences.json"))
 var restored=Preferences.new();assert(restored.load_file("/private/tmp/ashen-preferences.json") and restored.values.combat=="map" and restored.values.music==0 and restored.values.text_speed==55)
 var invalid=prefs.values.duplicate();invalid.effects=4;assert(not prefs.valid(invalid))
 invalid.effects="loud";assert(not prefs.valid(invalid))
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-preferences-campaign.json";root.add_child(app);await process_frame
 app.settings_path="/private/tmp/ashen-preferences-ui.json";app.show_options("title");await process_frame;await process_frame
 var mode=app.ui.find_child("CombatMode",true,false);mode.selected=2;mode.item_selected.emit(2)
 var music=app.ui.find_child("MusicVolume",true,false);music.value=0
 assert(app.preferences.values.combat=="map" and app.music.volume_db==-80,"Menu updates playback and audio")
 var text=app.ui.find_child("TextSpeed",true,false);text.selected=2;text.item_selected.emit(2)
 app.close_options();await process_frame
 assert(restored.load_file(app.settings_path) and restored.values.text_speed==0)
 app.show_dialogue([{"speaker":"lyra","text":"Instant text."},{"speaker":"oren","text":"Second line."}],func():app.show_title())
 assert(app.dialogue_label.visible_characters==-1);app.advance_dialogue()
 assert(app.dialogue_index==1,"Instant dialogue advances with one press")
 app.finish_dialogue();app.game.start_battle();app.make_map();app.show_battle()
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var events=app.game.combat(a,b);var rng=app.game.rng.state;var hp=b.hp;var camera_position=app.camera.position
 await app.cinematic(a,b,events)
 assert(app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and app.camera.position==camera_position,"Quick mode keeps tactical camera")
 assert(app.game.rng.state==rng and b.hp==hp,"Presentation does not reroll or apply damage twice")
 a.hp=a.max_hp-6;a.acted=false;a.potions=1;app.selected=a
 app.tonic();await process_frame
 assert(app.busy and a.potions==0,"Healing animation locks input after one tonic is spent")
 while app.busy:await process_frame
 assert(a.hp==a.max_hp and a.potions==0 and app.game.rng.state==rng,"Healing feedback does not apply health twice or consume RNG")
 assert(app.unit_nodes[a.id].player.state=="idle" and app.unit_nodes[a.id].spent,"Finished field action returns to spent idle")
 app.show_options("battle");await process_frame;await process_frame
 for control in app.ui.find_children("*","Button",true,false):assert(control.get_global_rect().end.y<=app.ui.size.y,"Options controls fit viewport")
 app.close_options();assert(app.screen=="battle","Options return to tactical play")
 app.show_title();await process_frame;await process_frame
 for control in app.ui.find_children("*","Button",true,false):assert(control.get_global_rect().end.y<=app.ui.size.y,"Title controls fit viewport")
 for chapter in range(12):
  app.game.chapter=chapter;app.game.story_seen.append("opening_"+str(chapter));app.show_camp();await process_frame;await process_frame
  for control in app.ui.find_children("*","Button",true,false):
   if control.text in ["Options","Save campaign","Transfer a local save","Return to title","Deploy company  >"]:assert(control.get_global_rect().end.y<=app.ui.size.y,"Camp controls fit all twelve chapters")
 app.queue_free();await process_frame
 print("PASS: local preferences, volume, cinematic modes, instant dialogue, persistence and unchanged combat simulation")
 quit()
