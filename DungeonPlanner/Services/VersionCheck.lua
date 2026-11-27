-- VersionCheck.lua
-- Players with Dungeon Planner say which version they have in their hello message. When
-- someone has a newer one, say so once (per session): old versions mean old bugs.
local _, ns = ...
local L = ns.L
local V = {}
ns.VersionCheck = V

-- "5.2.43" -> { 5, 2, 43 }; anything that isn't a version gives nil.
local function parts(v)
    if type(v) ~= "string" or not v:match("^%d+[%.%d]*$") then return nil end
    local t = {}
    for n in v:gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end

-- Is a newer than b?
function V.Newer(a, b)
    local pa, pb = parts(a), parts(b)
    if not (pa and pb) then return false end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

V.newest = nil
local told = false

function V.Saw(version, sender)
    if not V.Newer(version, ns.VERSION) then return end
    if V.newest and not V.Newer(version, V.newest) then return end
    V.newest = version
    ns.db.newestSeen = version
    if told then return end
    told = true
    ns.After(2, function()
        ns.Say(L.VERSION_NEWER:format(version, ns.VERSION))
    end)
end

-- After an update, forget the newer version we'd seen.
ns.Listen("LOGIN", function()
    if ns.db.newestSeen and not V.Newer(ns.db.newestSeen, ns.VERSION) then ns.db.newestSeen = nil end
    V.newest = ns.db.newestSeen
end)
