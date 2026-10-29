extends SceneTree
# The readout shares profiles with simulation. Exercise actual cover, healing,
# hover/keyboard inspection, off-board hiding and cinematic visibility restore.
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")
func run():
 var game=Rules.new();var seen={}
 for chapter in range(12):
  game.chapter=chapter;game.start_battle()
  var a=game.units[0].duplicate(true);var b=game.living("enemy")[0].duplicate(true)
  a.weapon="sword";b.weapon="sword";a.item="iron_sword";b.item="iron_sword";a.pow=20;b.defense=3;a.speed=8;b.speed=8
  game.units=[a,b]
  for y in range(game.board_size().y):
   for x in range(game.board_size().x):
    var p=Vector2i(x,y);var symbol=game.terrain(p);var profile=game.terrain_profile(p)
    seen[symbol]=true
    assert(profile.move==(0 if symbol in ["#","~"] else 2 if symbol in ["f","h"] else 1),"Terrain readout preserves movement costs")
    assert(profile.cover==(2 if symbol in ["f","h","o"] else 0) and profile.avoid==profile.cover*5,"Terrain readout preserves combat cover")
    assert(profile.heal==(6 if symbol in ["+","o"] else 0),"Terrain readout preserves recovery")
    b.x=x;b.y=y;a.x=x-1;a.y=y;b.hp=1;b.max_hp=30
    var forecast=game.forecast(a,b)
    assert(forecast.hit==85-profile.avoid,"Displayed avoidance is used by real forecasts")
    assert(forecast.damage==game.attack_power(a)-b.defense-profile.cover,"Displayed cover reduces real damage")
    game.next_player_turn();assert(b.hp==1+profile.heal,"Displayed recovery is applied at turn start")
 assert(seen.size()==9,"All authored terrain symbols checked")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/ashen-terrain-test.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();await process_frame
 app.move_map_cursor(Vector2i.RIGHT)
 assert(app.terrain_card.tile==app.cursor_tile,"Keyboard cursor updates terrain")
 for y in range(app.game.board_size().y):
  for x in range(app.game.board_size().x):
   app.preview_route(Vector2i(x,y))
   assert(app.terrain_card.heading.text==app.game.terrain_profile(Vector2i(x,y)).name.to_upper(),"Mouse route preview updates terrain even without a selection")
 app.preview_route(Vector2i(-1,-1));assert(not app.terrain_card.visible,"Off-board pointer hides stale terrain")
 var a=app.game.units[0];var b=app.game.living("enemy")[0];a.x=8;a.y=4;b.x=9;b.y=4
 await app.cinematic(a,b,[{"actor":a.id,"target":b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{a.id:20,b.id:20})
 assert(not app.terrain_card.visible,"Combat returns each tactical panel to its prior visibility")
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  app.ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);app.ui.size=dimensions
  app.terrain_card.inspect(app.game,Vector2i(0,0));await process_frame;await process_frame
  assert(app.terrain_card.get_rect().end.x<dimensions.x-325 and app.terrain_card.get_rect().end.y<dimensions.y-84,"Terrain card remains clear of command and help panels")
  for label in [app.terrain_card.heading,app.terrain_card.values,app.terrain_card.detail]:
   assert(label.get_global_rect().end.x<=app.terrain_card.get_global_rect().end.x and label.get_global_rect().end.y<=app.terrain_card.get_global_rect().end.y,"Terrain labels fit their frame")
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: nine terrain profiles across twelve maps, real movement/cover/healing values, cursor readout and visibility restoration")
 quit()
