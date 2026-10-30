"""Render two original campaign themes from the existing verified CC0 bank.

Each 32-bar calm/Ablaze pair shares one event timeline and exact frame count.
This leaves the first act's score and all short game effects unchanged.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from orchestra_samples import OrchestraSamples

ROOT = Path(__file__).resolve().parent.parent
RATE = 22050
BARS = 32
THEMES = [
    dict(id='road', title='The Road Beneath the Ash', bpm=96, first_chapter=4, seed=38109,
         chords=[(45,48,52),(41,45,48),(50,53,57),(40,44,47),
                 (45,48,52),(43,47,50),(41,45,48),(40,44,47),
                 (48,52,55),(43,47,50),(41,45,48),(45,48,52),
                 (50,53,57),(41,45,48),(40,44,47),(45,48,52)],
         melody=[[(69,0,2),(72,2,1),(71,3,1)],[(69,0,1.5),(65,1.5,.5),(64,2,2)],
                 [(65,0,1),(69,1,1),(74,2,1.5),(72,3.5,.5)],[(71,0,2),(68,2,2)],
                 [(72,0,1),(76,1,1.5),(74,2.5,.5),(72,3,1)],[(71,0,1.5),(67,1.5,.5),(62,2,2)],
                 [(65,0,1),(69,1,1),(72,2,2)],[(71,0,1),(68,1,1),(64,2,1.5)],
                 [(76,0,1.5),(79,1.5,.5),(76,2,1),(72,3,1)],[(74,0,2),(71,2,1),(67,3,1)],
                 [(69,0,1),(72,1,1),(77,2,1),(76,3,1)],[(72,0,2),(69,2,2)],
                 [(74,0,1),(77,1,1.5),(76,2.5,.5),(74,3,1)],[(72,0,1),(69,1,1),(65,2,2)],
                 [(68,0,1),(71,1,1),(76,2,1.5),(71,3.5,.5)],[(69,0,3)]]),
    dict(id='dawnless', title='Dawn Without Kings', bpm=120, first_chapter=8, seed=72931,
         chords=[(52,55,59),(48,52,55),(55,59,62),(50,54,57),
                 (52,55,59),(57,60,64),(48,52,55),(47,51,54),
                 (55,59,62),(50,54,57),(48,52,55),(52,55,59),
                 (57,60,64),(48,52,55),(47,51,54),(52,55,59)],
         melody=[[(76,0,.75),(79,.75,.25),(83,1,1),(81,2,1),(79,3,1)],[(76,0,1),(72,1,1),(74,2,1),(76,3,1)],
                 [(79,0,1.5),(83,1.5,.5),(81,2,1),(79,3,1)],[(78,0,1),(74,1,1),(69,2,2)],
                 [(76,0,1),(79,1,.5),(83,1.5,.5),(81,2,1),(76,3,1)],[(81,0,1.5),(84,1.5,.5),(83,2,1),(81,3,1)],
                 [(79,0,1),(76,1,1),(72,2,1),(76,3,1)],[(78,0,1),(75,1,1),(71,2,1.5)],
                 [(83,0,2),(81,2,1),(79,3,1)],[(81,0,1),(78,1,1),(74,2,2)],
                 [(76,0,.75),(79,.75,.25),(84,1,1),(83,2,1),(79,3,1)],[(76,0,2),(71,2,1),(76,3,1)],
                 [(81,0,1),(84,1,1),(83,2,.5),(81,2.5,.5),(76,3,1)],[(79,0,1.5),(76,1.5,.5),(72,2,2)],
                 [(75,0,1),(78,1,1),(83,2,1),(78,3,1)],[(76,0,3)]])
]


def render(theme,bank):
    beat_seconds=60/theme['bpm'];frames=round(BARS*4*beat_seconds*RATE)
    results={}
    for mode in ('calm','ablaze'):
        rng=np.random.default_rng(theme['seed'])
        track=np.zeros((frames,2),dtype=np.float64);intense=mode=='ablaze'
        def place(signal,beat,pan=0):
            start=round(beat*beat_seconds*RATE)%frames
            stereo=np.stack((signal*np.sqrt((1-pan)/2),signal*np.sqrt((1+pan)/2)),axis=1)
            count=min(len(signal),frames-start);track[start:start+count]+=stereo[:count]
            if count<len(signal):track[:len(signal)-count]+=stereo[count:]
        def note(pitch,beat,length,instrument,volume,pan=0):
            sound=bank.render(pitch,length*beat_seconds,instrument,volume)
            if sound is None:raise ValueError('Missing verified instrument: '+instrument)
            place(sound,beat,pan)
        def percussion(beat,accent=False):
            t=np.arange(round(.45*RATE))/RATE
            if accent:
                noise=rng.uniform(-1,1,len(t));high=noise-.75*np.roll(noise,1)
                sound=(high*.07+np.sin(2*np.pi*180*t)*.07)*np.exp(-t*22)
            else:sound=(np.sin(2*np.pi*(52*t+1.8*(1-np.exp(-t*25))))+.2*np.sin(2*np.pi*87*t))*np.exp(-t*11)*.25
            place(sound*(1-np.exp(-t*1500)),beat,.15 if accent else -.15)
        for bar in range(BARS):
            chord=theme['chords'][bar%16];start=bar*4
            for i,pitch in enumerate(chord):note(pitch,start,4.2,'strings',.12 if intense else .1,(i-1)*.4)
            pattern=[0,2,1,2,0,1,2,1] if theme['id']=='road' else [0,1,2,1,2,1,0,2]
            for step,degree in enumerate(pattern):note(chord[degree]+12,start+step*.5,.85,'harp',.07 if intense else .12,-.4)
            for pitch,offset,length in theme['melody'][bar%16]:
                note(pitch,start+offset,length*.94,'strings' if intense else 'flute',.23 if intense else .2,.12)
                if bar>=16 and bar%4 in (2,3):note(pitch-12,start+offset,length*.9,'horn' if intense else 'harp',.09,-.25)
            if intense:
                for step in range(8):note(chord[0]-12 if step%2==0 else chord[0]-5,start+step*.5,.44,'bass',.19,.05)
                for beat in (0,2):percussion(start+beat)
                for beat in (1,3):percussion(start+beat,True)
                if bar%4==3:percussion(start+3.5,True)
                for pitch in chord:note(pitch+12,start,1.4,'horn',.1,-.3)
            else:note(chord[0]-12,start,3.8,'bass',.13,-.15)
        dry=track.copy()
        for delay,gain in ((.071,.14),(.137,.10),(.223,.07),(.337,.045)):
            track+=np.roll(dry,round(delay*RATE),axis=0)[:,::-1]*gain
        track*=min(.87/np.max(np.abs(track)),(.15 if intense else .12)/np.sqrt(np.mean(track**2)))
        output=ROOT/'assets/audio'/f"{theme['id']}-{mode}.wav"
        with wave.open(str(output),'wb') as stream:
            stream.setparams((2,2,RATE,0,'NONE','not compressed'))
            stream.writeframes((track*32767).astype('<i2').tobytes())
        metrics=dict(peak=float(np.max(np.abs(track))),rms=float(np.sqrt(np.mean(track**2))),boundary_step=float(np.max(np.abs(track[0]-track[-1]))))
        results[mode]=dict(path='res://'+str(output.relative_to(ROOT)),**metrics)
        print(theme['title'],mode,f'{frames/RATE:.2f}s',metrics,flush=True)
    return dict(id=theme['id'],title=theme['title'],first_chapter=theme['first_chapter'],bpm=theme['bpm'],bars=BARS,frames=frames,sample_rate=RATE,channels=2,arrangements=results,
                composition_sha256=hashlib.sha256(json.dumps([theme['chords'],theme['melody']]).encode()).hexdigest())


if __name__=='__main__':
    bank=OrchestraSamples(RATE)
    existing=json.loads((ROOT/'assets/audio/score.json').read_text())
    profiles=[dict(id='standard',title=existing['title'],first_chapter=0,bpm=existing['bpm'],bars=existing['bars'],frames=existing['frames'],sample_rate=RATE,channels=2,
                   arrangements={mode:dict(path=f'res://assets/{mode}.wav') for mode in ('calm','ablaze')})]
    profiles.extend(render(theme,bank) for theme in THEMES)
    (ROOT/'assets/audio/themes.json').write_text(json.dumps(dict(version=1,source='scripts/render_campaign_music.py',samples='VSCO 2 Community Edition, CC0; see orchestra-sources.json and VSCO-LICENSE.txt',profiles=profiles),indent=2)+'\n')
