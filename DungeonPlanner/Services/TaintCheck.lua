-- TaintCheck: /dp taint. WoW Forever's client writes no taint.log, so this looks for game
-- values that Dungeon Planner has tainted (the reason spells can stop casting from the
-- spellbook). The game's issecurevariable() says, for any global or table field, whether
-- it is still secure and which addon tainted it. We check every global, then the fields of
-- the spellbook, the window manager and the other frames we touch, and print what we find.
local ADDON, ns = ...

local TC = {}
ns.TaintCheck = TC

local FRAMES = {
    "PlayerSpellsFrame", "SpellBookFrame", "UIParent", "FramePositionDelegate", "WorldMapFrame",
    "QuestMapFrame", "LFGParentFrame", "PVEFrame", "SettingsPanel", "TaxiFrame", "GameTooltip",
    "QuestLogMicroButton", "UIPanelWindows", "UISpecialFrames", "StaticPopupDialogs", "Menu",
}

local function mine(by)
    return by == ADDON
end

local function checkTable(name, t, depth, seen, out)
    if type(t) ~= "table" or seen[t] or depth > 3 or #out > 40 then return end
    seen[t] = true
    for k, v in pairs(t) do
        if type(k) == "string" or type(k) == "number" then
            local ok, secure, by = pcall(issecurevariable, t, k)
            if ok and not secure and mine(by) then
                tinsert(out, name .. "." .. tostring(k))
            end
            if type(v) == "table" and type(k) == "string" and not k:find("^_") then
                checkTable(name .. "." .. k, v, depth + 1, seen, out)
            end
        end
    end
end

function TC.Run()
    if not issecurevariable then
        ns.Say("Taint check: this client has no issecurevariable().")
        return
    end
    local out, seen = {}, {}
    -- Every global Dungeon Planner has written or tainted (our own names are fine).
    for k in pairs(_G) do
        if type(k) == "string" then
            local ok, secure, by = pcall(issecurevariable, k)
            if ok and not secure and mine(by)
                and not k:find("^DungeonPlanner") and not k:find("^SLASH_DUNGEONPLANNER")
                and not k:find("^BINDING_") then
                tinsert(out, k)
            end
        end
    end
    -- Fields of the frames and tables that matter for the spellbook and windows.
    for _, name in ipairs(FRAMES) do
        local t = _G[name]
        if type(t) == "table" then checkTable(name, t, 1, seen, out) end
    end
    if #out == 0 then
        ns.Say("Taint check: nothing tainted by Dungeon Planner right now.")
    else
        ns.Say(("Taint check: %d value(s) tainted by Dungeon Planner:"):format(#out))
        for i = 1, math.min(#out, 40) do ns.Say("  " .. out[i]) end
    end
end
