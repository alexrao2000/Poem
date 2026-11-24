extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")
func press(app,text_value):
 var buttons=app.ui.find_children("*","Button",true,false).filter(func(b):return b.text==text_value)
 assert(buttons.size()==1 and not buttons[0].disabled);buttons[0].pressed.emit()
func settle():
 await process_frame;await process_frame
func inspect(app):
 for dimensions in [Vector2(720,640),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions;await settle()
  var frame=Rect2(Vector2.ZERO,dimensions)
  for node in app.ui.find_children("*","Control",true,false):
   if not node.is_visible_in_tree():continue
   var parent=node.get_parent();var scroll=null
   while parent!=app.ui:
    if parent is ScrollContainer:scroll=parent;break
    parent=parent.get_parent()
   var bounds=node.get_global_rect()
   if scroll!=null:assert(bounds.position.x>=scroll.global_position.x-1 and bounds.end.x<=scroll.get_global_rect().end.x+1)
   else:assert(frame.grow(1).encloses(bounds),"Music room fixed controls fit supported sizes")
func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-music-room.json"
 root.add_child(app);await process_frame
 var state=app.game.save_data("camp").duplicate(true);var preferences=app.preferences.values.duplicate(true)
 app.show_music_room();assert(app.screen=="title","Audition opens only through Options")
 for mode in ["playing","paused","stopped","fading"]:
  app.score_director.cancel_fade();app.music.stop();app.music.stream_paused=false
  if mode!="stopped":app.music.play(9.0)
  if mode=="paused":app.music.stream_paused=true
  if mode=="fading":
   app.game.chapter=4;app.select_score_theme();app.music_mix(true)
   await create_timer(.06).timeout
  var original_voice=app.music;var original_pair=app.score;var original_id=app.score_director.current_id
  var original_paused=original_voice.stream_paused;var original_playing=original_voice.playing
  var original_playback=original_voice.get_stream_playback() if original_voice.has_stream_playback() else null
  var outgoing=app.score_director.outgoing;var outgoing_paused=outgoing.stream_paused if is_instance_valid(outgoing) else false
  var act_fade=app.score_director.fade;var battle_fade=app.music_transition
  var act_running=act_fade!=null and act_fade.is_valid() and act_fade.is_running()
  var battle_running=battle_fade!=null and battle_fade.is_valid() and battle_fade.is_running()
  app.show_options("camp");press(app,"Listen to campaign music")
  var preview=app.ui.get_node("MusicRoomAudio");var preview_ref=weakref(preview)
  print("Audition ",mode,": screen=",app.screen," campaign paused=",original_voice.stream_paused," campaign playing=",original_voice.playing," preview playing=",preview.director.player.playing)
  assert(app.screen=="music_room" and not original_voice.playing and preview.director.player.playing)
  if original_playing or original_paused:assert(original_voice.stream_paused)
  var suspended_position=original_voice.get_playback_position()
  if is_instance_valid(outgoing):assert(outgoing.stream_paused)
  if act_running:assert(not act_fade.is_running())
  if battle_running:assert(not battle_fade.is_running())
  await inspect(app)
  var chooser=app.ui.find_child("MusicRoomTheme",true,false);assert(chooser.item_count==4 and chooser.has_focus())
  var assigned=["Chapters 01–04","Chapters 05–08","Chapters 09–11","Chapter 12"]
  for index in range(chooser.item_count):
   chooser.select(index);chooser.item_selected.emit(index)
   var voice=preview.director.player;var pair=preview.director.score
   assert(preview.theme_index==index and preview.director.current_id==preview.director.profiles[index].id)
   assert(app.ui.find_child("MusicRoomDetails",true,false).text.begins_with(assigned[index]))
   assert(not preview.select_theme(-1) and not preview.select_theme(chooser.item_count) and not preview.select_theme(index))
   voice.seek(12.0);await settle();var position=voice.get_playback_position()
   app.ui.find_child("MusicRoomAblaze",true,false).pressed.emit();await create_timer(.48).timeout
   assert(preview.ablaze and preview.director.player==voice and preview.director.score==pair and voice.pitch_scale==1.0)
   assert(pair.get_sync_stream_volume(0)<=-59 and absf(pair.get_sync_stream_volume(1))<.01)
   assert(voice.get_playback_position()>=position-.03,"Arrangement switching never restarts or seeks the shared musical clock")
   app.ui.find_child("MusicRoomCalm",true,false).pressed.emit();await create_timer(.48).timeout
   assert(not preview.ablaze and absf(pair.get_sync_stream_volume(0))<.01 and pair.get_sync_stream_volume(1)<=-59)
   assert(preview.director.outgoing==null,"Theme crossfades release their outgoing pair")
  assert(app.music==original_voice and app.score==original_pair and app.score_director.current_id==original_id)
  assert(absf(original_voice.get_playback_position()-suspended_position)<.04,"Campaign playhead stays paused from the moment audition opens")
  if original_playback!=null:assert(original_voice.get_stream_playback()==original_playback,"Campaign decoder is retained, never restarted")
  var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_ESCAPE;key.echo=true;app._unhandled_input(key)
  assert(app.screen=="music_room")
  if mode=="playing":press(app,"Return to Options")
  elif mode=="fading":app.show_options("camp")
  else:key.echo=false;app._unhandled_input(key)
  assert(app.screen=="options" and original_voice.stream_paused==original_paused and original_voice.playing==original_playing)
  if is_instance_valid(outgoing):assert(outgoing.stream_paused==outgoing_paused)
  if act_running:assert(act_fade.is_running())
  if battle_running:assert(battle_fade.is_running())
  await settle();await settle();assert(preview_ref.get_ref()==null,"Every audition controller releases on screen exit")
  if mode!="fading":
   var launch=app.ui.find_child("OpenMusicRoom",true,false)
   assert(launch.has_focus() and launch.get_parent().get_parent().get_global_rect().grow(1).encloses(launch.get_global_rect()),"Returning restores visible focus to the music control in the long Options page")
  await create_timer(.5).timeout
 app.game.chapter=0
 assert(app.game.save_data("camp")==state and app.preferences.values==preferences,"Audition changes no campaign, RNG or preferences")
 app.preferences.values.music=0;app.apply_audio_preferences();app.show_options("camp");press(app,"Listen to campaign music")
 var muted=app.ui.get_node("MusicRoomAudio")
 assert(muted.director.player.volume_db<=-79)
 muted.select_theme(2);await create_timer(.5).timeout;assert(muted.director.player.volume_db<=-79)
 assert(app.ui.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Music volume: 0%")))
 muted.select_arrangement(true)
 for index in [0,1,3,0,2]:
  muted.select_theme(index)
  assert(muted.ablaze and muted.director.score.get_sync_stream_volume(1)==0,"New themes retain the chosen arrangement")
  assert(muted.director.get_child_count()<=2,"Rapid selection retains at most the current and outgoing preview voice")
 muted.select_arrangement(false);var interrupted=weakref(muted)
 press(app,"Return to Options");await settle()
 assert(interrupted.get_ref()==null and not app.music.stream_paused,"Closing during simultaneous theme/arrangement fades releases the room and restores the campaign")
 await verify_authored_labels(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: four-theme music room, continuous Calm/Ablaze switching, bounded crossfades, twenty layout checks, muted preview, guarded navigation and playing/paused/stopped/fading campaign restoration without state changes")
 quit()

func verify_authored_labels(app):
 var chapters=app.game.content.chapters
 var originals=chapters.duplicate(true)
 for i in range(chapters.size()):
  chapters[i].score_theme="road" if i==1 or i in [4,5,6,7] else "standard"
 chapters[0].score_theme="dawnless"
 app.game.chapter=1
 var campaign_voice=app.music
 var state=app.game.save_data("camp");var rng=app.game.rng.state
 app.show_options("camp");press(app,"Listen to campaign music")
 var room=app.ui.get_node("MusicRoomAudio")
 var chooser=app.ui.find_child("MusicRoomTheme",true,false)
 var details=app.ui.find_child("MusicRoomDetails",true,false)
 assert(chooser.selected==1 and room.director.current_id=="road" and details.text=="Chapters 02, 05–08 · 96 BPM")
 await inspect(app)
 chooser.select(2);chooser.item_selected.emit(2)
 assert(room.director.current_id=="dawnless" and details.text=="Chapter 01 · 120 BPM")
 chapters[0].score_theme="standard"
 chooser.select(1);chooser.item_selected.emit(1)
 chooser.select(2);chooser.item_selected.emit(2)
 assert(details.text=="120 BPM","Unused music stays accessible without advertising an incorrect chapter")
 chapters.assign(originals)
 press(app,"Return to Options");await settle()
 assert(app.game.save_data("camp")==state and app.game.rng.state==rng and app.music==campaign_voice)
 print("PASS: Music Room follows the authored theme and formats split, single and unused chapter assignments")
