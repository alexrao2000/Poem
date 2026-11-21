extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var active_frames=0
var skip_next=false
var skipped=false

func _initialize():call_deferred("run")

func monitor(app):
 if not app.stage.visible:return
 assert(app.stage.can_process(),"Visible arena resumes processing")
 var hold=app.stage.get_node_or_null("CombatHitStop")
 if hold!=null and not hold.held.is_empty():return
 var actors=app.stage.get_children().filter(func(node):return node is Imported)
 for actor in actors:
  assert(actor.can_process() and actor.player.can_process(),"Visible encounters resume actor and animation processing")
  active_frames+=1
  if skip_next and actor.pose_name=="strike":app.skip_combat=true;skip_next=false;skipped=true

func verify_suspended(app) -> Array:
 assert(not app.stage.visible and app.stage.process_mode==Node.PROCESS_MODE_DISABLED,"Returning from combat suspends the entire hidden arena")
 await process_frame;await process_frame
 var players=[];var callbacks=[];var updates=[0];var references=[]
 for actor in app.stage.get_children():
  if not actor is Imported:continue
  references.append(weakref(actor))
  players.append({"player":actor.player,"position":actor.player.current_animation_position})
  assert(not actor.can_process() and not actor.player.can_process(),"Hidden imported fighters inherit suspension")
  for rig in actor.skeletons:
   var callback=func():updates[0]+=1
   rig.skeleton_updated.connect(callback);callbacks.append([rig,callback])
 assert(players.size()==2,"Actual encounter left both revised actors available for measurement")
 assert(app.stage.get_child_count()==2,"Map return releases arena scenery and interrupted effects before suspending the fighters")
 await create_timer(.15).timeout
 for item in players:assert(item.player.current_animation_position==item.position,"Hidden animation playheads do not advance")
 assert(updates[0]==0,"Hidden actors emit no skeleton updates")
 for entry in callbacks:entry[0].skeleton_updated.disconnect(entry[1])
 return references

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-stage-lifecycle.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.game.start_battle();app.make_map();app.show_battle()
 var a=app.game.living("player")[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state;var scale=Engine.time_scale
 var callback=monitor.bind(app);process_frame.connect(callback)
 var previous=[]
 for mode in ["ordinary","skipped","victory"]:
  skip_next=mode=="skipped"
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1 if mode!="victory" else 20,"remaining":19 if mode!="victory" else 0,"hit":true,"crit":false}],{a.id:20,b.id:20})
  for reference in previous:assert(reference.get_ref()==null,"The next encounter releases all prior hidden actors before its new stage runs")
  previous=await verify_suspended(app)
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng and Engine.time_scale==scale,"Stage lifetime leaves simulation, RNG and playback speed untouched")
 assert(skipped and active_frames>20,"Real ordinary, skipped and victory exchanges ran on an active stage")
 process_frame.disconnect(callback)
 # The same suspended stage can be reused directly for the model viewer.
 app.show_model_view(a);await process_frame;await process_frame
 var preview=app.preview_actor
 assert(preview is Imported and app.stage.visible and preview.can_process(),"Outfit preview reactivates a stage suspended by combat")
 var before=preview.player.current_animation_position;await create_timer(.15).timeout
 assert(preview.player.current_animation_position!=before,"Visible preview idle animation advances normally")
 for reference in previous:assert(reference.get_ref()==null,"Opening the preview disposes of hidden encounter actors")
 app.close_model_view();await process_frame
 assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Preview round trip preserves resolved state")
 app.show_battle()
 # A newly constructed tactical scene still supports the next real encounter.
 a=app.game.units.filter(func(unit):return unit.id==a.id)[0];b=app.game.units.filter(func(unit):return unit.id==b.id)[0]
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 await verify_suspended(app)
 await Shutdown.dispose(app);await process_frame
 print("PASS: four real encounters suspend hidden animation/skeleton work, resume after skip/victory, free replaced actors and reopen an animated outfit preview without changing campaign/RNG/speed");quit()
