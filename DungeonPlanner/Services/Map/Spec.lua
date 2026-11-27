-- DungeonMap: the game's own dungeon map art with numbered bosses in kill order, the
-- entrance, a route line, and ticks for bosses you've killed.
--
-- Floors come from (1) the map IDs the game uses for each classic dungeon, (2) floors the
-- addon saw you stand on inside a dungeon, (3) dungeon maps named like the dungeon.
-- Bosses are placed by (1) the game's world -> map conversion, (2) our own math from the
-- floor's corners, (3) where you stood when you killed them. When the game has no map
-- picture at all (Forever's new dungeons), the tab draws the route as a boss-order chart.
local _, ns = ...
local P = ns.Private("DMap")
local L = ns.L

local DMap = {}
ns.DMap = DMap

local DUNGEON_TYPE = 4
local B_ENC, B_NPC, B_NAME, B_LVL, B_WX, B_WY, B_DISPLAY = 1, 2, 3, 4, 5, 6, 7
-- Map numbers to search. Forever numbers its own new maps from one million up.
P.SCAN_RANGES = { { 1, 4000 }, { 1000000, 1006000 } }

-- The game's floor maps for each classic instance (instance map ID -> uiMap IDs).
P.FLOORS = {
    [389] = { 213 }, [43] = { 279 }, [36] = { 291, 292 }, [33] = { 310, 311, 312, 313, 314, 315, 316 },
    [48] = { 221, 222, 223 }, [34] = { 225 }, [90] = { 226, 227, 228, 229 }, [47] = { 301 },
    [189] = { 302, 303, 304, 305 }, [129] = { 300 }, [70] = { 230, 231 }, [209] = { 219 },
    [349] = { 280, 281, 67, 68 }, [109] = { 220 }, [230] = { 242, 243 }, [229] = { 250, 251, 252, 253, 254, 255 },
    [429] = { 234, 235, 236, 237, 238, 239, 240 }, [289] = { 306, 307, 308, 309 }, [329] = { 317, 318 },
    [409] = { 232 }, [249] = { 248 }, [469] = { 287, 288, 289, 290 }, [309] = { 233 }, [509] = { 247 },
    [531] = { 320, 319, 321 }, [533] = { 166, 163, 165, 164, 162, 167 },
}
-- Blackrock Spire's upper floors as Forever numbers them.
for _, m in ipairs({ 1002295, 1002296, 1002297 }) do tinsert(P.FLOORS[229], m) end
DMap.FLOORS = P.FLOORS

function P.key(name) return ns.Data.Normalize(name) end

-- ---------------------------------------------------------------------------
-- What to draw: one "spec" per page, the same shape for database and Forever dungeons
-- ---------------------------------------------------------------------------

-- A boss's portrait model: the one we were given, else the portrait table (Data/BossArt.lua).
function DMap.DisplayFor(name, alias, given)
    if given and given > 0 then return given end
    local t = ns.BossDisplay
    return t and (t[name] or (alias and t[alias])) or nil
end
-- An icon for bosses that have no model (Data/BossArt.lua).
function DMap.IconFor(name, alias)
    local t = ns.BossIcon
    return t and (t[name] or (alias and t[alias])) or nil
end

-- A Forever boss's level (Data/BossArt.lua), else nil.
function DMap.LevelFor(dungeon, name, alias)
    local t = ns.BossLevel and ns.BossLevel[dungeon]
    return t and (t[name] or (alias and t[alias])) or nil
end

-- spec = { key, name, instanceID?, start = { wx, wy }?, bosses = { { index, name, npc?, enc?, lvl?, wx?, wy?, optional? } } }
function DMap.SpecForDungeon(mapID)
    local d = ns.DB.dungeons[mapID]
    if not d then return nil end
    local spec = { key = P.key(d.name), name = d.name, instanceID = mapID, start = d.start, bosses = {}, marks = {}, db = true }
    for i, b in ipairs(d.bosses) do
        tinsert(spec.bosses, { index = i, name = b[B_NAME], npc = b[B_NPC], enc = b[B_ENC], lvl = b[B_LVL], wx = b[B_WX], wy = b[B_WY],
            display = DMap.DisplayFor(b[B_NAME], nil, b[B_DISPLAY]) })
    end
    -- Quest markers: { questID, kind, wx, wy, name }  kind: s start, e turn in, k kill, i item, u use
    for _, q in ipairs(d.qmarks or {}) do
        tinsert(spec.marks, { quest = q[1], kind = q[2], wx = q[3], wy = q[4], what = q[5] })
    end
    return spec
end

function DMap.SpecForActivity(a)
    local name = a.fullName or a.name
    local f = ns.ForeverFor and ns.ForeverFor(name)
    local spec = { key = P.key(f and f.name or name), name = f and f.name or name, instanceID = a.mapID, bosses = {}, forever = f }
    if f then
        local names = { f.name, name }
        for _, al in ipairs(f.aliases or {}) do tinsert(names, al) end
        for i, b in ipairs(f.bosses) do
            local display = ns.EJ and (ns.EJ.Display(names, b.name) or (b.alias and ns.EJ.Display(names, b.alias)))
            tinsert(spec.bosses, { index = i, name = b.name, alias = b.alias, optional = b.optional, final = b.final,
                display = DMap.DisplayFor(b.name, b.alias, display), lvl = DMap.LevelFor(f.name, b.name, b.alias) })
        end
    else
        for i, n in ipairs(ns.Tracker and ns.Tracker.BossesForName(name) or {}) do
            tinsert(spec.bosses, { index = i, name = n })
        end
    end
    return spec
end
