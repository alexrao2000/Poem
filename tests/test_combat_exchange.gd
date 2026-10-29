extends SceneTree
# Observe actual cinematic poses through counters and follow-ups, including
# mixed weapon reach and skipping mid-exchange. No combat results are rerolled.
const Actor=preload("res://scripts/fighter_actor.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
var observing=false
var spells=[]
var contact_colors=[]
var misses=[]
var holds=0
var skip_on_hold=false
var blocked_poses=[]
var map_cues=[]

func watch_map_cue(node):
 if not node is Label:return
 await process_frame
 if node.text=="NO DAMAGE":map_cues.append(node.text)

func watch_block(node):
 if not node is Impact:return
 await process_frame
 var actors=node.get_parent().get_children().filter(func(child):return child is Actor and not child.is_queued_for_deletion())
 blocked_poses.append(actors.map(func(actor):return actor.pose_name))
 assert(node.amount.text=="NO DAMAGE" and node.burst==null,"Real blocked combat selects the restrained effect")

func watch_hold(node):
 if not node is HitStop:return
 await process_frame
 holds+=1
 assert(node.held.size()==2 and node.held.all(func(entry):return not entry.actor.can_process()),"Confirmed contact holds both live fighters")
 if skip_on_hold:node.get_parent().get_parent().skip_combat=true

func watch_miss(node):
 if not node is Projectile and not node is Impact:return
 var actors=node.get_parent().get_children().filter(func(child):return child is Actor and not child.is_queued_for_deletion())
 if actors.size()!=2:return
 var record={"position":actors[1].position,"pose":actors[1].pose_name}
 misses.append(record)
 if node is Projectile:
  await process_frame
  record.destination=node.destination

func watch_spell(node):
 if node is Projectile:
  await process_frame
  spells.append(node.spell)
  var expected={"ember":"EmberCore","gale":"WindCrescent0","thunder":"ThunderBolt0"}[node.spell]
  assert(node.body.has_node(expected),"Equipped folio selects its own airborne shape")
 elif node is Impact:
  await process_frame
  contact_colors.append(node.glow.material_override.albedo_color)

func _initialize():call_deferred("run")

func observe(app,shots,skip_at):
 var previous=0
 while observing:
  await process_frame
  if not app.stage.visible:continue
  var actors=app.stage.get_children().filter(func(node):return node is Actor and not node.is_queued_for_deletion())
  if actors.size()!=2:continue
  var active=actors.filter(func(node):return node.pose_name=="windup")
  var current=active[0].get_instance_id() if active.size()==1 else 0
  if current!=0 and current!=previous:
   shots.append({"a":actors[0].position,"b":actors[1].position,"kind":active[0].kind})
   if shots.size()==skip_at:app.skip_combat=true
  previous=current

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-exchange-test.json"
 root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle()
 app.stage.child_entered_tree.connect(watch_hold)
 var a=app.game.units[0];var b=app.game.living("enemy")[0]
 a.x=8;a.y=4;b.x=9;b.y=4;b.weapon="sword"
 for case in ["swords","mixed","skip","skip_hold"]:
  skip_on_hold=case=="skip_hold"
  a.weapon="lance" if case=="mixed" else "sword"
  var events=[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false},{"actor":b.id,"target":a.id,"damage":1,"remaining":19,"hit":true,"crit":false},{"actor":a.id,"target":b.id,"damage":1,"remaining":18,"hit":true,"crit":false}]
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  var shots=[];observing=true;observe(app,shots,2 if case=="skip" else -1)
  await app.cinematic(a,b,events,{a.id:20,b.id:20})
  observing=false;await process_frame
  assert(shots.size()==(1 if case=="skip_hold" else 2 if case=="skip" else 3),"Counter/follow-up order and mid-exchange skip retained: %s had %d windups"%[case,shots.size()])
  for shot in shots:
   assert(is_equal_approx(absf(shot.a.x-shot.b.x),Actor.melee_spacing(shot.kind)),"Each attack starts at its weapon's contact distance")
   assert(shot.a.x<shot.b.x,"Neither fighter crosses the combat axis")
  if case=="swords":
   assert(shots[0].a==shots[1].a and shots[0].b==shots[1].b and shots[0].a==shots[2].a,"Counter and follow-up hold engagement instead of repeating the approach")
  if case=="mixed":
   assert(shots[2].a.x<shots[1].a.x,"Long weapon steps back to regain reach after a short-weapon counter")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Animation never changes campaign outcomes")
  assert(app.world.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Every exchange returns to the map")
  for live in app.stage.get_children().filter(func(node):return node is Actor):assert(live.can_process(),"Skipping during contact never leaves a frozen actor")
  assert(not app.stage.has_node("CombatHitStop"),"Contact hold cleans up before the map returns")
 skip_on_hold=false
 var confirmed_holds=holds
 app.stage.child_entered_tree.connect(watch_miss)
 for weapon in ["sword","bow"]:
  a.weapon=weapon;a.job="Ranger" if weapon=="bow" else "Vanguard";b.x=10 if weapon=="bow" else 9
  misses.clear();var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":false,"crit":false}],{a.id:20,b.id:20})
  assert(misses.size()==(2 if weapon=="bow" else 1))
  for sample in misses:
   assert(sample.position.z<-.25 and sample.pose=="evade","Defender dodges before projectile release or melee contact")
   if sample.has("destination"):assert(is_zero_approx(sample.destination.z),"Missed projectile keeps its original aim instead of tracking the dodge")
  for actor in app.stage.get_children().filter(func(node):return node is Actor):assert(is_zero_approx(actor.position.z),"Dodge settles before returning to the map")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Dodge presentation never changes the miss result")
 app.stage.child_entered_tree.disconnect(watch_miss)
 assert(holds==confirmed_holds,"Missed strikes never run hit stop")
 app.stage.child_entered_tree.connect(watch_spell)
 a.weapon="magic";a.job="Arcanist"
 for folio in ["ember","gale","thunder"]:
  a.item=folio
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Folio presentation never changes spell results")
 assert(spells==["ember","gale","thunder"],"Real cinematic carries equipment identity through flight")
 assert(contact_colors.size()==3 and contact_colors[0]!=contact_colors[1] and contact_colors[1]!=contact_colors[2] and contact_colors[0]!=contact_colors[2],"Each element retains a distinct contact color")
 app.stage.child_entered_tree.disconnect(watch_spell)
 app.stage.child_entered_tree.connect(watch_block)
 confirmed_holds=holds;a.weapon="sword";a.job="Vanguard";b.x=9
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":true,"crit":false}],{a.id:20,b.id:20})
 assert(holds==confirmed_holds and blocked_poses.size()==1 and "guard" in blocked_poses[0],"Armor uses a guard response without damage hit stop")
 app.ui.child_entered_tree.connect(watch_map_cue)
 await app.map_combat_feedback([{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":true,"crit":false}])
 assert(map_cues==["NO DAMAGE"],"Map-only combat shares the blocked-hit label")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: continuous exchanges, mixed reach, early dodges, local hit stops, skip cleanup, guarded hits, three spell presentations and unchanged simulation")
 quit()
