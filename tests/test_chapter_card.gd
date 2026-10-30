extends SceneTree
const Card=preload("res://scripts/chapter_card.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():call_deferred("run")

func run():
 var rules=Rules.new();var saved=rules.save_data("camp").duplicate(true);var rng=rules.rng.state
 var host=Control.new();root.add_child(host);var layouts=0
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  for chapter in range(12):
   var info=rules.content.chapters[chapter]
   var card=Card.new();card.configure(host,chapter,info.title,info.place);await process_frame
   assert(card.size==dimensions and card.mouse_filter==Control.MOUSE_FILTER_STOP,"Chapter card covers the viewport and intercepts tactical clicks")
   assert(card.heading.text=="CHAPTER %02d"%[chapter+1] and card.title.text==info.title and card.place.text==info.place)
   for text in [card.heading,card.title,card.place,card.hint]:
    assert(card.get_rect().encloses(text.get_rect()),"Chapter text remains inside the supported viewport")
    assert(text.get_line_count()<=text.get_visible_line_count(),"Every chapter title fits without clipping")
    assert(text.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Text cannot intercept the card's skip click")
   await card.play(func():return true)
   assert(not card.visible and not card.motion.is_running(),"Keyboard skip stops the card's animation")
   card.queue_free();await process_frame;layouts+=1
 var card=Card.new();card.configure(host,0,"Ash on the Water","Cinderford")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 card.gui_input.emit(click);assert(card.skip_requested,"Pointer activation requests an isolated skip")
 await card.play(func():return false);assert(not card.visible and not card.motion.is_running())
 card.queue_free();await process_frame
 card=Card.new();card.configure(host,11,"Dawn Without Kings","The Sun Engine")
 await card.play(func():return false)
 assert(not card.visible and is_zero_approx(card.modulate.a),"Unskipped chapter card fades away automatically")
 card.queue_free();host.queue_free();await process_frame
 assert(rules.save_data("camp")==saved and rules.rng.state==rng,"Chapter card never owns campaign progression or random state")
 print("PASS: %d chapter headings, viewport/text bounds, automatic fade, pointer/keyboard skip and presentation-only state"%layouts)
 quit()
