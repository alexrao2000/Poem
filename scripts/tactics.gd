extends RefCounted
# Deterministic tactical planning. No presentation, random rolls or state mutation.
const DIRECTIONS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const ActionRange=preload("res://scripts/action_range.gd")

func _attack_offsets(game,unit: Dictionary) -> Array[Vector2i]:
 var item=game.item_for(unit)
 # Existing battle saves can have reach bounds that differ from the item range.
 return ActionRange.offsets(int(item.min_range),int(item.max_range),int(unit.reach))

func threatened_tiles(game,unit: Dictionary) -> Dictionary:
 var result={}
 if unit.hp<=0 or unit.weapon=="staff":return result
 var occupants=game.occupied_tiles()
 var moves={game.pos(unit):0} if unit.get("ai","")=="guard" else game.reachable(unit,occupants)
 var steps=_attack_offsets(game,unit)
 for p in moves:
  var occupied=occupants.get(p)
  if occupied!=null and occupied.id!=unit.id:continue
  for step in steps:
   var target=p+step
   if not result.has(target) and game.terrain(target) not in ["#","~"]:result[target]=true
 return result

func step_cost(game,p: Vector2i) -> int:
 return 2 if game.terrain(p) in ["f","h"] else 1

func distance_field(game,unit: Dictionary,goals: Array) -> Dictionary:
 return _reverse_field(game,unit,goals,game.occupied_tiles())

func _reverse_field(game,unit: Dictionary,goals: Array,occupants: Dictionary,goal_costs: Dictionary={},cost_scale: int=1) -> Dictionary:
 # Reverse weighted flood: cost at q is the cost of moving from q to a goal.
 var costs={};var queue=[]
 for p in goals:
  if game.terrain(p) not in ["#","~"]:
   costs[p]=goal_costs.get(p,0);queue.append(p)
 var next=0
 while next<queue.size():
  var p=queue[next];next+=1
  var value=costs[p]+step_cost(game,p)*cost_scale
  for direction in DIRECTIONS:
   var q=p+direction
   if game.terrain(q) in ["#","~"]:continue
   var occupant=occupants.get(q)
   if occupant!=null and occupant.team!=unit.team:continue
   if not costs.has(q) or value<costs[q]:costs[q]=value;queue.append(q)
 return costs

func attack_positions(game,unit: Dictionary,target: Dictionary) -> Array:
 return _attack_positions(game,unit,game.pos(target),_attack_offsets(game,unit),game.occupied_tiles())

func _attack_positions(game,unit: Dictionary,center: Vector2i,steps: Array[Vector2i],occupants: Dictionary) -> Array:
 var result=[]
 for step in steps:
  var p=center+step
  var other=occupants.get(p)
  if game.terrain(p) not in ["#","~"] and (other==null or other.id==unit.id):result.append(p)
 return result

func _pursuit(game,unit: Dictionary,foes: Array,free: Array,options: Dictionary,occupants: Dictionary) -> Dictionary:
 var priority={}
 var steps=_attack_offsets(game,unit)
 for index in foes.size():
  for tile in _attack_positions(game,unit,game.pos(foes[index]),steps,occupants):
   if not priority.has(tile):priority[tile]=index
 # One reverse search covers all foes. Whole movement costs sort first and
 # the remainder preserves the original foe order when costs tie.
 var scale_value=foes.size()
 var field=_reverse_field(game,unit,priority.keys(),occupants,priority,scale_value)
 var nearest=INF
 var nearest_priority=scale_value
 var destination=game.pos(unit)
 for tile in free:
  if not field.has(tile):continue
  var cost=int(field[tile])
  @warning_ignore("integer_division")
  var distance=cost/scale_value
  var value=distance+float(options[tile])*.03
  var rank=cost%scale_value
  if value<nearest or (value==nearest and rank<nearest_priority):
   nearest=value;nearest_priority=rank;destination=tile
 return {"position":destination,"cost":nearest}

func plan(game,unit: Dictionary) -> Dictionary:
 var here=game.pos(unit)
 var idle={"position":here,"action":"wait","target":"","alert":false}
 if not game.can_act(unit):return idle
 var occupants=game.occupied_tiles()
 var options={here:0}
 if not unit.get("moved",false) and unit.get("ai","")!="guard":options=game.reachable(unit,occupants)
 var free=[]
 for p in options:
  if p==here or not occupants.has(p):free.append(p)
 var foes=game.living("enemy" if unit.team=="player" else "player")
 if unit.team=="player":
  var goals=game.capture_tiles()
  if here in goals:return {"position":here,"action":"wait","target":"","alert":true}
  var reachable_goal=goals.find_custom(func(point):return point in free)
  if reachable_goal>=0:return {"position":goals[reachable_goal],"action":"wait","target":"","alert":true}
  if not goals.is_empty() and foes.is_empty():
   var unoccupied=goals.filter(func(point):return not occupants.has(point))
   var field=_reverse_field(game,unit,unoccupied,occupants)
   var best=game.pos(unit);var remaining=field.get(best,INF)
   for p in free:
    if field.get(p,INF)<remaining:best=p;remaining=field[p]
   return {"position":best,"action":"wait","target":"","alert":true}
  if foes.is_empty():return idle
  if unit.weapon=="staff":return plan_healer(game,unit,free,foes)
  if unit.hp<unit.max_hp*.40 and unit.get("potions",0)>0:
   return {"position":here,"action":"tonic","target":"","alert":true}
 if unit.team=="enemy" and unit.hp<unit.max_hp*.4 and unit.get("held_tonics",0)>0:
  return {"position":here,"action":"tonic","target":"","alert":true}
 if foes.is_empty():return idle
 if unit.team=="enemy" and unit.weapon=="staff":return plan_healer(game,unit,free,foes)
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
 var pursuit=_pursuit(game,unit,foes,free,options,occupants)
 if unit.get("ai","")=="sentry" and not unit.get("alerted",false) and pursuit.cost>3:return idle
 if pursuit.cost==INF:return idle
 return {"position":pursuit.position,"action":"wait","target":"","alert":true}

func plan_healer(game,unit: Dictionary,free: Array,foes: Array) -> Dictionary:
 var best={"position":game.pos(unit),"action":"wait","target":"","alert":true}
 var best_score=-INF
 var injured=game.units.filter(func(ally):return ally.team==unit.team and ally.id!=unit.id and (ally.hp>0 or game.DeathDoor.downed(ally)) and ally.hp<ally.max_hp)
 var probe=unit.duplicate(true)
 var threat_by_tile={}
 var healing=game.healing_power(unit)
 for ally in injured:
  for p in free:
   probe.x=p.x;probe.y=p.y
   if not game.can_heal(probe,ally):continue
   var threat: int=threat_by_tile.get(p,-1)
   if threat<0:
    threat=0
    for foe in foes:
     if absi(p.x-int(foe.x))+absi(p.y-int(foe.y))<=foe.reach:threat+=10
    threat_by_tile[p]=threat
   var value=mini(healing,ally.max_hp-ally.hp)*4-threat
   if game.DeathDoor.downed(ally):
    value+=100
    if ally.get("carried_by","").is_empty():value+=(3-int(ally.bleed_turns))*30
   if value>best_score:
    best_score=value;best={"position":p,"action":"heal","target":ally.id,"alert":true}
 if best.action=="heal":return best
 if unit.hp<unit.max_hp*.6 and unit.get("potions",0)>0:
  best.action="tonic";return best
 # Reach a downed patient even if the standing company has moved away.
 var nearest=INF
 for ally in injured:
  if not game.DeathDoor.downed(ally):continue
  var field=distance_field(game,unit,attack_positions(game,unit,ally))
  for p in free:
   var remaining=field.get(p,INF)
   var value=remaining+game.pos(unit).distance_to(p)*.03
   if value<nearest:nearest=value;best.position=p
 if nearest<INF:return best
 # Follow the company while keeping distance from enemy weapons.
 var company=game.living(unit.team)
 for p in free:
  var nearest_ally=999;var nearest_foe=999
  for ally in company:
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
