-- Plans.lua
-- Pull plans: a named set of drawings for a whole dungeon (every floor), saved so you can
-- keep a few ("Tank route", "Skip trash"...), load one onto the maps, and share it all.
-- Saved: ns.db.pullPlans[dungeon][name] = { floors = { [floor] = drawing }, saved = time }
local _, ns = ...
local L = ns.L
local MD = ns.MapDraw
local P = ns.Private("MapDraw")

local function dungeonOf(k) return k and k:match("^(.*)#%d+$") end
function MD.Dungeon() return dungeonOf(P.key) end

local function store(dungeon)
    ns.db.pullPlans = ns.db.pullPlans or {}
    ns.db.pullPlans[dungeon] = ns.db.pullPlans[dungeon] or {}
    return ns.db.pullPlans[dungeon]
end

-- The drawings on every floor of a dungeon: { [floor] = drawing }
local function floorsOf(dungeon)
    local out = {}
    for k, d in pairs(ns.db.mapDraw or {}) do
        local dn, f = k:match("^(.*)#(%d+)$")
        if dn == dungeon and (#d.strokes + #d.markers + #d.texts) > 0 then out[tonumber(f)] = d end
    end
    return out
end

function MD.Plans(dungeon)
    local names = {}
    for name in pairs(dungeon and store(dungeon) or {}) do tinsert(names, name) end
    table.sort(names)
    return names
end

function MD.SavePlan(name, dungeon)
    dungeon = dungeon or MD.Dungeon()
    name = name and strtrim(name)
    if not (dungeon and name and name ~= "") then return false end
    local floors = floorsOf(dungeon)
    if not next(floors) then ns.Print(L.PLAN_NOTHING) return false end
    store(dungeon)[name] = { floors = CopyTable(floors), saved = ns.Now() }
    ns.Print(L.PLAN_SAVED:format(name))
    return true
end

function MD.LoadPlan(name, dungeon)
    dungeon = dungeon or MD.Dungeon()
    local plan = dungeon and store(dungeon)[name]
    if not plan then return false end
    ns.db.mapDraw = ns.db.mapDraw or {}
    for f in pairs(floorsOf(dungeon)) do ns.db.mapDraw[dungeon .. "#" .. f] = nil end
    for f, d in pairs(plan.floors) do ns.db.mapDraw[dungeon .. "#" .. f] = CopyTable(d) end
    if P.render then P.render() end
    ns.Print(L.PLAN_LOADED:format(name))
    return true
end

function MD.DeletePlan(name, dungeon)
    dungeon = dungeon or MD.Dungeon()
    if dungeon and store(dungeon)[name] then
        store(dungeon)[name] = nil
        ns.Print(L.PLAN_DELETED:format(name))
        return true
    end
    return false
end

-- Load it here and send every floor to the group.
function MD.SharePlan(name, dungeon)
    dungeon = dungeon or MD.Dungeon()
    if not MD.LoadPlan(name, dungeon) then return false end
    if not MD.Channel() then ns.Print(L.DRAW_NO_GROUP) return false end
    local n = 0
    for f in pairs(store(dungeon)[name].floors) do
        if MD.ShareKey(dungeon .. "#" .. f, true) then n = n + 1 end
    end
    ns.Print(L.PLAN_SHARED:format(name, n))
    return true
end

StaticPopupDialogs.DUNGEONPLANNER_PLANNAME = {
    text = L.PLAN_NAME_PROMPT, button1 = OKAY or "OK", button2 = CANCEL or "Cancel",
    hasEditBox = true, maxLetters = 32,
    OnAccept = function(self, dungeon)
        local box = self.editBox or self.EditBox
        MD.SavePlan(box and box:GetText(), dungeon)
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        MD.SavePlan(self:GetText(), parent.data)
        parent:Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- The Plans menu on the map.
function MD.PlansMenu(owner)
    local dungeon = MD.Dungeon()
    if not (dungeon and MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.PLAN_TITLE)
        root:CreateButton(L.PLAN_SAVE_NEW, function()
            if StaticPopup_Show then StaticPopup_Show("DUNGEONPLANNER_PLANNAME", nil, nil, dungeon) end
        end)
        local names = MD.Plans(dungeon)
        if #names == 0 then root:CreateButton(GRAY_FONT_COLOR:WrapTextInColorCode(L.PLAN_NONE), function() end) end
        for _, name in ipairs(names) do
            local sub = root:CreateButton(name)
            if sub and sub.CreateButton then
                sub:CreateButton(L.PLAN_LOAD, function() MD.LoadPlan(name, dungeon) end)
                sub:CreateButton(L.PLAN_SHARE, function() MD.SharePlan(name, dungeon) end)
                sub:CreateButton(L.PLAN_DELETE, function() MD.DeletePlan(name, dungeon) end)
            end
        end
    end)
end
