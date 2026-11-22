extends SceneTree
## The same replay exposes wounded holds and recovery in both model sets.
## Replacing or closing it must cancel delayed poses without touching the save.
const Shutdown=preload("helpers/game_shutdown.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
func _initialize():call_deferred("run")
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-revival-preview-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 var saved=app.game.save_data("camp").duplicate(true);var count=0
 for sample in [["current","lyra",""],["revised","petra",""],["source","female","estoc"],["styled","rider_female","javelin"],["source","warden","field_staff"],["styled","caster","ember"]]:
  if sample[0] in ["current","revised"]:
   app.preferences.values.character_models=sample[0];app.show_model_view(app.game.roster.filter(func(unit):return unit.id==sample[1])[0])
  else:
   app.debug_session.begin(app.game,"camp");app.options_return="camp"
   app.show_source_model_view(sample[1],sample[2],sample[0]=="styled")
  await process_frame;await process_frame
  var actor=app.preview_actor;var choice=app.ui.find_child("PreviewAction",true,false);var actions=app.stage.get_node("PreviewActionPlayer")
  assert((actor is Imported)==(sample[0]!="current"))
  var index=-1
  for at in choice.item_count:
   if choice.get_item_metadata(at)=="revive":index=at
  assert(index>=0,"Every supported model view exposes Revival")
  for size in [Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)]:
   viewport.size=size;await process_frame;await process_frame
   assert(Rect2(Vector2.ZERO,Vector2(size)).encloses(choice.get_global_rect()))
  choice.select(index);choice.item_selected.emit(index)
  var seen=[];var holding=false;var deadline=Time.get_ticks_msec()+3000
  while actions.playing and Time.get_ticks_msec()<deadline:
   await process_frame
   if actor.pose_name not in seen:seen.append(actor.pose_name)
   if actor.pose_name=="down" and actions.pending.size()==2:holding=true
  assert(not actions.playing and seen.has("down") and seen.has("revive") and holding and actor.pose_name=="idle" and actions.pending.is_empty(),"The replay falls, holds, rises and returns ready")
  actions.play("revive");deadline=Time.get_ticks_msec()+2000
  while actions.pending.size()!=2 and Time.get_ticks_msec()<deadline:await process_frame
  assert(actions.pending.size()==2 and actor.pose_name=="down")
  var hold=actions.current;actions.play("idle");await actions.finished;await create_timer(.6).timeout
  assert(not hold.is_valid() and actor.pose_name=="idle" and actions.pending.is_empty(),"Replacing the wounded hold cancels its future rise")
  actions.play("revive");await create_timer(.05).timeout;var pending=actions.current;var ref=weakref(actor)
  app.close_model_view();await process_frame;await process_frame
  assert(ref.get_ref()==null and not pending.is_valid() and not is_instance_valid(actions),"Closing the viewer cancels its replay and releases the actor")
  assert(app.game.save_data("camp")==saved)
  if app.debug_session.active:app.debug_session.end(app.game);assert(app.game.save_data("camp")==saved)
  count+=1
 assert(not FileAccess.file_exists(app.save_path) and not FileAccess.file_exists(app.save_path+".debug"))
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d current/revised/source/styled revival viewers, three-size selector bounds, full replay, held-pose replacement, close cleanup and unchanged campaign/save"%count)
 quit()
