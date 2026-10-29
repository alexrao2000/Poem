extends SceneTree
# Check real forecast values, paired card bounds, and lifecycle through keyboard
# retargeting, cinematic concealment and screen replacement.
const Forecast=preload("res://scripts/battle_forecast.gd")
const Rules=preload("res://scripts/rules.gd")
const Portraits=preload("res://scripts/portraits.gd")
var concealed=false
func watch_cinematic(app):
 while app.world.visible:await process_frame
 concealed=is_instance_valid(app.forecast_panel) and not app.forecast_panel.visible

func _initialize():call_deferred("run")
func run():
 var game=Rules.new();game.chapter=5;game.start_battle();var portraits=Portraits.new()
 var host=Control.new();root.add_child(host)
 var foe=game.living("enemy")[0]
 for size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=size
  for source in game.roster:
   var unit=source.duplicate(true);unit.team="player";unit.x=4;unit.y=4;unit.hp=999;unit.max_hp=999;foe.x=5;foe.y=4
   var before=game.rng.state;var forecast=Forecast.new();forecast.configure(host,game,unit,foe,[portraits.get_portrait(unit.id),portraits.get_unit_portrait(foe)])
   await process_frame
   var expected=game.forecast(unit,foe);var reverse=game.forecast(foe,unit)
   assert(forecast.records[0].portrait.texture!=null,"Named recruit portrait appears in the comparison")
   assert(forecast.records[1].portrait.texture!=null and forecast.records[1].portrait.flip_h,"Enemy class portrait faces the recruit")
   assert(forecast.records[0].stats[0].value.text==str(expected.damage)+(" ×2" if expected.double else ""))
   assert(forecast.records[0].stats[1].value.text==str(expected.hit)+"%")
   assert(forecast.records[1].stats[0].value.text==(str(reverse.damage)+(" ×2" if reverse.double else "") if expected.counter else "—"))
   for record in forecast.records:
    var bounds=record.card.get_rect()
    assert(bounds.position.x>=0 and bounds.position.y>=0 and bounds.end.x<size.x-325 and bounds.end.y<=size.y-110,"Forecast leaves the command sidebar and help strip clear")
    for node in record.card.get_children():
     assert(node.position.x>=0 and node.position.y>=0 and node.get_rect().end.x<=record.card.size.x+.01 and node.get_rect().end.y<=record.card.size.y+.01,"All comparison content fits its card")
    var hp=record.hp
    assert(hp.get_theme_font("font").get_string_size(hp.text,HORIZONTAL_ALIGNMENT_LEFT,-1,hp.get_theme_font_size("font_size")).x<=hp.size.x,"Maximum health values fit without truncation")
   assert(forecast.records[0].card.get_rect().end.x<forecast.records[1].card.position.x)
   assert(game.rng.state==before,"Forecast display never consumes RNG")
   forecast.queue_free();await process_frame
 host.queue_free();await process_frame
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-forecast-ui.json";root.add_child(app);await process_frame
 app.game.start_battle();app.make_map();app.show_battle();app.selected=app.game.units[0];app.target=app.game.living("enemy")[0]
 app.update_side();await process_frame
 assert(is_instance_valid(app.forecast_panel) and app.forecast_panel.visible)
 var attacker=app.selected;var defender=app.target;attacker.x=8;attacker.y=4;defender.x=9;defender.y=4
 watch_cinematic(app)
 await app.cinematic(attacker,defender,[{"actor":attacker.id,"target":defender.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{attacker.id:20,defender.id:20})
 assert(concealed and app.forecast_panel.visible,"Forecast is concealed during combat and restored with the tactical controls")
 app.move_map_cursor(Vector2i.RIGHT);await process_frame
 assert(app.target==null and app.forecast_panel==null,"Keyboard retargeting dismisses the comparison without canceling the selected ally")
 app.target=app.game.living("enemy")[0];app.update_side();await process_frame
 var first=weakref(app.forecast_panel);app.update_side();await process_frame
 assert(first.get_ref()==null and is_instance_valid(app.forecast_panel),"Updating stats replaces the old comparison cleanly")
 app.show_camp();await process_frame
 assert(app.forecast_panel==null,"Changing screens clears the forecast reference")
 app.game.start_battle();app.make_map();app.show_battle();await process_frame
 for player in app.sfx_players:player.stop()
 app.music.stop();await create_timer(.15).timeout
 app.queue_free();await process_frame
 print("PASS: 24 paired forecasts at three viewport sizes, real damage/hit/counter values, health bounds, retargeting and screen cleanup")
 quit()
