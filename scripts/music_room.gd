extends Node
## Private audition playback. Campaign voices and in-flight fades are suspended
## in place and restored even when another screen removes the room unexpectedly.
const Director=preload("res://scripts/score_director.gd")
var director: Node
var held_voices: Array=[]
var held_tweens: Array=[]
var mix: Tween
var theme_index=0
var ablaze=false

func configure(campaign: Node,campaign_mix,chapter: int,volume: float):
 name="MusicRoomAudio"
 for voice in [campaign.player,campaign.outgoing]:
  if is_instance_valid(voice):
   held_voices.append({"voice":voice,"paused":voice.stream_paused});voice.stream_paused=true
 for tween in [campaign.fade,campaign_mix]:
  if tween!=null and tween.is_valid() and tween.is_running():held_tweens.append(tween);tween.pause()
 director=Director.new();add_child(director);director.configure(volume)
 var profile=director.profile_for(chapter);theme_index=director.profiles.find(profile)
 director.select_chapter(chapter);director.player.play()

func select_theme(index: int) -> bool:
 if index<0 or index>=director.profiles.size() or index==theme_index:return false
 if mix and mix.is_valid():mix.kill()
 theme_index=index;director.select_chapter(int(director.profiles[index].first_chapter))
 apply_arrangement(false)
 return true

func select_arrangement(value: bool):
 if value==ablaze:return
 ablaze=value;apply_arrangement(true)

func apply_arrangement(animate: bool):
 if mix and mix.is_valid():mix.kill()
 var target=1.0 if ablaze else 0.0
 if not animate:
  director.apply_arrangement(target);return
 mix=create_tween()
 mix.tween_method(director.apply_arrangement,director.arrangement_blend,target,Director.ARRANGEMENT_FADE_SECONDS)

func _exit_tree():
 if mix and mix.is_valid():mix.kill()
 if is_instance_valid(director):director.stop()
 for state in held_voices:
  if is_instance_valid(state.voice):state.voice.stream_paused=state.paused
 for tween in held_tweens:
  if tween.is_valid():tween.play()
 held_voices.clear();held_tweens.clear()
