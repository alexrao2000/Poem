extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Models=preload("res://scripts/combat_models.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const PATH="res://assets/models/adapter_test.tscn"
func _initialize():call_deferred("run")

func fixture() -> PackedScene:
 var scene=Node3D.new();scene.name="AuthoredModel"
 var hand=Node3D.new();hand.name="Hand";scene.add_child(hand);hand.owner=scene
 var impact=Marker3D.new();impact.name="Impact";impact.position=Vector3(0,1,0);scene.add_child(impact);impact.owner=scene
 var skeleton=Skeleton3D.new();skeleton.name="Skeleton3D";scene.add_child(skeleton);skeleton.owner=scene;skeleton.add_bone("Arm")
 var player=AnimationPlayer.new();player.name="AnimationPlayer";scene.add_child(player);player.owner=scene
 var library=AnimationLibrary.new()
 for clip in ["idle","walk","swing","fall"]:
  var animation=Animation.new();animation.length=1.0
  var track=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(track,"Hand")
  animation.position_track_insert_key(track,0,Vector3.ZERO);animation.position_track_insert_key(track,1,Vector3(0,2,0))
  track=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(track,"Skeleton3D:Arm")
  animation.rotation_track_insert_key(track,0,Quaternion.IDENTITY);animation.rotation_track_insert_key(track,1,Quaternion(Vector3.RIGHT,1))
  library.add_animation(clip,animation)
 player.add_animation_library("",library)
 var packed=PackedScene.new();assert(packed.pack(scene)==OK);scene.free()
 # Exercise the real resource loader without shipping a test model in the game.
 packed.take_over_path(PATH)
 return packed

func specification() -> Dictionary:
 return {"scene":PATH,"scale":2.0,"yaw":90.0,"offset":[0,.1,0],"player":"AnimationPlayer","sockets":{"projectile":"Hand","impact":"Impact"},"poses":{
  "idle":{"clip":"idle"},"advance":{"clip":"walk"},"windup":{"clip":"swing","from":0,"to":.4},"strike":{"clip":"swing","from":.4,"to":1},"hit":{"clip":"swing","from":.2,"to":.3},"evade":{"clip":"swing","from":0,"to":.2},"down":{"clip":"fall"}}}

func run():
 var packed=fixture();assert(ResourceLoader.exists(PATH))
 var world=Node3D.new();root.add_child(world)
 var models=Models.new("");var spec=specification();var g=Rules.new();g.start_battle();var unit=g.units[0]
 models.catalog={"characters":{"lyra":spec},"classes":{"Vanguard":spec},"enemy_classes":{"Vanguard":spec}}
 var rng=g.rng.state;var saved=g.save_data("battle").duplicate(true)
 var actor=models.build(world,unit,Vector3(3,0,0));assert(actor!=null and actor.kind=="sword")
 assert(actor.model.scale==Vector3.ONE*2 and is_equal_approx(actor.model.rotation.y,PI/2))
 assert(actor.socket_position("impact").is_equal_approx(Vector3(3,2.1,0)),"Model transform applies to effect sockets")
 assert(actor.socket_position("guard")==actor.socket_position("impact"),"Authored models without a guard socket preserve their actual impact attachment")
 actor.sockets.guard=actor.model.get_node("Hand")
 assert(actor.socket_position("guard")==actor.model.get_node("Hand").global_position,"Optional authored guard socket follows its own animation attachment")
 actor.sockets.erase("guard")
 assert(actor.socket_position("gaze").is_equal_approx(actor.socket_position("impact")+Vector3.UP*.55),"Authored models without an eye socket retain a sensible gaze fallback")
 await actor.pose("windup",.05).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,.8,0)),"Windup ends at the authored attack split")
 assert(not actor.player.is_playing(),"Non-looping poses hold instead of resetting")
 await actor.pose("strike",.05).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,2,0)),"Strike reaches authored impact")
 assert(actor.model.get_node("Skeleton3D").get_bone_pose_rotation(0).is_equal_approx(Quaternion(Vector3.RIGHT,1)),"Skeleton animation tracks remain attached")
 await actor.pose("critical_hit",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,.6,0)),"Optional critical recoil uses the authored hit interval instead of idle")
 actor.poses.critical_hit={"clip":"swing","from":.3,"to":.5}
 await actor.pose("critical_hit",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,1,0)),"A dedicated authored critical reaction takes precedence")
 await actor.pose("throw_windup",.01).finished;assert(actor.pose_name=="throw_windup")
 await actor.pose("throw",.01).finished;assert(actor.model.get_node("Hand").position.y==2)
 for preparation in ["critical_windup","critical_throw_windup"]:
  await actor.pose(preparation,.01).finished
  assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,.8,0)),"Optional critical preparation falls back to an authored windup")
 actor.poses.throw_windup={"clip":"swing","from":0.0,"to":.6}
 await actor.pose("critical_throw_windup",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,1.2,0)),"Critical throw prefers a dedicated authored throw when available")
 actor.poses.critical_windup={"clip":"swing","from":0.0,"to":.7}
 await actor.pose("critical_windup",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,1.4,0)),"Dedicated authored critical preparation takes precedence")
 await actor.pose("cast_windup",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,.8,0)),"Optional staff preparation falls back to authored windup")
 await actor.pose("cast",.01).finished
 assert(actor.model.get_node("Hand").position.y==2,"Optional staff release falls back to authored strike")
 await actor.pose("recover",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,2,0)) and not actor.player.is_playing(),"Optional recovery falls back to the authored idle section without requiring a new asset clip")
 actor.poses.recover={"clip":"swing","from":.7,"to":.9}
 await actor.pose("recover",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,1.8,0)),"Dedicated authored recovery clip takes precedence")
 await actor.pose("victory",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,2,0)),"Optional finishing stance falls back to the authored idle section")
 assert(actor.finish_flourish(.01)==null,"Models without a flourish do not replay a placeholder idle or finishing clip")
 actor.poses.victory_flourish={"clip":"swing","from":.1,"to":.4}
 await actor.finish_flourish(.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,.8,0)),"Optional authored flourish plays its own section")
 actor.poses.victory={"clip":"swing","from":.2,"to":.6}
 await actor.pose("victory",.01).finished
 assert(actor.model.get_node("Hand").position.is_equal_approx(Vector3(0,1.2,0)),"An authored finishing section takes precedence when supplied")
 actor.pose("advance",.01);await process_frame;assert(actor.player.is_playing() and actor.player.current_animation=="walk","Approach plays locomotion")
 var other=models.build(world,unit,Vector3.ZERO)
 var hold=preload("res://scripts/combat_hit_stop.gd").new();root.add_child(hold)
 var pause=hold.play([actor,other],.12)
 var animation_position=actor.player.current_animation_position
 var hand_position=actor.model.get_node("Hand").position
 await create_timer(.05).timeout
 assert(actor.player.current_animation_position==animation_position and actor.model.get_node("Hand").position==hand_position,"Hit stop also freezes inherited authored animation players")
 await pause.finished
 await create_timer(.03).timeout
 assert(actor.player.current_animation_position>animation_position,"Authored animation resumes after contact hold")
 other.poses.idle={"clip":"swing","from":0.0,"to":1.0};other.pose("idle")
 actor.pose("strike",.01)
 assert(other.player.get_animation("swing").loop_mode==Animation.LOOP_LINEAR and actor.player.get_animation("swing").loop_mode==Animation.LOOP_NONE,"Each actor owns animation loop settings")
 assert(actor.weapon_trail_points().is_empty(),"An authored rig without trail sockets requests the existing accent fallback")
 var edge_spec=spec.duplicate(true);edge_spec.sockets.trail_inner="Hand";edge_spec.sockets.trail_tip="Impact"
 models.catalog.characters.lyra=edge_spec
 var edged=models.build(world,unit,Vector3(2,0,3));await edged.pose("windup",.01).finished
 var edge=edged.weapon_trail_points()
 assert(edge.size()==2 and edge[0].is_equal_approx(edged.model.get_node("Hand").global_position) and edge[1].is_equal_approx(edged.model.get_node("Impact").global_position),"Optional authored edge sockets retain animation, scale, yaw and actor placement")
 models.catalog.characters.lyra=spec
 assert(models.issues.is_empty())
 assert(g.rng.state==rng and g.save_data("battle")==saved,"Assets never mutate simulation or saves")
 var bad=spec.duplicate(true);bad.poses.strike.to=9
 models.catalog.characters.lyra=bad
 var fallback=models.build(world,unit,Vector3.ZERO)
 assert(fallback!=null and models.issues.size()==1,"Invalid character override falls back to valid class asset")
 bad=spec.duplicate(true);bad.player="Missing";models.catalog={"characters":{"lyra":bad}}
 assert(models.build(world,unit,Vector3.ZERO)==null)
 bad=spec.duplicate(true);bad.sockets.projectile="Missing";models.catalog.characters.lyra=bad
 assert(models.build(world,unit,Vector3.ZERO)==null)
 for invalid in [null,{}, {"scene":"user://outside.glb"},{"scene":PATH,"scale":0},{"scene":PATH,"offset":[0,INF,0]}]:assert(not models.specification_error(invalid).is_empty())
 models.catalog={"characters":{"lyra":1},"promotions":{"dawnblade":2},"classes":{"Vanguard":3},"enemy_classes":{"Vanguard":4}}
 unit.promotion="dawnblade";assert(models.candidates(unit)==[1,2,3])
 var foe=unit.duplicate(true);foe.id="enemy";foe.team="enemy";foe.promotion="";assert(models.candidates(foe)==[4])
 var fighters=Fighters.new();fighters.models.catalog={};var procedural=fighters.build(world,unit,Vector3.ZERO)
 assert(procedural.bone("Arm")!=null and not procedural.has_meta("source_model"),"Unmapped roster retains procedural actors")
 assert(procedural.socket_position("impact")==Vector3(0,1.1,0))
 # Run the actual battle presentation through the same adapter, including ranged effects.
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-model-test.json";root.add_child(app);await process_frame
 app.fighters.models.catalog={"classes":{},"enemy_classes":{}}
 for job in g.content.classes:
  app.fighters.models.catalog.classes[job]=spec
  app.fighters.models.catalog.enemy_classes[job]=spec
 app.game.start_battle();app.make_map();app.show_battle()
 var archer=app.game.units.filter(func(u):return u.id=="sera")[0];var enemy=app.game.living("enemy")[0]
 archer.x=8;archer.y=4;enemy.x=10;enemy.y=4
 var events=app.game.combat(archer,enemy);rng=app.game.rng.state
 await app.cinematic(archer,enemy,events)
 var imported=app.stage.get_children().filter(func(node):return node.has_meta("source_model"))
 assert(imported.size()==2 and app.game.rng.state==rng,"Cinematic uses both authored actors without rerolling combat")
 assert(not app.stage.visible and app.world.visible,"Authored combat returns to tactical map")
 for effect_player in app.sfx_players:effect_player.stop()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);world.queue_free();await process_frame
 packed=null
 print("PASS: authored model selection, animation sections, skeletal tracks, sockets, instance isolation and procedural fallback")
 quit()
