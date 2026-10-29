extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Tactics=preload("res://scripts/tactics.gd")
func _initialize():
 var g=Rules.new();var ai=Tactics.new();g.start_battle()
 var enemy=g.living("enemy")[1];var ally=g.units[0]
 g.units=[enemy,ally];enemy.x=4;enemy.y=3;ally.x=6;ally.y=3;enemy.ai="pursue"
 var rows=[]
 for y in range(10):rows.append(".....#........" if y<8 else "..............")
 g.content.chapters[0].map=rows;g.begin_enemy_phase()
 var state=g.rng.state;var plan=ai.plan(g,enemy)
 assert(plan.position.y>=6,"Pursuit moves away from the target to go around the wall")
 assert(g.rng.state==state,"Planning does not consume random rolls")
 assert(g.pos(enemy)==Vector2i(4,3),"Planning does not mutate the unit")
 for i in range(5):
  ai.apply_plan(g,enemy,ai.plan(g,enemy));g.begin_enemy_phase()
 assert(g.distance(enemy,ally)<=1,"Pursuit completes the detour")
 g=Rules.new();g.start_battle();enemy=g.living("enemy")[2];ally=g.units[0];g.units=[enemy,ally]
 g.content.chapters[0].map=[]
 for y in range(10):g.content.chapters[0].map.append("..............")
 enemy.x=4;enemy.y=3;ally.x=5;ally.y=3;enemy.ai="pursue";g.begin_enemy_phase()
 plan=ai.plan(g,enemy)
 assert(plan.action=="attack","Archer can reposition to attack adjacent target")
 ai.apply_plan(g,enemy,plan);assert(g.distance(enemy,ally)==2,"Archer respects minimum range")
 g=Rules.new();g.start_battle();ally=g.units[0];enemy=g.living("enemy")[0]
 ally.x=4;ally.y=4;enemy.x=5;enemy.y=4
 g.phase="enemy";assert(g.combat(ally,enemy).is_empty(),"Cannot initiate during opposing phase")
 g.phase="player";assert(g.move_unit(ally,Vector2i(4,5)),"Legal move")
 assert(not g.move_unit(ally,Vector2i(4,6)),"No second move")
 assert(g.undo_move(ally) and g.pos(ally)==Vector2i(4,4),"Undo restores origin and movement")
 assert(not g.move_unit(ally,Vector2i(5,4)),"Cannot occupy enemy square")
 var healer=g.units[3];healer.x=3;healer.y=4;ally.hp-=10
 assert(g.heal(healer,ally) and ally.hp==ally.max_hp,"Staff heals adjacent ally")
 assert(not g.heal(healer,ally),"One healing action")
 assert(not g.use_tonic(ally),"Cannot waste tonic at full HP")
 ally.hp-=10;assert(g.use_tonic(ally) and ally.potions==1,"Tonic consumes one use and one action")
 enemy.ai="guard";enemy.x=12;enemy.y=4;g.begin_enemy_phase()
 assert(ai.plan(g,enemy).position==g.pos(enemy),"Guard holds objective")
 print("PASS: obstacle detours, archer spacing, pure planning, phase/action legality and healing")
 quit()
