extends SceneTree
# Viewer choices are temporary. Exercise both builders across the full roster,
# then switch real controls during a queued revival and preserve view state.

const Actor=preload("res://scripts/fighter_actor.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const MapUnit=preload("res://scripts/campaign_map_unit.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var returned=0
func _initialize():call_deferred("run")
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func select_model(app,index):
 var control=app.ui.find_child("PreviewModels",true,false)
 control.select(index);control.item_selected.emit(index)
func action_index(control,key):
 for index in control.item_count:
  if control.get_item_metadata(index)==key:return index
 return -1
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-preview-models-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.settings_path=app.save_path+".settings";app.preferences.values.character_models="current";assert(app.preferences.save_file(app.settings_path))
 app.game.story_seen=["opening_0"];app.show_camp();assert(app.persist_campaign("camp"))
 var saved=canonical(app.game.save_data("camp"));var disk=FileAccess.get_file_as_string(app.save_path);var settings=FileAccess.get_file_as_string(app.settings_path);var preferences=app.preferences.values.duplicate(true)
 var builds=0
 for recruit in app.game.roster:
  var promotions=[""]
  for promotion in app.game.promotions:
   if promotion.base==recruit.job:promotions.append(promotion.id)
  assert(promotions.size()==3)
  for promotion in promotions:
   var unit=recruit.duplicate(true);unit.team="player";unit.promotion=promotion
   for mode in ["current","revised"]:
    var result=app.make_preview_fighter(unit,Vector3(35,0,0),mode)
    assert(result.available and ((result.actor is Imported)==(mode=="revised")),"Every recruit and promotion can select either model set locally")
    if mode=="revised":assert(result.actor.model.get_meta("character_identity")==unit.id)
    result.actor.queue_free();await process_frame;builds+=1
 var unsupported=app.game.roster[0].duplicate(true);unsupported.team="player";unsupported.weapon="staff";unsupported.item="field_staff"
 var fallback=app.make_preview_fighter(unsupported,Vector3(35,0,0),"revised")
 assert(not fallback.available and fallback.actor is Actor,"Unavailable revised outfits keep a current-model fallback without claiming availability")
 fallback.actor.queue_free();await process_frame
 var layouts=0
 var callback=func():returned+=1;app.show_camp()
 for id in ["lyra","nell","tarin","ivo","mara","sera","oren","bram"]:
  var unit=app.game.roster.filter(func(value):return value.id==id)[0]
  app.show_model_view(unit,callback);await process_frame;await process_frame
  assert(app.preview_actor is Actor and app.ui.find_child("PreviewModels",true,false).selected==0)
  var sprite=app.ui.find_child("PreviewMapSprite",true,false)
  var map_data=unit.duplicate(true);map_data.team="player";map_data.acted=false
  var tactical=MapUnit.new();app.pieces.add_child(tactical);tactical.configure(app.map_catalog,map_data)
  assert(sprite.visual_id==tactical.visual_id and sprite.catalog==app.map_catalog and sprite.player.clip()==tactical.player.clip())
  assert(sprite.mouse_filter==Control.MOUSE_FILTER_IGNORE and sprite.focus_mode==Control.FOCUS_NONE and sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST)
  for frame in sprite.player.clip().frames:
   tactical.player.index=tactical.player.clip().frames.find(frame);tactical.update_frame()
   var texture=tactical.sprite.texture
   var pixel_scale=Vector2(tactical.sprite.scale.x,tactical.sprite.scale.y)
   var offset=tactical.sprite.offset
   assert(sprite.catalog.frame_texture(sprite.visual_id,int(frame))==texture)
   assert(sprite.frame_rect(int(frame)).is_equal_approx(Rect2(Vector2(offset.x,-offset.y-texture.get_height())*pixel_scale,texture.get_size()*pixel_scale)))
  sprite.player.play("idle","south",true)
  var first=sprite.player.frame_index()
  sprite._process(float(sprite.player.clip().duration_ms[0])/1000.0+.01)
  assert(sprite.player.frame_index()!=first,"The thumbnail advances the real tactical idle animation")
  tactical.queue_free()
  for dimensions in [Vector2i(720,640),Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=dimensions;await process_frame;await process_frame
   var control=app.ui.find_child("PreviewModels",true,false)
   assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(control.get_global_rect()) and control.get_minimum_size().x<=control.size.x,"Model choices stay reachable at every supported size")
   assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(sprite.get_global_rect()) and sprite.get_global_rect().end.x<app.stage.get_node("PreviewCamera").clear_rect().position.x)
   for frame in sprite.player.clip().frames:
    assert(Rect2(Vector2.ZERO,sprite.size).encloses(sprite.display_frame_rect(int(frame))),"Every idle frame fits the thumbnail around a common foot pivot")
   for button in app.ui.find_children("*","Button",true,false):
    if button.is_visible_in_tree() and button.get_viewport()==viewport:assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(button.get_global_rect()),"All viewer actions and Return remain visible beside the selector")
   layouts+=1
  app.preview_actor.rotation.y=-.65;var frame=app.stage.get_node("PreviewCamera");frame.zoom=.82;frame.reframe()
  var choice=app.ui.find_child("PreviewAction",true,false);var revive=action_index(choice,"revive");assert(revive>=0)
  choice.select(revive);choice.item_selected.emit(revive)
  var player=app.stage.get_node("PreviewActionPlayer");var deadline=Time.get_ticks_msec()+3000
  while player.pending.size()!=2 and Time.get_ticks_msec()<deadline:await process_frame
  assert(player.pending.size()==2 and app.preview_actor.pose_name=="down")
  var old=weakref(app.preview_actor);var old_sprite=weakref(sprite);var held=player.current
  app.ui.find_child("PreviewModels",true,false).grab_focus();assert(app.ui.find_child("PreviewModels",true,false).has_focus())
  select_model(app,2);await process_frame;await process_frame
  assert(app.ui.find_child("PreviewModels",true,false).has_focus(),"Keyboard comparison keeps focus on the replacement selector")
  assert(old.get_ref()==null and not held.is_valid(),"Switching models releases the old actor and cancels its queued revival")
  assert(old_sprite.get_ref()==null and app.ui.find_child("PreviewMapSprite",true,false).visual_id=="recruit."+id,"Switching the close-up model retains its tactical identity")
  assert(app.preview_actor is Imported and app.preview_actor.model.get_meta("character_identity")==id)
  assert(is_equal_approx(app.preview_actor.rotation.y,-.65) and is_equal_approx(app.stage.get_node("PreviewCamera").zoom,.82))
  choice=app.ui.find_child("PreviewAction",true,false)
  assert(choice.get_item_metadata(choice.selected)=="revive" and app.stage.get_node("PreviewActionPlayer").selected_action=="revive","Switching retains and restarts the chosen supported replay")
  select_model(app,1);await process_frame;await process_frame;assert(app.preview_actor is Actor and app.ui.find_child("PreviewModels",true,false).has_focus())
  assert(canonical(app.game.save_data("camp"))==saved and app.preferences.values==preferences and not app.debug_session.active)
  assert(FileAccess.get_file_as_string(app.save_path)==disk and FileAccess.get_file_as_string(app.settings_path)==settings,"Preview switches never write campaign or preference files")
  app.close_model_view();await process_frame;assert(app.screen=="camp")
 assert(returned==8)
 viewport.size=Vector2i(1024,640);app.show_model_view(unsupported,callback,{},"revised");await process_frame;await process_frame
 var warnings=app.ui.find_children("*","Label",true,false).filter(func(label):return label.text=="Revised preview unavailable for this outfit.")
 assert(warnings.size()==1 and warnings[0].get_line_count()<=warnings[0].get_visible_line_count() and app.preview_actor is Actor)
 for button in app.ui.find_children("*","Button",true,false):
  if button.is_visible_in_tree() and button.get_viewport()==viewport:assert(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(button.get_global_rect()),"Unsupported outfits keep every action reachable alongside their notice")
 app.close_model_view();await process_frame
 app.preferences.values.character_models="revised"
 var nell=app.game.roster.filter(func(unit):return unit.id=="nell")[0]
 app.show_model_view(nell,callback);await process_frame;assert(app.preview_actor is Imported)
 select_model(app,1);await process_frame;assert(app.preview_actor is Actor and app.preferences.values.character_models=="revised")
 app.close_model_view();await process_frame;app.show_model_view(nell,callback);await process_frame
 assert(app.preview_actor is Imported and app.ui.find_child("PreviewModels",true,false).selected==0,"Reopening uses the active setting, not the last temporary override")
 app.close_model_view();await process_frame
 app.preferences.values.character_models="current";app.debug_session.begin(app.game,"camp",true)
 app.show_model_view(nell,callback);await process_frame;assert(app.preview_actor is Imported)
 select_model(app,1);await process_frame;assert(app.preview_actor is Actor and app.debug_session.revised_duelists and app.preferences.values.character_models=="current")
 select_model(app,0);await process_frame;assert(app.preview_actor is Imported and app.debug_session.revised_duelists,"Use current settings respects the existing Debug class choice")
 app.close_model_view();await process_frame
 app.show_source_model_view("female","estoc",false);await process_frame
 assert(app.ui.find_child("PreviewModels",true,false)==null and app.ui.find_child("PreviewMapSprite",true,false)==null,"Source studies retain their independent styling controls")
 app.close_model_view();await process_frame;app.debug_session.end(app.game)
 assert(canonical(app.game.save_data("camp"))==saved and app.preferences.values==preferences)
 assert(FileAccess.get_file_as_string(app.save_path)==disk and FileAccess.get_file_as_string(app.settings_path)==settings and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d roster/promotion model builds, %d viewer layouts with matching animated map sprites, eight live model swaps with held-revival cleanup and retained rotation/zoom/action; inherited settings, fallback, source-study isolation and unchanged saves/preferences"%[builds,layouts])
 quit()
