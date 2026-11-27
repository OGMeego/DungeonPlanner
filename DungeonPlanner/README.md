# Dungeon Planner for WoW: Forever

Everything for dungeons in one addon, built from Blizzard's own templates so it looks
like part of the game.

## Install

Unzip so the folder is `World of Warcraft\_forever_\Interface\AddOns\DungeonPlanner`, then
restart the game fully the first time. If the AddOns list says "out of date", run
`/run print(select(4, GetBuildInfo()))` and put that number on the `## Interface:` line
of `DungeonPlanner.toc`.

## What's inside

- **Group Finder planner** — a new side tab in Blizzard's Group Finder. Best-match sorting
  (role, level, your dungeon quests, gear upgrades, friends, people you've grouped with),
  an Applicants inbox for whispers about your group, confirmed roles and shared quests
  between Dungeon Planner users. Whispers are only ever sent with the Whisper button.
- **Dungeons window** (`/dp journal`, minimap button) — every classic dungeon:
  - Overview: bosses in order, with kills ticked off, and what to do before you go.
  - Quests: split into In your quest log / Ready to pick up / Later / Completed. Quests you
    have get a green bar and an IN YOUR LOG tag with your progress (gold TURN IN when done).
    Locked quests say which quest to do first. Who gives it and where, a one-click map pin,
    rewards with upgrade arrows, the quest's own text, and warnings for the tricky ones.
  - Loot: by boss, with drop chances, "usable only" filter and upgrade percentages.
  - New in Forever: Forever's dungeons from the Group Finder, with boss order learned as you play.
- **Travel guide (walking arrow)** — press the arrow button on any quest, or *Guide to
  Entrance* on a dungeon page. It plans the fastest way using walking, the flight paths
  *you* know, boats, zeppelins and your Hearthstone, then leads you step by step:
  "Go to the flight master at Crossroads" → "Fly to Thunder Bluff" → "Go to Rahauro".
  The arrow turns toward each step (green when you face the right way), shows yards and
  time, moves on by itself when you arrive, and tells you to pick up flight paths you
  pass. Click it for the full step list; right-click to skip, go back, recalculate or stop.
  On foot it follows a real walking network (paths around mountains, cliffs and water,
  from Exehn's Dungeon Journal with permission), so the arrow turns at each bend instead
  of pointing straight at a cliff. Flight paths to click are highlighted on the flight map.
- **Breadcrumbs** — if a dungeon quest needs earlier quests, the guide starts at the first
  one you still need and keeps going by itself: pick up, turn in, next quest, until the
  dungeon quest is in your log. Quest tooltips show the whole chain.
- **Dungeon maps** — every dungeon's map (the Dungeon Journal maps by Exehn, with permission):
  boss portraits in kill order, the entrance, quest markers, a floor picker and ticks for kills.
  Inside a dungeon, `/dp map` (or the button on the world map) opens the map of where you are.
- **Draw on the maps and share** — Draw (5 colours), Erase, Text labels and the 8 raid markers
  on any map floor; drag, mouse-wheel to resize, right-click to remove; Undo, Clear, and Share
  sends your drawing to your party or raid. **Pull plans** save every floor's drawings under a
  name, to load later or share as a whole.
- **Polished journal** — dungeon cards with the game's journal art, bosses with round
  portraits, level badges and "can drop N items", a boss card on its loot, and every quest
  showing what it asks you to do.
- **Loot without running anything** — every boss's drops plus notable trash drops for classic
  dungeons; for Forever's new dungeons the game's own Encounter Journal loot (real items),
  with researched drop lists and quest rewards as a backup.
- **Forever's nine new dungeons** — Hall of Thanes, Ruins of Lordaeron, Excavation Site,
  City of Dalaran, The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and
  Shaper's Terrace, with boss order, entrances (Guide to Entrance works), quests with
  givers and spots (map pin and Guide me), and loot by boss where it's been published.
- **Gear Upgrades** (`/dp gear`) — the best upgrades for your role from dungeons around your level.
- **Dungeon Tracker** — inside a dungeon: a run timer with your best time, bosses in order
  (ticked off as they die, next one marked) and your quests for that dungeon with their objectives. Drag to move,
  click to collapse, right-click for the journal.

- **Character Logs** (`/dp logs`) — every run of every character: date, time, cleared or not,
  who was with you, deaths, kills, experience, money and each boss's kill time. Best times
  per dungeon, compared with your group's. Scarlet Monastery, Dire Maul and Blackrock Spire
  are logged per wing ("Scarlet Monastery: Library"), and resetting a dungeon closes the run
  so the next one starts fresh (`/dp newrun` does it by hand). Click a run for details,
  right-click to delete.
- **Wishlist** (`/dp wishlist`) — right-click any item to add it. Groups going where it drops
  are marked in the Group Finder, and you get a warning when its boss dies.
- **Item sources** — every item tooltip says where it drops ("Mr. Smite, The Deadmines (20%)").
- **Party Quests** (`/dp party`) — which dungeon quests each member of your group has, who
  is missing what; click to share or to be guided. Sent to your group only, never whispered.
- **Secrets** — 26 of Forever's solved secrets (riddles, epic chains, secret bosses, hidden
  quests, curios and pets): steps with "Guide me", your progress, and Mark Done. The secret
  bosses (Lyn the Ignored, The Abandoned, Viktor the Vile) show how to summon them on the
  dungeon pages and maps.
- **Quest tips** — warnings and tips on dungeon quests: parts done outside the dungeon, which
  boss drops the item you need, and quests best done together.
- **Loot filter** — in the Filter menu: armor type (or best for your class), weapon types and
  stats. Saved per character and used on every loot page.
- **Onyxia attunement** — every step of the chain for your faction, with what you've done
  and what's in your log.
- **Tier sets** — Tier 0 and Tier 0.5 for your class (or every class): which pieces you own
  and where each one drops.
- **Smarter routes** — the arrow walks through the real mountain passes (Thandol Span, Dun
  Algaz, South Gate...) and learns new crossings as you walk from zone to zone.
- **Comfort** — resize the journal from its corner, change its size in the options, a Filter
  menu (Forever's dungeons only, hide completed quests, usable loot), key bindings, and
  10 languages: English, German, French, Spanish, Italian, Portuguese, Russian, Korean and
  Chinese (Simplified and Traditional), including the secrets and quest warnings.

Commands: `/dp`, `/dp journal`, `/dp map`, `/dp logs`, `/dp wishlist`, `/dp party`, `/dp gear`,
`/dp tracker`, `/dp newrun`, `/dp options`, `/dp version`, `/dp comm`, `/dp flights`, `/dp bug`, `/dp data`, `/dp record <name>`, `/dp record stop`, `/dp trails`, `/dp trail <name>`, `/dp debug`, `/dp mapdebug`.

## Files

Built like the Raid Assignment Manager: `Core/` (namespace, events, saved variables),
`Locales/`, `Data/` (generated data), `Services/` (logic: quests, routes, maps, logs,
wishlist, sharing), `UI/` (Group Finder panel, journal, map, arrow, tracker, options) and
`Bootstrap.lua` last (slash commands and key bindings). Each module keeps state its files
share in one private table (`ns.Private("Journal")`).

## Learning Forever's changes

WoW Forever changed many quests and drops, so the addon learns them while you play:

- **Boss drops**: when you open a creature's loot inside a dungeon, its equippable and
  quest items are recorded (once per corpse). The journal marks them *seen in Forever*,
  or *new in Forever* when the classic data didn't have them, with observed drop rates.
- **Quest givers**: when you open a dungeon quest's dialog, the giver and your position are
  recorded, and the journal's map pin uses that position.
- **Quests per dungeon**: quests that make progress while you're in a dungeon are tied to it,
  including Forever's new quests and new dungeons.

With sharing on (settings), these facts are passed to other Dungeon Planner users over the
hidden channel: creature, dungeon and item IDs, and quest-giver positions. Nothing about
you is shared, and messages wait until you're out of dungeons and combat. Your own
observations always win over anything received.

## Sharing quest data

WoW Forever changed many quests' XP and rewards. With your yes (asked once, and a setting you can change any time), Dungeon Planner notes what the game shows you for quests: the quest, your level, the XP and money, the reward items, and which NPC gives it and where. No character, account or guild names. Nothing is sent on its own: when enough notes wait, a small **Share quest data** button shows up in an inn or city (also in Settings, or type `/dp data`). Click it, copy the text, and paste it into the **Send quest data** form on the addon's GitHub page. The confirmed numbers then go into the addon for everyone.

## Data

Quest, boss and loot data comes from open Classic databases (see CREDITS.md). WoW Forever
changed some quests and items, so expect some differences; your quest log and the
game's live item stats always win.
