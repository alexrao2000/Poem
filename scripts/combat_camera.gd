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

static func frame_pair(attacker: Vector3,defender: Vector3,phase: String,ranged: bool,mounted=false) -> Dictionary:
 var midpoint=(attacker+defender)*.5
 var height=1.45 if mounted else 1.08
 var separation=attacker.distance_to(defender)
 var distance=maxf(5.8 if not ranged else 6.8,separation*1.4)
 var aim=midpoint+Vector3(0,height,0)
 var fov=48.0
 if phase=="finish":
  var direction=signf(defender.x-attacker.x)
  aim=attacker+Vector3(0,1.45 if mounted else 1.05,0)
  return {"anchor":aim+Vector3(direction*1.8,.65,5.8 if mounted else 4.8),"focus":aim,"lens":46.0}
 if phase=="windup":
  aim=aim.lerp(attacker+Vector3(0,height,0),.24)
  distance*=.94;fov=46.0
 elif phase=="impact":
  aim=aim.lerp(defender+Vector3(0,height,0),.22)
  distance*=.90;fov=46.0
 return {"anchor":aim+Vector3(1.25,.85,distance),"focus":aim,"lens":fov}

func shot(attacker: Vector3,defender: Vector3,phase: String,ranged: bool,mounted=false,duration=.24) -> Tween:
 if movement and movement.is_valid():movement.kill()
 var frame=frame_pair(attacker,defender,phase,ranged,mounted)
 movement=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 movement.tween_property(self,"anchor",frame.anchor,duration)
 movement.tween_property(self,"focus",frame.focus,duration)
 movement.tween_property(self,"lens",frame.lens,duration)
 return movement

func establish(attacker: Vector3,defender: Vector3,ranged: bool,mounted=false):
 var frame=frame_pair(attacker,defender,"wide",ranged,mounted)
 anchor=frame.anchor;focus=frame.focus;lens=frame.lens;apply_frame()

func impact(critical=false):
 if impact_motion and impact_motion.is_valid():impact_motion.kill()
 shake_offset=Vector2.ZERO
 var strength=.075 if critical else .032
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
