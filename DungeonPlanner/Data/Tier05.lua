-- Tier05.lua
-- The Tier 0.5 upgrade chain (patch 1.10 classic), step by step. Quest IDs and order from
-- CMaNGOS classic-db (GPL-3.0); the hints are Dungeon Planner's own words (Locales: T05_n).
-- A step is { title, ids, hint }: ids is a quest ID, a { A = id, H = id } pair, a
-- { class = id } table per faction (class steps), or { any = { ids } } when you do one of several.
local _, ns = ...

local A_CLASS = {
    earnest = { DRUID = 8905, HUNTER = 8906, MAGE = 8907, PALADIN = 8908, PRIEST = 8909, ROGUE = 8910, WARLOCK = 8911, WARRIOR = 8912 },
    comp    = { DRUID = 8926, HUNTER = 8931, MAGE = 8932, PALADIN = 8933, PRIEST = 8934, ROGUE = 8935, WARLOCK = 8936, WARRIOR = 8937 },
    parting = { DRUID = 8951, HUNTER = 8952, MAGE = 8953, PALADIN = 8954, PRIEST = 8955, ROGUE = 8956, WARLOCK = 8958, WARRIOR = 8959 },
    best    = { DRUID = 8999, HUNTER = 9000, MAGE = 9001, PALADIN = 9002, PRIEST = 9003, ROGUE = 9004, WARLOCK = 9005, WARRIOR = 9006 },
}
local H_CLASS = {
    earnest = { DRUID = 8913, HUNTER = 8914, MAGE = 8915, PRIEST = 8916, ROGUE = 8917, SHAMAN = 8918, WARLOCK = 8919, WARRIOR = 8920 },
    comp    = { DRUID = 8927, HUNTER = 8938, MAGE = 8939, PRIEST = 8940, ROGUE = 8941, SHAMAN = 8942, WARLOCK = 8943, WARRIOR = 8944 },
    parting = { SHAMAN = 8957, DRUID = 9016, HUNTER = 9017, MAGE = 9018, PRIEST = 9019, ROGUE = 9020, WARLOCK = 9021, WARRIOR = 9022 },
    best    = { DRUID = 9007, HUNTER = 9008, PRIEST = 9009, ROGUE = 9010, SHAMAN = 9011, WARLOCK = 9012, WARRIOR = 9013, MAGE = 9014 },
}

-- WoW Forever also has its own quest IDs for the four class steps (seen in Questie's Forever
-- quest tags; 97447 confirmed in Forever by player traces). A step counts as done with either.
local FOREVER = { earnest = { 97411, 97447 }, comp = { 97412, 97448 }, parting = { 97413, 97449 }, best = { 97414, 97450 } }

ns.Tier05Chain = {
    { "An Earnest Proposition", { class = "earnest" }, 1 },
    { "A Supernatural Device", { A = 8922, H = 8923 }, 2 },
    { "The Ectoplasmic Distiller", 8921, 3 },
    { "Hunting for Ectoplasm", 8924, 4 },
    { "A Portable Power Source", 8925, 5 },
    { "A Shifty Merchant", 8928, 6 },
    { "Return to Deliana / Mokvar", { A = 8977, H = 8978 }, 7 },
    { "Just Compensation", { class = "comp" }, 8 },
    { "In Search of Anthion", { A = 8929, H = 8930 }, 9 },
    { "Dead Man's Plea", 8945, 10 },
    { "Proof of Life", 8946, 11 },
    { "Anthion's Strange Request", 8947, 12 },
    { "Anthion's Old Friend", 8948, 13 },
    { "Falrin's Vendetta", 8949, 14 },
    { "The Instigator's Enchantment", 8950, 15 },
    { "The Challenge", 9015, 16 },
    { "Anthion's Parting Words", { class = "parting" }, 17 },
    { "Bodley's Unfortunate Fate", { A = 8960, H = 9032 }, 18 },
    { "Three Kings of Flame", 8961, 19 },
    { "Components of Importance", { any = { 8962, 8963, 8964, 8965 } }, 20 },
    { "The Left Piece of Lord Valthalak's Amulet", { any = { 8966, 8967, 8968, 8969 } }, 21 },
    { "I See Alcaz Island In Your Future...", 8970, 22 },
    { "More Components of Importance", { any = { 8985, 8986, 8987, 8988 } }, 23 },
    { "The Right Piece of Lord Valthalak's Amulet", { any = { 8989, 8990, 8991, 8992 } }, 24 },
    { "Final Preparations", 8994, 25 },
    { "Mea Culpa, Lord Valthalak", 8995, 26 },
    { "Return to Bodley", 8996, 27 },
    { "Back to the Beginning", { A = 8997, H = 8998 }, 28 },
    { "Saving the Best for Last", { class = "best" }, 29 },
}

-- The quest IDs a step means for a faction and class: a list (done when any is done).
function ns.Tier05Ids(step, side, class)
    local ids = step[2]
    if type(ids) == "number" then return { ids } end
    if ids.any then return ids.any end
    if ids.class then
        local t = (side == "A" and A_CLASS or H_CLASS)[ids.class]
        local out = {}
        if class and t[class] then out[1] = t[class]
        else for _, id in pairs(t) do out[#out + 1] = id end end
        for _, id in ipairs(FOREVER[ids.class] or {}) do out[#out + 1] = id end
        return out
    end
    return { ids[side] }
end
