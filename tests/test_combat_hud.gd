extends SceneTree
const HUD=preload("res://scripts/combat_hud.gd")
const Rules=preload("res://scripts/rules.gd")
const Portraits=preload("res://scripts/portraits.gd")

func _initialize():call_deferred("run")

func run():
 verify_segments()
 var game=Rules.new();game.new_campaign();var portraits=Portraits.new()
 var host=Control.new();root.add_child(host)
 var regions=[]
 for job in Portraits.ENEMY_CLASSES:
  var face=portraits.get_unit_portrait({"id":"lyra","team":"enemy","job":job})
  assert(face!=null and face!=portraits.get_portrait("lyra"),"Enemy class identity takes precedence over a coincidentally matching recruit ID")
  assert(face==portraits.get_unit_portrait({"id":"another_enemy","team":"enemy","job":job}),"Class portraits share cached texture regions")
  assert(face.region not in regions and Rect2(Vector2.ZERO,face.atlas.get_size()).encloses(face.region),"Eight distinct enemy portrait regions stay inside the atlas")
  regions.append(face.region)
 assert(portraits.get_unit_portrait({"id":"unknown","team":"enemy","job":"Unknown"})==null,"Unknown classes retain the existing fallback")
 var foe={"id":"foe","name":"Imperial gate captain","team":"enemy","job":"Knight","max_hp":999,"weapon":"lance"}
 for viewport_size in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=viewport_size
  for recruit in game.roster:
   var unit=recruit.duplicate(true);unit.team="player"
   var advantage=1 if unit.weapon=="axe" else -1 if unit.weapon=="sword" else 0
   var hud=HUD.new();hud.configure(host,[
    {"unit":unit,"hp":unit.hp,"portrait":portraits.get_portrait(unit.id),"class_name":game.class_name_for(unit),"weapon":game.item_for(unit).name,"triangle":advantage},
    {"unit":foe,"hp":999,"portrait":portraits.get_unit_portrait(foe),"class_name":"Armored commander","weapon":"Rider-stop pike","triangle":-advantage}])
   await process_frame;await process_frame
   var left=hud.records[unit.id].plate;var right=hud.records.foe.plate
   assert(hud.records.foe.portrait.flip_h and not hud.records[unit.id].portrait.flip_h,"Enemy portrait faces inward toward its opponent")
   assert(left.get_rect().end.x<right.position.x,"Nameplates leave the arena center clear")
   for id in hud.records:
    var r=hud.records[id];var bounds=r.plate.get_rect()
    assert(r.icon.texture!=null,"Every weapon family has a readable icon")
    assert(bounds.position.x>=0 and bounds.end.x<=host.size.x and bounds.end.y<=host.size.y,"Nameplates fit desktop viewport")
    for child in r.plate.get_children():
     assert(child.position.x>=0 and child.position.y>=0 and child.get_rect().end.x<=r.plate.size.x+.1 and child.get_rect().end.y<=r.plate.size.y,"Portrait, labels and health fit nameplate")
    assert(r.weapon.get_rect().end.x<=r.hp.position.x,"Weapon and health text do not overlap")
    var expected=advantage if id==unit.id else -advantage
    assert(r.matchup.advantage==expected and r.matchup.visible==(expected!=0),"Both sides retain their directional weapon matchup, with neutral pairings hidden")
    if r.matchup.visible:
     assert(r.matchup.get_rect().position.x>=r.icon.get_rect().end.x and r.matchup.get_rect().end.x<=r.weapon.position.x,"Matchup arrow has its own space between icon and weapon name")
    var font=r.hp.get_theme_font("font");var font_size=r.hp.get_theme_font_size("font_size")
    assert(font.get_string_size(r.hp.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=r.hp.size.x,"Full health numbers fit at the save cap")
   hud.mark_actor("foe");assert(hud.records.foe.plate.active and not hud.records[unit.id].plate.active)
   hud.queue_free();await process_frame
 var hero=game.roster[0].duplicate(true);hero.team="player"
 var reversed=HUD.new();reversed.configure(host,[{"unit":foe,"hp":999,"portrait":portraits.get_unit_portrait(foe),"class_name":"Knight","weapon":"Steel spear"},{"unit":hero,"hp":hero.hp,"portrait":portraits.get_portrait(hero.id),"class_name":"Vanguard","weapon":"Iron sword"}])
 assert(not reversed.records.foe.portrait.flip_h and reversed.records[hero.id].portrait.flip_h,"Enemy-initiated combat still turns both portraits inward")
 var original=[reversed.records.foe.plate.position,reversed.records[hero.id].plate.position]
 var entrance=reversed.reveal();entrance.pause()
 assert(reversed.records.foe.plate.position==original[0]-Vector2(36,0) and reversed.records[hero.id].plate.position==original[1]+Vector2(36,0),"Opposing plates enter from their own outer edges")
 assert(reversed.records.foe.plate.modulate.a==0 and reversed.records[hero.id].plate.modulate.a==0,"Entrance begins transparent")
 entrance.custom_step(.06)
 var partial=reversed.entrance
 assert(partial>0 and partial<1 and reversed.records.foe.plate.position.x>original[0].x-36,"Entrance moves continuously into its settled layout")
 reversed.set_health(hero.id,hero.hp-3,true);host.size=Vector2(1024,640);await process_frame;reversed.arrange()
 assert(reversed.entrance==partial and reversed.records[hero.id].meter.value==hero.hp-3,"Resize and health updates do not restart or overwrite presentation state")
 for id in reversed.records:assert(is_equal_approx(reversed.records[id].plate.modulate.a,partial))
 entrance.custom_step(.2)
 assert(reversed.entrance==1 and reversed.records.foe.plate.modulate.a==1,"Entrance completes before the existing pre-combat pause ends")
 for id in reversed.records:
  var plate=reversed.records[id].plate
  assert(plate.position.x>=0 and plate.get_rect().end.x<=host.size.x,"Settled plates fit after an in-flight resize")
 entrance=reversed.reveal();entrance.custom_step(.04)
 var exit_motion=reversed.dismiss(.02);await exit_motion.finished
 assert(reversed.entrance==0 and not entrance.is_valid(),"Dismissal cancels an interrupted entrance")
 await create_timer(.2).timeout
 assert(reversed.entrance==0,"A cancelled entrance cannot bring departing nameplates back")

 reversed.queue_free();await process_frame
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
 print("PASS: 24 combat portraits at three desktop sizes, text bounds, per-point/grouped pip geometry, exact partial fill, active side, mirrored entrance/dismissal, in-flight resize, damage trails and interrupted HP animation")
 quit()

func verify_segments():
 var meter=HUD.HealthMeter.new();root.add_child(meter)
 for width in [90,160,261,392]:
  meter.size=Vector2(width,12)
  for maximum in [1,2,23,40,60,99,481,999]:
   meter.maximum=maximum
   for fraction in [0.0,.17,.5,1.0]:
    meter.value=maximum*fraction;meter.trailing=minf(maximum,meter.value+5)
    var parts=meter.segments();var health=0.0;var ghost=0.0;var previous=0.0;var right=0.0
    assert(parts.size()<=maxi(1,floori((width-2)/4)),"Large HP totals keep a bounded number of readable segments")
    if maximum<=floori((width-2)/4):assert(parts.size()==maximum,"Normal health totals show one pip per HP")
    for part in parts:
     assert(part.start==previous and part.end>part.start,"Segment ranges cover HP contiguously without skipped points")
     assert(part.rect.position.x>=right and part.rect.end.x<=width-1+.001 and part.rect.size.x>0,"Actual pip geometry stays separated inside the meter")
     assert(part.rect.position.y==2 and part.rect.end.y==10,"Beveled pips retain the existing health meter height")
     health+=part.fill*(part.end-part.start);ghost+=part.ghost*(part.end-part.start)
     previous=part.end;right=part.rect.end.x
    assert(previous==maximum and absf(health-meter.value)<.001 and absf(ghost-meter.trailing)<.001,"Pip fill and delayed damage carry the exact animated HP, including partial final groups")
 meter.queue_free()
