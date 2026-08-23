# Wizards Wager: Game Scope and Beta Direction

## Document purpose

This document defines the planned scope of Wizards Wager and provides a shared
direction for design, content, frontend, and backend work.

The project is currently a developer-only live alpha. The next major goal is a
publicly playable beta with a complete level 1-100 progression path, roughly 20
hours of gameplay, and the major faction-war systems working together.

This is a scope document rather than a final balance specification. Exact
numbers that have not yet been decided are listed under Open Design Decisions
instead of being silently assumed.

## High concept

Wizards Wager is a persistent side-scrolling MMO built around an endless war
between two factions:

- The Justice Knights kill those responsible for the death of their soldiers
  in the name of justice.
- The Avenger Knights retaliate for the death of their soldiers in the name of
  vengeance.

Because both factions treat retaliation as morally necessary, neither side can
end the cycle. Their kingdoms occupy opposite ends of a single long world, and
their armies collide continuously in the center.

The player begins outside this conflict, learns the game in the sewers, enters
the central battlefield as a neutral character, and chooses their initial path
through their actions. The result should feel like the faction conflict of
World of Warcraft combined with the accessible side-scrolling combat,
progression, and quest structure of MapleStory.

## Product pillars

### A living single-lane war

The main world is one seamless, server-authoritative simulation. NPC armies,
players, reinforcements, faction retaliation, resource conflicts, and other
world events continue to operate in real time.

The overall structure should feel like a large-scale, persistent, single-lane
strategy battle viewed and played as a side-scrolling action RPG.

### Action determines allegiance

Players do not choose a faction from a menu. A neutral player enters the
central war, attacks one side, and gains reputation with the opposing side.
Allegiance is earned through play and can later be changed through defection,
reputation repair, and the bounty system.

### Character and warband progression

The player grows from a basic warrior into a military leader. Character levels,
attributes, faction rank, and recruited soldiers all contribute to long-term
power.

### Player-driven territorial conflict

Players fight over useful resource areas. Holding territory requires living
defenders, forcing players to choose between bringing their strongest
followers with them and leaving soldiers behind to protect faction resources.

### A social world worth watching

The game supports up to 200 concurrent players in one world if server
performance allows it. Neutral towns, trading, open faction PvP, arena
competition, live spectatorship, and wagering create activity beyond questing
and grinding.

## Target beta

### Audience and environment

- Current state: developer-only live alpha.
- Target state: publicly playable beta.
- Initial world population target: 1-200 concurrent players.
- Scaling policy: increase the supported population only as far as the server
  simulation and networking remain stable.

### Required beta content

The beta is intended to include:

- a sewer tutorial;
- the seamless main world and its two kingdoms;
- a complete level 1-100 progression path;
- approximately 20 hours of character progression;
- approximately 20 questlines or progression chapters;
- Justice and Avenger allegiance paths;
- faction reputation, defection, and reputation repair;
- main-road, resource-area, and mob-area faction PvP;
- neutral towns;
- a central neutral hub town;
- a real-time one-versus-one arena lobby;
- shared enterable areas;
- kings and faction progression;
- follower recruitment and warbands;
- resource-node capture and defense;
- crafting;
- player trading;
- gold-based economic systems;
- betting on live arena matches;
- basic equipment and consumable purchases;
- fast travel;
- character and follower customization.

This is the full beta target. It should be implemented in playable milestones
so that unfinished systems do not prevent regular testing of the core loop.

## Player journey

### 1. Sewer tutorial

The player begins at level 1 in the sewers as a neutral character and simple
physical warrior.

The tutorial introduces:

- movement and platforming;
- targeting;
- basic attacks;
- health, stamina, and mana;
- zombies, skeletons, and goblins;
- experience and leveling;
- attribute-point assignment;
- death and restarting;
- leaving an enterable area for the persistent main world.

### 2. Central battlefield

The sewer exit places the player in the middle of the war between Justice and
Avenger Knights. Both factions are initially neutral toward the player and are
focused on fighting each other.

Neutral players may attack either faction. Killing a Knight:

- increases reputation with the opposing faction;
- decreases reputation with the defeated Knight's faction;
- contributes to the continuing retaliation cycle.

Stronger faction NPCs prevent a new player from safely advancing too far
toward either kingdom before earning sufficient levels and allegiance.

### 3. Initial allegiance

At +100 reputation with a faction, the player becomes allied with that faction
and unlocks the beginning of its main quest progression.

A guarding Knight directs the player to the faction commander. From that
point, quests rather than raw reputation become the primary progression gate.

### 4. Military progression

The player completes faction quests, gains levels, earns gold and reputation,
and advances through military ranks while moving from the center toward the
chosen faction's kingdom.

The rank structure is:

1. Newbie
2. Officer
3. General
4. Warlord

Each rank permits the player to recruit one additional NPC soldier, up to a
warband of four followers at Warlord rank.

### 5. The king

Faction progression eventually grants access to that faction's throne room and
king. The expected time to complete the core faction journey and reach the
king is approximately 10 hours, including required level grinding.

Reaching the king is a major progression milestone, not the end of the ongoing
world conflict.

### 6. Continuing play

After establishing a faction path, the player continues through:

- level progression toward level 100;
- faction warfare;
- resource capture and defense;
- follower leveling and customization;
- crafting and trading;
- arena participation and betting;
- PvP against enemy-faction players;
- defection or reputation repair;
- repeatable grinding and world events.

## World structure

### Main world

The main world is one seamless horizontal server simulation. Traveling from
one kingdom to the other should take approximately 5-10 minutes without fast
travel.

The minimum west-to-east structure is:

```text
Justice Throne Room
    -> Main Justice Town
    -> Justice Warfront Camp
    -> Central Battle Area and Sewer Exit
    -> Avenger Warfront Camp
    -> Main Avenger Town
    -> Avenger Throne Room
```

The map can use vertical space, including underground routes and above-ground
spaces, while preserving the readable left-to-right strategic structure.

### Enterable areas

Players select an entrance in the world to enter another area.

Enterable areas can be used for:

- quest hubs;
- resource nodes;
- concentrated monster spawns;
- crafting or gathering;
- the sewer;
- neutral towns;
- specialized encounters;
- future content types.

For the initial beta implementation, these are shared spaces with no designed
population limit. They are separate gameplay areas but are not private solo or
party copies.

### Fast travel

Players can unlock or access fast travel between selected locations. Fast
travel is a gold sink. Exact unlock conditions, destinations, prices, and
combat restrictions remain to be defined.

## Server-authoritative world

The server is authoritative for:

- player state and persistent progression;
- NPC physics and movement;
- NPC targeting and combat;
- damage, death, and respawning;
- faction relationships and reputation;
- reinforcement spawns;
- quest progress and rewards;
- PvP legality and outcomes;
- follower ownership and state;
- resource-node ownership and defenders;
- shared-area membership;
- trading and economic transactions;
- arena matches and betting outcomes.

The main world must remain consistent for all connected players. The client
provides responsive presentation and submits player intent, but it does not
decide authoritative combat or ownership outcomes.

## Factions, reputation, and retaliation

### Initial state

New players are neutral to both Justice and Avenger factions.

Both factions are:

- hostile toward each other;
- initially neutral toward the player;
- attackable by a neutral player in the central battle.

### Reputation

The first major threshold is:

- +100 reputation: allied status and access to the faction's main questline.

After +100, quest progression is the core gate. Additional reputation is still
awarded but should support the quest and rank structure rather than replace it.

The currently required relationship states are:

- neutral;
- friendly;
- allied;
- hostile.

Additional named reputation tiers should not be added until they have a
specific gameplay purpose.

### Defection and recovery

Faction choice is not permanent. Players can:

- defect from their current faction;
- become neutral again;
- repair damaged reputation;
- pay off a bounty through an NPC in the sewers.

The exact costs, cooldowns, quest consequences, follower consequences, and
territorial consequences of defection remain to be specified.

### Retaliation and reinforcements

Faction NPC deaths influence live server events. When players kill a faction's
NPCs, that faction's king can send Knights to retaliate against the responsible
players or other members of their faction.

This creates the fiction and mechanics of an endless war while allowing a
delay between major reinforcement waves. Reinforcement size, targeting,
cooldowns, and escalation rules remain to be balanced.

## PvE and quests

### Quest structure

The beta needs a level 1-100 progression path lasting approximately 20 hours.
The working content target is at least 20 questlines or progression chapters.

At an average, this implies:

- roughly one hour of intended play per questline;
- roughly five character levels per questline;
- a mixture of directed quest completion and level grinding.

These are planning averages rather than requirements for every individual
quest.

The initial quest vocabulary includes:

- travel to a location;
- kill a target number of enemies;
- collect a target number of drops;
- speak to a commander, guard, king, or other NPC;
- participate in a faction battle;
- capture or defend a resource area;
- reach a required level or military rank.

### Quest rewards

Initial quest rewards are:

- experience;
- gold;
- faction reputation.

Equipment rewards and class-specific rewards can expand after the initial
warrior combat and progression systems are stable.

### Faction paths

Justice and Avenger players progress in opposite directions from the central
battlefield. Both paths should have comparable:

- progression time;
- experience and gold rewards;
- access to gameplay systems;
- difficulty;
- rank advancement;
- resource opportunities.

The factions can use mirrored mechanical structures while retaining distinct
characters, writing, locations, and motivations.

## Character progression

### Level progression

- Starting level: 1.
- Level cap: 100.
- Target time to level 100: approximately 20 hours.
- Experience required for the next level: current level multiplied by 10.
- Each level grants five attribute points.
- Every attribute has a minimum value of 1.
- Unspent points cannot fall below the amount earned through leveling.

The level curve and reward values must be tested together. The formula above
defines the current implementation, but enemy and quest XP must be tuned to
produce the 20-hour target.

### Initial combat identity

All players begin as simple physical warriors using straightforward attacks.
Classes, spells, and more specialized builds should be designed after the
basic warrior, PvE, PvP, and server-authoritative combat are stable.

### Attributes

#### Strength

- Basic physical damage equals Strength.
- Critical-hit damage equals two times Strength.

#### Agility

- Walk speed: `200 + (2 x Agility)`.
- Sprint speed: `320 + (2 x Agility)`.
- Jump velocity: `-400 - (8 x Agility)`.
- Stamina drain: `max(2, 12 - (0.5 x Agility))`.

#### Intelligence

- Maximum mana: `100 + (15 x Intelligence)`.
- Magic power: `1 + Intelligence`.
- A power-up adds bonus damage equal to Intelligence.

#### Luck

- Critical chance: `1% + (1% x Luck)`.
- Luck 1 produces a 2% critical chance.
- Luck 10 produces an 11% critical chance.
- Critical chance is capped at 75%.

#### Endurance

- Maximum health: `100 + (10 x Endurance)`.
- Maximum stamina: `100 + (5 x Endurance)`.

### Combat resource rules

- A basic attack costs 20 stamina.
- Basic attacks have a 0.5-second cooldown.
- Stamina regenerates at 20 points per second up to its maximum.
- A power-up costs 20 mana.
- A power-up lasts 10 seconds.

## Death and meta-progression

The intended direction is permadeath:

- the character dies permanently;
- the player returns to the initial spawn point;
- gold is retained as account-level meta-progression.

The precise reset still needs to be defined. In particular, the design must
state whether death resets level, attributes, faction reputation, quests,
rank, followers, inventory, crafting progress, fast-travel unlocks, and
resource ownership.

Until those rules are decided, permadeath should be treated as a design pillar
requiring validation rather than a fully specified implementation.

## Player-versus-player rules

Players can attack members of the opposing faction in:

- the main road;
- resource areas;
- monster spawn areas.

Neutral towns are safe areas unless a future rule explicitly says otherwise.

The central neutral hub includes a real-time one-versus-one arena lobby where
players can:

- register to fight;
- watch live matches;
- wager gold on the outcome.

The server must control matchmaking state, match boundaries, combat results,
disconnect handling, wager locking, payouts, and fraud prevention.

Rules for neutral players, friendly fire, parties, level differences, spawn
protection, kill rewards, repeated kills, and combat logging remain to be
specified.

## Followers and warbands

### Capacity

Players unlock one follower slot per military rank:

| Rank | Maximum followers |
|---|---:|
| Newbie | 1 |
| Officer | 2 |
| General | 3 |
| Warlord | 4 |

### Recruitment

The player can recruit a spawned soldier belonging to their faction. Exact
eligibility, recruitment cost, availability, and protection against removing
essential world defenders remain to be defined.

### Identity and growth

Recruited soldiers:

- follow and fight for the player;
- gain levels;
- can die;
- can be nicknamed;
- can have their sprite customized similarly to the player;
- can be assigned to defend resource nodes.

The long-term fantasy is for each player to command a small customized warband
against enemy players and their warbands.

### Commands

The planned minimum command set is:

- follow the player;
- stay or defend a position;
- attack the player's selected target;
- become hostile toward a selected enemy or enemy type.

Follower AI and combat remain server-authoritative.

## Resource nodes and territorial control

Resource areas are entered from the main world and can be controlled by either
faction.

The initial capture loop is:

1. Attack the enemy-controlled resource area.
2. Defeat its current defenders.
3. Claim the resource node for the attacking faction.
4. Assign at least one recruited follower as its defender.
5. Improve the node's NPC protection by spending gold.
6. Defend it against future enemy attacks.

A node cannot be considered securely held without at least one assigned
follower. This creates a direct tradeoff: every soldier left behind to protect
territory is unavailable to the player's active warband.

Node control is intended to persist while players are offline, but the exact
ownership duration, production cycle, notification system, minimum defense,
capture time, rewards, and undefended-node behavior remain to be defined.

## Economy

### Primary currency

Gold is the primary currency. It is earned from quests and may also be earned
through combat, trading, resource control, crafting, arena activity, or other
server-authoritative rewards.

Gold persists through character death and therefore provides the main form of
account-level meta-progression.

### Planned gold sinks

- potions;
- equipment;
- fast travel;
- soldier recruitment;
- soldier revival;
- improved NPC defenders at resource nodes;
- cosmetics;
- crafting and trading costs;
- arena betting.

Because gold survives permadeath, sinks and faucets must be balanced to prevent
older accounts from permanently overwhelming new characters.

### Trading and crafting

Trading and crafting are required beta systems, but their item model, recipes,
resources, restrictions, interfaces, and economic safeguards have not yet
been defined.

## Current alpha foundation

The current project already contains or represents:

- account login and persistent player identity;
- multiplayer presence and remote-player presentation;
- a Forest world;
- player movement, sprinting, jumping, and platforming;
- server-authoritative enemy presentation;
- zombies, goblins, and skeletons;
- Justice and Avenger Knights;
- Knight-versus-Knight combat;
- targeting and target cycling;
- basic attacks and power-ups;
- health, stamina, mana, damage, death, and respawning;
- experience, levels, stat points, and the five attributes;
- faction reputation state and the +100 commitment threshold;
- gold and betting-related systems;
- chat, profiles, friends, achievements, and leaderboards;
- map-authoring support for surfaces, spawns, factions, behaviors, quests, and
  quest givers;
- an authored example quest involving zombies, goblins, and skeletons.

Not all authored or frontend-supported features are necessarily complete on
the deployed backend. Backend behavior must be verified separately.

## Major beta work remaining

### Content and world

- Build the sewer tutorial.
- Establish the complete kingdom-to-kingdom world layout.
- Add both towns, both warfront camps, both throne rooms, and the neutral hub.
- Build and connect shared enterable areas.
- Create the level 1-100 content matrix.
- Author and implement approximately 20 questlines.
- Add commanders, guards, kings, merchants, crafting NPCs, and bounty services.

### Faction systems

- Permit neutral attacks against Knights where intended.
- Complete reputation gains and losses.
- Implement allegiance, defection, neutrality recovery, and bounty payment.
- Implement king-triggered retaliation and reinforcement waves.
- Gate locations, quests, ranks, and NPC reactions by faction state.

### Combat and PvP

- Define and implement PvP legality by area.
- Add safe towns and spawn protection.
- Balance levels and attributes for PvE and PvP.
- Build the one-versus-one arena and spectator flow.
- Connect betting to authoritative live arena outcomes.

### Followers and territory

- Implement rank-based follower capacity.
- Recruit world soldiers.
- Persist follower identity, appearance, level, and state.
- Implement follower commands and server AI.
- Implement follower death and revival.
- Implement resource-node capture, ownership, defense, upgrades, and rewards.

### Economy and items

- Define the item and inventory model.
- Add potion and equipment purchases.
- Implement crafting.
- Implement safe player-to-player trading.
- Balance gold income, sinks, betting, and permadeath retention.

### Technical validation

- Load-test the seamless server world.
- Establish a supported player count before promising 200 players.
- Measure server physics and NPC costs at representative populations.
- Validate persistence across disconnects and deployments.
- Add abuse protection for combat, trading, betting, and resource ownership.

## Recommended implementation milestones

These milestones are delivery order, not cuts from the beta target.

### Milestone 1: Complete the new-player loop

- Sewer tutorial.
- Level 1 enemies and initial quests.
- Exit into the central battlefield.
- Neutral Knight attacks.
- Reputation gain and loss.
- +100 allegiance.
- Guard-to-commander quest handoff.

Success means a fresh player can learn the game, make an initial faction
choice through combat, and begin a persistent faction questline.

### Milestone 2: One complete faction slice

- One warfront camp.
- One main town.
- One throne room and king.
- Level and quest progression along one faction path.
- Rank progression.
- Basic merchants, gold sinks, and fast travel.

Success means one faction offers a complete center-to-king journey before the
content structure is mirrored and differentiated for the other faction.

### Milestone 3: Opposing faction and PvP

- Equivalent progression for the second faction.
- PvP areas and safe areas.
- Spawn protection and anti-abuse rules.
- Faction retaliation and reinforcement events.
- Defection and bounty recovery.

Success means the two-sided war works for real players without trapping or
griefing new characters.

### Milestone 4: Followers and resource warfare

- Four military ranks.
- Recruitable, persistent, customizable followers.
- Follower targeting and defense commands.
- Capturable resource areas.
- Offline defenders and gold-funded protection.
- Follower death and revival.

Success means players can form warbands and make meaningful choices between
active strength and territorial defense.

### Milestone 5: Economy and social competition

- Item and inventory model.
- Crafting.
- Player trading.
- Arena registration and live matches.
- Spectating and authoritative betting.
- Finalized gold faucets and sinks.

Success means gold connects questing, warbands, territory, commerce, and
spectator competition.

### Milestone 6: Level 1-100 beta completion

- Approximately 20 questlines or progression chapters.
- Approximately 20 hours of tested progression.
- Content and reward parity between both faction paths.
- Complete map and travel network.
- Population and server-load validation.
- Economy, PvP, and progression balance passes.
- New-player, death, recovery, and endgame usability passes.

Success means the intended beta can be played from a new character through
level 100 with all required headline systems available.

## Beta acceptance criteria

The beta scope is complete when:

1. A new player can complete the sewer tutorial without developer assistance.
2. The player can enter the central battlefield and choose either initial
   allegiance through combat.
3. Both factions provide viable progression from the center to their king.
4. A player can progress from level 1 to 100 in approximately 20 hours.
5. At least 20 questlines or equivalent progression chapters are playable.
6. The main world operates as one consistent server-authoritative simulation.
7. Players can enter and leave shared secondary areas.
8. Enemy-faction PvP works in allowed areas and is prevented in safe towns.
9. Military ranks unlock up to four persistent recruited followers.
10. Followers can fight, level, die, be customized, and defend a resource node.
11. Either faction can capture, reinforce, lose, and recapture a resource node.
12. Gold can be earned, retained through death, and spent on multiple useful
    systems.
13. Crafting and secure player trading are functional.
14. Players can join, watch, and bet on authoritative one-versus-one matches.
15. Defection, reputation recovery, and bounty payment prevent faction choice
    from becoming an irreversible account trap.
16. The supported concurrent-player target is established through load testing
    and communicated accurately.

## Scope guardrails

The following should not block the beta unless later promoted into scope:

- multiple player classes;
- complex spell trees;
- raids;
- guild systems;
- private housing;
- multiple seamless worlds;
- private dungeon copies;
- large equipment-rarity systems;
- faction-specific mechanical advantages;
- more reputation tiers without explicit rewards;
- features that do not support progression, war, territory, economy, or social
  competition.

The initial warrior must be stable before classes are added.

## Open design decisions

The following questions must be answered during specification work:

1. Does "approximately 20 questlines" mean 20 total structures with faction
   variants, or 20 unique questlines per faction?
2. Exactly what character progress is erased by permadeath?
3. What account-level state survives death besides gold?
4. How is a character distinguished from an account in the current login and
   persistence model?
5. What are the rules, costs, cooldowns, and consequences of defection?
6. What behavior distinguishes friendly NPCs from allied NPCs?
7. What are the four rank unlock requirements?
8. Can any spawned soldier be recruited, or only designated recruitable
   soldiers?
9. What happens to a follower when its owner disconnects?
10. Can followers be permanently lost, and how does paid revival interact with
    permanent follower death?
11. What happens to followers, ranks, and defended nodes when a player defects?
12. How long does capturing a resource node take?
13. What resource does each node produce, and who receives it?
14. What happens when a node has no assigned player follower?
15. How are offline attacks and defense notifications handled?
16. What prevents one faction or veteran account from permanently controlling
    all resource nodes?
17. What items exist in the beta, and how are inventory limits handled?
18. What is the smallest complete crafting recipe and resource loop?
19. What trading restrictions prevent duplication, fraud, and transfers during
    permadeath?
20. Can neutral players participate in open PvP, and how are parties containing
    mixed allegiances handled?
21. What prevents high-level players from repeatedly killing new players?
22. What are arena matchmaking, disconnect, draw, and wager-refund rules?
23. Which fast-travel locations exist, and how are they unlocked?
24. How frequently and strongly do kings send retaliation forces?
25. What measured server conditions determine the final supported player cap?

