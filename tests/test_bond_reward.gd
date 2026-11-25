extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Reward=preload("res://scripts/progress_reward.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
var app
func _initialize():call_deferred("run")
func canonical(data):return JSON.parse_string(JSON.stringify(data))

func run():
 app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-bond-reward-%d.json"%Time.get_ticks_usec()
 root.add_child(app);await process_frame
 app.preferences.values.auto_end=false;app.preferences.values.combat="map"
 await verify_layouts()
 for mode in ["attack","level","cap","heal","carried","counter","repeat","chapter_cap","fallen_partner"]:
  app.game.new_campaign();app.game.action_saves=true;app.game.start_battle()
  var a=app.game.units[0];var partner=app.game.units[1];var scout=app.game.units[2];var medic=app.game.units[3]
  var enemy=app.game.living("enemy")[0];var reserve=app.game.living("enemy")[1]
  a.x=8;a.y=4;partner.x=8;partner.y=5;scout.x=0;scout.y=2;medic.x=0;medic.y=3
  a.speed=50;a.pow=1;a.defense=100
  enemy.x=9;enemy.y=4;enemy.job="Vanguard";enemy.weapon="sword";enemy.item="iron_sword";enemy.defense=100;enemy.pow=1;enemy.speed=0;enemy.ai="guard"
  reserve.x=12;reserve.y=7;reserve.boss=true
  app.game.units=[a,partner,scout,medic,enemy,reserve]
  var participant=a;var bond_id="lyra_oren"
  if mode=="level":a.xp=90
  if mode=="cap":a.level=99;a.xp=0
  if mode=="repeat":app.game.supports.earn(app.game,a)
  if mode=="chapter_cap":app.game.supports.state[bond_id]={"points":3,"rank":0,"chapter":0,"earned":3,"turn":-1}
  if mode=="fallen_partner":partner.hp=0
  if mode in ["heal","carried"]:
   participant=medic;bond_id="sera_ivo";scout.hp=1
   if mode=="carried":
    app.game.death_door=true;scout.hp=0;app.game.DeathDoor.fall(app.game,scout)
    assert(app.game.DeathDoor.rescue(app.game,medic,scout));medic.acted=false
  if mode=="counter":app.game.begin_enemy_phase();reserve.acted=true
  app.make_map();app.show_battle();app.selected=participant
  var expect_bond=mode not in ["repeat","chapter_cap","fallen_partner"]
  if mode=="counter":app.end_turn(true)
  elif mode=="heal":app.click_tile(app.game.pos(scout))
  elif mode=="carried":app.heal_carried_ally(scout)
  else:app.target=enemy;app.player_attack()
  var saw=false;var growth={};var rng=0
  while app.busy:
   await process_frame
   if not is_instance_valid(app.reward_panel) or saw:continue
   await process_frame
   var panel=app.reward_panel;saw=true
   assert(panel.record.has("bond")==expect_bond,"Only newly earned cooperation appears: "+mode)
   assert(panel.record.unit.id==participant.id,"The actual acting ally owns the bond reward")
   if expect_bond:
    assert(panel.record.bond.id==bond_id and panel.record.bond.gained==1 and panel.record.bond.points==1)
    assert(panel.content.get_node("BondReadiness").text=="Conversation ready at camp","First point announces the available conversation without granting its rank")
    assert(app.game.supports.progress(bond_id).rank==0)
   if mode=="cap":assert(panel.record.xp_gain==0 and participant.level==99 and participant.xp==0,"Level cap still gives cooperation feedback without invented experience")
   if mode=="level":assert(panel.leveled,"Bond progress accompanies the real level-up")
   var saved=Rules.new();assert(saved.load_game(app.save_path)=="battle")
   assert(canonical(saved.save_data("battle"))==canonical(app.game.save_data("battle")),"The displayed growth and bond were committed before animation")
   growth=participant.duplicate(true);rng=app.game.rng.state
   panel.request_continue();panel.request_continue()
  assert(saw and app.game.rng.state==rng,"Actual action displayed a reward without rerolling")
  for stat in ["level","xp","max_hp","pow","defense","speed"]:assert(participant[stat]==growth[stat],"Reward cannot reapply growth")
  assert(app.game.supports.progress(bond_id).points==(1 if expect_bond or mode=="repeat" else 3 if mode=="chapter_cap" else 0),"Duplicate/capped/fallen feedback cannot earn extra bonds")
  assert(not is_instance_valid(app.reward_panel))
 await Shutdown.dispose(app)
 print("PASS: 78 partner/XP/level layouts at three sizes; nine actual attack/heal/carried/counter/cap/repeat/casualty flows with committed read-only bond rewards and no extra rank, growth or RNG")
 quit()

func verify_layouts():
 var host=Control.new();host.theme=app.ui.theme;root.add_child(host)
 var snapshot=app.game.save_data("camp").duplicate(true)
 var preview=Rules.new();preview.new_campaign(true);preview.trials.flags.death_legacies=true;preview.start_battle()
 for unit in preview.units:
  if unit.id in ["sera","ivo"]:unit.hp=0
 preview.commit_casualties()
 assert(preview.bond_available(preview.supports.entry_for("maelin_tovin")))
 for dimensions in [Vector2(1024,640),Vector2(1280,720),Vector2(1440,900)]:
  host.size=dimensions
  for entry in preview.supports.entries:
   for leveled in [false,true]:
    var unit=preview.roster.filter(func(u):return u.id==entry.members[0])[0].duplicate(true)
    var before={"level":unit.level,"xp":0};var gains={}
    for stat in Reward.STATS:before[stat[0]]=unit[stat[0]];gains[stat[0]]=0
    if leveled:unit.level+=1
    var names=[]
    for id in entry.members:names.append(preview.roster.filter(func(u):return u.id==id)[0].name)
    var bond={"id":entry.id,"names":names,"points":3,"gained":1,"rank":1,"ready":leveled}
    var card=Reward.new();card.configure(host,{"unit":unit,"before":before,"gains":gains,"xp_gain":25,"bond":bond},app.portraits.get_portrait(unit.id),unit.job)
    await process_frame;await process_frame
    assert(Rect2(Vector2.ZERO,host.size).encloses(card.get_rect()),"Expanded reward fits the viewport")
    for child in card.content.get_children():
     assert(Rect2(Vector2.ZERO,card.content.size).encloses(child.get_rect()),"Bond footer and existing contents fit the card")
     if child is Label:assert(child.size.x>=child.get_minimum_size().x,"Every partner name and readiness line fits")
    var title=card.content.get_node("BondNames");var pips=card.content.get_node("BondProgress")
    assert(not title.get_rect().intersects(pips.get_rect()) and pips.points==3,"Names and six-point meter do not overlap")
    assert(card.content.get_node("BondReadiness").text==( "Conversation ready at camp" if leveled else "3 / 6 bond points · Rank C"))
    card.queue_free();await process_frame
 assert(app.game.save_data("camp")==snapshot,"Layout previews leave the campaign unchanged")
 host.queue_free();await process_frame
