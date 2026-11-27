-- Events.lua
-- One event frame for the whole addon, plus internal messages between modules.
local _, ns = ...

-- ---------------------------------------------------------------------------
-- Events (one frame, handler lists; unknown events are skipped, not fatal)
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    tinsert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- Internal messages between modules (no game events involved).
local callbacks = {}
function ns.Listen(message, fn)
    callbacks[message] = callbacks[message] or {}
    tinsert(callbacks[message], fn)
end
function ns.Fire(message, ...)
    local list = callbacks[message]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end
