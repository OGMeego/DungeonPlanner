-- Share.lua
-- Sharing: pack, compress and send in chunks over the group's addon channel.
local _, ns = ...
local L = ns.L
local MD = ns.MapDraw
local PREFIX = "DPMap"
local CHUNK = 230
local PACE = 0.06
local DRAW_W = 3
local P = ns.Private("MapDraw")

-- ---------------------------------------------------------------------------
-- Sharing: pack -> compress -> chunks over the group's addon channel
-- ---------------------------------------------------------------------------

local function deflate()
    return _G.DungeonPlanner_LibDeflate or (LibStub and LibStub("LibDeflate", true))
end

local function c9(c) return math.floor(c * 9 + 0.5) end

function MD.Pack(k, d)
    local out = { "1", "K\t" .. k }
    for _, s in ipairs(d.strokes or {}) do
        local o, px, py = {}, 0, 0
        for i = 1, #s.pts - 1, 2 do
            local x, y = math.floor(s.pts[i] * 1000 + 0.5), math.floor(s.pts[i + 1] * 1000 + 0.5)
            o[#o + 1] = (x - px) .. "," .. (y - py)
            px, py = x, y
        end
        local c = s.color or P.COLORS[1]
        out[#out + 1] = "S\t" .. c9(c[1]) .. c9(c[2]) .. c9(c[3]) .. "\t" .. (s.w or DRAW_W) .. "\t" .. table.concat(o, ";")
    end
    for _, m in ipairs(d.markers or {}) do
        out[#out + 1] = ("M\t%d\t%d\t%d\t%d"):format(m.i, math.floor(m.x * 1000 + 0.5), math.floor(m.y * 1000 + 0.5), m.size or 26)
    end
    for _, t in ipairs(d.texts or {}) do
        local c = t.color or { 1, 0.95, 0.6 }
        out[#out + 1] = ("T\t%d\t%d\t%d\t%d%d%d\t%s"):format(math.floor(t.x * 1000 + 0.5), math.floor(t.y * 1000 + 0.5),
            t.size or 14, c9(c[1]), c9(c[2]), c9(c[3]), (t.text or ""):gsub("[\t\n]", " "))
    end
    return table.concat(out, "\n")
end

function MD.Unpack(str)
    local d = { strokes = {}, markers = {}, texts = {} }
    local k
    for line in (str .. "\n"):gmatch("([^\n]*)\n") do
        local tag, rest = line:match("^(%a)\t(.*)$")
        if tag == "K" then
            k = rest
        elseif tag == "S" then
            local col, w, body = rest:match("^(%d%d%d)\t(%d+)\t(.*)$")
            if col then
                local pts, px, py = {}, 0, 0
                for dx, dy in body:gmatch("(-?%d+),(-?%d+)") do
                    px, py = px + tonumber(dx), py + tonumber(dy)
                    pts[#pts + 1] = P.clamp01(px / 1000); pts[#pts + 1] = P.clamp01(py / 1000)
                end
                if #pts >= 4 then
                    tinsert(d.strokes, { pts = pts, w = tonumber(w),
                        color = { tonumber(col:sub(1, 1)) / 9, tonumber(col:sub(2, 2)) / 9, tonumber(col:sub(3, 3)) / 9 } })
                end
            end
        elseif tag == "M" then
            local i, x, y, s = rest:match("^(%d)\t(%d+)\t(%d+)\t(%d+)$")
            if i and tonumber(i) >= 1 and tonumber(i) <= 8 then
                tinsert(d.markers, { i = tonumber(i), x = P.clamp01(tonumber(x) / 1000), y = P.clamp01(tonumber(y) / 1000), size = tonumber(s) })
            end
        elseif tag == "T" then
            local x, y, s, col, text = rest:match("^(%d+)\t(%d+)\t(%d+)\t(%d%d%d)\t(.*)$")
            if x then
                tinsert(d.texts, { x = P.clamp01(tonumber(x) / 1000), y = P.clamp01(tonumber(y) / 1000), size = tonumber(s),
                    text = text:sub(1, 60),
                    color = { tonumber(col:sub(1, 1)) / 9, tonumber(col:sub(2, 2)) / 9, tonumber(col:sub(3, 3)) / 9 } })
            end
        end
    end
    return k, d
end

local function checksum(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%x"):format(h)
end

local function channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end
MD.Channel = channel

local queue, pumping = {}, false
local function pump()
    local item = table.remove(queue, 1)
    if not item then pumping = false return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, item.msg, item.ch) end
    if C_Timer and C_Timer.After then C_Timer.After(PACE, pump) else pump() end
end
local function send(msg, ch)
    tinsert(queue, { msg = msg, ch = ch })
    if not pumping then pumping = true; pump() end
end

function MD.Encode(payload)
    local lib = deflate()
    if lib then return lib:EncodeForWoWAddonChannel(lib:CompressDeflate(payload)), "D" end
    return payload:gsub("\n", "\1"), "R"
end

function MD.Decode(transport, fmt)
    if fmt == "D" then
        local lib = deflate()
        local raw = lib and lib:DecodeForWoWAddonChannel(transport)
        return raw and lib:DecompressDeflate(raw)
    end
    return (transport:gsub("\1", "\n"))
end

function MD.Share() return MD.ShareKey(P.key) end

-- Send one floor's drawing (key = "dungeon#floor") to the group.
function MD.ShareKey(k, quiet)
    local d = k and ns.db.mapDraw and ns.db.mapDraw[k]
    local ch = channel()
    if not ch then return ns.Print(L.DRAW_NO_GROUP) end
    if not k then return end
    -- An empty map is shared too: it clears everyone else's drawing for this floor.
    local empty = not (d and (#d.strokes + #d.markers + #d.texts) > 0)
    local payload = MD.Pack(k, d or { strokes = {}, markers = {}, texts = {} })
    local enc, fmt = MD.Encode(payload)
    local id = tostring(math.floor((GetTime and GetTime() or 0) * 1000) % 100000000)
    local chunks = {}
    for i = 1, #enc, CHUNK do chunks[#chunks + 1] = enc:sub(i, i + CHUNK - 1) end
    send(("B|%s|%d|%s|%s"):format(id, #chunks, fmt, checksum(enc)), ch)
    for i, c in ipairs(chunks) do send(("D|%s|%d|%s"):format(id, i, c), ch) end
    if not quiet then ns.Print(empty and L.DRAW_SENT_CLEAR or L.DRAW_SENT) end
    return true
end

-- Open a shared drawing's map (after combat if you're fighting).
local pendingOpen
function MD.OpenShared(k)
    if InCombatLockdown and InCombatLockdown() then pendingOpen = k return end
    local dungeon, floor = k:match("^(.*)#(%d+)$")
    if dungeon and ns.DMap then ns.DMap.OpenOn(dungeon, tonumber(floor)) end
end
ns.On("PLAYER_REGEN_ENABLED", function()
    if pendingOpen then
        local k = pendingOpen
        pendingOpen = nil
        MD.OpenShared(k)
    end
end)

-- Receiving
local incoming = {}
function MD.OnMessage(prefix, msg, _, sender)
    if prefix ~= PREFIX or type(msg) ~= "string" then return end
    sender = ns.Safe(sender)
    if not sender then return end
    if ns.Key and ns.Key(sender) == ns.Key(UnitName("player")) then return end
    local id, n, fmt, cs = msg:match("^B|(%d+)|(%d+)|(%a)|(%x+)$")
    if id then
        incoming[sender .. id] = { n = tonumber(n), fmt = fmt, cs = cs, parts = {}, got = 0 }
        return
    end
    local id2, i, chunk = msg:match("^D|(%d+)|(%d+)|(.*)$")
    local t = id2 and incoming[sender .. id2]
    if not t then return end
    i = tonumber(i)
    if not t.parts[i] then t.parts[i] = chunk; t.got = t.got + 1 end
    if t.got < t.n then return end
    incoming[sender .. id2] = nil
    local enc = table.concat(t.parts)
    if checksum(enc) ~= t.cs then return end
    local payload = MD.Decode(enc, t.fmt)
    if not payload then return end
    local k, d = MD.Unpack(payload)
    if not k then return end
    ns.db.mapDraw = ns.db.mapDraw or {}
    local who = Ambiguate and Ambiguate(sender, "short") or sender
    if (#d.strokes + #d.markers + #d.texts) == 0 then
        -- They cleared it: clear ours too.
        ns.db.mapDraw[k] = nil
        if P.key == k then P.render() end
        return ns.Print(L.DRAW_RECEIVED_CLEAR:format(who, (k:gsub("#(%d+)$", " (%1)"))))
    end
    ns.db.mapDraw[k] = d
    if P.key == k then P.render() end
    if ns.opt.openSharedMaps then
        ns.Print(L.DRAW_RECEIVED_OPEN:format(who))
        MD.OpenShared(k)
    else
        ns.Print(L.DRAW_RECEIVED:format(who, (k:gsub("#(%d+)$", " (%1)"))))
    end
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
ns.On("CHAT_MSG_ADDON", MD.OnMessage)
