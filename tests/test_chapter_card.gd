extends SceneTree
const Card=preload("res://scripts/chapter_card.gd")
const Rules=preload("res://scripts/rules.gd")
const AppScript=preload("res://scripts/main.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
func _initialize():call_deferred("run")

func run():
 var rules=Rules.new();var saved=rules.save_data("camp").duplicate(true);var rng=rules.rng.state
 var host=Control.new();root.add_child(host);var layouts=0
 var bands={}
 var minimum_contrast=INF
 for dimensions in [Vector2(720,640),Vector2(768,900),Vector2(900,640),Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  for chapter in range(12):
   var info=rules.content.chapters[chapter]
   var horizon=Color(AppScript.CHAPTER_LIGHTING[info.environment].horizon)
   var card=Card.new();card.configure(host,chapter,info.title,info.place,horizon);await process_frame
   bands[card.band_color]=true
   var bright=Color.WHITE.lerp(card.band_color,card.band_color.a).srgb_to_linear().get_luminance()
   for label in [card.heading,card.title,card.place]:
    var light=label.get_theme_color("font_color").srgb_to_linear().get_luminance()
    minimum_contrast=minf(minimum_contrast,(light+.05)/(bright+.05))
   assert(card.trim_color!=Card.TRIM and card.hint.get_theme_constant("outline_size")==3)
   assert(card.size==dimensions and card.mouse_filter==Control.MOUSE_FILTER_STOP,"Chapter card covers the viewport and intercepts tactical clicks")
   assert(card.heading.text=="CHAPTER %02d"%[chapter+1] and card.title.text==info.title and card.place.text==info.place)
   for text in [card.heading,card.title,card.place,card.hint]:
    assert(card.get_rect().encloses(text.get_rect()),"Chapter text remains inside the supported viewport")
    assert(text.get_line_count()<=text.get_visible_line_count(),"Every chapter title fits without clipping")
    assert(text.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Text cannot intercept the card's skip click")
   await card.play(func():return true)
   assert(not card.visible and not card.motion.is_running(),"Keyboard skip stops the card's animation")
   card.queue_free();await process_frame;layouts+=1
 assert(bands.size()==12 and minimum_contrast>4.8,"Every chapter has its own band and retains text contrast over a bright field")
 var card=Card.new();card.configure(host,0,"Ash on the Water","Cinderford")
 assert(card.band_color==Card.BAND and card.trim_color==Card.TRIM)
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 card.gui_input.emit(click);assert(card.skip_requested,"Pointer activation requests an isolated skip")
 await card.play(func():return false);assert(not card.visible and not card.motion.is_running())
 card.queue_free();await process_frame
 card=Card.new();card.configure(host,11,"Dawn Without Kings","The Sun Engine")
 await card.play(func():return false)
 assert(not card.visible and is_zero_approx(card.modulate.a),"Unskipped chapter card fades away automatically")
 card.queue_free();host.queue_free();await process_frame
 await verify_deployment()
 assert(rules.save_data("camp")==saved and rules.rng.state==rng,"Chapter card never owns campaign progression or random state")
 print("PASS: %d chapter headings, twelve battlefield tints, minimum contrast %.3f, viewport bounds at 720, real deployment, automatic fade and pointer/keyboard skip"%[layouts,minimum_contrast])
 quit()

func verify_deployment():
 var app=load("res://main.tscn").instantiate();app.settings_path=""
 app.save_path="/private/tmp/poem-chapter-card-%d.json"%Time.get_ticks_usec()
 root.add_child(app);await process_frame
 app.game.chapter=8;app.deploy_company()
 var card=app.ui.get_node("ChapterCard")
 var night=app.environment.sky.sky_material.sky_horizon_color
 assert(night==Color(AppScript.CHAPTER_LIGHTING.observatory.horizon) and card.title.text=="A Borrowed Sun")
 assert(card.band_color==Color(Card.BAND.lerp(night.darkened(.64),.65),Card.BAND.a))
 while app.busy:
  app.chapter_card_skip=true;app.phase_skip=true;await process_frame
 assert(app.screen=="battle" and not app.ui.has_node("ChapterCard"))
 await Shutdown.dispose(app);await process_frame
