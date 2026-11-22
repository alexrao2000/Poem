extends RefCounted
## Read-only totals for the arsenal, including growth, promotions and weight.
static func preview(game,unit: Dictionary,item: Dictionary) -> Dictionary:
 var candidate=unit.duplicate(true);candidate.item=item.id
 var staff=unit.weapon=="staff"
 var current_power=game.healing_power(unit) if staff else game.attack_power(unit)
 var power=game.healing_power(candidate) if staff else game.attack_power(candidate)
 var speed=game.attack_speed(candidate);var speed_change=speed-game.attack_speed(unit)
 var power_change=power-current_power
 return {"power":power,"power_change":power_change,"speed":speed,"speed_change":speed_change,
  "text":"With this item · %s   ·   %s"%[stat("Healing" if staff else "Attack",power,power_change),stat("Speed",speed,speed_change)]}

static func stat(title: String,value: int,change: int) -> String:
 return "%s %d%s"%[title,value," (%+d)"%change if change!=0 else ""]
