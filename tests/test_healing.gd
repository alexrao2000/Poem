extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const Heal=preload("res://scripts/combat_heal.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Rules=preload("res://scripts/rules.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
var light_count=0
var harmful_count=0

func _initialize():call_deferred("run")

func watch_effect(node):
 if node is Heal:light_count+=1
 if node is Impact or node is HitStop:harmful_count+=1

func run():
 var world=Node3D.new();root.add_child(world);world.position=Vector3(3,0,4)
 var rules=Rules.new();var fighters=Fighters.new()
 for unit in rules.roster.filter(func(recruit):return recruit.weapon=="staff"):
  for direction in [-1,1]:
   var recruit=unit.duplicate(true);recruit.team="player"
   var actor=fighters.build(world,recruit,Vector3.ZERO);actor.rotation.y=direction*PI/2
   for key in ["cast_windup","cast"]:
    var motion=actor.pose(key,.08)
    while motion.is_running():
     await process_frame
     assert(actor.bone("Weapon").global_basis.y.dot(Vector3.UP)>.999,"Raised staff remains upright through the entire cast")
     assert(actor.socket_position("projectile").distance_to(actor.bone("Weapon").to_global(Vector3(0,.78,0)))<.0001,"Healing departs from the staff's luminous crown")
   actor.queue_free();await process_frame
 for height in [1.1,1.85]:
  var from=Vector3(5,2.0,4);var to=Vector3(9,height,4)
  var effect=Heal.new();world.add_child(effect);var motion=effect.play(from,to,Vector3(9,0,4),12)
  var reference=weakref(effect)
  assert(not effect.amount.visible,"Healing number waits for light to arrive")
  assert(effect.glow.material_override.billboard_keep_scale and effect.glow.material_override.disable_fog,"Recovery bloom retains animated scale without fog revealing its transparent rectangle")
  for strand in range(3):
   assert(effect.flight_point(0,strand)==from and effect.flight_point(1,strand).distance_to(to)<.0001,"All three strands connect actual world-space sockets")
  await effect.arrived
  assert(effect.amount.visible and effect.amount.text=="+12" and effect.trails.all(func(entry):return not entry.node.visible),"Recovery cue replaces travel at contact")
  assert(effect.rings[0].global_position.distance_to(Vector3(9,.06,4))<.0001,"Recovery circle stays at the feet even for mounted allies")
  assert(effect.glow.global_position.distance_to(to)<.0001,"Bloom follows recipient height under transformed parents")
  await motion.finished;await process_frame
  assert(reference.get_ref()==null,"Completed recovery releases all temporary geometry")
 world.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-healing-test.json";root.add_child(app);await process_frame
 app.preferences.values.auto_end=false
 var score=app.score
 for mode in ["all","player","map","skip_windup","skip_light"]:
  app.game.start_battle();app.make_map();app.show_battle();app.preferences.values.combat=mode if mode in ["all","player","map"] else "all"
  app.stage.child_entered_tree.connect(watch_effect)
  var healer=app.game.units.filter(func(unit):return unit.id=="ivo")[0];var recipient=app.game.units[0]
  healer.x=4;healer.y=4;healer.xp=0;recipient.x=4;recipient.y=5;recipient.hp=recipient.max_hp-6
  if mode=="player":recipient.job="Rider"
  app.refresh_pieces();app.selected=healer
  var camera_position=app.camera.position;var rng=app.game.rng.state;var effect_count=light_count;var observed_hp=[];var did_skip=false
  app.click_tile(app.game.pos(recipient))
  assert(app.busy and healer.acted and healer.xp==30 and recipient.hp==recipient.max_hp,"Staff action resolves health and experience once before presentation")
  var resolved=app.game.save_data("battle").duplicate(true)
  # Repeated input during the cutaway must not spend another action or award XP.
  app.click_tile(app.game.pos(recipient))
  while app.busy:
   await process_frame
   var hud=app.ui.get_node_or_null("CombatHUD")
   if hud!=null and not hud.is_queued_for_deletion():
    assert(not app.ui.get_node("CombatCaption").visible,"Healing uses its local number and health meter without a duplicate headline")
    observed_hp.append(hud.records[recipient.id].meter.value)
    assert(hud.records.values().all(func(record):return not record.plate.enemy),"Healing shows two allied nameplates")
   var actors=app.stage.get_children().filter(func(node):return node is Actor and not node.is_queued_for_deletion())
   if app.stage.visible and actors.size()==2:
    assert(actors[1].pose_name=="idle","Ally never recoils, dodges or falls during recovery")
    if mode=="skip_windup" and actors[0].pose_name=="cast_windup":app.skip_combat=true;did_skip=true
    if mode=="skip_light" and light_count>effect_count:app.skip_combat=true;did_skip=true
   if mode=="map":assert(not app.stage.visible and app.camera.position==camera_position,"Quick healing retains the tactical camera")
  assert(app.game.save_data("battle")==resolved and app.game.rng.state==rng,"Animation, repeated input and skip preserve HP, XP, support and RNG")
  assert(app.world.visible and app.pieces.visible and not app.stage.visible and app.camera.position==camera_position and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Staff cutaway restores the complete map view")
  assert(app.unit_nodes[healer.id].spent and app.selected==null,"Completed recovery consumes exactly one field action")
  assert(app.ui.get_node_or_null("CombatHUD")==null and app.stage.get_node_or_null("CombatHeal")==null,"Map return has no leftover recovery effect or HUD")
  if mode in ["skip_windup","skip_light"]:assert(did_skip,"Skip was exercised during the intended phase")
  assert(light_count-effect_count==(0 if mode in ["map","skip_windup"] else 1),"Animation preference and early skip control the cast: "+mode)
  if mode!="map":
   assert(not observed_hp.is_empty() and observed_hp[0]==recipient.max_hp-6,"Close-up begins with the pre-heal HP")
   for i in range(1,observed_hp.size()):assert(observed_hp[i]>=observed_hp[i-1],"Recovery meter only rises")
   if mode not in ["skip_windup","skip_light"]:assert(is_equal_approx(observed_hp[-1],recipient.max_hp),"HP reaches the already-resolved recovery result")
  await create_timer(.5).timeout
  assert(app.score==score and absf(app.score.get_sync_stream_volume(0))<.01 and app.score.get_sync_stream_volume(1)<-59,"Staff presentation returns the existing synchronized score to calm")
 assert(harmful_count==0,"Healing never emits damaging impact or hit-stop effects")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout;await Shutdown.dispose(app);await process_frame
 print("PASS: three staff rigs, world-space recovery, mounted recipients, real field healing, rising HP, preferences, skip cleanup and unchanged resolved progression")
 quit()
