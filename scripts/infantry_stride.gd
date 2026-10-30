extends RefCounted
# Ground-distance gait: the stance foot moves backward relative to the body
# at exactly the body's travel rate. A two-segment solve preserves limb lengths.

const LENGTH=1.6
const ROBE_LENGTH=1.2
const THIGH=.36
const SHIN=.38
const REACH=.70
const LIFT=.22

static func phase_for(clock: float,side: int) -> float:
 return fposmod(clock/TAU+.25+side*.5,1.0)

static func foot(phase: float,span=.4,lift=LIFT) -> Vector2:
 if phase<=.5:return Vector2(lerpf(-span,span,phase*2),0)
 var t=(phase-.5)*2
 var z=span*(1+2*t-12*t*t+8*t*t*t)
 return Vector2(z,lift*sin(PI*t))

static func solve(clock: float,robed=false) -> Dictionary:
 var left_phase=phase_for(clock,0);var right_phase=phase_for(clock,1)
 var span=ROBE_LENGTH*.25 if robed else LENGTH*.25;var lift=.16 if robed else LIFT
 var left=foot(left_phase,span,lift);var right=foot(right_phase,span,lift)
 var planted=left if left_phase<=.5 else right
 var reach=.72 if robed else REACH
 var height=sqrt(reach*reach-planted.x*planted.x)
 var a=angles(left,height);var b=angles(right,height)
 return {"LeftLeg":Vector3(a.x,0,0),"LeftKnee":Vector3(a.y,0,0),"RightLeg":Vector3(b.x,0,0),"RightKnee":Vector3(b.y,0,0)}

static func angles(target: Vector2,height: float) -> Vector2:
 var down=height-target.y;var length=Vector2(target.x,down).length()
 var distance=clampf(length,absf(THIGH-SHIN)+.00001,THIGH+SHIN-.00001)
 var upper=atan2(-target.x,down)+acos(clampf((THIGH*THIGH+distance*distance-SHIN*SHIN)/(2*THIGH*distance),-1,1))
 var knee=-acos(clampf((distance*distance-THIGH*THIGH-SHIN*SHIN)/(2*THIGH*SHIN),-1,1))
 return Vector2(upper,knee)
