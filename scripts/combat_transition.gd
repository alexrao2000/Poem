extends Control
# A restrained radial veil carries the tactical zoom into the arena. Geometry
# uses a fixed pattern so presentation never consumes the campaign RNG.
var progress=0.0:
 set(value):progress=clampf(value,0,1);queue_redraw()
var focal=Vector2(.5,.5)
var focal_source: Callable
var motion: Tween
var streaks=true

func configure(parent: Control,source=Callable()):
 name="CombatTransition";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=30
 parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 focal_source=source

func conceal(duration=.42,with_streaks=true) -> Tween:
 if motion and motion.is_valid():motion.kill()
 streaks=with_streaks;progress=0
 motion=create_tween();motion.tween_property(self,"progress",1.0,duration)
 return motion

func reveal(duration=.22) -> Tween:
 if motion and motion.is_valid():motion.kill()
 focal_source=Callable();focal=Vector2(.5,.5);progress=1
 motion=create_tween();motion.tween_property(self,"progress",0.0,duration)
 return motion

func cover_alpha() -> float:return smoothstep(.52,1.0,progress)

func _draw():
 if progress<=0:return
 var center=size*focal
 if focal_source.is_valid():center=focal_source.call()
 var radius=size.length()*.65
 var envelope=sin(progress*PI)
 draw_rect(Rect2(Vector2.ZERO,size),Color(.06,.10,.16,envelope*.10))
 if streaks:
  for i in range(28):
   var angle=i*TAU/28+.035*sin(i*2.7)
   var direction=Vector2(cos(angle),sin(angle));var normal=Vector2(-direction.y,direction.x)
   var start=radius*(.18+progress*.65+float(i%3)*.055)
   var length=radius*(.14+float(i%4)*.025)
   var width=1.5+float(i%3)
   var color=Color(.72,.81,.84,envelope*.24) if i%3 else Color(.88,.81,.64,envelope*.27)
   draw_colored_polygon(PackedVector2Array([center+direction*start,center+direction*(start+length)+normal*width,center+direction*(start+length)-normal*width]),color)
 draw_rect(Rect2(Vector2.ZERO,size),Color(.06,.10,.16,cover_alpha()))
