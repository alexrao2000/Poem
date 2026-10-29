extends SceneTree
const HUD=preload("res://scripts/combat_hud.gd")
const Rules=preload("res://scripts/rules.gd")
const Portraits=preload("res://scripts/portraits.gd")

func _initialize():call_deferred("run")

func run():
 var game=Rules.new();game.new_campaign();var portraits=Portraits.new()
 var host=Control.new();root.add_child(host)
 var foe={"id":"foe","name":"Imperial gate captain","team":"enemy","max_hp":999,"weapon":"lance"}
 for viewport_size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=viewport_size
  for recruit in game.roster:
   var unit=recruit.duplicate(true);unit.team="player"
   var hud=HUD.new();hud.configure(host,[
    {"unit":unit,"hp":unit.hp,"portrait":portraits.get_portrait(unit.id),"class_name":game.class_name_for(unit),"weapon":game.item_for(unit).name},
    {"unit":foe,"hp":999,"portrait":null,"class_name":"Armored commander","weapon":"Rider-stop pike"}])
   await process_frame;await process_frame
   var left=hud.records[unit.id].plate;var right=hud.records.foe.plate
   assert(left.get_rect().end.x<right.position.x,"Nameplates leave the arena center clear")
   for id in hud.records:
    var r=hud.records[id];var bounds=r.plate.get_rect()
    assert(r.icon.texture!=null,"Every weapon family has a readable icon")
    assert(bounds.position.x>=0 and bounds.end.x<=host.size.x and bounds.end.y<=host.size.y,"Nameplates fit desktop viewport")
    for child in r.plate.get_children():
     assert(child.position.x>=0 and child.position.y>=0 and child.get_rect().end.x<=r.plate.size.x+.1 and child.get_rect().end.y<=r.plate.size.y,"Portrait, labels and health fit nameplate")
    assert(r.weapon.get_rect().end.x<=r.hp.position.x,"Weapon and health text do not overlap")
    var font=r.hp.get_theme_font("font");var font_size=r.hp.get_theme_font_size("font_size")
    assert(font.get_string_size(r.hp.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=r.hp.size.x,"Full health numbers fit at the save cap")
   hud.mark_actor("foe");assert(hud.records.foe.plate.active and not hud.records[unit.id].plate.active)
   hud.queue_free();await process_frame
 var hud=HUD.new();hud.configure(host,[{"unit":foe,"hp":999,"portrait":null,"class_name":"Knight","weapon":"Steel spear"}])
 var meter=hud.records.foe.meter
 hud.set_health("foe",800);await create_timer(.07).timeout
 assert(meter.value<999 and meter.value>800 and meter.trailing>meter.value,"Damage drains HP before delayed loss trail")
 hud.set_health("foe",300);await create_timer(.55).timeout
 assert(is_equal_approx(meter.value,300) and is_equal_approx(meter.trailing,300),"Follow-up damage cancels previous interpolation")
 assert(hud.records.foe.hp.text=="300 / 999","Readout follows the animated meter")
 hud.set_health("foe",0,true);assert(meter.value==0 and meter.trailing==0,"Instant skip state stays consistent")
 hud.set_health("foe",2000,true);assert(meter.value==999,"Presentation caps HP to maximum")
 hud.queue_free();host.queue_free();await process_frame
 print("PASS: 24 combat portraits at three desktop sizes, text bounds, active side, damage trails and interrupted HP animation")
 quit()
