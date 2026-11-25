# Campaign editor

Poem campaigns are ordered sets of battles, recruit arrivals, section checkpoints, and story scenes. The editor opens a copy of Poem or a new campaign and stores the draft in the local authoring library. The same versioned document can be exported as JSON and opened in either build.

## Authoring

The chapter list shows play order and section starts. Authors can insert, duplicate, move, and remove chapters. A stable chapter key links its recruit arrivals, story scenes, and route pin, so reordering a battle moves its associated material with it. The first chapter always starts a section.

The map workspace combines a terrain brush with controls for deployment tiles, enemy placements, hard-mode reinforcements, and the objective. Authors can resize a board and choose its battlefield environment and score. The Encounters workspace assigns the commander, chapter-wide enemy levels, individual level overrides, classes, strategies, and compatible equipment. Set an enemy’s arrival turn and phase to bring them in as reinforcements. Arrivals use the nearest open passable tile if the marked tile is occupied. The editor identifies blocked tiles, overlapping placements, and missing objective markers before playtest. The runtime uses its regular tactical rules and two-stage combat presentation.

The story workspace edits the chapter name, location, briefing, opening, and closing. Authors can also place dialogue at the start of a chosen player or enemy phase. An unfinished scene resumes when its battle is loaded. Dialogue lines use the campaign roster and portrait catalogue. The company workspace edits recruit names, introductions, classes, base stats, arrivals, epilogues, and initial deployment. Add up to sixteen recruits with their own identities and a catalogue appearance. Use the recruit ID shown in the picker when you write their dialogue. The Bonds workspace pairs recruits, sets the chapter and points required for each rank, and edits its conversations and shared epilogue. The company earns those points in battle and reads the scenes at camp. Campaign settings record the draft’s default experiment switches.

The chapter picker and editing controls sit above the Battle, Encounters, Story, Company, Bonds, and Rules workspaces. Save draft keeps a local copy. Transfer JSON copies a draft for sharing and accepts a pasted document. Playtest can start at the first war council or the selected chapter. It uses its own save path and returns to the same draft and selected chapter.

## When the map becomes a battlefield

The reveal uses the same illustrated valley shown during campaign briefings. Deploying for the late route battle opens on the familiar chart from directly overhead. The camera tilts toward the war table as the grid spreads from the capital and the army pieces arrive. Click or press Tab to move directly to the tactical view. Drawn roads become cheap approaches, mountain passes use hill movement, marked crossings carry troops over otherwise blocked water, and the illustrated capital becomes the objective stronghold.

The route battle keeps the existing classes, weapons, forecasting, and rules switches. On the board the pieces stand for companies led by Poem’s characters. The terrain card names places the campaign has already visited. Their tiles come from the same chapter pins used on the route screen. The close-up shows the commanders and the local terrain where their pieces met. The original score, “The Roads Between,” moves from Calm to Ablaze on the same playhead during each exchange. Earlier route screens hint at the grid with a faint cartographer’s scale.

The editor offers a Valley war table chapter template. Its terrain and markers use normalized coordinates on the same route illustration, so the route pin and the authored board align at different window sizes. Poem’s own first route battle belongs late in the campaign, when the company can recognize the locations from earlier chapters.

## Game data and playtest

A campaign document contains its format and version, title, ordered chapters, roster settings, bonds, and defaults. Chapter entries carry the campaign fields for terrain, deployments, encounters, objectives, music, and scenery alongside their story scenes. The editor resolves stable recruit arrival and bond chapter keys to chapter indices when it makes a runtime copy. Removing a chapter moves those arrivals and conversations to the next surviving chapter, or the previous chapter if it was the finale. Each playtest runs against its own copy and saves independently of the normal campaign.

Verification covers draft import and export, chapter edits and arrival remapping, editor layout at narrow widths, a complete two-chapter playtest, and a turn on the valley grid. The world-map encounter must use the same image as the route view and enter its tactical and 3D combat paths through the normal controls.
