# Backend Engineer Prompt 1: Authoritative New-Player and Faction Progression

You are working on the authoritative backend for Wizards Wager. Read
`WIZARDS_WAGER_GAME_SCOPE.md`,
`BACKEND_MILESTONE_1_CLARIFICATIONS.md`, and the frontend's existing backend
request and map-definition documents, then inspect the current backend
implementation before editing. The clarification document is the controlling
contract wherever the earlier prompt left a choice unresolved.

Do not stop at a proposal or schema design. Implement, migrate, test, and
document the complete backend portion of the first playable progression slice:

> A new player begins in the sewer, completes an authoritative tutorial quest
> chain against Zombies, Goblins, and Skeletons, exits into the central
> battlefield, attacks either initially neutral Knight faction, earns opposing
> faction reputation, reaches +100, and completes the chosen faction's
> guard-to-commander handoff.

The backend must remain authoritative for maps, transitions, combat legality,
kills, quest state, experience, rewards, faction reputation, allegiance, and
persistence.

## Deliver the milestone in four large steps

### 1. Make authored maps, shared areas, NPCs, and quests authoritative

Finish the backend path that validates, stores, activates, and serves published
map definitions. It must support the existing authored concepts required by
this slice:

- maps and shared secondary areas;
- physics surfaces and spawn areas;
- combatant archetypes and behavior profiles;
- faction declarations and directed relationships;
- quest definitions and ordered stages;
- quest givers and their positions;
- stable entrance/exit definitions or an equivalent stable transition model.

Add the sewer and central-war content through data/bootstrap/migrations rather
than one-off runtime constants. Reject invalid definitions and broken
references before activation. Publishing or repairing definitions must be
idempotent and must not create duplicate live spawns, quests, NPCs, or
transitions.

New characters must spawn in the sewer. Existing characters must retain a
valid saved location or be moved to a documented safe fallback only when their
saved location is invalid.

Implement authenticated, server-approved transitions between the sewer and the
central battlefield. Validate the entrance, origin area, destination,
proximity, player state, and request idempotency. Publish the authoritative
destination and position so all affected presence/world subscriptions remain
consistent.

### 2. Complete the persistent quest engine needed for the full game

Implement a reusable authoritative quest system driven by authored quest data,
not special cases for this tutorial.

It must support:

- quest availability and prerequisite evaluation;
- accept, decline/no-op, abandon where allowed, status, and completion;
- ordered multi-stage quests;
- kill objectives by authoritative archetype ID;
- travel/enter-area objectives;
- talk/interact objectives by stable NPC ID;
- reward bundles containing experience, gold, and faction reputation;
- quest and stage gating by level, faction relationship, allegiance, and prior
  quest completion;
- persistent progress across death, reconnect, relog, and deployment;
- idempotent command and event processing.

Only confirmed server events may advance objectives. NPC deaths caused only by
NPCs must not count as player kills. Define and test the contribution rule if
multiple players damage the same target; do not let clients declare kills,
drops, objective progress, or completion.

Provide authoritative quest-state snapshots on login/world join and focused
events for offers, acceptance, objective progress, stage advancement,
completion, rejection, and rewards. Every event must include stable quest and
stage IDs and enough absolute state for a reconnecting client to recover
without replaying the entire history.

Use this engine to register and run:

- a concise sewer tutorial chain involving Zombies, Goblins, and Skeletons;
- a sewer-exit/travel objective;
- a Justice guard-to-commander handoff;
- an Avenger guard-to-commander handoff.

### 3. Implement the initial faction choice as authoritative gameplay

Resolve the current contract conflict in favor of the scope document: Justice
and Avenger Knights are initially neutral toward a new player but may be
attacked by that player in the designated central battlefield.

Do not globally redefine all neutral NPCs as attackable. Combat legality must
consider the player's state, target faction, map/area, and authored rules.

For a server-confirmed player kill of a central-battle Knight:

- killing a Justice Knight increases Avenger reputation;
- killing a Justice Knight decreases Justice reputation;
- killing an Avenger Knight increases Justice reputation;
- killing an Avenger Knight decreases Avenger reputation;
- the same kill can affect reputation only once;
- the player receives an absolute faction-state update.

Store reputation deltas in configurable data. Repeated requests, duplicate
death events, reconnects, and concurrent processing must never duplicate
rewards.

At +100 reputation with Justice or Avenger:

- establish the player's current allied faction;
- update directed NPC/player combat relationships;
- make only the chosen faction's starting guard quest available;
- prevent accepting the rival starting quest unless the player later completes
  the not-yet-implemented defection flow;
- preserve the opposing faction's appropriate hostile or non-allied state;
- persist and publish the complete faction state.

Do not implement full defection, bounty payment, or permanent faction lock in
this milestone. Model allegiance data so those later systems can be added
without destructive migration.

Keep Knight-versus-Knight targeting, server physics, attacks, death, and
respawning operational. A player initiating legal combat may cause appropriate
local retaliation, but do not introduce the later king reinforcement system in
this milestone unless it already exists and can be preserved safely.

### 4. Integrate, load-test the slice, and prove recovery behavior

Publish a concise checked-in client contract covering commands, snapshots,
events, identifiers, error codes, idempotency keys, and example payloads.
Extend the existing realtime/world protocol rather than building a separate
quest connection.

Add automated integration coverage for at least:

- new-player sewer spawn;
- map-definition validation and idempotent activation;
- no duplicate authored combatants after restart or republish;
- valid and invalid area transitions;
- accepting, progressing, completing, and restoring quests;
- authoritative Zombie, Goblin, and Skeleton kill credit;
- prevention of duplicate quest and reward credit;
- neutral-player attacks rejected outside allowed rules;
- neutral-player attacks accepted against both Knight factions in the central
  battle;
- correct positive and negative reputation for each Knight type;
- exactly-once reputation changes under duplicate/concurrent events;
- +100 allegiance and correct guard quest availability;
- rejection of the rival guard quest;
- both guard-to-commander talk objectives;
- reconnect and relog recovery at every major stage;
- multiplayer players progressing independently in the same shared area;
- no regression in current player combat, NPC combat, stats, death, respawn,
  world snapshots, chat-adjacent world presence, or existing enemies.

Exercise the shared sewer and central battle with representative concurrent
players and authoritative NPCs. This is not the final 200-player certification,
but obvious per-player polling, duplicate simulation, unbounded event growth,
or database contention must be corrected now.

## Engineering constraints

- Inspect the actual backend and migrations before changing them.
- Preserve unrelated work and existing production data.
- Use transactions, uniqueness constraints, and idempotency rather than
  process-local flags for exactly-once persistence.
- Store balance values and content relationships in data where practical.
- Never trust client-reported position, kill, reward, quest completion, faction
  standing, or map membership.
- Keep the main world and shared areas compatible with one server-authoritative
  simulation.
- Do not implement the undefined full permadeath reset. Retain the current
  death/respawn contract for this milestone and document that temporary choice.
- Do not add classes, complex inventory, resource nodes, followers, crafting,
  trading, arena betting, or king retaliation as part of this prompt.
- Prefer a complete vertical slice over disconnected schema and endpoint work.

## Completion report

When finished, report:

- migrations and authoritative systems implemented;
- authored/bootstrap content registered;
- the final client contract with example payloads;
- automated and load tests run with results;
- how idempotency and reconnect recovery were verified;
- deployment or configuration actions required;
- any scope requirement not completed and the exact blocker.
