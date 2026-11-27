-- ForeverText.lua
-- Forever dungeon notes and quest objectives in your language: Locales/Notes/<lang>.lua can
-- give a translation for each English text (ns.LocaleNotes.forever = { [english] = text }).
local _, ns = ...

local function walk(t, tr, seen)
    if seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        if (k == "note" or k == "obj") and type(v) == "string" and tr[v] then
            t[k] = tr[v]
        elseif type(v) == "table" then
            walk(v, tr, seen)
        end
    end
end

function ns.ApplyForeverText()
    local tr = ns.LocaleNotes and ns.LocaleNotes.forever
    if tr and ns.ForeverDB then walk(ns.ForeverDB, tr, {}) end
end
ns.ApplyForeverText()
