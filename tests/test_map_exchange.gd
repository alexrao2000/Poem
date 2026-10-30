extends SceneTree
# The field preserves pre-exchange figures until presentation finishes, then
# exposes the already-resolved roster before XP cards or the next actor can run.

const Shutdown=preload("helpers/game_shutdown.gd")
const MapUnit=preload("res://scripts/campaign_map_unit.gd")
const Actor=preload("res://scripts/fighter_actor.gd")
const Reward=preload("res://scripts/progress_reward.gd")
var app
var mode=""
var lost_id=""
var old_visual
var saw_contact=false
var saw_return=false
var saw_reward=false
var skip_arena=false
var expected_facings={}
var saw_facing=false

func _initialize():call_deferred("run")

func setup():
 mode=""
 app.game.new_campaign();app.game.start_battle();app.preferences.values.auto_end=false
 var a=app.game.living("player")[0];var b=app.game.living("enemy")[0];var spare=app.game.living("player")[1]
 a.x=8;a.y=4;b.x=9;b.y=4;spare.x=0;spare.y=0;b.ai="guard"
 app.game.units=[a,spare,b];app.make_map();app.show_battle()
 app.pieces.visibility_changed.connect(watch_return)
 app.ui.child_entered_tree.connect(watch_ui)
 app.stage.child_entered_tree.connect(watch_arena)
 saw_contact=false;saw_return=false;saw_reward=false;saw_facing=false
 return [a,b,spare]

func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-map-exchange.json";root.add_child(app);await process_frame
 await verify_departures()
 var directions={"defeat":[Vector2i.RIGHT,"east","west"],"counter":[Vector2i.UP,"north","south"],"survive":[Vector2i.LEFT,"west","east"],"heal":[Vector2i.DOWN,"south","north"],"skip":[Vector2i.RIGHT,"east","west"]}
 for case in ["defeat","counter","survive","heal","skip"]:
  var pair=setup();var a=pair[0];var b=pair[1];mode="arena";app.busy=true;app.preferences.values.combat="all"
  b.x=a.x+directions[case][0].x;b.y=a.y+directions[case][0].y;app.refresh_pieces()
  lost_id="";skip_arena=case=="skip";var initial={a.id:a.hp,b.id:b.hp};var events=[]
  if case=="heal":
   b.team="player";b.hp-=6;app.refresh_pieces();initial[b.id]=b.hp;b.hp+=4
   a.weapon="staff";a.item="heal_staff";events=[{"actor":a.id,"target":b.id,"healing":4}]
  else:
   var target=a if case=="counter" else b;var attacker=b if case=="counter" else a
   var damage=3 if case=="survive" else target.hp;target.hp-=damage
   lost_id=target.id if target.hp==0 else ""
   events=[{"actor":attacker.id,"target":target.id,"damage":damage,"remaining":target.hp,"hit":true,"crit":false}]
  expected_facings={a.id:directions[case][1],b.id:directions[case][2]}
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  await app.cinematic(a,b,events,initial)
  assert(saw_return and saw_facing,"Field departure and return were observed for "+case)
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Field synchronization only presents resolved outcomes")
  app.busy=false
 for case in ["enemy_kill","enemy_counter"]:
  var pair=setup();var a=pair[0];var b=pair[1];mode="map";app.preferences.values.combat="map"
  if case=="enemy_kill":
   a.hp=1;a.speed=0;b.speed=50;b.pow=100;lost_id=a.id
  else:
   b.hp=1;b.speed=0;b.defense=0;a.speed=50;a.pow=100;a.defense=30;lost_id=b.id
  app.refresh_pieces()
  app.end_turn();old_visual=app.unit_nodes[lost_id]
  while app.busy:await process_frame
  assert(saw_contact,"Resolved enemy turn still presents the defeated unit's actual map reaction: "+case)
  assert(not app.unit_nodes.has(lost_id),"Defeated map figure disappears after feedback")
  if case=="enemy_counter":assert(saw_reward,"Counterattack XP begins after field synchronization")
 mode="";await Shutdown.dispose(app);await process_frame
 print("PASS: five arena returns (defeat/counter/survival/heal/skip), actual enemy kill/counter map reactions, 25 coordinated sprite exits and teardown, updated health before XP, and unchanged resolved state")
 quit()

func watch_return():
 if mode!="arena":return
 if not app.pieces.visible:
  for id in expected_facings:
   assert(app.unit_nodes[id].player.facing==expected_facings[id] and app.map_facings[id]==expected_facings[id],"Both map figures face the exchange before the arena handoff")
  saw_facing=true;return
 saw_return=true;verify_field()
 for id in expected_facings:
  if app.unit_nodes.has(id):assert(app.unit_nodes[id].player.facing==expected_facings[id],"Surviving map figures retain their facing through the combat return")

func verify_field():
 for unit in app.game.units:
  assert(app.unit_nodes.has(unit.id)==(unit.hp>0),"Map visibility agrees with resolved health before the reveal or reward")
  if unit.hp>0:
   var visual=app.unit_nodes[unit.id]
   assert(is_equal_approx(visual.hp_ratio,float(unit.hp)/unit.max_hp),"Returning health bars reflect damage and healing immediately")
   assert(visual.spent==unit.acted,"Returning action tint agrees with the resolved turn state")

func watch_arena(node):
 if mode!="arena" or not skip_arena or not node is Actor:return
 await process_frame;app.skip_combat=true

func watch_ui(node):
 if mode!="map":return
 if node is Reward:
  await process_frame
  verify_field();saw_reward=true;node.requested_close=true
 if not node is Label:return
 await process_frame
 if not is_instance_valid(node) or not node.text.is_valid_int() and not node.text.begins_with("CRIT "):return
 if app.game.units.filter(func(unit):return unit.id==lost_id)[0].hp>0:return
 if not is_instance_valid(old_visual):
  assert(false,"Enemy turn removed its defeated sprite before presenting the hit");return
 if old_visual.player.state=="defeated":
  assert(old_visual.is_visible_in_tree() and old_visual.hp_ratio==0,"Defeated sprite receives its hit and empty health bar before removal")
  saw_contact=true
  assert(old_visual.departing and old_visual.sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED,"Actual quick-map kills start their owned fade")
  var minimum=old_visual.defeat_opacity;var maximum=minimum
  while is_instance_valid(old_visual) and old_visual.is_visible_in_tree():
   minimum=minf(minimum,old_visual.defeat_opacity);maximum=maxf(maximum,old_visual.defeat_opacity)
   await process_frame
  if is_instance_valid(old_visual):minimum=minf(minimum,old_visual.defeat_opacity)
  assert(minimum<.3 and maximum>.7,"Actual enemy kill and counter-kill traverse the opacity range during existing feedback")

func verify_departures():
 var stage=Node3D.new();root.add_child(stage)
 var units=app.game.roster.duplicate(true)
 var commander=units[0].duplicate(true);commander.team="enemy";commander.boss=true;units.append(commander)
 for source in units:
  var unit=source.duplicate(true);unit.acted=false
  if not unit.has("team"):unit.team="player"
  var actor=MapUnit.new();stage.add_child(actor);actor.configure(app.map_catalog,unit);actor.selected=true
  var shared=actor.marker.material_override;var original_alpha=shared.albedo_color.a
  actor.react(true,0);var motion=actor.fade_defeat();motion.pause()
  assert(actor.fade_defeat()==motion,"Repeated defeat notification cannot restart or lengthen the exit")
  motion.custom_step(.13);actor._process(.01)
  assert(actor.defeat_opacity>.3 and actor.defeat_opacity<.7 and actor.sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED,"Map defeat uses real translucent coverage after the hit pose registers")
  assert(is_equal_approx(actor.sprite.modulate.a,actor.defeat_opacity) and is_equal_approx(actor.health.modulate.a,actor.defeat_opacity),"Sprite animation cannot overwrite the exit opacity; health fades together")
  assert(actor.marker.material_override!=shared and is_equal_approx(shared.albedo_color.a,original_alpha),"Only the defeated unit owns a fading contact shadow")
  if actor.commander_insignia!=null:assert(is_equal_approx(actor.commander_insignia.modulate.a,actor.defeat_opacity),"Commander insignia exits with its figure")
  assert(not actor.ring.visible,"A defeated selected unit cannot leave a glowing selection marker")
  motion.custom_step(.1);assert(not actor.visible and actor.defeat_opacity==0,"Complete map exit hides the whole figure before damage text finishes")
  actor.queue_free();await process_frame
 var actor=MapUnit.new();stage.add_child(actor);var unit=units[0].duplicate(true);unit.team="player";unit.acted=false;actor.configure(app.map_catalog,unit)
 var interrupted=actor.fade_defeat();interrupted.pause();interrupted.custom_step(.1);actor.free();await process_frame
 assert(not interrupted.is_valid(),"Scene teardown kills the bound exit tween")
 stage.queue_free();await process_frame
