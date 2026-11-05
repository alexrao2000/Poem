extends RefCounted
# Debug experiments use a separate save slot. Leaving restores the exact live
# campaign snapshot, including unsaved progress, rule toggles and RNG state.

var active=false
var checkpoint: Dictionary={}
var return_screen="title"

func begin(game,screen: String):
 if active:return
 return_screen=screen
 checkpoint=game.save_data("battle" if screen=="battle" else "camp").duplicate(true)
 active=true

func end(game) -> String:
 if not active:return return_screen
 if game.restore_save(checkpoint).is_empty():return return_screen
 game.roster=checkpoint.roster.duplicate(true);game.units=checkpoint.units.duplicate(true)
 active=false;checkpoint.clear()
 return return_screen

func load_chapter(game,index: int):
 if not active or index<0 or index>=game.content.chapters.size():return
 game.new_campaign(game.permadeath);game.chapter=index
 game.story_seen=["opening_"+str(index)]
 game.deployed=game.available().slice(0,6).map(func(unit):return unit.id)
 game.start_battle()

func heal(game):
 if not active:return
 for unit in game.living("player"):unit.hp=unit.max_hp

func revive(game):
 if not active:return
 for unit in game.roster:unit.fallen=false;unit.fallen_chapter=-1;unit.hp=unit.max_hp
 for unit in game.available():
  if game.deployed.size()<6 and unit.id not in game.deployed:game.deployed.append(unit.id)
 game.start_battle()
