extends RefCounted
## A critically damped, bounded rotation settles loose lengths at a fixed root.
## No physics/RNG: actor processing owns the clock, visibility and hit-stop.
var root: Node3D
var angle=Vector2.ZERO
var velocity=Vector2.ZERO
var phase=0.0
var strength=.1

func bind(actor: Node3D,identity: String):
 root=actor.bone("HairFall")
 if root==null:return
 strength=root.get_meta("sway_strength",.1)
 phase=float(absi(identity.hash())%1000)/100.0

func update(clock: float,pose: String,delta: float):
 if root==null or not is_instance_valid(root):return
 var drive=.95 if pose=="critical_hit" else .85 if pose=="advance" else -.45 if pose in ["windup","critical_windup","throw_windup","critical_throw_windup"] else .65 if pose in ["strike","throw","hit","evade"] else 0.0
 var t=clock+phase
 var goal=Vector2(sin(t*1.8)*.18+drive,sin(t*2.3)*.30)*strength
 if pose=="down":goal=Vector2.ZERO
 # Exact critically damped step for a held target, stable even on long frames.
 var dt=maxf(0,delta);var omega=11.0;var decay=exp(-omega*dt)
 var error=angle-goal;var impulse=velocity+omega*error
 angle=goal+(error+impulse*dt)*decay
 velocity=(velocity-omega*impulse*dt)*decay
 angle=angle.clamp(Vector2.ONE*-strength,Vector2.ONE*strength)
 root.rotation=Vector3(angle.x,0,angle.y)
