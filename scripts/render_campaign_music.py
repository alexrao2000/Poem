"""Render original campaign themes from the existing verified CC0 bank.

Each 32-bar calm/Ablaze pair shares one event timeline and exact frame count.
The opening theme and short game effects are rendered separately.
"""
from pathlib import Path
import argparse
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
                 [(75,0,1),(78,1,1),(83,2,1),(78,3,1)],[(76,0,3)]]),
    dict(id='sun_engine', title='The Light We Keep', bpm=112, seed=58433,
         harp_pattern=(0,2,1,2,1,0,2,1),
         chords=[(50,53,57),(46,50,53),(53,57,60),(48,52,55),
                 (50,53,57),(55,59,62),(46,50,53),(45,49,52),
                 (53,57,60),(52,55,60),(55,58,62),(50,53,57),
                 (46,50,53),(48,52,55),(45,49,52),(50,53,57)],
         melody=[[(74,0,1.5),(77,1.5,.5),(81,2,1),(79,3,1)],[(77,0,2),(74,2,1),(70,3,1)],
                 [(72,0,1),(77,1,1),(81,2,1.5),(79,3.5,.5)],[(76,0,1),(79,1,1),(72,2,1.5)],
                 [(74,0,1),(77,1,1),(81,2,2)],[(83,0,1.5),(81,1.5,.5),(79,2,1),(74,3,1)],
                 [(77,0,1),(82,1,1),(81,2,1),(77,3,1)],[(76,0,1),(73,1,1),(69,2,1.5)],
                 [(77,0,1),(81,1,1),(84,2,1.5),(81,3.5,.5)],[(79,0,2),(76,2,1),(72,3,1)],
                 [(74,0,1),(79,1,1),(82,2,1),(81,3,1)],[(77,0,1),(81,1,1),(74,2,1.75)],
                 [(77,0,1),(82,1,1),(86,2,1.5),(84,3.5,.5)],[(84,0,1.5),(79,1.5,.5),(76,2,1),(79,3,1)],
                 [(81,0,1),(76,1,1),(73,2,1.5),(76,3.5,.5)],[(74,0,3.5)]]),
    dict(id='abbey', title='Vespers for the Empty Tower', bpm=88, beats_per_bar=3, seed=30617,
         harp_pattern=(0,2,1,0,1,2),
         chords=[(55,58,62),(51,55,58),(48,52,55),(50,54,57),
                 (55,58,62),(53,57,60),(51,55,58),(50,54,57),
                 (48,52,55),(57,60,64),(53,57,60),(55,58,62),
                 (51,55,58),(48,52,55),(50,54,57),(55,58,62)],
         melody=[[(67,0,1),(74,1,.75),(70,1.75,1.25)],[(67,0,1.75),(70,2,.75)],
                 [(72,0,1),(76,1,1),(74,2,.75)],[(69,0,.75),(66,1,1.5)],
                 [(67,0,1),(74,1,.5),(77,1.5,.5),(74,2,1)],[(72,0,1.25),(69,1.25,.75),(65,2,.75)],
                 [(67,0,1),(70,1,1.75)],[(69,0,1),(66,1,1),(62,2,.75)],
                 [(72,0,1),(76,1,.75),(79,1.75,1.25)],[(81,0,1.75),(76,2,.75)],
                 [(77,0,1),(72,1,.5),(74,1.5,.5),(72,2,.75)],[(70,0,1),(67,1,1.75)],
                 [(67,0,.75),(70,.75,.75),(75,1.5,1.5)],[(76,0,1),(72,1,1),(67,2,.75)],
                 [(69,0,.75),(74,.75,.75),(66,1.5,1.25)],[(67,0,2.5)]]),
    dict(id='starfall', title='The Turning Sky', bpm=128, beats_per_bar=5, seed=45083,
         harp_pattern=(0,2,1,2,1,0,0,2,1,2),
         ablaze_harp_pattern=(0,1,0,2,2,1,2,0,2,1),
         chords=[(54,57,61),(50,54,57),(52,57,61),(49,53,56),
                 (54,57,61),(47,51,54),(50,54,57),(49,53,56),
                 (57,61,64),(52,56,59),(47,50,54),(54,57,61),
                 (50,54,57),(47,51,54),(49,53,56),(54,57,61)],
         melody=[[(78,.5,1.5),(76,2,.5),(73,3,1.75)],[(74,0,1.5),(69,1.5,1),(73,3,1.5)],
                 [(76,0,1),(81,1,1.5),(80,3,.75),(76,3.75,1)],[(77,0,1.5),(73,2,.75),(68,3,1.5)],
                 [(73,0,1),(78,1,1.5),(81,3,1.0),(78,4,1)],[(83,0,1.5),(78,2,1),(75,3,1.5)],
                 [(76,0,.75),(74,.75,1.5),(69,3,1.5)],[(73,0,1),(77,1.5,1.5),(68,3,1.5)],
                 [(81,0,1.5),(85,1.5,1),(83,3,.75),(81,3.75,1)],[(80,0,1.5),(76,1.5,1),(71,3,1.75)],
                 [(74,0,1),(78,1,1.75),(76,3,.75),(74,3.75,1)],[(73,0,1.5),(69,2,1),(78,3,1.5)],
                 [(81,0,1.0),(76,1.5,1),(74,3,1.5)],[(75,0,1),(78,1,1.25),(83,3,1.5)],
                 [(80,0,1),(77,1,1),(73,3,.75),(77,3.75,1)],[(78,0,3),(73,3.5,1)]]),
    dict(id='greywood', title='Where the Lanterns Wait', bpm=96, beats_per_bar=3, seed=61972,
         harp_pattern=(0,2,1,2,1,2),
         percussion_pattern=((0,1.5),(.5,2.5)),
         chords=[(50,53,57),(43,47,50),(48,52,55),(45,48,52),
                 (50,53,57),(47,50,53),(43,47,50),(45,48,52),
                 (48,52,55),(43,47,50),(45,48,52),(50,53,57),
                 (41,45,48),(43,47,50),(45,48,52),(50,53,57)],
         melody=[[(62,.5,.5),(65,1,.5),(69,1.5,1.5)],[(71,0,1),(69,1,.5),(67,1.5,1.25)],
                 [(64,0,1.5),(67,1.5,1),(72,2.5,.5)],[(71,0,.5),(69,.5,1),(64,1.5,1.25)],
                 [(65,0,.5),(69,.5,1),(74,1.5,1.5)],[(77,0,1),(74,1,.5),(71,1.5,1.25)],
                 [(67,0,1.5),(71,1.5,.5),(74,2,1)],[(72,0,1),(69,1,.5),(64,1.5,1.0)],
                 [(72,.5,.5),(76,1,.5),(79,1.5,1.5)],[(77,0,1),(74,1,.5),(71,1.5,1.5)],
                 [(72,0,.75),(76,.75,.75),(69,1.5,1.25)],[(74,0,1.25),(69,1.5,.5),(65,2,1)],
                 [(69,0,.5),(72,.5,1),(77,1.5,1.5)],[(74,0,1),(71,1,.5),(67,1.5,1.5)],
                 [(69,0,1),(64,1,.5),(65,1.5,.5),(67,2,.75)],[(62,0,2.5)]]),
    dict(id='glass_harbor', title='When the Tide Turns', bpm=116, seed=81913,
         harp_pattern=(0,2,1,0,2,1,2,1),
         percussion_pattern=((0,1.5,3),(1,2.5)),
         chords=[(43,46,50),(51,55,58),(46,50,53),(41,45,48),
                 (43,46,50),(48,52,55),(51,55,58),(50,54,57),
                 (46,50,53),(45,48,53),(48,51,55),(43,46,50),
                 (51,55,58),(48,52,55),(50,54,57),(43,46,50)],
         melody=[[(67,.5,1),(74,1.5,.75),(70,2.25,.75),(69,3,1)],
                 [(67,0,1.5),(70,1.5,1),(75,2.5,1.5)],
                 [(77,0,1.25),(74,1.5,.75),(72,2.25,.75),(70,3,1)],
                 [(69,0,1),(72,1.5,1.5),(65,3,.75)],
                 [(67,.5,1),(74,1.5,.75),(79,2.25,.75),(77,3,1)],
                 [(76,0,1.25),(72,1.5,.75),(67,2.5,1.5)],
                 [(70,0,1.5),(75,1.5,1),(79,2.5,1.5)],
                 [(78,0,1.5),(76,1.5,.75),(74,2.25,.75),(69,3,.75)],
                 [(70,.5,1),(77,1.5,.75),(82,2.25,.75),(81,3,1)],
                 [(77,0,1.5),(72,1.5,.75),(69,2.5,1.5)],
                 [(72,0,1),(75,1.5,1),(79,2.5,1.25)],
                 [(74,0,1.5),(70,1.5,.75),(67,2.5,1.5)],
                 [(70,.5,1),(75,1.5,.75),(79,2.25,.75),(82,3,1)],
                 [(84,0,1.25),(79,1.5,.75),(76,2.25,.75),(72,3,1)],
                 [(74,0,1),(78,1.5,.75),(81,2.25,.75),(78,3,.75)],
                 [(79,0,1.5),(74,1.5,1),(67,2.5,1.0)]]),
]


def render(theme,bank):
    beats = theme.get('beats_per_bar', 4)
    beat_seconds=60/theme['bpm'];frames=round(BARS*beats*beat_seconds*RATE)
    results={}
    default_pattern=(0,2,1,2,0,1,2,1) if theme['id']=='road' else (0,1,2,1,2,1,0,2)
    calm_pattern=theme.get('harp_pattern',default_pattern)
    downbeats, accents = {3: ((0,), (1, 2)), 4: ((0, 2), (1, 3)), 5: ((0, 3), (1.5, 4))}[beats]
    downbeats, accents = theme.get('percussion_pattern', (downbeats, accents))
    for mode in ('calm','ablaze'):
        rng=np.random.default_rng(theme['seed'])
        track=np.zeros((frames,2),dtype=np.float64);intense=mode=='ablaze'
        pattern=theme.get('ablaze_harp_pattern',calm_pattern) if intense else calm_pattern
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
            chord=theme['chords'][bar%16];start=bar*beats
            for i,pitch in enumerate(chord):note(pitch,start,beats+.2,'strings',.12 if intense else .1,(i-1)*.4)
            for step,degree in enumerate(pattern):note(chord[degree]+12,start+step*.5,.85,'harp',.07 if intense else .12,-.4)
            for pitch,offset,length in theme['melody'][bar%16]:
                note(pitch,start+offset,length*.94,'strings' if intense else 'flute',.23 if intense else .2,.12)
                if bar>=16 and bar%4 in (2,3):note(pitch-12,start+offset,length*.9,'horn' if intense else 'harp',.09,-.25)
            if intense:
                for step in range(beats*2):note(chord[0]-12 if step%2==0 else chord[0]-5,start+step*.5,.44,'bass',.19,.05)
                for beat in downbeats:percussion(start+beat)
                for beat in accents:percussion(start+beat,True)
                if bar%4==3:percussion(start+beats-.5,True)
                for pitch in chord:note(pitch+12,start,1.4,'horn',.1,-.3)
            else:note(chord[0]-12,start,beats-.2,'bass',.13,-.15)
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
    profile=dict(id=theme['id'],title=theme['title'])
    if 'first_chapter' in theme:profile['first_chapter']=theme['first_chapter']
    if beats!=4:profile['beats_per_bar']=beats
    profile.update(bpm=theme['bpm'],bars=BARS,frames=frames,sample_rate=RATE,channels=2,arrangements=results,
                   composition_sha256=hashlib.sha256(json.dumps([theme['chords'],theme['melody']]).encode()).hexdigest())
    return profile


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--theme',choices=[theme['id'] for theme in THEMES])
    selected=parser.parse_args().theme
    bank=OrchestraSamples(RATE)
    manifest=ROOT/'assets/audio/themes.json'
    if selected:
        catalog=json.loads(manifest.read_text())
        profiles={profile['id']:profile for profile in catalog['profiles']}
        profiles[selected]=render(next(theme for theme in THEMES if theme['id']==selected),bank)
        catalog['profiles']=list(profiles.values())
    else:
        original=json.loads((ROOT/'assets/audio/score.json').read_text())
        standard=dict(id='standard',title=original['title'],first_chapter=0,bpm=original['bpm'],bars=original['bars'],
                      frames=original['frames'],sample_rate=RATE,channels=2,
                      arrangements={mode:dict(path=f'res://assets/{mode}.wav') for mode in ('calm','ablaze')})
        catalog=dict(version=1,source='scripts/render_campaign_music.py',
                     samples='VSCO 2 Community Edition, CC0; see orchestra-sources.json and VSCO-LICENSE.txt',
                     profiles=[standard]+[render(theme,bank) for theme in THEMES])
    manifest.write_text(json.dumps(catalog,indent=2)+'\n')
