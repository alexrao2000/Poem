extends RefCounted
# Diagonal hoof pairs alternate stance and swing. The support hoof travels back
# through local space at the body's forward rate, with opposite front/hind bends.

const FootPath=preload("res://scripts/infantry_stride.gd")
const LENGTH=1.8
const UPPER=.41
const LOWER=.45
const REACH=.84
const LIFT=.18
const PAIRS=[0,1,1,0]

static func phase_for(clock: float,index: int) -> float:
 return FootPath.phase_for(clock,PAIRS[index])

static func solve(clock: float) -> Dictionary:
 var support=FootPath.foot(FootPath.phase_for(clock,0),LENGTH*.25,LIFT)
 if FootPath.phase_for(clock,0)>.5:support=FootPath.foot(FootPath.phase_for(clock,1),LENGTH*.25,LIFT)
 var height=sqrt(REACH*REACH-support.x*support.x);var result={}
 for index in range(4):
  var target=FootPath.foot(phase_for(clock,index),LENGTH*.25,LIFT)
  var down=height-target.y;var distance=clampf(Vector2(target.x,down).length(),absf(UPPER-LOWER)+.00001,UPPER+LOWER-.00001)
  var bend=1.0 if index%2==0 else -1.0
  var upper=atan2(-target.x,down)+bend*acos(clampf((UPPER*UPPER+distance*distance-LOWER*LOWER)/(2*UPPER*distance),-1,1))
  var knee=-bend*acos(clampf((distance*distance-UPPER*UPPER-LOWER*LOWER)/(2*UPPER*LOWER),-1,1))
  result["HorseLeg"+str(index)]=Vector3(upper,0,0)
  result["HorseKnee"+str(index)]=Vector3(knee,0,0)
 return result
