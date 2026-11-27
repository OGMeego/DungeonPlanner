-- Namespace: the addon's shared table and safe API helpers.
-- WoW Forever runs the modern (Midnight-era) client with Lua 5.1. Some values can be
-- "secret" in instances and combat: every read from the game goes through Safe/Field.
local ADDON, ns = ...
local L = ns.L

ns.ADDON = ADDON
do
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(meta or function() end, ADDON, "Version")
    ns.VERSION = (ok and v) or "?"
end
ns.PREFIX = "DungeonPlnr" -- addon message prefix (max 16 characters)
ns.PROTOCOL = 1

-- Each module keeps state its files share in one private table (Journal, map, route...).
-- Nothing outside the module should touch it.
local private = {}
function ns.Private(module)
    private[module] = private[module] or {}
    return private[module]
end

-- ---------------------------------------------------------------------------
-- Safe helpers
-- ---------------------------------------------------------------------------

local isSecret = issecretvalue or function() return false end

-- A value we may use: nil when missing or secret.
function ns.Safe(v)
    if v == nil then return nil end
    local ok, secret = pcall(isSecret, v)
    if not ok or secret then return nil end
    return v
end

-- A table field we may use.
function ns.Field(t, key)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[key] end)
    if not ok then return nil end
    return ns.Safe(v)
end

local function pack(...) return { n = select("#", ...), ... } end

-- Call an API that may be missing or may error on this client. Returns its values or nil.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = pack(pcall(fn, ...))
    if not r[1] then return nil end
    return unpack(r, 2, r.n)
end

-- Same player -> same key. Names on WoW Forever can include a surname and a realm.
function ns.Key(name)
    name = ns.Safe(name)
    if type(name) ~= "string" or name == "" then return nil end
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "none")
        if ok and type(short) == "string" then name = short end
    end
    return strlower(name)
end

-- Short display name ("Name" for your realm, "Name-Realm" otherwise).
-- A character's name without the realm ("Dalah-Some Realm" -> "Dalah"). Group members
-- are matched by this: addon messages can carry a realm that UnitName doesn't (WoW
-- Forever's realms), and two people in one group never share a name.
function ns.Short(name)
    name = ns.Safe(name)
    if type(name) ~= "string" or name == "" then return nil end
    return (name:match("^([^%-]+)") or name)
end

function ns.SameName(a, b)
    a, b = ns.Short(a), ns.Short(b)
    return a ~= nil and b ~= nil and strlower(a) == strlower(b)
end

function ns.Display(name)
    name = ns.Safe(name)
    if type(name) ~= "string" then return "?" end
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "none")
        if ok and type(short) == "string" then return short end
    end
    return name
end

-- Always shown: answers to something you typed (/dp help, /dp debug...).
function ns.Say(...)
    local msg = strjoin(" ", tostringall(...))
    DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR:WrapTextInColorCode(L.ADDON_TITLE .. ":") .. " " .. msg)
end

-- Everything else the addon says in chat. Off with the "Dungeon Planner messages in chat"
-- setting (warnings still show on screen where they have their own alert).
function ns.Print(...)
    if ns.opt and ns.opt.chatMessages == false then return end
    ns.Say(...)
end

function ns.Now() return GetServerTime and GetServerTime() or time() end

function ns.Ago(seconds)
    if not seconds or seconds < 60 then return L.AGO_NOW end
    if seconds < 3600 then return L.AGO_MIN:format(floor(seconds / 60)) end
    if seconds < 86400 then return L.AGO_HOUR:format(floor(seconds / 3600)) end
    return L.AGO_DAY:format(floor(seconds / 86400))
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) end
end

-- Run fn at most once per `delay` seconds, coalescing bursts of calls.
function ns.Debounce(delay, fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        ns.After(delay, function()
            pending = false
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end)
    end
end

-- Class color for a class file name ("WARRIOR").
function ns.ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return c or NORMAL_FONT_COLOR
end

function ns.ClassName(classFile)
    if not classFile then return "" end
    local names = LOCALIZED_CLASS_NAMES_MALE
    return (names and names[classFile]) or (classFile:sub(1, 1) .. strlower(classFile:sub(2)))
end

-- Set an atlas if the client has it; returns true on success.
function ns.SetAtlas(tex, atlas, useSize)
    if not (tex and atlas) then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then return false end
    return pcall(tex.SetAtlas, tex, atlas, useSize and true or false) and true or false
end

-- Inline atlas markup for text, or "" when the atlas is missing.
function ns.AtlasMarkup(atlas, size)
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then return "" end
    if CreateAtlasMarkup then return CreateAtlasMarkup(atlas, size or 14, size or 14) end
    return ("|A:%s:%d:%d|a"):format(atlas, size or 14, size or 14)
end
