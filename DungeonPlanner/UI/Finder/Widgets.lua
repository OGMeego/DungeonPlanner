-- UI: the "Dungeon Planner" side tab and panel inside Blizzard's Group Finder.
-- Everything is built from Blizzard's own templates and atlases (the same ones the Browse
-- Groups window uses), so it reads as part of the game. We never write to Blizzard's
-- frames or variables: that would taint the Group Finder and block its searches.
local _, ns = ...
local P = ns.Private("Finder.UI")
local L = ns.L

local UI = {}
ns.UI = UI

local ROW_H = 58
local GROUP_FINDER_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local REFRESH_MACRO = "/click LFGBrowseFrameRefreshButton"
local TAB_ICON = "Interface\\Icons\\INV_Misc_Map_01"

P.ROLE_ATLAS = {
    tank = "groupfinder-icon-role-large-tank",
    healer = "groupfinder-icon-role-large-heal",
    dps = "groupfinder-icon-role-large-dps",
}
P.ROLE_MICRO = {
    tank = "groupfinder-icon-role-micro-tank",
    healer = "groupfinder-icon-role-micro-heal",
    dps = "groupfinder-icon-role-micro-dps",
}
P.ROLE_ORDER = { "tank", "healer", "dps" }

P.panel, P.sideTab = nil
P.selectedKey = nil       -- key of the selected row (per tab)
P.activeTab = 1     -- 1 = groups & players, 2 = applicants
P.rowsData = {}

-- ---------------------------------------------------------------------------
-- Small widget helpers (all Blizzard templates)
-- ---------------------------------------------------------------------------

function P.Text(parent, font, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK", font or "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

function P.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function P.Tooltip(owner, title, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    for _, line in ipairs(lines or {}) do
        if type(line) == "table" then
            GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 0.82, line[4] or 0, true)
        else
            GameTooltip:AddLine(line, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        end
    end
    GameTooltip:Show()
end

function P.colorize(text, color)
    if not color then return text end
    return color:WrapTextInColorCode(text)
end
