-- ForeverDB: the nine dungeons that are new in WoW Forever. The game's own data doesn't
-- carry these yet, so this was researched by hand from public player guides (November 2026)
-- and written in our own words. Anything the addon sees in game (boss kills, loot, quest
-- givers) is learned on top of this and wins where they disagree.
--
-- Dungeon:  name, aliases, min, max, zone (entrance zone, as the world map names it),
--           entrance = { x, y }, note (how to get in), bosses (in kill order),
--           quests (in the order you'd pick them up)
-- Boss:     { name, optional = true?, final = true?, loot = { { item, slot }, ... } }
-- Quest:    { title, side = "A" | "H" | "B", lvl, giver, zone, x, y, after = title?, note }
--           x/y missing = the guides didn't give a spot; the quest log marker is used instead.
local _, ns = ...

ns.ForeverDB = {
    {
        name = "Hall of Thanes", aliases = { "Halls of Thanes", "The Hall of Thanes" },
        side = "A", counterpart = "Ruins of Lordaeron", -- inside Ironforge: Horde must get past the city guards
        -- The safe way in for the Horde: the roads, not the mountains. Spots are where the guards
        -- and quest givers stand at each landmark (open NPC data); the guide walks you through them.
        routes = {
            H = {
                { zone = "Silverpine Forest", x = 45.6, y = 42.6, r = 40,
                  text = "The Sepulcher, Silverpine Forest",
                  hint = "From Orgrimmar take the zeppelin to the Undercity, then head south into Silverpine." },
                { zone = "Hillsbrad Foothills", x = 60.2, y = 18.6, r = 50,
                  text = "Tarren Mill, Hillsbrad Foothills",
                  hint = "Follow the road south out of Silverpine and east across Hillsbrad. Grab the flight path." },
                { zone = "Arathi Highlands", x = 20.0, y = 49.0, r = 80,
                  text = "Into the Arathi Highlands",
                  hint = "Take the road east from Tarren Mill until you cross into Arathi." },
                { zone = "Wetlands", x = 49.9, y = 18.2, r = 50,
                  text = "Thandol Span, into the Wetlands",
                  hint = "Follow the road south to the huge stone bridge and cross it. This is Alliance land now." },
                { zone = "Wetlands", x = 52.6, y = 83.0, r = 60,
                  text = "Dun Algaz, south end of the Wetlands",
                  hint = "Stay on the main road south. It's the safest path through the Wetlands." },
                { zone = "Loch Modan", x = 24.8, y = 18.4, r = 50,
                  text = "Algaz Station, Loch Modan",
                  hint = "Climb the long stairs through the pass. Dwarf guards stand here - keep running." },
                { zone = "Loch Modan", x = 22.1, y = 73.1, r = 50,
                  text = "South Gate Pass, west side of Loch Modan",
                  hint = "Head south along the western hills to the tunnel into Dun Morogh." },
                { zone = "Dun Morogh", x = 86.3, y = 48.8, r = 50,
                  text = "South Gate Outpost, Dun Morogh",
                  hint = "Through the tunnel and past the gate. Then west towards Ironforge." },
                { zone = "Dun Morogh", x = 53.0, y = 35.0, r = 40,
                  text = "The gates of Ironforge",
                  hint = "Before you go in: take off your gear. City guards will likely kill you a few times, and unequipped gear takes no damage. The spirit healer is just outside, so each death is a short run." },
                { zone = "Ironforge", x = 43.5, y = 52.0, r = 12,
                  text = "The High Seat, Ironforge",
                  hint = "Go to King Magni's throne room. As you enter, take the cobwebbed corridor on your left." },
                { zone = "Ironforge", x = 44.0, y = 51.8, r = 10,
                  text = "Hall of Thanes",
                  hint = "Follow the winding stairs down into Old Ironforge. The portal is at the lava bridge, next to Thom Filch." },
            },
        },
        min = 13, max = 18, zone = "Ironforge", entrance = { 44.0, 51.8 },
        note = "Old Ironforge, below the High Seat. Head down from the throne room.",
        -- Spots on the game's Hall of Thanes map picture (0-1 across, 0-1 down), measured from
        -- a screenshot of the map: Anvilmar's Rest, the middle hall, Dark Iron Ingress, Reliquary of Kings.
        -- Our own drawing of the layout, used until the game offers its map (0-1 across, 0-1 down).
        sketch = {
            areas = {   -- { left, top, right, bottom }
                { 0.488, 0.760, 0.528, 0.960 },   -- entrance stair
                { 0.470, 0.775, 0.548, 0.880 },   -- entrance room
                { 0.408, 0.562, 0.612, 0.775 },   -- Anvilmar's Rest
                { 0.269, 0.575, 0.415, 0.742 },   -- west tombs
                { 0.612, 0.575, 0.755, 0.742 },   -- east tombs
                { 0.446, 0.427, 0.574, 0.575 },   -- the middle hall
                { 0.493, 0.200, 0.521, 0.430 },   -- the long hall north
                { 0.462, 0.100, 0.552, 0.235 },   -- Reliquary of Kings
                { 0.574, 0.455, 0.690, 0.505 },   -- tunnel east
                { 0.665, 0.355, 0.800, 0.555 },   -- Dark Iron Ingress
                { 0.300, 0.270, 0.495, 0.300 },   -- west reliquary wing
                { 0.519, 0.270, 0.720, 0.300 },   -- east reliquary wing
            },
            labels = {
                { "Reliquary of Kings", 0.640, 0.180 },
                { "Dark Iron Ingress", 0.735, 0.320 },
                { "Anvilmar's Rest", 0.430, 0.800 },
            },
        },
        mapPins = {
            entrance = { 0.508, 0.933 },
            ["Faldrim Anvilmar"] = { 0.511, 0.667 },
            ["Plunder"] = { 0.508, 0.510 },
            ["Magmatus"] = { 0.745, 0.474 },
            ["Durgen Dirgehammer"] = { 0.505, 0.164 },
        },
        bosses = {
            { name = "Faldrim Anvilmar", loot = { { "Spiritwraith Drape", "Back", 34.1, id = 271097 }, { "Ephemeral Choker", "Neck", 33.9, id = 270227 }, { "Aetherwisp Bracers", "Cloth Wrist", 31.9, id = 271096 } } },
            { name = "Magmatus", alias = "Infurnus", loot = { { "Fang of Magmatus", "Dagger", id = 271095 }, { "Flamefist Grips", "Leather Hands", id = 270231 }, { "Kindlegem Girdle", "Mail Waist", id = 270230 } } },
            { name = "Plunder", loot = { { "Golemheart Stave", "Staff", 35.1, id = 270228 }, { "Treads of the Protector Golem", "Mail Feet", 32.9, id = 270229 }, { "Golemguard Chest", "Mail Chest", 32.1, id = 271098 } } },
            { name = "Durgen Dirgehammer", final = true, loot = { { "Durgen's Crescent Axe", "One-Hand Axe", 28.9, id = 270256 }, { "Direhammer Leggings", "Leather Legs", 26.9, id = 270260 }, { "Robes of the Disgraced Thane", "Cloth Chest", 24.9, id = 270261 }, { "Durgen Dirgehammer's Head", "Quest", 50.8, id = 274286 } } },
        },
        quests = {
            { title = "The Restless Dead", rewards = { "Dusty Belt", "Cryptwalker Bracers" }, side = "B", lvl = 15, giver = "Afadra Dunwall", zone = "Ironforge", x = 33.8, y = 47.9,
              note = "Near the way down to the dungeon." },
            { title = "Important Heirlooms", rewards = { "Dwarven Tome", "Tomb Robber's Gloves" }, side = "B", lvl = 15, giver = "Thom Filch", zone = "Ironforge", x = 32.5, y = 44.5 },
            { title = "A Visitor to Dun Morogh", side = "A", lvl = 13, giver = "Beldin Steelgrill", zone = "Dun Morogh", x = 49.6, y = 48.6,
              note = "Optional lead-in, outside Kharanos." },
            { title = "Farsen's Watch", side = "A", lvl = 14, giver = "Earthseer Farsen", zone = "Dun Morogh", x = 64.8, y = 58.5,
              after = "A Visitor to Dun Morogh" },
            { title = "Nip 'Em in the Bud", side = "A", lvl = 14, giver = "Earthseer Farsen", zone = "Dun Morogh", x = 64.8, y = 58.5 },
            { title = "Underground Map", obj = "Bring the Dark Iron Map to Earthseer Farsen.", side = "A", lvl = 15, giver = "Dark Iron Map (drop)", zone = "Dun Morogh", x = 76.7, y = 60.7,
              note = "Dark Iron Spies around here drop the map that starts it." },
            { title = "Old Ironforge Incursion", obj = "Kill Durgen Dirgehammer in the Hall of Thanes.", rewards = { "Calibrated Blunderbuss", "Ironforge Greathammer", "Deepblaze" }, side = "A", lvl = 16, giver = "Earthseer Farsen", zone = "Dun Morogh", x = 64.8, y = 58.5,
              after = "Underground Map", note = "Kill Durgen Dirgehammer." },
            { title = "An Ancient Grudge", rewards = { "Catacomb Cloak", "Deepgrave Trousers" }, side = "B", lvl = 16, giver = "Ghostly Attendant", note = "Starts inside the dungeon." },
            { title = "The Treaty of Understanding", obj = "Bring the ancient tablet from the Hall of Thanes to King Magni.", side = "B", lvl = 16, giver = "Ancient tablet", note = "Found inside; hand it to King Magni." },
        },
    },
    {
        name = "Ruins of Lordaeron", aliases = { "The Ruins of Lordaeron" },
        side = "H", counterpart = "Hall of Thanes", -- above the Undercity: deep in Horde land
        min = 15, max = 20, zone = "Undercity", entrance = { 71.6, 11.4 },
        note = "Surface ruins above the Undercity: through the front gate, then left up the stairs before the keep.",
        bosses = {
            { name = "Witherfang", loot = { { "Segmented Spider Leg", "Two-Hand, Staff", 31.9, id = 271203 }, { "Witherbite Bracers", "Wrist, Leather", 31.5, id = 271202 }, { "Atrophic Girdle", "Waist, Mail", 28.7, id = 271201 }, { "Highly Toxic Strain", "Quest", 26.5 } } }, { name = "The Baron", loot = { { "Meathook Slicer", "One-Hand, Dagger", 31.1, id = 271204 }, { "Leftover Abomination Skin", "Chest, Cloth", 30.9, id = 271206 }, { "Abomination Bones", "Chest, Mail", 29.9, id = 271205 }, { "Abominable Head", "Quest", 36.5 }, { "Head of the Baron", "Quest", 18.2 } } }, { name = "Viktor the Vile", optional = true, secret = "Secret boss: clear around the ruined house with the standing chimney, rest, then click the fire under the chimney. Five waves; Viktor comes with the sixth. Kill every add or he may not show.", loot = { { "Vileblood Scimitar", "One-Hand, Sword", 34.5, id = 271218 }, { "Bloodied Chestwraps", "Chest, Leather", 32.8, id = 271212 }, { "Vilewalkers", "Feet, Mail", 32.7, id = 271211 } } }, { name = "The Abandoned", optional = true, secret = "Secret boss: clear the small hall with the knight statue on the left side, rest, then walk up to the statue. Three waves of undead, then The Abandoned.", loot = { { "Scepter of the Abandoned", "Main Hand, Mace", 34.8, id = 271216 }, { "Grip of Fear", "Hands, Mail", 32.8, id = 271208 }, { "Rotmender's Leggings", "Legs, Cloth", 32.3, id = 271207 } } },
            { name = "Bjork", loot = { { "Corpse Chopper", "Two-Hand, Axe", 35.2, id = 271217 }, { "Bonerust Leggings", "Legs, Mail", 32.7, id = 271209 }, { "Tuskwrap Belt", "Waist, Cloth", 32.1, id = 271210 } } }, { name = "Lordaeron Captain", optional = true, loot = { { "Phantom Armor", "Chest, Mail", 48.0, id = 6642 }, { "Haunting Blade", "Two-Hand, Sword", 47.2, id = 6641 } } }, { name = "Rath'mael", final = true, loot = { { "Mirror of Rath'mael", "Off Hand, Shield", 34.2, id = 271213 }, { "Coldspire Staff", "Two-Hand, Staff", 32.7, id = 271215 }, { "Rotmender's Treads", "Feet, Cloth", 32.2, id = 271214 }, { "Blueprint: Fermenter", "Blueprint", 7.1, id = 273085 } } },
        },
        quests = {
            { title = "A Frightened Request", rewards = { "Edward's Knife", "Tabitha's Cuffs" }, side = "H", lvl = 22, giver = "Tabitha Heartweaver", zone = "Silverpine Forest", x = 44.4, y = 42.8,
              note = "At the Sepulcher." },
            { title = "Light's Justice", rewards = { "The Stitcher", "Spare Part Bindings" }, side = "H", lvl = 22, giver = "Morbin Lightbane", zone = "Undercity", x = 57.9, y = 89.5,
              note = "Near the Royal Quarter." },
            { title = "The New Plague", rewards = { "Plaguefang", "Blight Gloves" }, side = "H", lvl = 22, zone = "Undercity" },
            { title = "The Wrath of Rath'mael", obj = "Defeat Rath'mael in the Ruins of Lordaeron.", rewards = { "Forsaken Greataxe", "Gnarled Necromancer's Staff" }, side = "H", lvl = 22, giver = "Deathguard Kristof", zone = "Tirisfal Glades", x = 65.3, y = 60.1,
              note = "Comes after the Rear Guard Patrol chain in Tirisfal." },
            { title = "Crest of Lordaeron", rewards = { "Small Sack of Gems" }, side = "B", lvl = 22, giver = "Crest (drop)", note = "Starts inside the dungeon." },
            { title = "Unending Torment", side = "B", lvl = 21, giver = "Inside the dungeon", note = "Starts inside the dungeon." },
            { title = "Abominable Creatures", rewards = { "Monstrous Cleaver", "Grave Shroud", "Slain Baron's Signet" }, side = "A", lvl = 21, giver = "Inside the dungeon", note = "Starts inside. Captain Truman by the entrance takes the Baron's head afterwards." },
            { title = "Bloodied Insignia", rewards = { "Duty Bound Leggings", "Remembrance Armor" }, side = "A", lvl = 22, giver = "Inside the dungeon", note = "Starts inside the dungeon." },
            { title = "Remember That I Love You", side = "A", lvl = 22, giver = "Inside the dungeon", note = "Two parts; starts inside." },
        },
    },
    {
        name = "Excavation Site: Wetlands", aliases = { "Excavation Site", "Wetlands Excavation Site" },
        min = 26, max = 31, zone = "Wetlands", entrance = { 47.8, 56.3 },
        note = "Climb the new road up the mountain near Whelgar's Excavation; the portal is on the hilltop (about 53.4, 65.3).",
        bosses = {
            { name = "Saltspine", loot = { { "Supple Bellyskin Leggings", "Legs, Leather", 34.1, id = 273022 }, { "Glinteye Slippers", "Feet, Cloth", 30.7, id = 273024 }, { "Saltscale Girdle", "Waist, Mail", 29.4, id = 273023 } } }, { name = "Shadetooth", loot = { { "Garb of Florid Feathers", "Chest, Leather", 31.0, id = 273026 }, { "Raptor's Gaze", "Held In Off-hand", 29.2, id = 273027 }, { "Raptorclaw Greaves", "Feet, Mail", 28.1, id = 273025 }, { "Blueprint: Greenhouse", "Blueprint", 7.0, id = 273106 } } }, { name = "Highland Horror", loot = { { "Horrible Rootcore", "Quest", 73.0 } } }, { name = "Relic Guardian", final = true, loot = { { "Golemsight Long Gun", "Ranged, Gun", 31.4, id = 273029 }, { "Reliquary Mantle", "Shoulder, Mail", 30.5, id = 273028 }, { "Ring of Power Regulation", "Finger", 29.5, id = 273030 }, { "Blueprint: Rock Garden", "Blueprint", 6.6, id = 273097 }, { "Titan Relic", "Quest", 30.8, id = 270866 } } },
        },
        quests = {
            { title = "Songblade Search", obj = "Find Daewyn's body in a Dragonmaw tent after Shadetooth.", side = "A", lvl = 31, giver = "Dorin Songblade", zone = "Redridge Mountains", x = 25.6, y = 46.6,
              note = "The body is in a Dragonmaw tent after Shadetooth." },
            { title = "Fallen in the Fen", rewards = { "Daewyn's Girdle", "Songblade Stabilizer" }, side = "A", lvl = 31, giver = "Daewyn Songblade (inside)",
              after = "Songblade Search", note = "Turn in to Dorin Songblade (Redridge Mountains 30.8, 46.6)." },
            { title = "Seeking Caitlin", side = "A", lvl = 31, giver = "Llana", zone = "Ashenvale", x = 35.0, y = 48.5, note = "Optional lead-in." },
            { title = "Lost in the Thicket Things", obj = "Find Ardin on a wooden platform near the Relic Guardian.", side = "A", lvl = 31, giver = "Caitlin Grassman", zone = "Wetlands", x = 11.9, y = 58.8,
              after = "Seeking Caitlin", note = "Ardin waits near the last boss." },
            { title = "Heartwoven", rewards = { "Greater Healing Potion x4", "Mana Potion x4" }, side = "A", lvl = 31, giver = "Ardin Grassman (inside)",
              after = "Lost in the Thicket Things", note = "Turn in to Caitlin Grassman (Wetlands 11.8, 58.6)." },
            { title = "Horrors in the Highland", obj = "Kill the Highland Horror and bring its Horrible Rootcore to Rethiel.", rewards = { "Ironwood Destroyer", "Curl of Life", "Hornbeam Heft" }, side = "A", lvl = 31, giver = "Rethiel the Greenwarden", zone = "Wetlands", x = 56.3, y = 40.3,
              note = "Needs Tramping Paws, Fire Taboo and Blisters on the Land first." },
            { title = "Lost Relic Carry", obj = "Take the Titan Relic from the Relic Guardian to Prospector Whelgar.", side = "A", lvl = 31, giver = "Titan Relic (Relic Guardian)", note = "Take it to Prospector Whelgar (Wetlands 38.8, 52.3)." },
            { title = "Prehistoric Prism", rewards = { "Explorer's League Dustcover", "Healer's Staff", "Heavehammer" }, side = "A", lvl = 31, giver = "Prospector Whelgar", zone = "Wetlands", x = 38.8, y = 52.2,
              after = "Lost Relic Carry", note = "Turn in to High Explorer Magellas (Ironforge 69.6, 18.6)." },
            { title = "Dragonmaw Rumors", side = "H", lvl = 31, giver = "Zaruk", zone = "Arathi Highlands", x = 74.4, y = 35.6, note = "Lead-in." },
            { title = "Open the Maw", obj = "Kill 2 Dragonmaw Saboteurs and 4 Warders, and loot a Dragonmaw Dispatch.", rewards = { "Knife-Polishing Rag", "Dirt-Heavy Bracers" }, side = "H", lvl = 31, giver = "Deathstalker Agent", zone = "Wetlands", x = 51.4, y = 59.2,
              after = "Dragonmaw Rumors", note = "Behind a small hill near the climb." },
            { title = "Changing Tastes", obj = "Loot 4 Thicket Raptor Meat from raptors in Stalker's Thicket.", rewards = { "Satchel of Potions", "Serrated Raptor Claw" }, side = "H", lvl = 31, giver = "Borstan", zone = "Orgrimmar", x = 57.3, y = 53.3, note = "Upstairs in the Drag." },
            { title = "Elder Knowledge", obj = "Take the Titan Relic from the Relic Guardian to Bashana Runetotem.", side = "H", lvl = 31, giver = "Titan Relic (Relic Guardian)", note = "Take it to Bashana Runetotem (Thunder Bluff 70.8, 33.7)." },
            { title = "Earthen Echo", rewards = { "Heavehammer", "Healer's Staff", "Furs of the Earthen Ring" }, side = "H", lvl = 31, giver = "Bashana Runetotem", zone = "Thunder Bluff", x = 70.8, y = 33.8,
              after = "Elder Knowledge", note = "Turn in to Muln Earthfury (Mulgore 33.4, 22.4)." },
        },
    },
    {
        name = "City of Dalaran", aliases = { "Dalaran", "Dalaran Sewers" },
        min = 28, max = 33, zone = "Silverpine Forest", entrance = { 69.3, 45.6 },
        note = "Through the sewers. The Dalaran Sewer Key comes from Heart of Disruption.",
        bosses = {
            { name = "Arcane Anomaly", loot = { { "Ephemeral Grips", "Hands, Cloth", 33.9, id = 273034 }, { "Mana-Warped Chain Shirt", "Chest, Mail", 33.1, id = 273035 }, { "Runemender's Seal", "Finger", 33.0, id = 273031 } } }, { name = "Fel Ancient", loot = { { "Felbough Arm", "Two-Hand, Polearm", 34.8, id = 273037 }, { "Garb of Fallen Felbark", "Chest, Leather", 34.4, id = 273038 }, { "Blightleaf Rope", "Waist, Cloth", 30.8, id = 273039 } } }, { name = "Mana Devourer", loot = { { "Spine of the Devourer", "Two-Hand, Staff", 33.5, id = 273040 }, { "Slitherwrap Girdle", "Waist, Leather", 33.3, id = 273041 }, { "Manascale Treads", "Feet, Mail", 33.1, id = 273042 } } }, { name = "Arcanic Enigma", loot = { { "Drape of Shifting Energy", "Back", 36.1, id = 273045 }, { "Arcanowisp Robes", "", 33.6 }, { "Wand of Mana Concentration", "Ranged, Wand", 30.3, id = 273043 } } },
            { name = "Unstable Sentinel", loot = { { "Guardian's Dualblade", "Two-Hand, Axe", 34.6, id = 273046 }, { "Unstable Crystalline Shoulderpads", "Shoulder, Leather", 32.8, id = 273047 }, { "Refractory Scaleguards", "Legs, Mail", 31.1, id = 273048 }, { "Blueprint: Spinning Wheel", "Blueprint", 6.7, id = 273099 } } }, { name = "Atrexis the Grave Knight", loot = { { "Graveweave Bindings", "Wrist, Cloth", 35.2, id = 273036 }, { "Bonebinder's Signet", "Finger", 35.0, id = 273032 }, { "Gravespike Repeater", "Ranged, Crossbow", 29.8, id = 273033 } } }, { name = "Lyn the Ignored", optional = true, secret = "Secret boss: kill Atrexis first, then go straight on (not right to the stairs) into the small room with planks over water. Clear it and use the Tome of Dalaran on the purple rune. The tome comes from Arugal\'s Black Tome (Shadowfang Keep) used at the Ambermill Leyline Focus.", loot = { { "Tendonscraper Dagger", "Main Hand, Dagger", 36.9, id = 273053 }, { "Cartilage Shapers", "Hands, Leather", 32.3, id = 273054 }, { "Bonepile Gaze", "Off Hand, Shield", 30.8, id = 273055 } } },
            { name = "Mana Wraith" }, { name = "Shade of the Archmage", final = true, loot = { { "Archmagister's Faceted Pendant", "Neck", 34.0, id = 273049 }, { "Ponderous Orb", "Held In Off-hand", 31.2, id = 273052 }, { "Violet Sorcerer's Mantle", "Shoulder, Cloth", 30.2, id = 273051 }, { "Blueprint: Arcane Salvager", "Blueprint", 6.8, id = 273103 }, { "Arcane Mote", "Quest", 41.2 } } },
        },
        quests = {
            { title = "Heart of Disruption", obj = "Gets you the Dalaran Sewer Key you need to enter.", rewards = { "Spellguard Pauldrons", "Renewing Footpads", "Defender of Dalaran" }, side = "A", lvl = 33, giver = "Image of Archmage Modera", zone = "Silverpine Forest", x = 68.7, y = 45.2,
              note = "Gives the sewer key." },
            { title = "Heart of Disruption", obj = "Gets you the Dalaran Sewer Key you need to enter.", rewards = { "Battle Spaulders", "Enchanted Sandals", "Striking Staff" }, side = "H", lvl = 33, giver = "Magus Wordeen Voidglare", zone = "Hillsbrad Foothills", x = 61.6, y = 20.8,
              note = "Gives the sewer key." },
            { title = "Starving Arcane", rewards = { "Fallen Guard's Pendant", "Arcane Infused Rod" }, side = "A", lvl = 33, giver = "Image of Archmage Modera", zone = "Silverpine Forest", x = 68.7, y = 45.2 },
            { title = "A Green Sample", rewards = { "Vine Pruner's Cloak", "Thorn Protecting Girdle" }, side = "A", lvl = 33, giver = "Shylamiir", zone = "Stormwind City", x = 31.3, y = 62.9 },
            { title = "Power Overwhelming", rewards = { "Violet Sash", "Runebound Gloves" }, side = "A", lvl = 33, giver = "High Sorcerer Andromath", zone = "Stormwind City", x = 48.8, y = 87.6 },
            { title = "Source of Power", rewards = { "Unstable Power Core", "Construct Cloak" }, side = "H", lvl = 33, giver = "Doctor Martin Felben", zone = "Undercity", x = 46.4, y = 74.2 },
            { title = "The Grave Knight", obj = "Defeat Atrexis the Grave Knight in Dalaran.", rewards = { "Gravewalker Boots", "Undead Knight's Bracers" }, side = "H", lvl = 33, giver = "Melisara", zone = "Hillsbrad Foothills", x = 62.4, y = 20.4 },
            { title = "Opportunistic Education", rewards = { "Solid Gold Band", "Larcenist's Belt" }, side = "B", lvl = 33, giver = "Rexxie Copperclutch", zone = "Silverpine Forest", x = 69.3, y = 45.6,
              note = "By the sewer entrance." },
        },
    },
    {
        name = "The Drowned City", aliases = { "Drowned City" },
        min = 35, max = 40, zone = "Stranglethorn Vale", entrance = { 21.0, 28.0 },
        note = "Underwater off the west coast, at the Vile Reef. Bring water breathing if you have it.",
        bosses = {
            { name = "Zul'Alai", loot = { { "Oathbound Bracers", "", 33.6 }, { "Berserker Shackles", "", 33.3 }, { "Bloodslash Axe", "", 33.1 }, { "Linken's Boots of Iron", "", 1.0 } } }, { name = "Var'Taka", loot = { { "Priestess Cloak", "", 34.5 }, { "Harpoon of Command", "", 33.4 }, { "Brinebelly Leggings", "", 32.0 } } }, { name = "Primeval Elemental", optional = true, loot = { { "Heart of the Primeval", "", 35.9 }, { "Waterlogged Burial Shroud", "", 32.8 }, { "Robe of the Drowned", "", 31.3 } } },
            { name = "Captain Dreadrise", loot = { { "Dreadfrost Saber", "", 33.7 }, { "Frosty Blunderbuss", "", 33.4 }, { "Briny Sash", "", 32.9 } } }, { name = "Deathless Marrow", loot = { { "Knucklebone Ring", "", 32.6 }, { "Bloodspine Staff", "", 28.4 }, { "Viscera Spaulders", "", 27.9 }, { "Ancient Gurubashi Idol", "Quest", 50.9 } } }, { name = "Min'loth the Serpent", final = true, loot = { { "Serpentbane Crown", "", 35.3 }, { "Ritual-Binder's Gloves", "", 32.9 }, { "Maw of Min'loth", "", 31.7 }, { "Linken's Boots of Iron", "", 1.3 } } },
        },
        quests = {
            { title = "Magics of the Drowned City", side = "A", lvl = 36, giver = "Loremaster Dibbs", zone = "Hillsbrad Foothills", x = 50.6, y = 57.0,
              note = "In Southshore." },
            { title = "Take Two With Water", side = "A", lvl = 36, giver = "Loremaster Dibbs", zone = "Hillsbrad Foothills", x = 50.6, y = 57.0 },
            { title = "Ancient Gurubashi Secrets", side = "A", lvl = 37, giver = "Archmage Timear", zone = "Alterac Mountains", x = 15.6, y = 73.6 },
            { title = "Ancient Gurubashi Idol", obj = "Bring back the Ancient Gurubashi Idol from Deathless Marrow.", rewards = { "Earthen Ring" }, side = "H", lvl = 37, giver = "Mazu'kon", zone = "Mulgore" },
            { title = "The Drowned City", side = "H", lvl = 36, giver = "Kin'weelay", zone = "Stranglethorn Vale", x = 32.2, y = 27.8, note = "At Grom'gol." },
            { title = "The Only Good Brinescale...", rewards = { "Tidesoaked Leggings", "Naga Priestess's Mantle" }, side = "H", lvl = 36, giver = "Aggro'gosh", zone = "Stranglethorn Vale", x = 32.2, y = 28.8,
              note = "At Grom'gol." },
            { title = "Shady Saltseers", rewards = { "Rusted Troll War Belt", "Saltseer's Helm" }, side = "B", lvl = 37, giver = "Krazek", zone = "Stranglethorn Vale", x = 27.0, y = 77.2, note = "In Booty Bay." },
            { title = "The Saltseer Captain", rewards = { "Mutinous Cuffs", "South Seas Shroud" }, side = "B", lvl = 38, giver = "Krazek", zone = "Stranglethorn Vale", x = 27.0, y = 77.2,
              after = "Shady Saltseers" },
        },
    },
    {
        name = "Krol'dok Stronghold", aliases = { "Krol'Dok Stronghold", "Kroldok" },
        min = 40, max = 45, zone = "Riverglades", entrance = { 37.0, 37.0 },
        note = "Cave just west of the stronghold gates.",
        bosses = {
            { name = "Slavecrusher Grox", loot = { { "Slavecrusher Scepter", "One-Hand, Mace", 35.2, id = 274995 }, { "Chain of Binding", "Waist, Mail", 33.0, id = 274997 }, { "Resistance Breaker Spaulder", "Shoulder, Mail", 31.0, id = 274996 }, { "Blueprint: Expert Campfire", "Blueprint", 4.5, id = 273101 } } }, { name = "Twilight Commander Zarmork", alias = "Twilight Commander Zarmok", loot = { { "Zarmok's Plated Signet", "Finger", 34.3, id = 275000 }, { "Shadowlight Athame", "Main Hand, Dagger", 32.4, id = 274998 }, { "Shadecaster's Leggings", "Legs, Cloth", 31.7, id = 274999 } } }, { name = "Handler Ashka", alias = "War Handler Ashka", loot = { { "Bloodied Gutslicer", "Two-Hand, Sword", 36.4, id = 275001 }, { "War Handler's Gaze", "Head, Leather", 34.4, id = 275002 }, { "Worgbinder's Treads", "Feet, Plate", 29.2, id = 275003 } } },
            { name = "Nar'Gurk", alias = "Nar'gurk", loot = { { "Chain of the Corruptor", "Neck", 35.8, id = 275004 }, { "Krol'dok Warplate Helmet", "Head, Plate", 28.1, id = 275006 }, { "Krol'dok Warplate Chest", "Chest, Plate", 26.1, id = 275005 }, { "Tome of Twilight", "Quest", 42.1 } } }, { name = "Bossman Toof" }, { name = "Overlord Mugg", final = true, loot = { { "Mugg's Jabber", "One-Hand, Fist Weapon", 25.0, id = 275007 }, { "Strongly Scented Hood", "Head, Cloth", 24.3, id = 275010 }, { "Mugg's Crosser", "One-Hand, Fist Weapon", 21.9, id = 275008 }, { "Emblem of Slamming", "Trinket", 21.0, id = 275009 }, { "Eye of Mugg", "Quest", 43.8 } } },
        },
        quests = {
            { title = "Vengeance of the Highborne", side = "A", lvl = 37, giver = "Ranath Nightstride", zone = "Alterac Mountains", x = 17.8, y = 66.0,
              note = "In Dalaran." },
            { title = "Twilight Mementos", side = "A", lvl = 38, giver = "Sergeant Riftan", zone = "Riverglades", x = 30.5, y = 48.9,
              note = "Opens after the Saving Sunnyglade chain." },
            { title = "Tome of Twilight", obj = "Recover the Tome of Twilight from Nar'Gurk.", rewards = { "Twilight Initiate's Belt", "Torn Cultist Cloak" }, side = "A", lvl = 39, giver = "Ashe Amberhall", zone = "Riverglades", x = 66.6, y = 81.0, note = "Farholde Keep." },
            { title = "Eye of Mugg", obj = "Kill Overlord Mugg and bring back his eye.", rewards = { "Rock on Stick", "Bigger Rock on Bigger Stick", "Stick No Rock" }, side = "A", lvl = 40, giver = "Demar Brant", zone = "Riverglades", x = 66.6, y = 81.0,
              note = "Farholde Keep; opens after Scraps of Knowledge." },
            { title = "A Token of Vengeance", rewards = { "Semblance of Twilight" }, side = "H", lvl = 38, giver = "Da'Grosh", zone = "Riverglades", x = 33.4, y = 38.0,
              note = "Opens after the Encroaching Twilight chain." },
            { title = "Tome of Twilight", obj = "Recover the Tome of Twilight from Nar'Gurk.", rewards = { "Indoctrinated Choker", "Convert's Bindings" }, side = "H", lvl = 39, giver = "Tran'Gul", zone = "Riverglades", x = 59.5, y = 44.0, note = "Rog'mar." },
            { title = "Eye of Mugg", obj = "Kill Overlord Mugg and bring back his eye.", rewards = { "Rock on Stick", "Bigger Rock on Bigger Stick", "Stick No Rock" }, side = "H", lvl = 40, giver = "Krom'Rosh", zone = "Riverglades", x = 59.4, y = 49.6, note = "Rog'mar." },
            { title = "Krol'dok Moulding", obj = "Turn in the moulding Tunk drops in the smithy after the third boss.", side = "B", lvl = 38, giver = "Tunk (drop)", note = "From Tunk in the smithy after the third boss." },
            { title = "Key Ingredients", rewards = { "Krol'dok Compound Key" }, side = "A", giver = "Alphonse Dumas", zone = "Riverglades", x = 64.4, y = 82.0,
              after = "Krol'dok Moulding", note = "Bring 4 Thick Leather and 12 Iron Bars: you get the Krol'dok Compound Key." },
            { title = "Key Ingredients", rewards = { "Krol'dok Compound Key" }, side = "H", giver = "Kreza Darkthorn", zone = "Riverglades", x = 59.8, y = 46.0,
              after = "Krol'dok Moulding", note = "Bring 4 Thick Leather and 12 Iron Bars: you get the Krol'dok Compound Key." },
        },
    },
    {
        name = "Alcaz Prison", aliases = { "Alcaz Island Prison", "Alcaz Island" },
        min = 48, max = 53, zone = "Dustwallow Marsh", entrance = { 75.3, 14.1 },
        note = "Swim to Alcaz Island, enter the keep, and take the basement corridor to the portal.",
        bosses = {
            { name = "Tidemistress Ca'zass", loot = { { "Tidesong Wand", "Wand", 31.7 }, { "Seascale Bracers", "Mail Wrist", 31.0, id = 276736 }, { "Cloak of the Tidemistress", "Back", 31.0, id = 276737 }, { "Ca'zass's Head", "Quest", 30.5, id = 273883 } } },
            { name = "Overseer Wrex", loot = { { "Alcaz Willcrusher", "Two-Hand Mace", 33.9, id = 276732 }, { "Wrex's Pinky Ring", "Finger", 32.8, id = 276734 }, { "Grips of Control", "Plate Hands", 31.0 }, { "Overseer's Keyring", "Key", 10.7 } } },
            { name = "The Questioner", loot = { { "Fingerbreaker Stamp", "Trinket", 36.4, id = 276743 }, { "Defias Enforcer's Shoulderpads", "Leather Shoulder", 31.9, id = 276741 }, { "Girdle of Extracted Answers", "Plate Waist", 29.6, id = 276742 }, { "Ornate Shackle Key", "Quest", 25.0, id = 274029 } } },
            { name = "Katerina the Cleaner", loot = { { "Katerina's Shanker", "Dagger", 34.7, id = 276738 }, { "Sentimental Locket", "Neck", 33.0, id = 276740 }, { "Cutthroat Chestguard", "Mail Chest", 31.6 } } },
            { name = "Zarla Ober", final = true, alias = "Blazeroar", loot = { { "Zarla's Snack Pouch", "Trinket", 34.7, id = 276744 }, { "Defias Enforcer's Legguards", "Leather Legs", 33.7, id = 276746 }, { "Beastbond Robe", "Cloth Chest", 29.3, id = 276745 }, { "Zarla's Journal", "Quest", 15.2, id = 276890 } } },
        },
        quests = {
            { title = "The Dragon's Journal", side = "A", lvl = 46, giver = "Archmage Lan'dalock", zone = "Alterac Mountains", x = 15.5, y = 73.7,
              note = "In Dalaran." },
            { title = "Our Man in Theramore", side = "A", lvl = 48, giver = "Master Mathias Shaw", zone = "Stormwind City", note = "Lead-in." },
            { title = "A Bit of Wet Work", side = "A", lvl = 48, giver = "Sully McCleary", zone = "Dustwallow Marsh", after = "Our Man in Theramore" },
            { title = "The Secret Prison", side = "A", lvl = 48, giver = "Sully McCleary", zone = "Dustwallow Marsh", after = "Our Man in Theramore" },
            { title = "The Missing Kor'kron", side = "H", lvl = 48, giver = "Eitrigg", zone = "Orgrimmar", note = "Lead-in." },
            { title = "Blood Red Bandanas", obj = "Collect Blood Red Bandanas from the Defias in Alcaz Prison.", rewards = { "Bloodsplattered Bandana", "Makeshift Belt" }, side = "H", lvl = 48, giver = "Sergeant Ulka", zone = "Dustwallow Marsh", after = "The Missing Kor'kron" },
            { title = "A Little Payback", side = "H", lvl = 48, giver = "Sergeant Ulka", zone = "Dustwallow Marsh", after = "The Missing Kor'kron" },
            { title = "No Orc Left Behind", side = "H", lvl = 48, giver = "Sergeant Ulka", zone = "Dustwallow Marsh", after = "The Missing Kor'kron" },
            { title = "The Honor of the Kor'kron", side = "H", giver = "Commander Folkar (inside)", after = "No Orc Left Behind", note = "Starts inside the dungeon." },
            { title = "Thrall Needs to Know", rewards = { "Fatebound Buckler", "Courier's Clasp", "Dustwallow Dirk" }, side = "H", giver = "Commander Folkar (inside)", after = "The Honor of the Kor'kron", note = "Starts inside the dungeon." },
            { title = "Bad News for Folkar", side = "H", giver = "Perfumed Note (drop)", note = "Drops inside." },
            { title = "More Valuable Than Gold", obj = "Use Mason Connery's note to find his hidden treasure in the Moonbrook inn, Westfall.", side = "B", lvl = 53, giver = "Mason Connery", note = "Starts inside, once you free Mason Connery with the key The Questioner carries." },
            { title = "The Man in the Iron Chains", obj = "Free Mason Connery. Keep The Questioner alive until you have this quest.", side = "B", lvl = 48, giver = "Mason Connery", note = "Inside. Keep The Questioner alive until you have it." },
            { title = "More Valuable than Gold", side = "B", lvl = 48, giver = "Mason Connery", after = "The Man in the Iron Chains", note = "Inside." },
        },
    },
    {
        name = "Blackmaw Hold", aliases = {},
        min = 55, max = 60, zone = "Azshara", entrance = { 38.5, 33.3 },
        note = "Furbolg city in western Azshara.",
        bosses = {
            { name = "Impaan the Imprisoner", loot = { { "Flameslash Crescent", "", 33.2 }, { "Robes of Dark Summons", "", 31.8 }, { "Impish Chain Hood", "", 31.5 } } }, { name = "Bonesnout the Unbroken", loot = { { "Lucky Shovelnose Tuft", "", 33.0 }, { "Spike Crested Bracers", "Wrist, Plate", 31.8, id = 280061 }, { "Tuskblade Halberd", "", 31.6 }, { "Tusks of the Unbroken", "Quest", 28.7 } } }, { name = "Withermaw", loot = { { "Cloak of the Fleshborer", "", 32.2 }, { "Bloodfur Bulwark", "", 30.2 }, { "Withering Grips", "", 30.2 }, { "Claws of the Great Bear", "Quest", 26.5 } } }, { name = "Unbound Spirit", loot = { { "Flamebreak Talisman", "Trinket", 36.0, id = 280071 }, { "Cowl of Dark Ambition", "", 31.6 }, { "Burnished Pridescales", "", 30.3 } } },
            { name = "Elder Shaman Bloodmane", loot = { { "Bloody Claws of Attack", "One-Hand, Fist Weapon", 36.1, id = 280068 }, { "Veilpiercer Girdle", "", 24.1 }, { "Shamanic Wristguards", "", 21.3 }, { "Blackmaw Ritual Totem", "Quest", 28.8 }, { "Reliquary of Tyr", "Quest", 1.9 } } }, { name = "Blackmaw Behemoth", loot = { { "Behemoth Bones", "", 34.8 }, { "Trousers of the Ebon Giant", "", 32.7 }, { "Blackmaw Chain Belt", "", 28.5 } } }, { name = "Varrox Bleakhoof", final = true, loot = { { "Horns of Varrox", "", 32.8 }, { "Bleak Eye Shoulderplates", "", 32.4 }, { "Scalding Flamehoof", "", 30.8 }, { "Head of Varrox Bleakhoof", "Quest", 4.0 } } },
        },
        quests = {
            { title = "Get to the Roots of It", side = "A", lvl = 56, giver = "Mathrengyl Bearwalker", zone = "Darnassus", x = 35.4, y = 8.4 },
            { title = "Get to the Roots of It", side = "H", lvl = 56, giver = "Nara Wildmane", zone = "Thunder Bluff", x = 75.6, y = 31.0 },
            { title = "Blackmaw Magic", side = "A", lvl = 57, giver = "Archmage Timear", zone = "Alterac Mountains", x = 15.4, y = 74.0 },
            { title = "Blackmaw Magic", side = "H", lvl = 57, giver = "Muln Earthfury", zone = "Mulgore", x = 33.4, y = 22.5 },
            { title = "Claws that Rend, Tusks that Gore", obj = "Bring back the Claws of the Great Bear and the Tusks of the Unbroken.", side = "B", lvl = 57, giver = "Ogtinc", zone = "Azshara", x = 42.4, y = 42.7 },
            { title = "Blackmaw Pouches", obj = "Collect Blackmaw Pouches from the furbolgs inside.", side = "B", lvl = 57, giver = "Ekkal", zone = "Azshara", x = 42.0, y = 38.9 },
            { title = "The Twin Bears", side = "B", lvl = 58, giver = "Lorekeeper Nok", zone = "Azshara", x = 41.4, y = 20.0 },
            { title = "Blackmaw Reclamation", side = "B", lvl = 58, giver = "Gatekeeper Rageroar", zone = "Azshara", x = 42.4, y = 20.2,
              note = "Needs Report to Rageroar from Ekkal first." },
            { title = "A Lost Memento", obj = "Return the Feathered Charm Necklace that drops inside.", side = "B", lvl = 57, giver = "Feathered Charm Necklace (drop)", note = "Drops inside." },
        },
    },
    {
        name = "Shaper's Terrace", aliases = { "The Shaper's Terrace" },
        min = 58, max = 60, zone = "Un'Goro Crater", entrance = { 56.0, 12.0 },
        note = "Titan terrace on the north rim of the crater. Power crystals are used inside.",
        bosses = {
            { name = "Cinder", loot = { { "Heartflame Gauntlets", "", 52.3 }, { "Cinderedge Crescent", "", 46.4 } } }, { name = "Snowtalon", loot = { { "Crownroar Chestplate", "", 51.1 }, { "Albinofur Grips", "Hands, Mail", 47.8, id = 280026 } } }, { name = "Bolt", loot = { { "Bolt's Charged Eyeball", "", 52.5 }, { "Sparklance Wand", "", 47.2 } } }, { name = "Vitrix", loot = { { "Cinderedge Crescent", "", 20.4 }, { "Sparklance Wand", "", 19.2 }, { "Bolt's Charged Eyeball", "", 19.2 }, { "Crownroar Chestplate", "", 14.3 }, { "Heartflame Gauntlets", "", 13.5 }, { "Albinofur Grips", "Hands, Mail", 12.2, id = 280026 } } },
            { name = "Titanosaur", optional = true, loot = { { "Titanosaur Scale Pendant", "Neck", 55.9, id = 280009 }, { "Gargantuan Wristguards", "", 50.7 }, { "Deeproar Cord", "Waist, Cloth", 50.0, id = 280011 } } }, { name = "Tor'Rel", alias = "Izha'Rel and Tor'Rel", optional = true }, { name = "Venomridge", optional = true, loot = { { "Venomvessel Ring", "Finger", 33.7, id = 280015 }, { "Spiderchitin Wrap", "", 30.1 }, { "Octoclaw Chain Boots", "", 30.1 } } },
            { name = "Thunderhoof", optional = true, loot = { { "Deep Jungle Rifle", "", 35.5 }, { "Dinofrill Casque", "", 29.8 }, { "Hammer of Thundering Hooves", "", 29.3 } } }, { name = "Direhorn Matriarch", optional = true, loot = { { "Scaleguard Scimitar", "", 37.4 }, { "Tooth of the Matriarch", "", 33.7 }, { "Regal Direhorn Drape", "", 27.1 } } },
            { name = "Nanaya", final = true, loot = { { "Nanaya's Control Spire", "Two-Hand, Staff", 37.8, id = 280023 }, { "Leggings of Curation", "Legs, Cloth", 31.6, id = 280025 }, { "Legplates of Reinforced Crystal", "Legs, Plate", 24.8, id = 280024 }, { "Maker's Spark", "Crafting Reagent", 95.4, id = 273128 }, { "Blueprint: Arcane Forge", "Blueprint", 4.6, id = 273116 } } },
        },
        quests = {},
    },
}

-- Lookup by any name the Group Finder or the game uses.
local byKey
function ns.ForeverFor(name)
    if type(name) ~= "string" or not ns.Data then return nil end
    if not byKey then
        byKey = {}
        for _, d in ipairs(ns.ForeverDB) do
            byKey[ns.Data.Normalize(d.name)] = d
            for _, a in ipairs(d.aliases or {}) do byKey[ns.Data.Normalize(a)] = d end
        end
    end
    local key = ns.Data.Normalize(name)
    if not key then return nil end
    if byKey[key] then return byKey[key] end
    for k, d in pairs(byKey) do
        if #k >= 6 and #key >= 6 and (key:find(k, 1, true) or k:find(key, 1, true)) then return d end
    end
end
