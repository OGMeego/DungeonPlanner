-- Wings: dungeons that are really several runs. Boss -> wing, and each wing's last boss.
local _, ns = ...

ns.Wings = {
    ["Scarlet Monastery"] = {
        { name = "WING_SM_GRAVEYARD", last = "Bloodmage Thalnos", bosses = { "Interrogator Vishas", "Bloodmage Thalnos", "Azshir the Sleepless", "Fallen Champion", "Ironspine" } },
        { name = "WING_SM_LIBRARY", last = "Arcanist Doan", bosses = { "Houndmaster Loksey", "Arcanist Doan" } },
        { name = "WING_SM_ARMORY", last = "Herod", bosses = { "Herod" } },
        { name = "WING_SM_CATHEDRAL", last = "High Inquisitor Whitemane", bosses = { "High Inquisitor Fairbanks", "Scarlet Commander Mograine", "High Inquisitor Whitemane" } },
    },
    ["Dire Maul"] = {
        { name = "WING_DM_EAST", last = "Alzzin the Wildshaper", bosses = { "Pusillin", "Zevrim Thornhoof", "Hydrospawn", "Lethtendris", "Alzzin the Wildshaper" } },
        { name = "WING_DM_WEST", last = "Prince Tortheldrin", bosses = { "Tendris Warpwood", "Illyanna Ravenoak", "Magister Kalendris", "Immol'thar", "Tsu'zee", "Prince Tortheldrin" } },
        { name = "WING_DM_NORTH", last = "King Gordok", bosses = { "Guard Mol'dar", "Stomper Kreeg", "Guard Fengus", "Guard Slip'kik", "Captain Kromcrush", "Cho'Rush the Observer", "King Gordok" } },
    },
    ["Blackrock Spire"] = {
        { name = "WING_BRS_LOWER", last = "Overlord Wyrmthalak", bosses = { "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone", "Mother Smolderweb", "Urok Doomhowl", "Quartermaster Zigris", "Halycon", "Gizrul the Slavener", "Overlord Wyrmthalak" } },
        { name = "WING_BRS_UPPER", last = "General Drakkisath", bosses = { "Pyroguard Emberseer", "Solakar Flamewreath", "Jed Runewatcher", "Goraluk Anvilcrack", "Warchief Rend Blackhand", "Gyth", "The Beast", "General Drakkisath" } },
    },
}

-- The wing a boss belongs to, for a dungeon: wing table or nil.
function ns.WingOf(dungeon, boss)
    local wings = dungeon and ns.Wings[dungeon:gsub("^The ", "")]
    if not (wings and boss) then return nil end
    local key = ns.Data.Normalize(boss)
    for _, w in ipairs(wings) do
        for _, b in ipairs(w.bosses) do
            if ns.Data.Normalize(b) == key then return w end
        end
    end
end
