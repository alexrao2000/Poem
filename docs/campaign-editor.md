# Campaign editor

Poem campaigns are ordered sets of battles, recruit arrivals, section checkpoints, and story scenes. Choose a blank campaign with New draft, or open the draft library to copy Poem. Copy Poem with the Valley battle puts the war table between Crown Approach and the Sun Engine in a 13-chapter draft. In that battle, stop at Reed Crossing, Hallow Abbey, or Windscar Pass and finish an action to hear from the valley. The same versioned document can be exported as JSON and opened in either build.

From the title, choose **Begin the chronicle → The Roads Between** to play that 13-chapter campaign. It uses the rules you choose and keeps its own local save. Use **Continue The Roads Between** to resume, or import a matching save code through **Transfer a local save** at the title.

Copy Hold the Valley Roads opens a tested Hard campaign at Chapter 12 with a fixed playtest seed. Hold Reed Crossing, Hallow Abbey, and the capital at the same time. The draft includes Merrin’s relief company and Aster’s recruitment after two losses. Change individual switches in Rules to run the experiment with a different setup, or use Play from start to begin at Cinderford.

**Copy Signals in the Valley** opens the version with a defense, three reserve enemies, and the abbey signal scene. Set the **Permadeath** toggle beside the button before copying. Both playtests start in the editor at Chapter 12 with the same seed, Harder enemy forces, retry pressure, and Death’s Door.

Use Move to… above the Battle workspace to move the selected chapter to a specific number. The preview shows where it will land in the current order. Chapter-linked recruits, scenes, and standards follow their chapter. Check campaign flags links that reorder a war table ahead of a required route location.

Use Recruit on visit in Story’s Tile events to offer a reserve or a recruit scheduled for a later chapter. A standing ally recruits them by finishing an action on the tile. They join the company for the next deployment. The site can also play dialogue and replenish field tonics. In battle, choose Next site or press J to cycle through available tile events.

Company shows the recruit’s portrait and tactical sprite as you change appearance or class. Use Starting equipment to assign any weapon compatible with their class. The recruit arrives with it equipped. Chapter and legacy unlocks govern later choices from the shared arsenal. Preview 3D model opens the selected recruit with their equipped weapon. Choose a combat action to see the animation, then use Return to editor to resume editing the same recruit.

## Authoring

The chapter list shows play order and section starts. Authors can insert, duplicate, move, and remove chapters. A stable chapter key links its recruit arrivals, story scenes, and route pin, so reordering a battle moves its associated material with it. The first chapter always starts a section.

Each section can have its own relief, withdrawal, and memorial scenes. They follow the chapter when you reorder the campaign. Section restart rules trigger relief and withdrawal. Death events trigger memorials and add the names of the fallen. Read scenes can be replayed from the company’s records.

At a section break, use Relief company in Story to assign specific recruits, including reserves without a scheduled chapter. With permadeath and section restarts enabled, those recruits join at the rally point and carry forward after withdrawal. Use scheduled relief to draw from that chapter and the next.

In Rules, choose which items appear under Legacy supplies, how many permanent losses make each item available, and how many credits it costs. Legacy purchase required keeps an item out of the regular arsenal until the company secures it.

Legacy arrivals can give a recruit an early or reserve-only entry after a loss. Set the number of recorded losses, choose which fallen class can trigger the arrival, and write the scene. Use Higher priority and Lower priority to choose which recruit arrives when multiple entries qualify for the same loss.

The map workspace combines a terrain brush with controls for deployment tiles, enemy placements, hard-mode reinforcements, and the objective. Authors can resize a board and choose its battlefield environment and score. Use Preview arena beside Environment to see and hear the close-up surroundings for the highlighted tile. The Encounters workspace assigns the commander, chapter-wide enemy levels, individual level overrides, classes, strategies, and compatible equipment. Set an enemy’s arrival turn and phase to bring them in as reinforcements. Arrivals use the nearest open passable tile if the marked tile is occupied. The editor identifies blocked tiles, overlapping placements, and missing objective markers before playtest. The runtime uses its regular tactical rules and two-stage combat presentation.

Use Preview score in Battle to listen to the selected chapter theme. Calm and Ablaze share the same playhead. Close the preview to return to your draft.

Drag to paint a continuous line with the terrain brush. Leaving and reentering the board starts a fresh line in the same stroke. Undo terrain and Redo terrain reverse whole brush strokes. On the focused Battle grid, use Command-Z or Control-Z to undo and add Shift to redo. Resizing a board starts a fresh terrain history for that chapter.

Use Edit terrain rows in Battle to copy or paste the full grid as text. Each character represents one tile, and the dimensions match the current grid. Apply terrain records one undoable edit. Deployment, objectives, scene positions, and inherited route terrain keep their current placement.

Switch on Fill connected area to paint touching tiles of the same terrain in one step. The fill stops at different terrain and inherited route tiles. Undo terrain reverses the whole fill.

Use Move placement to relocate a deployment tile or enemy with its equipment, level, strategy, and arrival settings. Select another placement to swap their tiles. Right-click or press Escape to cancel the selection.

Use Copy placement to repeat an enemy or deployment position on empty passable tiles. Enemy copies keep their equipment, level, Hard assignment, and arrival settings. Click more tiles to repeat the same source, or press Escape to clear the selection.

The war council and section rallies use the number of deployment tiles you placed for that chapter. The Positions screen previews the authored map and its prepared enemies.

For a seize battle, use Extra standard in Battle to add more objectives. Win by holding every standard at once with standing allies. Right-click or press Backspace to remove an extra standard. The Battle grid, Positions screen, and war table show all required tiles. During battle, the objective shows how many are held. Choose Next standard or press G to cycle through their positions. Check campaign flags standards cut off from deployment.

Turn on Hold standards through an enemy phase to require a defense after your allies capture the objectives. End the player phase with a standing ally on every standard. If a standard falls, retake it and defend again. Action saves keep the current defense if you leave during the enemy phase.

In Story, add a phase scene and choose When a standards defense begins to play it as the company starts its first defense. The scene plays before the enemy acts. Its action save remembers when the dialogue has finished.

In Encounters, choose Arrive to contest the standards for a reserve you want to send in when that defense starts. It deploys at the start of the enemy phase and can act right away. The reserve uses its normal arrival time whenever the chapter uses immediate capture.

On the war table, the camera pulls back as those reserves settle onto the chart. Press Tab to skip the arrival and return to the battle view.

Preview deployment lists the enemies on the opening board and the reserves that join later. It shows when each reserve will arrive, its marked tile, and how retry pressure changes its stats and held tonics.

In Encounters, set a chapter’s Hard enemy bonuses for maximum HP, attack, speed, and defense. These apply to the on-map enemies and later reinforcements when Harder enemy forces is enabled. Retry pressure still adds its own bonuses and uses the rally chapter’s settings after a section restart.

Use Hard only on a selected enemy to move it between difficulty groups. Its position, equipment, and arrival stay with it. The commander deploys in every difficulty.

Set Retry deployment on an enemy who starts on the map to choose whether they advance as a raider. Class default uses the campaign’s usual raider classes. The commander stays at their deployment tile during retry preparation. Timed reinforcements enter on their assigned phase.

Preview deployment compares the chapter’s initial enemies at pressure zero with a chosen pressure. The list includes positions, combat stats, and held tonics. It uses the authored chapter, its Hard settings, and a fresh company, with the same preparation rules as a playtest.

The story workspace edits the chapter name, location, briefing, opening, and closing. Authors can also place dialogue at the start of a chosen player or enemy phase. An unfinished scene resumes when its battle is loaded. Dialogue lines use the campaign roster and portrait catalogue. The company workspace edits recruit names, introductions, classes, base stats, arrivals, epilogues, and initial deployment. Add up to sixteen recruits with their own identities and a catalogue appearance. Use the recruit ID shown in the picker when you write their dialogue. The Bonds workspace pairs recruits, sets the chapter and points required for each rank, and edits its conversations and shared epilogue. The company earns those points in battle and reads the scenes at camp. Campaign settings record the draft’s default experiment switches.

Use Edit loss dialogue to give a line an alternate if its speaker or a required recruit has fallen. This applies to chapter scenes, battle dialogue, section scenes, and legacy arrivals. The game uses the first alternate whose speaker and required recruits are still alive. Edit the original line in the same dialog to keep its conditions.

Use **Preview after losses** to select one or more fallen recruits and check which lines survive. In Chapter 1, select Oren to hear Lyra deliver the evacuation briefing. The simulation is local to that preview.

Choose **Preview dialogue** below a scene to read the current draft with its names, portraits, and game dialogue controls. This also works for bond scenes and drafts with unfinished battles. Press **Esc** or choose **Return to editor** to resume editing at the same place.

Dialogue art follows the chapter’s environment when you reorder chapters. War-table scenes show the campaign atlas, including any chart imported in Route.

In Story, use Add tile scene to give a battlefield location its own dialogue. The Battle grid marks those tiles. A standing ally triggers the scene after finishing an action there, and the terrain card shows whether dialogue is still available. If you load a saved action that triggered an unfinished scene, it plays before you resume battle. On a war table, link a scene to an earlier Route pin to follow that pin and use its location art in the game and editor preview. Deleting the linked chapter keeps the scene on its last tile.

Enable Refill the visiting ally’s field tonics on a tile scene to bring that ally’s supply back to two. Hallow Abbey uses this in the Valley campaign draft. A cache without dialogue stays available until an ally who needs tonics finishes an action there.

In battle, a small marker shows each unused site. Green crosses mark tonic caches. The marker disappears after the site is used.

The chapter picker and editing controls sit above the Battle, Encounters, Story, Route, Company, Bonds, and Rules workspaces. Click the illustrated chart in Route to place the active chapter’s pin, or use the percentage fields for precise positioning. Save draft keeps a local copy. Transfer JSON lets you open or save a campaign file on your device, and also accepts pasted JSON. Playtest can start at the first war council or the selected chapter. If another chapter is unfinished, Test this battle still opens a ready chapter with its own save. A single-battle test returns directly to the editor after victory.

Use Copy in Open drafts to start a separate edition of a saved campaign. Use Remove to free its place in the library.

Check campaign lists the battles that need edits and flags seize tiles with no passable route from deployment. Select a chapter in the list to open its Battle workspace. You can still test a disconnected objective while you work on the map.

In Rules, Playtest setup lets you override the combat seed or choose a starting level of retry pressure. Enable Enemies prepare after resets to set the starting pressure. A saved draft remembers its selected chapter and setup when you save or start a playtest. Each setup opens its own playtest save. The campaign JSON carries the campaign rules while the local library remembers these playtest choices on this device.

To share a reproducible setup, choose **Transfer JSON → Include playtest setup in saved file**, then **Save JSON file**. Opening that file restores the selected chapter, seed setting, and starting retry pressure. Select **Play from start** or **Play chapter** to begin a fresh playtest with those settings.

Enable **Sacrifice costs & openings** in Rules to set the allied attack bonus, the recovery HP penalty, and the tonics returning allies start with. The defaults are +2 attack, 4 HP missing, and one tonic. Set the attack to zero to test recovery by itself. Set the HP penalty to zero and tonics to two to test the opening by itself.

Enable **Death’s door & rescue** in Rules to give downed allies one to four player phases for treatment. The default is two. Rescue pauses the countdown, and staff healing revives the ally. The battlefield badge shows the remaining phases.

In a full campaign playtest, open **Options → Debug mode** to branch from the current war council or battlefield. Try enemy pressure, a different seed, or an ally’s fall in a separate Debug save for that draft. The Debug report compares the draft’s own enemies and rally chapters. Turn Debug mode off to restore the position where you enabled it.

## When the map becomes a battlefield

The reveal uses the same illustrated valley shown during campaign briefings. Deploying for the late route battle opens on the familiar chart from directly overhead. The camera tilts toward the war table as the grid spreads from the capital and the army pieces arrive. Paper rustles as the chart opens, and a wooden contact sounds as the first piece settles. The score continues on the same playhead. Click or press Tab to move directly to the tactical view. Drawn roads become cheap approaches, mountain passes use hill movement, marked crossings carry troops over otherwise blocked water, and the illustrated capital becomes the objective stronghold.

Use **Atlas note** in Route to add a short survey entry to a chapter’s briefing. Players can read it after reaching the chapter and see it again from the late battle’s atlas. The original chart has survey entries at Reed Crossing, Hallow Abbey, Old Aqueduct, and Starfall. Notes you write follow their chapters if you move or reorder their pins.

On a war table, select **Reveal origin** in the Battle tools and choose the tile where the tactical grid should first appear. The same point closes the chart after a victory. Right-click or press Backspace to restore the default. A seize battle starts the reveal at its primary standard by default.

Choose **Preview atlas reveal** in Battle to watch the current chart unfold with your selected origin, standards, and starting company. Use **Replay reveal** to see it again, or press **Esc** whenever you want to return to the editor.

The route battle keeps the existing classes, weapons, forecasting, and rules switches. Allied sprites stand on octagonal counters and enemy sprites stand on hexagonal counters. Each piece represents a company led by a character. Miniature crossings, abbeys, forests, hills, and strongholds rise with the grid at reached sites. Their tiles come from the same chapter pins used on the route screen and the terrain card gives their names. The close-up shows the commanders and the terrain where their pieces met. The original score, “The Roads Between,” moves from Calm to Ablaze on the same playhead during each exchange. Earlier route screens hint at the grid with a faint cartographer’s scale.

The editor offers a Valley war table chapter template. Its terrain and markers use normalized coordinates on the same route illustration, so the route pin and the authored board align at different window sizes. In Poem, open Route at Crown Approach and choose Unroll the war table. That encounter brings the current company, formation, bonds, and trial state into a separate playtest save. Choose Save and return to route to leave it, then Resume the war table to pick up where you stopped. Each chronicle has its own optional war-table save. That encounter treats the Valley as its section rally. In the full **The Roads Between** campaign, the Valley battle belongs to the section that starts at Starfall. The section restart rule applies with permadeath enabled.

To carry an earlier location into a war table battle, set its terrain in Route. Moving that chapter’s pin moves the terrain on each later table. The Battle grid marks inherited tiles and names them when inspected. If entries share a tile, the latest preceding chapter with assigned terrain takes priority. The table keeps the terrain painted under each inherited tile so the paint returns if the pin moves or the assignment is cleared. The seize objective keeps its painted terrain.

Close-up battles at reached war-table sites can bring back local scenery. Reed Crossing’s tollhouse returns on its bridge tile, and Kingsroad’s bridge overlooks the canal and cargo hoist. Hallow Abbey brings back its floor mosaic and any memorial lamps. Windscar Pass shows the ridge and signal fires, and the capital stronghold uses the raised gate.

Route briefings show each reached location’s survey mark. The same marks appear in the editor’s war-table overlay and on the battlefield’s terrain card. Choose Next landmark or press L to inspect places from earlier chapters in campaign order. Use Index beside Next landmark to jump directly to a named place. Locations sharing a tile have separate entries in the index.

During a war-table battle, press **V** or select **Atlas** to reread the earlier briefings. **Show battle grid** overlays the terrain and standards. **Show units** marks your company, foes, downed allies, and control of the standards. With either layer on, select a tile with the pointer or use the arrow keys with the atlas focused to see its occupants, health, and standard holder. Open the atlas with a ready ally selected to trace legal routes and see their movement cost. **Inspect selected tile** returns to the battlefield at its survey mark.

Choose **Replay reveal** in the battle atlas to watch the chart become the battlefield again. Click or press Tab to skip. The scene returns to the current camera and selected unit.

The atlas remembers **Show battle grid** and **Show units** while you move between it and the same battlefield. Loading a battle opens the atlas with both layers off.

When a defeat sends the company back to an earlier chapter, **Preview rally company** lists the starting deployment, available reserves, and permanent losses before regrouping. The same preview is available in **Review losses** if ending the phase would cause that retreat.

With reset pressure enabled, **Compare enemy preparations** shows how the next pressure level changes each enemy’s starting position, combat stats, and held tonics at the rally.

Use Reuse this environment on later war tables in Route to give the tile that chapter’s close-up surroundings and ambience. Built-in locations including Glass Harbor and Starfall offer their original arenas by default. The war-table overlay names the chosen arena. Use Preview arena below the overlay to open the actual close-up scenery at that pin. When several eligible pins share a tile, the latest preceding chapter supplies it.

Choose a battle in the War-table overlay in Route to see its effective terrain and seize objective over the atlas. The readout follows the selected pin. Moving a pin or changing its inherited terrain updates the overlay as you edit.

Choose a later seize battle in the overlay and switch on Require this pin as a standard to make that location part of the victory condition. Its standard follows the pin when it moves. Deleting the linked chapter leaves a standard on its last tile.

Use Open atlas image in Route to use your own PNG or JPEG for a campaign. The picker accepts images up to 6 MB and 8 megapixels. Poem centers the image in a 3:2 crop, sizes it to 1,200 by 800 pixels, and stores it inside the campaign JSON. The route screen and war tables use the same picture. Place chapter pins and paint the table’s terrain against that picture.

Use Add blank war table in Route when you want to paint your own geography. It inserts a battle after the selected chapter and opens its 24 by 16 grid on the current atlas. The base grid starts with a stronghold objective and plain terrain. Earlier route pins still supply their assigned terrain.

## Game data and playtest

A campaign document contains its format and version, title, ordered chapters, roster settings, bonds, and defaults. Chapter entries carry the campaign fields for terrain, deployments, encounters, objectives, music, and scenery alongside their story scenes. The editor resolves stable recruit arrival and bond chapter keys to chapter indices when it makes a runtime copy. Removing a chapter moves those arrivals and conversations to the next surviving chapter, or the previous chapter if it was the finale. Each playtest runs against its own copy and saves independently of the normal campaign.

Verification covers draft import and export, chapter edits and arrival remapping, editor layout at narrow widths, a complete two-chapter playtest, and a turn on the valley grid. The world-map encounter must use the same image as the route view and enter its tactical and 3D combat paths through the normal controls.
