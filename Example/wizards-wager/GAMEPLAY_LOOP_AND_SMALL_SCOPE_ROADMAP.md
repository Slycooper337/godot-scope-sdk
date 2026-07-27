# Wizards Wager: Current Gameplay Loop and Small-Scope Roadmap

## Product summary

Wizards Wager is currently a compact online action RPG built around one
server-authoritative world. The player explores the Forest, fights enemies,
levels a persistent character, watches or influences an ongoing Knight battle,
and participates in a gold betting economy. Realtime players, chat, profiles,
leaderboards, achievements, and character customization provide the social
wrapper around that core.

The strongest identity already present is:

> Enter a living battlefield, fight alongside or against its factions, grow a
> persistent wizard, and wager on how the conflict will unfold.

Future work should make that fantasy clearer and more rewarding rather than
adding unrelated systems.

## Current gameplay loop

### 1. Enter the world

After login, the game restores the player's saved position, appearance, level,
stats, and resources. It connects to realtime services, joins the Forest, loads
the current world snapshot, and displays other online players and authoritative
enemies.

The Forest contains ordinary enemies such as Zombies, Goblins, and Skeletons,
plus server-controlled Justice and Avenger Knights participating in a perpetual
faction battle.

### 2. Traverse and choose a target

The player can:

- walk, sprint, jump, and drop through platforms;
- click an entity to target it;
- cycle visible targets with Tab or controller shoulder buttons;
- inspect the target's health and target marker;
- observe remote players and the Knight battle.

Movement is responsive locally and synchronized to other clients. Enemy and
Knight movement is server-authored and interpolated by the client.

### 3. Manage combat resources

Combat is built around three resources:

- **Health** determines survival.
- **Stamina** pays for attacks, jumping, and sprinting, then regenerates.
- **Mana** pays for the power-up and regenerates over time.

This creates a light decision loop: spend stamina on mobility or offense, and
decide when a mana-powered attack is worth using.

### 4. Fight

The player currently has two offensive modes:

- **Basic attack:** a short-range physical strike that normally damages one
  target.
- **Power-up:** costs mana, lasts for a limited duration, and lets a basic swing
  hit multiple valid enemies.

The client submits attack intent, while the server owns validation, damage,
critical hits, knockback, death, experience, cooldowns, and duplicate
protection. This keeps combat results consistent across players.

### 5. Resolve victory or defeat

When an enemy dies, the server awards progression and eventually replaces
world populations through the authoritative spawn lifecycle. Knight deaths can
also affect faction reputation and the player's eventual faction commitment.

When the player dies, the death presentation completes before the server-backed
revive restores the character to play.

### 6. Grow the character

Combat awards experience. Levels grant stat points that can be assigned to:

- **Strength:** physical damage;
- **Agility:** movement, jumping, attack speed, and sprint efficiency;
- **Intelligence:** mana capacity and magic power;
- **Luck:** critical-hit chance;
- **Endurance:** health, stamina, and stamina regeneration.

Progress is persistent and server-authoritative. This is the main long-term
advancement loop.

### 7. Participate in the faction conflict

Justice and Avenger Knights fight continuously under server AI. Faction
reputation records how the player's actions support one side, and reaching the
configured threshold can lock in a faction commitment.

This system is already the best bridge between moment-to-moment combat and a
larger world narrative, but the player's immediate goal and impact need to be
more visible during play.

### 8. Use the surrounding online systems

Outside direct combat, the player can:

- place a gold wager and review betting history;
- view leaderboard rank and achievements;
- chat locally and see speech bubbles;
- inspect online players, profiles, and status;
- send friend requests and messages;
- upload a custom character sprite.

These systems support retention and identity, but most currently operate beside
the combat loop rather than feeding back into it.

## Loop at a glance

```text
Enter Forest
    ↓
Find or observe a fight
    ↓
Choose target and manage stamina/mana
    ↓
Attack → server resolves damage/death
    ↓
Gain XP, faction reputation, and/or gold progress
    ↓
Spend stat points and make a faction/betting decision
    ↓
Return to the battlefield with slightly greater power or purpose
```

## What is working

### Clear mechanical foundation

Movement, targeting, basic attacks, resource costs, power-up combat, damage,
death, and respawn form a complete playable foundation.

### A world that moves without the player

The Knight conflict makes the map feel active. Because the simulation is
server-authoritative, it can continue to support spectators, multiple players,
dynamic relationships, and future cooperative behavior.

### Persistent reasons to return

Levels, stats, faction standing, gold, betting, achievements, leaderboard
position, social connections, and character appearance all provide forms of
continuity.

### Extensible data path

Enemy types, Knight archetypes, spawn groups, faction relationships, and much
of combat already flow through server data. New variations can reuse the
existing world and protocol rather than requiring new client systems.

## Current weaknesses

### The immediate objective is unclear

The player can fight, but the game does not consistently answer:

- What should I do in the next three minutes?
- Why should I fight this enemy instead of another?
- What changed because I won?

### Rewards are fragmented

Experience, faction reputation, gold betting, achievements, and leaderboard
rank exist, but they do not yet feel like one connected reward chain.

### The faction battle is more visible than meaningful

The Knights create spectacle, but the current presentation does not clearly
show the battle's score, current momentum, next resolution, or the player's
contribution.

### Character growth risks becoming invisible

Five stats change useful values, but most upgrades are numerical. Without
milestones or visible feedback, another stat point can feel weaker than it
actually is.

### The feature surface is already broad

The project has combat, RPG progression, factions, betting, achievements,
leaderboards, chat, friends, messages, profiles, customization, and multiplayer
presence. Adding crafting, inventory, loot rarity, classes, quests, guilds, or
additional maps now would increase maintenance faster than it improves the
core experience.

## Recommended direction

Keep the entire near-term game centered on one repeatable promise:

> Help shape a short Justice-versus-Avenger battle, earn a reward, improve one
> character, and decide what to wager on the next battle.

This connects the strongest existing systems without requiring a second world,
new combat architecture, or a large content pipeline.

## Recommended extensions, in priority order

### 1. Add one active battlefield objective

Give every player one simple, automatically assigned objective at a time. The
first version should use counters the server already knows how to produce.

Examples:

- Defeat 5 hostile enemies.
- Defeat 2 enemies while powered up.
- Help defeat 3 Justice or Avenger Knights.
- Survive for 3 minutes without dying.

Display the objective and progress directly in the HUD. Completing it should
award existing currencies only: experience, gold, or faction reputation.

Why this is the best first extension:

- it gives the current combat a clear short-term purpose;
- it reuses existing enemies, attacks, death events, and rewards;
- it does not require dialogue, quest givers, inventory, or a quest log;
- one objective slot prevents checklist bloat.

Keep the first release to three objective templates and one daily or
per-session completion.

### 2. Turn the Knight battle into a short visible round

Keep the same perpetual spawning and combat, but present it as repeating
five-to-ten-minute rounds. Add:

- Justice and Avenger defeat totals;
- a visible round timer;
- a leading-side indicator;
- a clear round result;
- a brief reset before the next round.

The battlefield can remain mechanically continuous if resetting populations is
undesirable. The "round" can simply score deaths during a time window.

This makes the existing spectacle understandable and gives chat, spectators,
faction reputation, and betting a shared event to discuss.

### 3. Attach betting directly to the visible battle

Use the same Justice-versus-Avenger round as the betting subject. A player
chooses a side before the lock time, sees the same timer used by the battlefield
HUD, and receives the result when that round ends.

Avoid adding betting markets, odds customization, items, or multiple concurrent
events. One battle, two sides, one lock time, and one payout is enough.

This turns betting from a separate menu activity into part of the gameplay
loop:

```text
Observe battle → choose side → fight or watch → round resolves → collect result
```

### 4. Add one elite modifier, not more enemy families

Occasionally promote an existing ordinary enemy or Knight to an elite. The
first implementation should use one modifier, such as:

- **Armored:** more health, stronger knockback resistance, higher reward.

Use the same sprite with a tint, outline, name prefix, or small icon. Reuse the
same attacks and AI. Do not add a new model, behavior tree, loot table, or
equipment system.

Once Armored is proven fun, add at most one more modifier such as Swift or
Empowered. Modifiers create encounter variety much more cheaply than new enemy
families.

### 5. Add visible stat milestones

Keep the existing five stats, but give a small, visible milestone at predictable
intervals—for example every five points:

- Strength: stronger hit flash or knockback.
- Agility: a small attack-speed milestone.
- Intelligence: slightly longer power-up duration.
- Luck: a clearer critical-hit effect.
- Endurance: a small health-regeneration delay improvement.

Milestones should alter an existing behavior, not unlock a new skill tree.
Expose the next milestone in the stat panel so spending a point has an obvious
goal.

### 6. Add one contextual battlefield event

After the round loop is stable, introduce a single event that changes the same
battle for 30–60 seconds:

- faction surge: one side temporarily respawns faster;
- mana storm: power-up mana regeneration increases in the battle area;
- elite arrival: one armored champion joins each side.

Run only one event type initially. Announce it in the HUD and chat, then return
to normal automatically. This creates variation without building a general
event framework prematurely.

## Smallest useful release plan

### Release A: Purpose

- One active objective slot.
- Three objective templates.
- HUD progress display.
- Existing XP or gold reward.

Success criterion: a new player can state what they are trying to accomplish
within 30 seconds of entering the Forest.

### Release B: Shared event

- Knight defeat counters.
- One round timer.
- Justice/Avenger round result.
- Betting lock and settlement tied to that result.

Success criterion: combatants and spectators understand who is winning and
when the outcome will resolve.

### Release C: Variety

- One Armored elite modifier.
- One stat milestone per stat, or only for the two most-used stats initially.
- One short battlefield event if the earlier releases remain stable.

Success criterion: repeated rounds feel different without requiring a new map
or a new combat control.

## Scope guardrails

For the next development phase:

- Keep one playable map.
- Keep one basic attack and one power-up.
- Keep health, stamina, and mana as the only combat resources.
- Reuse XP, gold, and faction reputation; add no new currency.
- Keep one active objective instead of a quest log.
- Keep one simultaneous battlefield round.
- Add modifiers to existing enemies before creating new enemy families.
- Use existing panels before creating another permanent window.
- Keep combat and rewards server-authoritative.
- Prefer configuration changes over new protocol families.

Explicitly defer:

- inventory and equipment;
- loot rarity and randomized drops;
- crafting;
- classes or branching skill trees;
- quest NPCs and dialogue systems;
- additional maps or procedural levels;
- guilds and party infrastructure;
- PvP;
- multiple simultaneous betting markets;
- a general-purpose live-event editor.

These may become appropriate later, but none is needed to prove the current
game's core.

## Decision filter for future ideas

Before accepting a feature, ask:

1. Does it make fighting, watching, or wagering on the Forest battle more
   meaningful?
2. Does it reuse an existing enemy, resource, reward, UI surface, or server
   event?
3. Can the player understand it without opening a new tutorial or menu?
4. Can the first version ship with one variant?
5. Can it be removed without invalidating persistent player data?

If an idea fails two or more of these checks, it is probably outside the
current small-scope direction.

## Recommended next implementation

Build **one active battlefield objective** first:

> Defeat 5 hostile enemies. Reward: a small amount of gold and experience.

Then add two variants using the same counter system. This is the smallest
change that gives the current combat a beginning, progress state, completion,
and reward. Once that loop feels good, make the Knight battle a visible timed
round and connect the existing betting system to its result.
