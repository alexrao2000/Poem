extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Preferences=preload("res://scripts/preferences.gd")
func _initialize():call_deferred("run")
func verify_sections(app):
 var snapshot=app.game.save_data("camp").duplicate(true);var settings=app.preferences.values.duplicate(true)
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  await process_frame;await process_frame
  var sections=app.ui.find_child("OptionsSections",true,false);var fixed=sections.get_global_rect()
  assert(Rect2(Vector2.ZERO,dimensions).encloses(fixed))
  for section in [{"title":"Presentation","control":"CombatMode"},{"title":"Audio","control":"MusicVolume"},{"title":"Campaign","control":"Permadeath"}]:
   app.ui.find_child("OptionsSection_"+section.title,true,false).pressed.emit()
   await process_frame;await process_frame
   var control=app.ui.find_child(section.control,true,false);var scroll=control.get_parent()
   while not scroll is ScrollContainer:scroll=scroll.get_parent()
   if not control.has_focus() or not scroll.get_global_rect().grow(1).encloses(control.get_global_rect()):print("Section ",section.title," at ",dimensions," focused=",control.has_focus()," control=",control.get_global_rect()," scroll=",scroll.get_global_rect()," offset=",scroll.scroll_vertical)
   assert(control.has_focus() and scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"Section shortcuts focus the corresponding visible setting")
   assert(sections.get_global_rect()==fixed,"Options section shortcuts remain fixed while reading content scrolls")
   for button in sections.get_children():assert(fixed.grow(1).encloses(button.get_global_rect()))
 assert(app.game.save_data("camp")==snapshot and app.preferences.values==settings,"Section navigation changes no campaign state, RNG or setting")
func run():
 var prefs=Preferences.new()
 assert(prefs.show_cinematic("player") and prefs.show_cinematic("enemy"),"Default retains full 3D combat")
 prefs.values.combat="player";assert(prefs.show_cinematic("player") and not prefs.show_cinematic("enemy"))
 prefs.values.combat="map";assert(not prefs.show_cinematic("player"))
 prefs.values.music=0;assert(prefs.volume_db("music")==-80)
 assert(prefs.save_file("/private/tmp/poem-preferences.json"))
 var restored=Preferences.new();assert(restored.load_file("/private/tmp/poem-preferences.json") and restored.values.combat=="map" and restored.values.music==0 and restored.values.text_speed==55)
 var invalid=prefs.values.duplicate();invalid.effects=4;assert(not prefs.valid(invalid))
 invalid.effects="loud";assert(not prefs.valid(invalid))
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-preferences-campaign.json";root.add_child(app);await process_frame
 app.settings_path="/private/tmp/poem-preferences-ui.json";app.show_options("title");await process_frame;await process_frame
 await verify_sections(app)
 var mode=app.ui.find_child("CombatMode",true,false);mode.selected=2;mode.item_selected.emit(2)
 var music=app.ui.find_child("MusicVolume",true,false);music.value=0
 assert(app.preferences.values.combat=="map" and app.music.volume_db==-80,"Menu updates playback and audio")
 var text=app.ui.find_child("TextSpeed",true,false);text.selected=2;text.item_selected.emit(2)
 press_escape(true);assert(app.screen=="options","Held Escape does not leave Options")
 press_escape();await process_frame
 assert(app.screen=="title","Fresh Escape applies Options and returns to its title origin")
 assert(restored.load_file(app.settings_path) and restored.values.text_speed==0)
 app.show_dialogue([{"speaker":"lyra","text":"Instant text."},{"speaker":"oren","text":"Second line."}],func():app.show_title())
 assert(app.dialogue_label.visible_characters==-1 and app.dialogue_stage.ready_indicator.visible and app.dialogue_stage.next_button.text=="Continue  >");app.advance_dialogue()
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
 app.camera.size=15.25;app.camera.h_offset=1.5
 var map_view=app.camera.transform
 app.show_options("battle");await process_frame;await process_frame
 for control in app.ui.find_children("*","Button",true,false):
  var ancestor=control.get_parent();var scrolled=false
  while ancestor!=app.ui:
   if ancestor is ScrollContainer:scrolled=true;break
   ancestor=ancestor.get_parent()
  if not scrolled:assert(control.get_global_rect().end.y<=app.ui.size.y,"Fixed Options controls fit viewport")
 var scroller=app.ui.find_children("*","ScrollContainer",true,false)[0]
 scroller.ensure_control_visible(app.ui.find_child("AutoEnd",true,false));await process_frame;await process_frame
 assert(scroller.get_global_rect().encloses(app.ui.find_child("AutoEnd",true,false).get_global_rect()),"Scrolled Options can reach the final setting")
 press_escape(true);assert(app.screen=="options")
 press_escape();assert(app.screen=="battle","Escape applies Options and returns to tactical play")
 assert(app.camera.transform==map_view and app.camera.size==15.25 and app.camera.h_offset==1.5,"Options preserve the tactical camera view")
 app.show_title();await process_frame;await process_frame
 for control in app.ui.find_children("*","Button",true,false):assert(control.get_global_rect().end.y<=app.ui.size.y,"Title controls fit viewport")
 app.show_credits();await process_frame;await process_frame
 for control in app.ui.find_children("*","Label",true,false):assert(control.get_global_rect().end.y<=app.ui.size.y,"Credits fit the viewport")
 var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;app._unhandled_input(escape)
 assert(app.screen=="title","Credits return to title through the normal back action")
 app.show_camp();app.show_options("camp");var campaign_before=app.game.save_data("camp").duplicate(true)
 press_escape();assert(app.screen=="camp" and app.game.save_data("camp")==campaign_before,"Options Escape preserves the campaign at its camp origin")
 app.show_dossier(app.game.roster[0]);press_escape(true);assert(app.screen=="dossier","Held back key cannot dismiss a dossier")
 app.show_model_view(app.game.roster[0]);await process_frame
 press_escape(true);assert(app.screen=="model","Held back key cannot dismiss a model preview")
 press_escape();assert(app.screen=="dossier")
 press_escape(true);assert(app.screen=="dossier","Held Escape after preview return cannot dismiss the next menu")
 press_escape();assert(app.screen=="camp" and app.game.save_data("camp")==campaign_before)
 for chapter in range(12):
  app.game.chapter=chapter;app.game.story_seen.append("opening_"+str(chapter));app.show_camp();await process_frame;await process_frame
  for control in app.ui.find_children("*","Button",true,false):
   if control.text in ["Options","Save campaign","Transfer a local save","Return to title","Deploy company  >"]:assert(control.get_global_rect().end.y<=app.ui.size.y,"Camp controls fit all twelve chapters")
 await Shutdown.dispose(app);await process_frame
 print("PASS: local preferences, fixed section navigation/focus at three sizes, volume, cinematic modes, instant dialogue, persistence and unchanged combat simulation")
 quit()

func press_escape(echo=false):
 var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;event.echo=echo;root.push_input(event,true)
 var release=InputEventKey.new();release.keycode=KEY_ESCAPE;root.push_input(release,true)
