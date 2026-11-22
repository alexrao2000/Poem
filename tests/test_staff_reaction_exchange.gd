extends SceneTree
# Staff users receive normal/critical physical contacts without attacking.
# The actual hit stop, promoted identities, enemy defeat and Skip retain the
# resolved campaign state and return to the same tactical camera.

const HitStop=preload("res://scripts/combat_hit_stop.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const ReactionHold=preload("helpers/reaction_hold.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var app
var critical=false
var skip_recoil=false
var contacts=0
func _initialize():call_deferred("run")
func observe(node):
 if not node is HitStop:return
 await ReactionHold.verify(node,critical)
 var patients=node.held.filter(func(entry):return entry.actor.kind=="staff")
 assert(patients.size()==1 and patients[0].actor is Imported and patients[0].actor.pose_name==("critical_hit" if critical else "hit"),"Actual revised staff recipient owns the selected reaction")
 contacts+=1
 if skip_recoil:app.ui.get_node("CombatPlayback").request_skip()
func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-staff-reaction-%d.json"%Time.get_ticks_usec();root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.combat="all";app.game.start_battle();app.make_map();app.show_battle();app.stage.child_entered_tree.connect(observe)
 var foe=app.game.living("enemy")[0].duplicate(true);foe.boss=false;foe.job="Vanguard";foe.weapon="sword";foe.item="iron_sword"
 for entry in [["ivo","luminary",false,false],["esme","wayfarer",true,false],["galen","luminary",true,false],["ivo","wayfarer",true,true],["enemy","",true,false]]:
  critical=entry[2];skip_recoil=entry[3]
  var a=foe.duplicate(true);var b=app.game.roster.filter(func(unit):return unit.id==("ivo" if entry[0]=="enemy" else entry[0]))[0].duplicate(true)
  b.team="player";b.promotion=entry[1];b.item="vigil_staff";b.acted=false;b.moved=false
  if entry[0]=="enemy":
   a=app.game.roster[0].duplicate(true);a.team="player";b.team="enemy";b.id="reaction_enemy_warden"
  a.x=8;a.y=4;a.hp=10;a.acted=false;a.moved=false;b.x=9;b.y=4;b.hp=5;app.game.units=[a,b];app.refresh_pieces();app.busy=true
  b.hp=0 if entry[0]=="enemy" else 2
  var state=app.game.save_data("battle").duplicate(true);var view=app.map_navigation.capture_view();var random=app.game.rng.state;var previous=contacts
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":5-b.hp,"remaining":b.hp,"hit":true,"crit":critical}],{a.id:10,b.id:5})
  await process_frame
  assert(contacts==previous+1 and app.game.save_data("battle")==state and app.game.rng.state==random and app.map_navigation.capture_view()==view)
  assert(app.world.visible and not app.stage.visible and app.stage.process_mode==Node.PROCESS_MODE_DISABLED and not app.stage.has_node("CombatHitStop"),"Staff reaction completion/Skip releases local hit stop and restores map ownership")
  if entry[0]=="enemy":assert(not app.unit_nodes.has(b.id),"Resolved enemy healer defeat is reflected on the returning map")
  else:assert(is_equal_approx(app.unit_nodes[b.id].hp_ratio,float(b.hp)/b.max_hp) and app.unit_nodes[b.id].health.visible,"Returning staff health reflects the resolved damage")
  app.busy=false
 assert(contacts==5 and not FileAccess.file_exists(app.save_path))
 await Shutdown.dispose(app);await process_frame
 print("PASS: five actual revised staff recipient scenes, three promoted identities, normal/critical contact freezing, recoil Skip, enemy defeat, current map health and unchanged state/RNG/camera/files")
 quit()
