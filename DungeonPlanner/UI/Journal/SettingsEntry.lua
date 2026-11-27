-- SettingsEntry.lua
-- "Settings" at the bottom of the journal's page list: Dungeon Planner's options, right in
-- the journal (the same options as in the game's Esc > Options > AddOns).
local _, ns = ...
local L = ns.L
local J = ns.Journal

J.RegisterPage("settings", { nav = L.HUB_SETTINGS, iconTex = "Interface\\Icons\\INV_Misc_Gear_01", order = 90,
    title = function() return L.HUB_SETTINGS end,
    rows = function() return {} end })

-- Show the options over the content area while the Settings page is up.
local P = ns.Private("Journal")
function J.SyncSettingsPanel()
    local f = P.frame
    if not f then return end
    local on = P.current and P.current.kind == "settings"
    if on and ns.OptionsPanelIn then
        local panel = ns.OptionsPanelIn(f.contentInset)
        panel:SetFrameLevel(f.content:GetFrameLevel() + 20)
        panel:Show()
    elseif ns.OptionsPanelIn and f.contentInset then
        local panel = ns.OptionsPanelIn(f.contentInset)
        if panel:IsShown() then panel:Hide() end
    end
end
