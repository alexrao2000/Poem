extends SceneTree
const Models=preload("res://scripts/debug_source_models.gd")
const Fighters=preload("res://scripts/fighters.gd")
const Blink=preload("res://scripts/face_blink.gd")
const Cutin=preload("res://scripts/critical_cutin.gd")
const Finish=preload("res://scripts/combat_finish.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("res://tests/helpers/game_shutdown.gd")
var app
var expected_id=""
var expected_color=Color.WHITE
var cutins=0
var finishes=0
func observe(node):
 if not node is Cutin and not node is Finish:return
 await process_frame
 var actor=app.stage.get_children().filter(func(value):return value is Imported and value.model.get_meta("character_identity","")==expected_id)[0]
 var blink=actor.model.get_node("Identity").blink
 assert(blink.surface.get_shader_parameter("personal_iris") and blink.surface.get_shader_parameter("iris_tint").is_equal_approx(expected_color),"Actual critical and finishing scenes retain the recruit's private palette")
 if node is Cutin:assert(blink.focused);cutins+=1
 else:assert(not blink.focused and not blink.serious);finishes+=1
func _initialize():call_deferred("run")
func run():
 var world=Node3D.new();root.add_child(world);var painter=Fighters.new();var rules=load("res://scripts/rules.gd").new()
 var before=rules.save_data("camp").duplicate(true);var rng=rules.rng.state;var profiles=painter.profiles.duplicate(true)
 var models=Models.new(["vanguard","vanguard_male","caster","caster_female","ranger_female","ranger_male","female","male"]);var materials=[];var count=0
 for id in ["lyra","rhea","cassian","tarin","vela","noor","sera","ari","faye","yuna"]:
  var source=rules.roster.filter(func(unit):return unit.id==id)[0]
  var promotions=[""];promotions.append_array(rules.promotions.filter(func(value):return value.base==source.job).map(func(value):return value.id))
  for promotion in promotions:
   var unit=source.duplicate(true);unit.team="player";unit.promotion=promotion
   var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.models.issues.is_empty());await process_frame
   var face=actor.model.get_node("Identity").blink.surface;var expected=id in ["lyra","tarin","sera"]
   assert(face!=null and not face in materials,"Every revised actor owns its face palette independently");materials.append(face)
   assert(face.get_shader_parameter("personal_iris")==expected,"Only the three authored portrait corrections enable iris tinting")
   assert(face.get_shader_parameter("warm_iris")== (id=="sera"),"Only the brown source cell selects the measured lower-iris mask")
   if expected:assert(face.get_shader_parameter("iris_tint").is_equal_approx(Color(profiles[id].appearance.iris_color)))
   assert(face.get_shader_parameter("open_face")==painter.face_atlas and face.get_shader_parameter("focused_face")==Blink.FOCUSED,"Personal colors reuse the existing expression artwork")
   for pose in ["critical_windup","strike","hit","down","idle"]:
    await actor.pose(pose,.02).finished
    assert(face.get_shader_parameter("personal_iris")==expected)
    if expected:assert(face.get_shader_parameter("iris_tint").is_equal_approx(Color(profiles[id].appearance.iris_color)),"Expression changes preserve the actor's private iris palette")
   actor.queue_free();await process_frame;count+=1
 for source in rules.roster:
  var unit=source.duplicate(true);unit.team="player";var actor=painter.build(world,unit,Vector3.ZERO)
  assert(not actor.face_blink.surface.get_shader_parameter("personal_iris"),"Current default models retain their original face rendering")
  actor.queue_free();await process_frame
 var head=Node3D.new();world.add_child(head);var mesh=MeshInstance3D.new();head.add_child(mesh);var blink=Blink.new()
 for setup in [[0,""],[0,"not-a-color"],[1,"7f8d62"],[3,"795239"],[6,"6a91b2"]]:
  head.set_meta("face_variant",setup[0]);blink.bind(mesh,painter.face_atlas,"validation",setup[1])
  assert(blink.surface.get_shader_parameter("personal_iris")== (setup[0] in [1,6]),"Missing/invalid colors and unmeasured iris cells safely retain their original painting")
  assert(blink.surface.get_shader_parameter("warm_iris")== (setup[0]==1))
 assert(painter.profiles==profiles and rules.save_data("camp")==before and rules.rng.state==rng)
 world.queue_free();await process_frame
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-iris-exchanges.json";root.add_child(app);await process_frame
 app.preferences.values.character_models="revised";app.preferences.values.combat="all";app.game.start_battle();app.make_map();app.show_battle()
 app.ui.child_entered_tree.connect(observe);app.stage.child_entered_tree.connect(observe)
 var source_foe=app.game.living("enemy")[0].duplicate(true)
 for id in ["lyra","tarin","sera"]:
  expected_id=id;expected_color=Color(profiles[id].appearance.iris_color)
  var a=app.game.roster.filter(func(unit):return unit.id==id)[0].duplicate(true);a.team="player";a.acted=false;a.moved=false;a.x=8;a.y=4;a.hp=2
  var b=source_foe.duplicate(true);b.x=10 if a.weapon in ["magic","bow"] else 9;b.y=4;b.hp=0
  app.game.units=[a,b];app.refresh_pieces();app.busy=true
  var battle=app.game.save_data("battle").duplicate(true);var seed=app.game.rng.state
  await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"hit":true,"crit":true,"damage":2,"remaining":0}],{a.id:2,b.id:2})
  assert(app.game.save_data("battle")==battle and app.game.rng.state==seed and app.world.visible and not app.stage.visible)
  app.busy=false
 assert(cutins==3 and finishes==3)
 await Shutdown.dispose(app);await process_frame
 print("PASS: ",count," revised base/promoted faces, three portrait palettes through five expressions, shared-atlas neighbors unchanged, 24 current-model fallbacks, private materials, invalid/unsupported palette fallback and three actual critical-to-victory exchanges")
 quit()
