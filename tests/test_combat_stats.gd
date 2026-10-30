extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
const HUD=preload("res://scripts/combat_hud.gd")
var expected_snapshot={}
var saw_snapshot=false
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var g=Rules.new();g.chapter=5;g.start_battle()
 var knight=g.units[1];var mage=g.living("enemy").filter(func(u):return u.weapon=="magic")[0]
 mage.x=knight.x+1;mage.y=knight.y;knight.defense=50;knight.resistance=2
 var damage=g.forecast(mage,knight).damage
 knight.defense=1;assert(g.forecast(mage,knight).damage==damage,"Magic ignores physical defense")
 knight.resistance+=4;assert(g.forecast(mage,knight).damage==damage-4,"Magic respects resistance")
 var blade=g.units[0];blade.x=knight.x+1;blade.y=knight.y
 var physical=g.forecast(blade,knight).damage;knight.resistance+=30
 assert(g.forecast(blade,knight).damage==physical,"Physical strikes ignore resistance")
 blade.item="estoc";g.normalize_equipment(blade)
 assert(g.effectiveness(blade,knight)==3 and g.forecast(blade,knight).effective)
 var heavy=g.forecast(blade,knight).damage
 knight.job="Rider";assert(g.effectiveness(blade,knight)==1 and g.forecast(blade,knight).damage==heavy-6,"Only weapon might is tripled, not total power")
 blade.item="iron_sword";assert(not g.forecast(blade,knight).effective)
 var lance=g.roster[1];assert(g.equip(lance,"riders_bane"));assert(g.effectiveness(lance,knight)==3)
 knight.job="Knight";assert(g.effectiveness(lance,knight)==1)
 var axe=g.roster.filter(func(u):return u.weapon=="axe")[0];assert(g.equip(axe,"war_hammer") and g.effectiveness(axe,knight)==3)
 var before=g.resistance_for(blade);blade.level=1;blade.xp=90;g.award_xp(blade,30)
 assert(blade.resistance==before+1,"Even-level growth grants resistance")
 g.new_campaign();var data=g.save_data("camp").duplicate(true)
 for unit in data.roster:unit.erase("resistance")
 assert(g.restore_save(data)=="camp" and g.roster[1].resistance==1,"Older saves receive class-appropriate resistance")
 g.roster[0].level=10;assert(g.promote(g.roster[0],"standard_bearer"))
 var promoted=g.roster[0].resistance;data=g.save_data("camp").duplicate(true);data.roster[0].erase("resistance")
 assert(g.restore_save(data)=="camp" and g.roster[0].resistance==8,"Migration includes level growth and promotion resistance")
 data=g.save_data("camp").duplicate(true);data.roster[0].resistance="bad";assert(not g.valid_save(data))
 data.roster[0].resistance=-1;assert(not g.valid_save(data))
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-stats-ui.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.selected=app.game.units[0];app.target=app.game.living("enemy")[0]
 app.update_side();await process_frame;await process_frame
 for control in app.side.get_children():assert(control.get_global_rect().end.y<=app.ui.size.y,"Resistance and effectiveness forecast fit viewport")
 await verify_exchange_snapshot(app)
 app.show_equipment(app.game.roster[0]);await process_frame
 await Shutdown.dispose(app);await process_frame
 print("PASS: physical/magic defenses, weapon-might effectiveness, growth, old-save migration, pre-growth exchange snapshots, live arena stats and forecast bounds")
 quit()

func verify_exchange_snapshot(app):
 var a=app.game.units[0];var b=app.game.living("enemy")[0]
 a.x=8;a.y=4;b.x=9;b.y=4;a.xp=90;a.pow=35;a.speed=20;b.hp=1;b.defense=0;b.speed=0
 var before={a.id:app.game.forecast(a,b),b.id:app.game.forecast(b,a)}
 before[a.id].available=true;before[b.id].available=before[a.id].counter
 before[a.id].max_hp=a.max_hp;before[b.id].max_hp=b.max_hp
 var hp={a.id:a.hp,b.id:b.hp};var level=a.level
 var events=app.game.combat(a,b)
 assert(not events.is_empty() and a.level==level+1,"A real resolved exchange crosses a level-up before presentation")
 expected_snapshot=events[0].exchange_forecast.duplicate(true)
 assert(a.max_hp==before[a.id].max_hp+2,"Fixture also gains maximum health before the arena opens")
 assert(expected_snapshot==before and app.game.forecast(a,b).damage!=before[a.id].damage,"Arena statistics retain the actual pre-growth forecast instead of recomputing leveled stats")
 app.make_map();app.show_battle();app.busy=true;app.ui.child_entered_tree.connect(watch_snapshot)
 var saved=app.game.save_data("battle").duplicate(true);var rng=app.game.rng.state
 await app.cinematic(a,b,events,hp)
 assert(saw_snapshot and app.game.save_data("battle")==saved and app.game.rng.state==rng,"Showing captured odds does not resolve combat again or mutate campaign state")
 app.busy=false
 var g=Rules.new();g.start_battle();a=g.units[0];b=g.living("enemy")[0]
 a.weapon="bow";a.item="iron_bow";a.x=8;a.y=4;b.weapon="sword";b.item="iron_sword";b.x=10;b.y=4
 events=g.combat(a,b)
 assert(not events.is_empty() and not events[0].exchange_forecast[b.id].available,"Out-of-range defenders retain the unavailable-counter state even after result resolution")

func watch_snapshot(node):
 if not node is HUD:return
 await process_frame
 for id in expected_snapshot:
  var record=node.records[id]
  assert(record.meter.maximum==expected_snapshot[id].max_hp,"Arena HP maximum stays at the pre-growth value until the reward panel presents the gain")
  assert(record.stats.data==expected_snapshot[id] and record.stats.visible and not record.job.visible,"The real arena receives each side's immutable exchange snapshot")
  assert(record.stats.columns[0].value.text==str(expected_snapshot[id].damage)+("×2" if expected_snapshot[id].double else ""),"Live damage readout includes the pre-exchange follow-up")
 saw_snapshot=true
 node.get_parent().get_parent().get_parent().skip_combat=true
