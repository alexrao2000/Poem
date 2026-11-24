extends SceneTree
## Scaled flights retain physical tip contact and spell identity. Actual map
## attacks verify sprite-body alignment, pre-contact health and committed saves.
const Projectile=preload("res://scripts/combat_projectile.gd")
const MapProjectile=preload("res://scripts/map_projectile.gd")
const Contact=preload("res://scripts/map_impact.gd")
const Rules=preload("res://scripts/rules.gd")
const Encounters=preload("res://scripts/debug_encounters.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var app
var target_id=""
var initial_health=0.0
var flights=[]
var impacts=[]
var observed=0
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))

func verify_shared_geometry(host: Node3D):
 for sample in [["bow",""],["lance",""],["magic","ember"],["magic","gale"],["magic","thunder"],["magic",""]]:
  var arena=Projectile.new();host.add_child(arena)
  var tactical=MapProjectile.new();host.add_child(tactical)
  var from=host.global_position+Vector3.UP;var to=from+Vector3.RIGHT*3
  arena.launch(from,to,sample[0],1,sample[1],{"width":.05}).kill()
  tactical.fly(from,to,sample[0],sample[1],{"width":.09}).kill()
  var models=arena.body.get_children();var scaled=tactical.body.get_children()
  assert(models.size()==scaled.size())
  for index in models.size():
   var first=models[index];var second=scaled[index]
   if sample[0]=="lance" and first.name=="Tip":
    assert(first.mesh!=second.mesh and first.mesh.get_aabb().size.x<second.mesh.get_aabb().size.x,
     "Each thrown spear tip retains the equipped width")
   else:
    assert(first.mesh==second.mesh,"Fixed shapes are shared between the two presentation modes")
   assert(first.material_override!=second.material_override and not first.material_override.no_depth_test and second.material_override.no_depth_test,
    "A map projectile can change depth without affecting the 3D projectile")
  if sample[0]=="bow":assert(models[2].mesh==models[3].mesh and models[3].mesh==models[4].mesh)
  arena.free();tactical.free()
 print("PASS: arrows, fixed spell pieces and shafts share geometry across both modes with independent materials and fitted spear tips")

func watch(node):
 if node is Contact:
  impacts.append(weakref(node));await process_frame
  assert(node.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.material_override.no_depth_test and mesh.material_override.render_priority==3))
  assert(node.find_children("*","Label3D",true,false).is_empty(),"Map contact keeps the existing single damage cue")
  return
 if not node is Projectile:return
 var victim=app.unit_nodes[target_id];var point=app.map_contact_point(victim)
 var first=flights.is_empty();flights.append(weakref(node))
 await process_frame
 assert(node.visual_scale==.55 and node.body.global_basis.get_scale().is_equal_approx(Vector3.ONE*.55))
 assert(node.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
 assert(node.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.material_override.no_depth_test and mesh.material_override.render_priority==3 and mesh.material_override.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_DISABLED),"Tactical shots share the map figures' overlay depth without writing depth or casting shadows")
 if first:
  assert(impacts.is_empty(),"Contact sparks wait for the first projectile to arrive")
  assert(node.destination.distance_to(point)<.0001,"The first projectile aims at the displayed target body before recoil/evasion")
  assert(victim.hp_ratio==initial_health,"Health feedback waits for the flight to reach contact")
  var saved=Rules.new();assert(saved.load_game(app.save_path)=="battle" and canonical(saved.save_data("battle"))==canonical(app.game.save_data("battle")),"Resolved combat was committed before the projectile appeared")
 assert(not app.stage.visible and app.pieces.visible)
 observed+=1

func run():
 var host=Node3D.new();root.add_child(host);host.position=Vector3(3,.2,-4);host.rotation.y=.3;host.scale=Vector3.ONE*1.3
 verify_shared_geometry(host)
 var view=Camera3D.new();host.add_child(view);view.rotation=Vector3(-.7,.3,0)
 for spell in ["","ember","gale","thunder"]:
  for damage in [0,3]:
   for critical in [false,true]:
    var effect=Contact.new();host.add_child(effect)
    var point=Vector3(3,.8,-4);var clock=effect.contact(point,view,{"damage":damage,"crit":critical},spell);clock.pause()
    assert(effect.global_position.distance_to(point)<.0001 and effect.global_basis.z.normalized().dot(view.global_basis.z.normalized())>.9999)
    assert((effect.burst!=null)==(damage>0),"Blocked hits omit damaging sparks")
    assert((effect.guard!=null)==(damage==0),"Only blocked hits show guard rings, including critical and spell flags")
    if damage==0:
     assert(effect.glow.material_override.albedo_color==Color("9caab5"))
     assert(effect.guard.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==240 and effect.guard.material_override.no_depth_test and effect.guard.material_override.render_priority==3)
    elif not spell.is_empty():assert(effect.glow.material_override.albedo_color==effect.Spell.palette(spell).accent)
    var ref=weakref(effect);clock.custom_step(.10);assert(effect.glow.material_override.albedo_color.a<.6)
    clock.custom_step(.11);await process_frame;assert(ref.get_ref()==null)
 view.queue_free();await process_frame
 var samples=0
 for scale_value in [.55,1.0]:
  for entry in [["bow",""],["lance",""],["magic","ember"],["magic","gale"],["magic","thunder"]]:
   for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
    for missed in [false,true]:
     var shot=Projectile.new();host.add_child(shot)
     var from=Vector3(3,.7,-4);var to=from+direction*2.5+Vector3.UP*.3
     shot.launch(from,to,entry[0],1,entry[1],{},missed,null,scale_value).kill();shot.set_process(false)
     assert(shot.point_at(1).distance_to(to)<.0001 and shot.body.global_basis.get_scale().is_equal_approx(Vector3.ONE*scale_value))
     for step in 13:
      shot.progress=shot.travel_end*step/12.0;shot._process(0)
      assert(shot.global_position.distance_to(shot.point_at(shot.progress))<.0001)
      assert(shot.body.global_basis.get_scale().is_equal_approx(Vector3.ONE*scale_value),"Repeated aiming retains the chosen scale beneath a transformed parent")
      if entry[0] in ["bow","lance"]:
       var tip=shot.body.get_node("Tip")
       assert(tip.to_global(Vector3(0,0,tip.mesh.get_aabb().position.z)).distance_to(shot.point_at(shot.progress))<.0001)
      elif step>0:assert(shot.wake.visible and shot.wake.mesh.get_surface_count()==1 and shot.spell==entry[1])
      samples+=1
     shot.queue_free();await process_frame
 host.queue_free();await process_frame
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-map-projectiles-%d.json"%Time.get_ticks_usec();viewport.add_child(app);await process_frame
 app.preferences.values.combat="map";app.preferences.values.auto_end=false
 var index=0
 for sample in [["sera","longbow"],["oren","javelin"],["bram","javelin"],["tarin","ember"],["tarin","gale"],["tarin","thunder"]]:
  viewport.size=[Vector2i(1024,640),Vector2i(1280,720),Vector2i(1440,900)][index%3];index+=1
  var setup=Encounters.start_recruit(app.game,sample[0],"",309,sample[1]);assert(not setup.is_empty())
  app.make_map();app.show_battle();await process_frame;await process_frame
  var actor=app.game.units.filter(func(u):return u.id==setup.actor)[0];var victim=app.game.units.filter(func(u):return u.id==setup.target)[0]
  app.selected=actor;app.click_tile(app.game.pos(victim));assert(app.target==victim)
  var expected=Rules.new();assert(expected.restore_save(app.game.save_data("battle"))=="battle")
  var expected_events=expected.combat(expected.units.filter(func(u):return u.id==actor.id)[0],expected.units.filter(func(u):return u.id==victim.id)[0]);assert(not expected_events.is_empty())
  target_id=victim.id;initial_health=app.unit_nodes[target_id].hp_ratio;flights.clear();impacts.clear();var before=observed
  app.pieces.child_entered_tree.connect(watch);app.player_attack();assert(app.busy)
  var deadline=Time.get_ticks_msec()+12000
  while app.busy and Time.get_ticks_msec()<deadline:
   await process_frame
   var card=app.ui.get_node_or_null("CasualtyCard")
   if card!=null:card.dismissed=true
   if is_instance_valid(app.reward_panel):app.reward_panel.request_continue()
  assert(not app.busy and observed>before and flights.all(func(ref):return ref.get_ref()==null))
  assert(impacts.size()==expected_events.filter(func(event):return event.hit).size() and impacts.all(func(ref):return ref.get_ref()==null),"Only landed attacks emit an accent, and every contact releases before map control returns")
  assert(canonical(app.game.save_data("battle"))==canonical(expected.save_data("battle")),"The visual flight adds no damage, XP, support or random rolls")
  app.pieces.child_entered_tree.disconnect(watch)
 await Shutdown.dispose(app);viewport.queue_free();await process_frame
 print("PASS: %d scaled/full-size flight samples across five projectiles, four directions and hits/misses; six actual three-size ranged map attacks, body alignment, pre-contact health, committed state/RNG and cleanup"%samples)
 quit()
