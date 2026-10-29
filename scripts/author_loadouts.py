"""Authored enemy weapons; independent of map geometry and player inventory."""
import json
from pathlib import Path

LOADOUTS = [
    ['iron_sword','iron_axe','scout_bow','light_lance','iron_sword'],
    ['pike','scout_bow','hatchet','iron_sword','gale','iron_axe'],
    ['recurve','hatchet','iron_sword','gale','iron_axe','dueling_sword'],
    ['thunder','light_lance','scout_bow','estoc','pike','ember'],
    ['pike','javelin','scout_bow','iron_sword','gale','dueling_sword','hatchet'],
    ['tempered_sword','hatchet','recurve','ember','light_lance','longbow','iron_axe'],
    ['pike','light_lance','scout_bow','gale','javelin','hatchet','recurve','iron_sword'],
    ['javelin','scout_bow','war_hammer','gale','estoc','longbow','pike','dueling_sword'],
    ['thunder','pike','recurve','gale','iron_sword','javelin','longbow','dueling_sword'],
    ['pike','great_axe','ember','scout_bow','riders_bane','tempered_sword','gale','war_hammer','dueling_sword'],
    ['javelin','pike','longbow','gale','estoc','riders_bane','hatchet','light_lance','dueling_sword'],
    ['thunder','pike','javelin','longbow','gale','tempered_sword','riders_bane','light_lance','dueling_sword','ember'],
]


def apply_loadouts(content, equipment):
    items = {item['id']: item for item in equipment}
    assert len(content['chapters']) == len(LOADOUTS)
    for chapter, loadout in zip(content['chapters'], LOADOUTS):
        assert len(chapter['enemies']) == len(loadout), chapter['title']
        for enemy, item_id in zip(chapter['enemies'], loadout):
            assert items[item_id]['kind'] == content['classes'][enemy['job']]['weapon']
            enemy['item'] = item_id


if __name__ == '__main__':
    root = Path(__file__).resolve().parent.parent
    path = root / 'data/campaign.json'
    campaign = json.loads(path.read_text())
    apply_loadouts(campaign, json.loads((root / 'data/equipment.json').read_text()))
    path.write_text(json.dumps(campaign, indent=2, ensure_ascii=False) + '\n')
    print('Assigned weapons to all twelve authored enemy formations.')
