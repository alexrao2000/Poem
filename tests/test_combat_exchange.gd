extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
# Observe actual cinematic poses through counters and follow-ups, including
# mixed weapon reach and skipping mid-exchange. No combat results are rerolled.
const Actor=preload("res://scripts/fighter_actor.gd")
const Projectile=preload("res://scripts/combat_projectile.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const HitStop=preload("res://scripts/combat_hit_stop.gd")
const Charge=preload("res://scripts/combat_charge.gd")
var observing=false
var spells=[]
var contact_colors=[]
var contact_shapes=[]
var misses=[]
var holds=0
var skip_on_hold=false
var blocked_poses=[]
var shield_contacts=0
var guard_flights=0
var map_cues=[]
var recoveries=[]
var skip_on_recovery=false
var sound_cues=[]
var travel_cues=[]
var heard_playbacks={}
var gathered=[]
var skip_on_charge=false

func watch_charge(node):
 if not node is Charge:return
 await process_frame
 gathered.append(node.spell)
 assert(not node.released and node.caster!=null,"Gathering starts during anticipation")
 if skip_on_charge:node.get_parent().get_parent().skip_combat=true

func watch_voices(app):
 for voice in app.sfx_players:
  var playback=voice.get_stream_playback() if voice.playing else null
  if playback!=null and heard_playbacks.get(voice)!=playback:watch_sound(app,voice)
  heard_playbacks[voice]=playback

func watch_sound(app,voice):
 var cue=app.sfx_streams.find_key(voice.stream)
 sound_cues.append(cue)
 if cue not in ["release_bow","release_lance","release_ember","release_gale","release_thunder"]:return
 var actors=app.stage.get_children().filter(func(node):return node is Actor and not node.is_queued_for_deletion())
 for actor in actors:
  if actor.pose_name not in ["strike","throw"]:continue
  if actor.kind=="bow":assert(not actor.bones.NockedArrow.visible,"Bow sound waits for the held arrow to leave")
  if actor.pose_name=="throw":assert(not actor.bones.Weapon.visible,"Thrown spear sound waits for the handoff")

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
 var shields=actors.filter(func(actor):return actor.pose_name=="guard" and actor.bones.has("Shield"))
 if not shields.is_empty():
  var defender=shields[0]
  assert(node.global_position.distance_to(defender.socket_position("guard"))<.001,"Actual blocked impact glints at the bowed shield surface")
  assert(defender.guard_weight>.999 and (-defender.bones.Shield.global_basis.z).dot(-defender.global_basis.z)>.999,"Shield is raised and facing the incoming attack before contact")
  shield_contacts+=1

func watch_guard_flight(node):
 if not node is Projectile:return
 await process_frame
 var actors=node.get_parent().get_children().filter(func(child):return child is Actor and not child.is_queued_for_deletion())
 var shields=actors.filter(func(actor):return actor.pose_name=="guard" and actor.bones.has("Shield"))
 assert(shields.size()==1,"Defender raises the shield before the projectile is released")
 assert(node.destination.distance_to(shields[0].socket_position("guard"))<.001,"Physical projectile flies to the shield instead of through the defender's torso")
 guard_flights+=1

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
  record.destination=node.destination;record.travel_end=node.travel_end

func watch_spell(node):
 if node is Projectile:
  var charge=node.get_parent().get_node_or_null("CombatCharge")
  assert(charge!=null and charge.released,"Projectile launches as the gathering dissipates")
  await process_frame
  spells.append(node.spell)
  var expected={"ember":"EmberCore","gale":"WindCrescent0","thunder":"ThunderBolt0"}[node.spell]
  assert(node.body.has_node(expected),"Equipped folio selects its own airborne shape")
 elif node is Impact:
  await process_frame
  contact_colors.append(node.glow.material_override.albedo_color)
  assert(node.elemental!=null,"Confirmed folio damage creates a distinct spatial impact")
  contact_shapes.append(node.elemental.spell)
  var actors=node.get_parent().get_children().filter(func(child):return child is Actor and child.pose_name in ["hit","critical_hit"])
  assert(actors.size()==1 and node.elemental.global_position.distance_to(actors[0].global_position)<.001,"Elemental impact rises from the actual recipient floor")

func _initialize():call_deferred("run")

func observe(app,shots,skip_at):
 var previous=0;var previous_recovery=0
 while observing:
  await process_frame
  if not app.stage.visible:continue
  var actors=app.stage.get_children().filter(func(node):return node is Actor and not node.is_queued_for_deletion())
  if actors.size()!=2:continue
  var active=actors.filter(func(node):return node.pose_name=="windup")
  var current=active[0].get_instance_id() if active.size()==1 else 0
  if current!=0 and current!=previous:
   assert(not app.ui.get_node("CombatCaption").visible,"Routine attacks leave the action area clear of duplicate headlines")
   var hud=app.ui.get_node("CombatHUD")
   assert(hud.entrance==1 and hud.records.values().all(func(record):return record.plate.modulate.a==1),"Actual nameplates settle within the existing pause before any attack begins")
   shots.append({"a":actors[0].position,"b":actors[1].position,"kind":active[0].kind,"matchups":hud.order.map(func(id):return hud.records[id].matchup.advantage)})
   if shots.size()==skip_at:app.skip_combat=true
  previous=current
  var recovering=actors.filter(func(node):return node.pose_name=="recover")
  var recovery_id=recovering[0].get_instance_id() if recovering.size()==1 else 0
  if recovery_id!=0 and recovery_id!=previous_recovery:
   recoveries.append(recovering[0].kind)
   if skip_on_recovery:app.skip_combat=true
  previous_recovery=recovery_id

func run():
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-exchange-test.json"
 root.add_child(app);await process_frame
 var sound_observer=watch_voices.bind(app);process_frame.connect(sound_observer)
 app.travel_audio.step_played.connect(func(family):
  travel_cues.append(family)
  assert(app.stage.visible and app.stage.get_children().any(func(node):return node is Actor and node.pose_name=="advance"),"Actual arena travel cues occur while a fighter advances or retreats"))
 app.game.start_battle();app.make_map();app.show_battle()
 app.stage.child_entered_tree.connect(watch_hold)
 var a=app.game.units[0];var b=app.game.living("enemy")[0]
 a.x=8;a.y=4;b.x=9;b.y=4;b.weapon="sword"
 for case in ["swords","mixed","axe","skip","skip_hold","skip_recovery"]:
  sound_cues.clear();travel_cues.clear()
  skip_on_hold=case=="skip_hold";skip_on_recovery=case=="skip_recovery";recoveries.clear()
  a.weapon="lance" if case=="mixed" else "axe" if case=="axe" else "sword"
  var events=[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false},{"actor":b.id,"target":a.id,"damage":1,"remaining":19,"hit":true,"crit":false},{"actor":a.id,"target":b.id,"damage":1,"remaining":18,"hit":true,"crit":false}]
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  var shots=[];observing=true;observe(app,shots,2 if case=="skip" else -1)
  await app.cinematic(a,b,events,{a.id:20,b.id:20})
  observing=false;await process_frame
  assert(shots.size()==(1 if case in ["skip_hold","skip_recovery"] else 2 if case=="skip" else 3),"Counter/follow-up order and mid-exchange skip retained: %s had %d windups"%[case,shots.size()])
  assert(recoveries.size()==(0 if case=="skip_hold" else 1 if case in ["skip","skip_recovery"] else 3),"Every completed strike recovers once; skip interrupts the sequence")
  var expected_matchup=1 if case=="mixed" else -1 if case=="axe" else 0
  for shot in shots:
   assert(shot.matchups==[expected_matchup,-expected_matchup],"Actual nameplates carry the resolved matchup through initiation, counter and follow-up")
   assert(is_equal_approx(absf(shot.a.x-shot.b.x),Actor.melee_spacing(shot.kind)),"Each attack starts at its weapon's contact distance")
   assert(shot.a.x<shot.b.x,"Neither fighter crosses the combat axis")
  if case=="swords":
   assert(travel_cues.size()==2 and travel_cues.all(func(family):return family.begins_with("foot_")),"A sword approach has two footfalls; stationary counters add none")
   assert(shots[0].a==shots[1].a and shots[0].b==shots[1].b and shots[0].a==shots[2].a,"Counter and follow-up hold engagement instead of repeating the approach")
  if case=="mixed":
   assert(shots[2].a.x<shots[1].a.x,"Long weapon steps back to regain reach after a short-weapon counter")
  if case in ["swords","mixed","axe"]:
   assert(sound_cues==["release_"+a.weapon,"hit","release_sword","hit","release_"+a.weapon,"hit"],"Every strike and counter uses its weapon cue before contact")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Animation never changes campaign outcomes")
  assert(app.world.visible and not app.stage.visible and app.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Every exchange returns to the map")
  for live in app.stage.get_children().filter(func(node):return node is Actor):assert(live.can_process(),"Skipping during contact never leaves a frozen actor")
  assert(not app.stage.has_node("CombatHitStop"),"Contact hold cleans up before the map returns")
 skip_on_hold=false;skip_on_recovery=false
 var confirmed_holds=holds
 app.stage.child_entered_tree.connect(watch_miss)
 for weapon in ["sword","bow","lance"]:
  sound_cues.clear()
  a.weapon=weapon;a.job="Ranger" if weapon=="bow" else "Knight" if weapon=="lance" else "Vanguard";b.x=10 if weapon in ["bow","lance"] else 9
  misses.clear();var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":false,"crit":false}],{a.id:20,b.id:20})
  assert(misses.size()==(2 if weapon in ["bow","lance"] else 1))
  assert(sound_cues==["release_"+weapon],"A missed attack has its release cue without a false impact sound")
  for sample in misses:
   assert(sample.position.z<-.25 and sample.pose=="evade","Defender dodges before projectile release or melee contact")
   if sample.has("destination"):
    assert(is_zero_approx(sample.destination.z),"Missed projectile keeps its original aim instead of tracking the dodge")
    assert(sample.travel_end>1,"Actual missed arrows and spears carry beyond their original aim point")
  for actor in app.stage.get_children().filter(func(node):return node is Actor):assert(is_zero_approx(actor.position.z),"Dodge settles before returning to the map")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Dodge presentation never changes the miss result")
 app.stage.child_entered_tree.disconnect(watch_miss)
 assert(holds==confirmed_holds,"Missed strikes never run hit stop")
 app.stage.child_entered_tree.connect(watch_spell)
 app.stage.child_entered_tree.connect(watch_charge)
 a.weapon="magic";a.job="Arcanist"
 for folio in ["ember","gale","thunder"]:
  sound_cues.clear()
  a.item=folio
  var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
  assert(sound_cues==["release_"+folio,"impact_"+folio],"Each equipped spell has its distinct launch sound followed by contact")
  assert(not app.stage.has_node("CombatCharge"),"Completed spell removes the anticipation effect")
  assert(app.game.save_data("battle")==saved and app.game.rng.state==rng,"Folio presentation never changes spell results")
 assert(spells==["ember","gale","thunder"],"Real cinematic carries equipment identity through flight")
 assert(contact_shapes==spells,"All three elements carry through gathering, flight and contact")
 assert(gathered==spells,"All three folios gather their own element before release")
 assert(contact_colors.size()==3 and contact_colors[0]!=contact_colors[1] and contact_colors[1]!=contact_colors[2] and contact_colors[0]!=contact_colors[2],"Each element retains a distinct contact color")
 app.stage.child_entered_tree.disconnect(watch_spell)
 sound_cues.clear();a.item="thunder"
 var critical_saved=app.game.save_data("battle").duplicate(true);var critical_rng=app.game.rng.state
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":3,"remaining":17,"hit":true,"crit":true}],{a.id:20,b.id:20})
 assert(sound_cues==["cutin","release_thunder","impact_thunder","critical"],"Actual critical spell keeps its element at contact and adds the existing critical accent")
 assert(app.game.save_data("battle")==critical_saved and app.game.rng.state==critical_rng)
 for contact in [{"hit":true,"damage":1,"crit":false},{"hit":true,"damage":3,"crit":true},{"hit":true,"damage":0,"crit":false},{"hit":false,"damage":0,"crit":false}]:
  sound_cues.clear();contact.merge({"actor":a.id,"target":b.id,"remaining":17})
  await app.map_combat_feedback([contact])
  var expected=["swing"] if not contact.hit else ["guard"] if contact.damage<=0 else ["impact_thunder","critical"] if contact.crit else ["impact_thunder"]
  assert(sound_cues==expected,"Map combat shares elemental damage sounds while preserving guard and miss cues")
 assert(app.game.save_data("battle")==critical_saved and app.game.rng.state==critical_rng,"Compact elemental feedback never changes the already-resolved result")
 sound_cues.clear();skip_on_charge=true
 var before_skip=app.game.save_data("battle").duplicate(true);var before_rng=app.game.rng.state
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":3,"remaining":17,"hit":true,"crit":true}],{a.id:20,b.id:20})
 assert(sound_cues.is_empty() and not app.stage.has_node("CombatCharge"),"Skipping a magical windup removes gathering without launch or impact sounds")
 assert(app.game.save_data("battle")==before_skip and app.game.rng.state==before_rng)
 app.stage.child_entered_tree.disconnect(watch_charge)
 app.stage.child_entered_tree.connect(watch_block)
 confirmed_holds=holds;a.weapon="sword";a.job="Vanguard";b.x=9
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":true,"crit":false}],{a.id:20,b.id:20})
 assert(holds==confirmed_holds and blocked_poses.size()==1 and "guard" in blocked_poses[0],"Armor uses a guard response without damage hit stop")
 app.stage.child_entered_tree.connect(watch_guard_flight)
 b.job="Knight";b.weapon="lance";b.item="iron_lance"
 for weapon in ["sword","bow"]:
  a.weapon=weapon;a.job="Ranger" if weapon=="bow" else "Vanguard";a.item="iron_bow" if weapon=="bow" else "iron_sword";b.x=10 if weapon=="bow" else 9
  for reverse in [false,true]:
   var shield_saved=app.game.save_data("battle").duplicate(true);var shield_rng=app.game.rng.state
   await app.cinematic(b if reverse else a,a if reverse else b,[{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":true,"crit":false}],{a.id:20,b.id:20})
   assert(app.game.save_data("battle")==shield_saved and app.game.rng.state==shield_rng,"Prepared guards and shield contacts never change resolved results")
 assert(shield_contacts==4 and guard_flights==2 and holds==confirmed_holds,"Melee and ranged guards work from either side without a damaging hit stop")
 app.stage.child_entered_tree.disconnect(watch_guard_flight)
 app.ui.child_entered_tree.connect(watch_map_cue)
 await app.map_combat_feedback([{"actor":a.id,"target":b.id,"damage":0,"remaining":20,"hit":true,"crit":false}])
 assert(map_cues==["NO DAMAGE"],"Map-only combat shares the blocked-hit label")
 for player in app.sfx_players:player.stop()
 process_frame.disconnect(sound_observer);heard_playbacks.clear()
 app.music.stop();await create_timer(.15).timeout
 await Shutdown.dispose(app);await process_frame
 print("PASS: continuous exchanges, mixed reach, early dodges, local hit stops, skip cleanup, guarded hits, three spell presentations and unchanged simulation")
 quit()
