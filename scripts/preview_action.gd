extends Node
# Replay from a meaningful starting pose rather than tweening a held endpoint
# onto itself. One controller cancels pending poses when selection or view changes.
# Travel loops the combat gait in place so inspection never moves the model away.

const Actor=preload("res://scripts/fighter_actor.gd")
signal finished
var actor: Node3D
var current: Tween
var pending=[]
var playing=false
var selected_action="idle"

func configure(subject: Node3D):actor=subject;process_priority=-1

func play(key: String):
 stop();selected_action=key
 if not is_instance_valid(actor):return
 if key=="advance":
  if actor is Actor:actor.gait_phase=0.0
  pending=[["advance",.24]]
 elif key=="idle":pending=[["idle",.18]]
 elif key=="strike":pending=[["windup",.26],["strike",.16]]
 elif key=="cast":pending=[["cast_windup",.28],["cast",.18]]
 elif key=="throw":pending=[["throw_windup",.26],["throw",.16]]
 elif key=="recover":pending=[["windup",.20],["strike",.14],["recover",.28]]
 else:pending=[["idle",.16],[key,.28]]
 playing=true;next_pose()

func next_pose():
 if pending.is_empty():playing=false;finished.emit();return
 var step=pending.pop_front();current=actor.pose(step[0],step[1])

func _process(dt):
 if not playing:return
 if not is_instance_valid(actor):stop();return
 if selected_action=="advance":
  if actor is Actor and actor.is_visible_in_tree():
   var speed=2.7 if actor.mounted else 1.8 if actor.kind in ["magic","staff"] else 2.4
   actor.advance_stride(speed*dt*actor.global_basis.z.length())
  elif actor.has_method("nominal_stride_speed") and actor.is_visible_in_tree():
   actor.advance_stride(actor.nominal_stride_speed()*dt*actor.global_basis.z.length())
  return
 if current and current.is_valid() and current.is_running():return
 next_pose()

func stop():
 playing=false;pending.clear()
 if current and current.is_valid():current.kill()
 current=null
 if selected_action=="advance" and is_instance_valid(actor) and actor.is_inside_tree():actor.pose("idle",.18)

func _exit_tree():stop()
