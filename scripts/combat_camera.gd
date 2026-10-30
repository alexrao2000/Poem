extends Node
## Continuous low three-quarter shots stay on one side of the combat axis.

var camera: Camera3D
var anchor=Vector3.ZERO
var focus=Vector3.ZERO
var lens=48.0
var shake_offset=Vector2.ZERO
var movement: Tween
var impact_motion: Tween

func configure(value: Camera3D):
 camera=value;anchor=camera.position;focus=camera.position-camera.basis.z;lens=camera.fov
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.h_offset=0;camera.v_offset=0

static func frame_pair(attacker: Vector3,defender: Vector3,phase: String,_ranged: bool,mounted=false,weapon="") -> Dictionary:
 var midpoint=(attacker+defender)*.5
 var height=2.90 if mounted else 2.08
 var separation=attacker.distance_to(defender)
 var distance=maxf(7.35 if mounted else 5.4,separation*1.25)
 var aim=midpoint+Vector3(0,height,0)
 var fov=48.0
 if phase=="finish":
  var direction=signf(defender.x-attacker.x)
  aim=attacker+Vector3(0,(1.45 if mounted else 1.05)+(.5 if weapon=="lance" else 0.0),0)
  return {"anchor":aim+Vector3(direction*1.8,.65,5.8 if mounted else 4.8),"focus":aim,"lens":46.0}
 if phase=="windup":
  aim=aim.lerp(attacker+Vector3(0,height,0),.10)
  distance*=.99
 elif phase=="impact":
  aim=aim.lerp(defender+Vector3(0,height,0),.08)
  distance*=.98
 aim.y=midpoint.y+height*.5-distance*tan(deg_to_rad(fov*.5))*.18
 return {"anchor":aim+Vector3(sin(.57)*distance,.85,cos(.57)*distance),"focus":aim,"lens":fov}

func shot(attacker: Vector3,defender: Vector3,phase: String,ranged: bool,mounted=false,duration=.24,weapon="") -> Tween:
 if movement and movement.is_valid():movement.kill()
 var frame=frame_pair(attacker,defender,phase,ranged,mounted,weapon)
 movement=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 movement.tween_property(self,"anchor",frame.anchor,duration)
 movement.tween_property(self,"focus",frame.focus,duration)
 movement.tween_property(self,"lens",frame.lens,duration)
 return movement

static func entrance_frame(frame: Dictionary,weight: float) -> Dictionary:
 var start=frame.focus+(frame.anchor-frame.focus)*1.08+Vector3.UP*.30
 return {"anchor":start.lerp(frame.anchor,weight),"focus":frame.focus,"lens":frame.lens}

func establish(attacker: Vector3,defender: Vector3,ranged: bool,mounted=false):
 if movement and movement.is_valid():movement.kill()
 var frame=frame_pair(attacker,defender,"wide",ranged,mounted)
 anchor=frame.anchor;focus=frame.focus;lens=frame.lens;apply_frame()

func enter(attacker: Vector3,defender: Vector3,ranged: bool,mounted=false,duration=.22) -> Tween:
 establish(attacker,defender,ranged,mounted)
 var frame=frame_pair(attacker,defender,"wide",ranged,mounted)
 var opening=entrance_frame(frame,0)
 anchor=opening.anchor;apply_frame()
 movement=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 movement.tween_method(func(weight):
  anchor=entrance_frame(frame,weight).anchor;apply_frame()
 ,0.0,1.0,duration)
 return movement

func impact(critical=false,direction=1.0):
 if impact_motion and impact_motion.is_valid():impact_motion.kill()
 shake_offset=Vector2.ZERO
 var strength=(.075 if critical else .032)*(-1.0 if direction<0 else 1.0)
 impact_motion=create_tween()
 impact_motion.tween_property(self,"shake_offset",Vector2(strength,.018),.035)
 impact_motion.tween_property(self,"shake_offset",Vector2(-strength*.45,-.008),.045)
 impact_motion.tween_property(self,"shake_offset",Vector2.ZERO,.08)

func apply_frame():
 if not is_instance_valid(camera):return
 camera.position=anchor+Vector3(shake_offset.x,shake_offset.y,0)
 camera.look_at(focus);camera.fov=lens

func _process(_dt):apply_frame()

func stop():
 if movement and movement.is_valid():movement.kill()
 if impact_motion and impact_motion.is_valid():impact_motion.kill()
 set_process(false);shake_offset=Vector2.ZERO
