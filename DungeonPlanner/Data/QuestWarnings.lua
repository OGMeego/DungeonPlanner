-- QuestWarnings: one line on quests that trip people up: parts done outside the dungeon,
-- or something you must (not) do inside. By quest ID (database quests) or title (Forever).
local _, ns = ...

ns.QuestWarnings = {
    byID = {
        [721] = "Done outside the dungeon, at the Uldaman dig site.",            -- A Sign of Hope
        [722] = "Done outside the dungeon: Magregan Deepshadow is at the dig site.", -- Amulet of Secrets
        [723] = "Done outside the dungeon, at the Uldaman dig site.",            -- Prospect of Faith
        [704] = "The Carved Stone Urns are on the ground at the dig site outside the dungeon.", -- Agmond's Fate
        [2283] = "The necklace drops at the dig site outside the dungeon.",       -- Necklace Recovery
        [1360] = "The chest is outside the instance, in the dig site.",          -- Reclaimed Treasures
        [2342] = "The Garrett Family Chest is outside the instance, in the dig site.", -- Reclaimed Treasures (Horde)
    },
    byTitle = {
        ["More Valuable Than Gold"] = "Don't kill The Questioner before the last boss, or you can't get this quest.",
        ["Dark Iron Legacy"] = "You have to be a ghost to talk to Franclorn Forgewright, in Blackrock Mountain on the way down to Blackrock Depths.",
    },
}
