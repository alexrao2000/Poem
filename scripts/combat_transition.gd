extends Control
# A radial veil follows the combatants through the tactical zoom and the reveal.
const INK=Color(.06,.10,.16)
const COOL_STREAK=Color(.72,.81,.84)
const WARM_STREAK=Color(.88,.81,.64)
const APERTURE_INNER=.17
const APERTURE_OUTER=.36
static var opening_mask: GradientTexture2D
var progress=0.0:
 set(value):progress=clampf(value,0,1);queue_redraw()
var focal_source: Callable
var motion: Tween
var streaks=true
var revealing=false
var ink=INK
var cool_streak=COOL_STREAK
var warm_streak=WARM_STREAK

func configure(parent: Control,source=Callable(),horizon=Color.TRANSPARENT):
 name="CombatTransition";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=30
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 focal_source=source
 if horizon.a>0:
  ink=INK.lerp(horizon.darkened(.81),.52)
  cool_streak=COOL_STREAK.lerp(horizon,.36)
  warm_streak=WARM_STREAK.lerp(horizon.lightened(.13),.28)

func conceal(duration=.42,with_streaks=true) -> Tween:
 if motion and motion.is_valid():motion.kill()
 revealing=false;streaks=with_streaks;progress=0
 motion=create_tween();motion.tween_property(self,"progress",1.0,duration)
 return motion

func reveal(duration=.22,source=Callable()) -> Tween:
 if motion and motion.is_valid():motion.kill()
 revealing=true;focal_source=source;progress=1
 motion=create_tween();motion.tween_property(self,"progress",0.0,duration)
 return motion

func cover_alpha() -> float:return smoothstep(.52,1.0,progress)

func shade_alpha() -> float:
 if revealing:return smoothstep(.03,.52,progress)*(1.0-cover_alpha())*.42
 return smoothstep(.08,.50,progress)*(1.0-cover_alpha())*.36

static func aperture_mask() -> GradientTexture2D:
 if opening_mask==null:
  var gradient=Gradient.new()
  gradient.offsets=PackedFloat32Array([0,APERTURE_INNER,.22,.31,APERTURE_OUTER,1])
  gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color(1,1,1,.18),Color(1,1,1,.82),Color.WHITE,Color.WHITE])
  opening_mask=GradientTexture2D.new()
  opening_mask.width=256;opening_mask.height=256
  opening_mask.fill=GradientTexture2D.FILL_RADIAL
  opening_mask.fill_from=Vector2(.5,.5);opening_mask.fill_to=Vector2(1,.5)
  opening_mask.gradient=gradient
 return opening_mask

func aperture_rect(projected: Vector2) -> Rect2:
 var center=projected-Vector2(0,size.y*.08)
 var far_edge=Vector2(maxf(center.x,size.x-center.x),maxf(center.y,size.y-center.y))
 var radius=maxf(size.y*3,far_edge.length()+1)
 var half=Vector2.ONE*radius
 return Rect2(center-half,half*2)

func projected_focus() -> Vector2:
 if not focal_source.is_valid():return size*.5
 var center: Vector2=focal_source.call()
 # The player's saved map view may be panned away from this exchange.
 if revealing:center=center.clamp(size*.10,size*.90)
 return center

func _draw():
 if progress<=0:return
 var center=projected_focus()
 var radius=size.length()*.65
 var envelope=sin(progress*PI)
 if (streaks or revealing) and focal_source.is_valid():
  draw_texture_rect(aperture_mask(),aperture_rect(center),false,Color(ink,shade_alpha()))
 else:
  draw_rect(Rect2(Vector2.ZERO,size),Color(ink,envelope*.10))
 if streaks:
  for i in range(28):
   var angle=i*TAU/28+.035*sin(i*2.7)
   var direction=Vector2(cos(angle),sin(angle));var normal=Vector2(-direction.y,direction.x)
   var start=radius*(.18+progress*.65+float(i%3)*.055)
   var length=radius*(.14+float(i%4)*.025)
   var width=1.5+float(i%3)
   var color=Color(cool_streak,envelope*.24) if i%3 else Color(warm_streak,envelope*.27)
   draw_colored_polygon(PackedVector2Array([center+direction*start,center+direction*(start+length)+normal*width,center+direction*(start+length)-normal*width]),color)
 draw_rect(Rect2(Vector2.ZERO,size),Color(ink,cover_alpha()))
