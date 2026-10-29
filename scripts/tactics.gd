extends RefCounted
# Deterministic tactical planning. No presentation, random rolls or state mutation.
const DIRECTIONS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]

func step_cost(game,p: Vector2i) -> int:
 return 2 if game.terrain(p) in ["f","h"] else 1

func distance_field(game,unit: Dictionary,goals: Array) -> Dictionary:
 # Reverse weighted flood: cost at q is the cost of moving from q to a goal.
 var costs={};var queue=[]
 for p in goals:
  if game.terrain(p) not in ["#","~"]:
   costs[p]=0;queue.append(p)
 while not queue.is_empty():
  var p=queue.pop_front()
  for direction in DIRECTIONS:
   var q=p+direction
   if game.terrain(q) in ["#","~"]:continue
   var occupant=game.at(q)
   if occupant!=null and occupant.team!=unit.team:continue
   var value=costs[p]+step_cost(game,p)
   if not costs.has(q) or value<costs[q]:costs[q]=value;queue.append(q)
 return costs

func attack_positions(game,unit: Dictionary,target: Dictionary) -> Array:
 var result=[];var center=game.pos(target)
 for y in range(-int(unit.reach),int(unit.reach)+1):
  for x in range(-int(unit.reach),int(unit.reach)+1):
   var distance=absi(x)+absi(y)
   if distance==0 or distance>unit.reach or (unit.weapon=="bow" and distance!=2):continue
   var p=center+Vector2i(x,y)
   var other=game.at(p)
   if game.terrain(p) not in ["#","~"] and (other==null or other.id==unit.id):result.append(p)
 return result

func plan(game,unit: Dictionary) -> Dictionary:
 var here=game.pos(unit)
 var idle={"position":here,"action":"wait","target":"","alert":false}
 if not game.can_act(unit):return idle
 var options=game.reachable(unit) if not unit.get("moved",false) else {here:0}
 if unit.get("ai","")=="guard":options={here:0}
 var free=[]
 for p in options:
  if p==here or game.at(p)==null:free.append(p)
 var foes=game.living("enemy" if unit.team=="player" else "player")
 if unit.team=="player":
  if game.info().objective=="seize" and game.objective_position() in free:
   return {"position":game.objective_position(),"action":"wait","target":"","alert":true}
  if game.info().objective=="seize" and foes.is_empty():
   var field=distance_field(game,unit,[game.objective_position()])
   var best=game.pos(unit);var remaining=field.get(best,INF)
   for p in free:
    if field.get(p,INF)<remaining:best=p;remaining=field[p]
   return {"position":best,"action":"wait","target":"","alert":true}
  if foes.is_empty():return idle
  if unit.weapon=="staff":return plan_healer(game,unit,free,foes)
  if unit.hp<unit.max_hp*.40 and unit.get("potions",0)>0:
   return {"position":here,"action":"tonic","target":"","alert":true}
 if foes.is_empty():return idle
 var best=idle;var best_score=-INF
 var probe=unit.duplicate(true)
 for p in free:
  probe.x=p.x;probe.y=p.y
  for foe in foes:
   if not game.can_attack(probe,foe):continue
   var forecast=game.forecast(probe,foe)
   var expected=forecast.damage*forecast.hit*.01*(2 if forecast.double else 1)
   var risk=0.0
   if forecast.counter:
    var counter=game.forecast(foe,probe)
    risk=counter.damage*counter.hit*.01*(2 if counter.double else 1)
   var cover=2 if game.terrain(p) in ["f","h","o"] else 0
   var value=expected*3-risk*.8+cover-float(options[p])*.05
   if expected>=foe.hp:value+=30
   if risk>=unit.hp:value-=50
   if value>best_score:
    best_score=value;best={"position":p,"action":"attack","target":foe.id,"alert":true}
 if best.action=="attack":return best
 if unit.get("ai","")=="guard":return idle
 var nearest=INF;var destination=here
 for foe in foes:
  var field=distance_field(game,unit,attack_positions(game,unit,foe))
  for p in free:
   var remaining=field.get(p,INF)
   var value=remaining+float(options[p])*.03
   if value<nearest:nearest=value;destination=p
 if unit.get("ai","")=="sentry" and not unit.get("alerted",false) and nearest>3:return idle
 if nearest==INF:return idle
 return {"position":destination,"action":"wait","target":"","alert":true}

func plan_healer(game,unit: Dictionary,free: Array,foes: Array) -> Dictionary:
 var best={"position":game.pos(unit),"action":"wait","target":"","alert":true}
 var best_score=-INF
 var injured=game.living(unit.team).filter(func(ally):return ally.id!=unit.id and ally.hp<ally.max_hp)
 for ally in injured:
  for p in free:
   if absi(p.x-int(ally.x))+absi(p.y-int(ally.y))!=1:continue
   var threat=0
   for foe in foes:
    if absi(p.x-int(foe.x))+absi(p.y-int(foe.y))<=foe.reach:threat+=10
   var value=mini(12,ally.max_hp-ally.hp)*4-threat
   if value>best_score:
    best_score=value;best={"position":p,"action":"heal","target":ally.id,"alert":true}
 if best.action=="heal":return best
 if unit.hp<unit.max_hp*.6 and unit.get("potions",0)>0:
  best.action="tonic";return best
 # Follow the company while keeping distance from enemy weapons.
 for p in free:
  var nearest_ally=999;var nearest_foe=999
  for ally in game.living(unit.team):
   if ally.id!=unit.id:nearest_ally=mini(nearest_ally,absi(p.x-int(ally.x))+absi(p.y-int(ally.y)))
  for foe in foes:nearest_foe=mini(nearest_foe,absi(p.x-int(foe.x))+absi(p.y-int(foe.y)))
  var value=-absf(nearest_ally-1)*2+minf(nearest_foe,5)-game.pos(unit).distance_to(p)*.03
  if value>best_score:best_score=value;best.position=p
 return best

func apply_plan(game,unit: Dictionary,choice: Dictionary) -> Array:
 if choice.position!=game.pos(unit) and not game.move_unit(unit,choice.position):return []
 unit.alerted=choice.get("alert",false) or unit.get("alerted",false)
 var candidates=game.units.filter(func(other):return other.id==choice.target)
 var target=candidates[0] if not candidates.is_empty() else null
 match choice.action:
  "attack":
   if target!=null:return game.combat(unit,target)
  "heal":
   if target!=null and game.heal(unit,target):return []
  "tonic":
   if game.use_tonic(unit):return []
 game.wait_unit(unit)
 return []
