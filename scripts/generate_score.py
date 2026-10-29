"""Original 32-bar paired score and game effects. Requires NumPy; no sampled audio.
Both full arrangements share tempo, harmony, melody, frame count and loop phase.
"""
from pathlib import Path
import json
import wave
import numpy as np
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'assets/audio';OUT.mkdir(parents=True,exist_ok=True)
SR=22050;BPM=108;BEAT=60/BPM;BARS=32;FRAMES=round(BARS*4*BEAT*SR)
rng=np.random.default_rng(85107)

def voice(midi,seconds,instrument,velocity=1):
    t=np.arange(max(1,round(seconds*SR)))/SR
    hz=440*2**((midi-69)/12)
    phase=2*np.pi*hz*t + (.018*np.sin(2*np.pi*5.1*t) if instrument in ('strings','flute','horn') else 0)
    if instrument=='flute':
        sound=np.sin(phase)+.19*np.sin(2*phase)+.055*np.sin(3*phase)
        attack=.065;release=.12
    elif instrument=='strings':
        sound=sum(np.sin(phase*h+.03*h)*(.65/h**1.6) for h in range(1,10))
        sound+=.14*np.sin(phase*1.002)+.14*np.sin(phase*.998)
        attack=.13;release=.19
    elif instrument=='horn':
        sound=sum(np.sin(phase*h)*np.exp(-h/3.5)/h**.6 for h in range(1,9))
        attack=.09;release=.13
    elif instrument=='harp':
        sound=(np.sin(phase)+.36*np.sin(2*phase)+.19*np.sin(3*phase)+.08*np.sin(4*phase))*np.exp(-t*3.5)
        attack=.008;release=.08
    elif instrument=='bass':
        sound=(np.sin(phase)+.27*np.sin(2*phase)+.12*np.sin(3*phase))*np.exp(-t*.7)
        attack=.015;release=.08
    else:
        sound=np.sin(phase)+.17*np.sin(phase*3)+.08*np.sin(phase*5)
        attack=.2;release=.25
    envelope=np.minimum(1,t/attack)*np.minimum(1,np.maximum(0,(seconds-t)/release))
    return sound*envelope*velocity

def place(track,signal,beat,pan=0):
    start=round(beat*BEAT*SR)%FRAMES
    stereo=np.stack([signal*np.sqrt((1-pan)/2),signal*np.sqrt((1+pan)/2)],axis=1)
    end=start+len(signal)
    if end<=len(track):track[start:end]+=stereo
    else:
        split=len(track)-start;track[start:]+=stereo[:split];track[:end-len(track)]+=stereo[split:]

def note(track,midi,beat,length,instrument,vol,pan=0):
    place(track,voice(midi,length*BEAT,instrument,vol),beat,pan)

# D minor, with an opening Dorian inflection and a lifted relative-major middle.
chords=[(50,53,57),(46,50,53),(53,57,60),(48,52,55),
        (50,53,57),(55,58,62),(46,50,53),(45,49,52),
        (53,57,60),(48,52,55),(50,53,57),(46,50,53),
        (55,58,62),(50,53,57),(48,52,55),(45,49,52)]*2
# Each tuple is (pitch, start beat in bar, duration); original composed motifs.
melody=[
 [(74,0,1.5),(77,1.5,.5),(76,2,1),(72,3,1)],
 [(70,0,2),(69,2,1),(65,3,1)],
 [(69,0,1),(72,1,1),(77,2,1.5),(76,3.5,.5)],
 [(72,0,2),(67,2,2)],
 [(69,0,1),(74,1,1.5),(77,2.5,.5),(79,3,1)],
 [(79,0,1.5),(77,1.5,.5),(74,2,1),(70,3,1)],
 [(77,0,1),(74,1,1),(70,2,1),(69,3,1)],
 [(73,0,2),(69,2,1),(72,3,1)],
 [(77,0,2),(81,2,1),(79,3,1)],
 [(76,0,1.5),(74,1.5,.5),(72,2,2)],
 [(74,0,1),(77,1,1),(81,2,1),(79,3,1)],
 [(77,0,1.5),(74,1.5,.5),(70,2,2)],
 [(79,0,1),(82,1,1),(81,2,1),(77,3,1)],
 [(77,0,1),(74,1,1),(69,2,1),(65,3,1)],
 [(67,0,1),(72,1,1),(76,2,1),(74,3,1)],
 [(73,0,2),(69,2,1.5)],
]

def drum(kind):
    seconds={'kick':.5,'snare':.24,'hat':.12,'timpani':.9}[kind]
    t=np.arange(round(seconds*SR))/SR
    if kind=='kick':return np.sin(2*np.pi*(48*t+2.2*(1-np.exp(-t*24))))*np.exp(-t*9)*.32
    if kind=='timpani':return (np.sin(2*np.pi*73*t)+.3*np.sin(2*np.pi*111*t))*np.exp(-t*4)*.24
    noise=rng.uniform(-1,1,len(t));high=noise-np.roll(noise,1)*.85
    if kind=='hat':return high*np.exp(-t*45)*.035
    return (high*.12+np.sin(2*np.pi*185*t)*.12)*np.exp(-t*20)

tracks={}
for mode in ['calm','ablaze']:
    track=np.zeros((FRAMES,2),dtype=np.float64)
    for bar,chord in enumerate(chords):
        start=bar*4;intense=mode=='ablaze'
        # Shared string bed and harmony; attacks remain in phase in both versions.
        for i,pitch in enumerate(chord):
            note(track,pitch,start,4.25,'strings',.11 if not intense else .13,(i-1)*.45)
        for beat in range(8):
            pitch=chord[[0,1,2,1,0,2,1,2][beat]]+12
            note(track,pitch,start+beat*.5,.9,'harp',.11 if not intense else .075,-.4)
        motif=melody[bar%16]
        for pitch,offset,length in motif:
            # Second pass adds a higher answering voice, retaining the original theme.
            note(track,pitch,start+offset,length*.94,'strings' if intense else 'flute',.23 if intense else .2,.12)
            if bar>=16 and bar%4 in [1,3]:
                note(track,pitch-12,start+offset,length*.9,'horn' if intense else 'harp',.10,-.25)
        if intense:
            for beat in range(8):
                note(track,chord[0]-12 if beat%2==0 else chord[0]-5,start+beat*.5,.43,'bass',.2,.05)
                place(track,drum('hat'),start+beat*.5,.45)
            for beat in [0,2]:place(track,drum('kick'),start+beat,-.1)
            for beat in [1,3]:place(track,drum('snare'),start+beat,.2)
            if bar%4==3:
                for beat in [2.5,3,3.5]:place(track,drum('timpani'),start+beat,-.3)
            for pitch in chord:note(track,pitch+12,start,1.3,'horn',.09,-.35)
        else:
            note(track,chord[0]-12,start,3.7,'bass',.12,-.15)
            if bar%8 in [6,7]:note(track,chord[1]+12,start+2,1.8,'choir',.045,.3)
    # Circular early reflections keep the tail seamless at the loop boundary.
    dry=track.copy()
    for delay,gain in [(.071,.14),(.137,.10),(.223,.07),(.337,.045)]:
        reflected=np.roll(dry,round(delay*SR),axis=0)
        track+=reflected[:,::-1]*gain
    peak=np.max(np.abs(track));rms=np.sqrt(np.mean(track**2))
    track*=min(.87/peak,(.15 if mode=='ablaze' else .12)/rms)
    tracks[mode]=track
    # Keep filenames expected by the current Godot score resource.
    with wave.open(str(ROOT/'assets'/f'{mode}.wav'),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes((track*32767).astype('<i2').tobytes())

# Short deterministic effects, also synthesized from first principles.
effects={}
t=np.arange(round(.16*SR))/SR
effects['swing']=rng.uniform(-1,1,len(t))*np.sin(np.pi*t/.16)**2*np.exp(-t*14)*.25
t=np.arange(round(.25*SR))/SR
effects['hit']=(rng.uniform(-1,1,len(t))*.12+np.sin(2*np.pi*115*t)*.5)*np.exp(-t*24)
effects['critical']=(rng.uniform(-1,1,len(t))*.2+np.sin(2*np.pi*(65*t+2*(1-np.exp(-t*35))))*.55)*np.exp(-t*15)
effects['heal']=sum(voice(p,.65,'harp',.18) for p in [74,77,81])
effects['magic']=sum(voice(p,.45,'flute',.12) for p in [74,81,86])
effects['phase']=sum(voice(p,.7,'horn',.13) for p in [50,57,62])
effects['select']=voice(81,.07,'harp',.13)
for name,sound in effects.items():
    with wave.open(str(OUT/f'{name}.wav'),'wb') as f:
        f.setparams((1,2,SR,0,'NONE','not compressed'));f.writeframes((np.clip(sound,-.9,.9)*32767).astype('<i2').tobytes())
(OUT/'score.json').write_text(json.dumps(dict(title='A Standard at Dawn',composer='Original procedural composition for Ashen Standard',bpm=BPM,bars=BARS,meter='4/4',sample_rate=SR,channels=2,frames=FRAMES,duration_seconds=FRAMES/SR,arrangements=['calm','ablaze'],source='scripts/generate_score.py',samples='None; all voices and effects synthesized'),indent=2)+'\n')
print(f'Wrote matched {BARS}-bar stereo arrangements: {FRAMES/SR:.2f}s, {FRAMES} frames each; {len(effects)} effects.')
