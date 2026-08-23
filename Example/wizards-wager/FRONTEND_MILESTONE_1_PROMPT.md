# Frontend Engineer Prompt 1: Complete the New-Player-to-Faction Loop

You are working on the Godot frontend for Wizards Wager. Read
`WIZARDS_WAGER_GAME_SCOPE.md` and
`BACKEND_MILESTONE_1_CLARIFICATIONS.md` first, then inspect the existing project
and reuse its current movement, combat, targeting, stat, faction,
map-authoring, and server-authoritative entity systems. Use the stable IDs and
shared contracts in the clarification document.

Do not stop at a design or implementation plan. Build and verify the complete
frontend portion of the first playable progression slice:

> A new player starts in the sewer, learns the core game through quests and
> combat, enters the center of the persistent faction war, attacks either
> Knight faction to earn standing with its rival, reaches +100 reputation, and
> receives the guard-to-commander handoff that begins the chosen faction's main
> questline.

Keep authoritative progression on the backend. The frontend should submit
intent, render authoritative results, and remain safe when messages are
duplicated, delayed, missing, or received after reconnecting.

## Deliver the milestone in four large steps

### 1. Build the complete sewer tutorial experience

Create a playable sewer starting area using the existing map-authoring system.
It may be a shared secondary area rather than a private instance. Give it a
clear entrance/exit connection to the center of the Forest/main-war map.

Author enough geometry, spawn areas, NPCs, and quest data to teach the player
through play:

- movement, jumping, and platforming;
- selecting and cycling targets;
- basic attacks;
- health, stamina, and mana;
- killing Zombies, Goblins, and Skeletons;
- gaining experience and levels;
- spending attribute points;
- recovering from death;
- completing objectives and leaving an enterable area.

Use a short quest chain rather than tutorial popups alone. Keep text concise
and use existing enemy types and mechanics. A player should always understand
their next action, current progress, reward, and where to go.

Add a clear world interaction for selecting an entrance or exit. The client
must request a transition and wait for backend approval before committing the
player to the destination map/area. Handle rejection, loading, reconnect, and
duplicate transition messages without trapping or duplicating the player.

### 2. Add a reusable quest and interaction presentation

Implement the minimum reusable UI needed for the entire level 1-100 quest path,
not a sewer-only hard-coded screen:

- nearby-NPC interaction;
- quest offer with title, description, objectives, and rewards;
- accept and decline;
- active quest display;
- objective progress updates;
- stage completion and next-stage presentation;
- quest completion and reward summary;
- locked quest explanation;
- interaction markers for available, active, and completable quests.

Drive all quest state from stable quest, stage, NPC, map, and faction
identifiers supplied by authored data and authoritative server messages.
Do not infer quest completion from local enemy death animations.

The UI must scale down cleanly, avoid covering core combat information, support
keyboard/mouse and the project's existing controller navigation, and coexist
with chat, player status, targeting, and faction reputation displays.

Restore the correct quest log, objective progress, map/area, and NPC state
after reconnecting.

### 3. Make the central faction choice fully playable and understandable

Place the sewer exit at the central Justice-versus-Avenger battlefield.
Preserve the existing server-authored Knight simulation.

Present both Knight factions as neutral but attackable for a new player. The
target display must clearly distinguish:

- faction identity;
- current relationship to the player;
- whether an attack is currently legal;
- the reputation consequences of helping or harming that faction.

When the backend confirms a Knight kill and reputation change, immediately
show both the gain with the opposing faction and the loss with the defeated
faction. Keep the existing +100 reputation progress visible and understandable.
Do not award or predict reputation locally.

At +100 reputation:

- present the newly allied faction clearly;
- update Knight relationship presentation;
- expose only that faction's starting guard quest;
- direct the player from the guard to the faction commander;
- complete a short commander interaction that visibly begins the main faction
  campaign.

Author equivalent guard and commander handoffs for Justice and Avenger paths.
They may share underlying quest structure but must use distinct stable IDs and
directional objectives.

### 4. Integrate, verify, and leave the slice production-ready

Coordinate the frontend/backend contract through a checked-in contract or
handoff document. Prefer extending the existing world event and map-authoring
patterns over creating a parallel transport or state system.

Verify at minimum:

- a brand-new player begins in the sewer;
- the tutorial can be completed without developer knowledge;
- quest stages advance only after authoritative confirmation;
- death, reconnect, and relog preserve or restore the correct state;
- the sewer exit reaches the central battlefield;
- both Justice and Avenger Knights are targetable when the server permits it;
- confirmed Knight kills update both faction standings;
- either faction can reach +100 and unlock only its proper guard;
- the guard-to-commander handoff completes for both paths;
- existing movement, combat, stats, chat, targeting, remote players, ordinary
  enemies, and Knight-versus-Knight combat continue to work.

Run the project's available validation, open the game where possible, and
visually inspect the new flow at common window sizes. Fix errors and obvious
layout or usability problems instead of only reporting them.

## Engineering constraints

- Inspect the current repository before editing and preserve unrelated work.
- Reuse the existing Forest, map-authoring resources, quest resources, UI
  conventions, and authoritative mob rendering.
- Do not put authoritative quest, reputation, combat, transition, or reward
  decisions in the client.
- Do not implement the still-undefined full permadeath reset. Preserve the
  current death/recovery behavior unless the backend contract explicitly
  supplies a temporary milestone rule.
- Do not add classes, spell trees, inventory complexity, private instances, or
  later-milestone systems.
- Do not replace stable authored IDs with node paths or display strings.
- Avoid a prototype that works only in a fixed order. The quest and interaction
  presentation must support later questlines without new UI code.

## Completion report

When finished, report:

- the full playable flow implemented;
- authored maps, NPCs, and quests added;
- the final frontend/backend contract;
- tests and manual flows performed;
- any backend dependency that remains;
- any scope requirement not completed and the exact blocker.
