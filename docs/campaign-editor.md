# Campaign editor

Poem campaigns are ordered sets of battles, recruit arrivals, section checkpoints, and story scenes. Choose a blank campaign with New draft, or open the draft library to copy Poem. Copy Poem with the Valley battle puts the war table between Crown Approach and the Sun Engine in a 13-chapter draft. In that battle, stop at Reed Crossing, Hallow Abbey, or Windscar Pass and finish an action to hear from the valley. The same versioned document can be exported as JSON and opened in either build.

## Authoring

The chapter list shows play order and section starts. Authors can insert, duplicate, move, and remove chapters. A stable chapter key links its recruit arrivals, story scenes, and route pin, so reordering a battle moves its associated material with it. The first chapter always starts a section.

Each section can have its own relief, withdrawal, and memorial scenes. They follow the chapter when you reorder the campaign. Section restart rules trigger relief and withdrawal. Death events trigger memorials and add the names of the fallen. Read scenes can be replayed from the company’s records.

At a section break, use Relief company in Story to assign specific recruits, including reserves without a scheduled chapter. With permadeath and section restarts enabled, those recruits join at the rally point and carry forward after withdrawal. Use scheduled relief to draw from that chapter and the next.

In Rules, choose which items appear under Legacy supplies, how many permanent losses make each item available, and how many credits it costs. Legacy purchase required keeps an item out of the regular arsenal until the company secures it.

Legacy arrivals can give a recruit an early or reserve-only entry after a loss. Set the number of recorded losses, choose which fallen class can trigger the arrival, and write the scene. Use Higher priority and Lower priority to choose which recruit arrives when multiple entries qualify for the same loss.

The map workspace combines a terrain brush with controls for deployment tiles, enemy placements, hard-mode reinforcements, and the objective. Authors can resize a board and choose its battlefield environment and score. The Encounters workspace assigns the commander, chapter-wide enemy levels, individual level overrides, classes, strategies, and compatible equipment. Set an enemy’s arrival turn and phase to bring them in as reinforcements. Arrivals use the nearest open passable tile if the marked tile is occupied. The editor identifies blocked tiles, overlapping placements, and missing objective markers before playtest. The runtime uses its regular tactical rules and two-stage combat presentation.

Drag to paint a continuous line with the terrain brush. Leaving and reentering the board starts a fresh line in the same stroke. Undo terrain and Redo terrain reverse whole brush strokes. On the focused Battle grid, use Command-Z or Control-Z to undo and add Shift to redo. Resizing a board starts a fresh terrain history for that chapter.

Switch on Fill connected area to paint touching tiles of the same terrain in one step. The fill stops at different terrain and inherited route tiles. Undo terrain reverses the whole fill.

Use Move placement to relocate a deployment tile or enemy with its equipment, level, strategy, and arrival settings. Select another placement to swap their tiles. Right-click or press Escape to cancel the selection.

The war council and section rallies use the number of deployment tiles you placed for that chapter. The Positions screen previews the authored map and its prepared enemies.

For a seize battle, use Extra standard in Battle to add more objectives. Win by holding every standard at once with standing allies. Right-click or press Backspace to remove an extra standard. The Battle grid, Positions screen, and war table show all required tiles. During battle, the objective shows how many are held. Choose Next standard or press G to cycle through their positions. Check campaign flags standards cut off from deployment.

In Encounters, set a chapter’s Hard enemy bonuses for maximum HP, attack, speed, and defense. These apply to the on-map enemies and later reinforcements when Harder enemy forces is enabled. Retry pressure still adds its own bonuses and uses the rally chapter’s settings after a section restart.

Set Retry deployment on an enemy who starts on the map to choose whether they advance as a raider. Class default uses the campaign’s usual raider classes. The commander stays at their deployment tile during retry preparation. Timed reinforcements enter on their assigned phase.

Preview deployment compares the chapter’s initial enemies at pressure zero with a chosen pressure. The list includes positions, combat stats, and held tonics. It uses the authored chapter, its Hard settings, and a fresh company, with the same preparation rules as a playtest.

The story workspace edits the chapter name, location, briefing, opening, and closing. Authors can also place dialogue at the start of a chosen player or enemy phase. An unfinished scene resumes when its battle is loaded. Dialogue lines use the campaign roster and portrait catalogue. The company workspace edits recruit names, introductions, classes, base stats, arrivals, epilogues, and initial deployment. Add up to sixteen recruits with their own identities and a catalogue appearance. Use the recruit ID shown in the picker when you write their dialogue. The Bonds workspace pairs recruits, sets the chapter and points required for each rank, and edits its conversations and shared epilogue. The company earns those points in battle and reads the scenes at camp. Campaign settings record the draft’s default experiment switches.

Use Edit loss dialogue to give a line an alternate if its speaker or a required recruit has fallen. This applies to chapter scenes, battle dialogue, section scenes, and legacy arrivals. The game uses the first alternate whose speaker and required recruits are still alive. Edit the original line in the same dialog to keep its conditions.

In Story, use Add tile scene to give a battlefield location its own dialogue. The Battle grid marks those tiles. A standing ally triggers the scene after finishing an action there, and the terrain card shows whether dialogue is still available. If you load a saved action that triggered an unfinished scene, it plays before you resume battle. On a war table, choose an earlier Route pin to move the scene whenever that pin moves. Deleting the linked chapter keeps the scene on its last tile.

Enable Refill the visiting ally’s field tonics on a tile scene to bring that ally’s supply back to two. Hallow Abbey uses this in the Valley campaign draft. A cache without dialogue stays available until an ally who needs tonics finishes an action there.

In battle, a small marker shows each unused site. Green crosses mark tonic caches. The marker disappears after the site is used.

The chapter picker and editing controls sit above the Battle, Encounters, Story, Route, Company, Bonds, and Rules workspaces. Click the illustrated chart in Route to place the active chapter’s pin, or use the percentage fields for precise positioning. Save draft keeps a local copy. Transfer JSON lets you open or save a campaign file on your device, and also accepts pasted JSON. Playtest can start at the first war council or the selected chapter. If another chapter is unfinished, Test this battle still opens a ready chapter with its own save. A single-battle test returns directly to the editor after victory.

Use Copy in Open drafts to start a separate edition of a saved campaign. Use Remove to free its place in the library.

Check campaign lists the battles that need edits and flags seize tiles with no passable route from deployment. Select a chapter in the list to open its Battle workspace. You can still test a disconnected objective while you work on the map.

In Rules, Playtest setup lets you override the combat seed or choose a starting level of retry pressure. Enable Enemies prepare after resets to set the starting pressure. A saved draft remembers its selected chapter and setup when you save or start a playtest. Each setup opens its own playtest save. The campaign JSON carries the campaign rules while the local library remembers these playtest choices on this device.

## When the map becomes a battlefield

The reveal uses the same illustrated valley shown during campaign briefings. Deploying for the late route battle opens on the familiar chart from directly overhead. The camera tilts toward the war table as the grid spreads from the capital and the army pieces arrive. Click or press Tab to move directly to the tactical view. Drawn roads become cheap approaches, mountain passes use hill movement, marked crossings carry troops over otherwise blocked water, and the illustrated capital becomes the objective stronghold.

The route battle keeps the existing classes, weapons, forecasting, and rules switches. Allied sprites stand on octagonal counters and enemy sprites stand on hexagonal counters. Each piece represents a company led by a character. Miniature crossings, abbeys, forests, hills, and strongholds rise with the grid at reached sites. Their tiles come from the same chapter pins used on the route screen and the terrain card gives their names. The close-up shows the commanders and the terrain where their pieces met. The original score, “The Roads Between,” moves from Calm to Ablaze on the same playhead during each exchange. Earlier route screens hint at the grid with a faint cartographer’s scale.

The editor offers a Valley war table chapter template. Its terrain and markers use normalized coordinates on the same route illustration, so the route pin and the authored board align at different window sizes. In Poem, open Route at Crown Approach and choose Unroll the war table. That encounter brings the current company, formation, bonds, and trial state into a separate playtest save. Choose Save and return to route to leave it, then Resume the war table to pick up where you stopped. A new chronicle starts its own war table. In a new chronicle with section restarts enabled, a defeat on the war table rallies at the Valley and keeps permanent losses and enemy preparations.

To carry an earlier location into a war table battle, set its terrain in Route. Moving that chapter’s pin moves the terrain on each later table. The Battle grid marks inherited tiles and names them when inspected. If entries share a tile, the latest preceding chapter with assigned terrain takes priority. The table keeps the terrain painted under each inherited tile so the paint returns if the pin moves or the assignment is cleared. The seize objective keeps its painted terrain.

Choose a battle in the War-table overlay in Route to see its effective terrain and seize objective over the atlas. The readout follows the selected pin. Moving a pin or changing its inherited terrain updates the overlay as you edit.

Choose a later seize battle in the overlay and switch on Require this pin as a standard to make that location part of the victory condition. Its standard follows the pin when it moves. Deleting the linked chapter leaves a standard on its last tile.

Use Open atlas image in Route to use your own PNG or JPEG for a campaign. The picker accepts images up to 6 MB and 8 megapixels. Poem centers the image in a 3:2 crop, sizes it to 1,200 by 800 pixels, and stores it inside the campaign JSON. The route screen and war tables use the same picture. Place chapter pins and paint the table’s terrain against that picture.

Use Add blank war table in Route when you want to paint your own geography. It inserts a battle after the selected chapter and opens its 24 by 16 grid on the current atlas. The base grid starts with a stronghold objective and plain terrain. Earlier route pins still supply their assigned terrain.

## Game data and playtest

A campaign document contains its format and version, title, ordered chapters, roster settings, bonds, and defaults. Chapter entries carry the campaign fields for terrain, deployments, encounters, objectives, music, and scenery alongside their story scenes. The editor resolves stable recruit arrival and bond chapter keys to chapter indices when it makes a runtime copy. Removing a chapter moves those arrivals and conversations to the next surviving chapter, or the previous chapter if it was the finale. Each playtest runs against its own copy and saves independently of the normal campaign.

Verification covers draft import and export, chapter edits and arrival remapping, editor layout at narrow widths, a complete two-chapter playtest, and a turn on the valley grid. The world-map encounter must use the same image as the route view and enter its tactical and 3D combat paths through the normal controls.
