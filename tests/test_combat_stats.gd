extends SceneTree
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
 app.show_equipment(app.game.roster[0]);await process_frame
 app.queue_free();await process_frame
 print("PASS: physical/magic defenses, weapon-might effectiveness, growth, old-save migration and forecast bounds")
 quit()
