-- Core.lua
-- Point d'entrée de l'addon : initialisation, events principaux, coordination.

-- Namespace global de l'addon
TC = TC or {}

-- ============================================================
-- Utilitaires de base
-- ============================================================

--- Affiche un message dans le chat avec le préfixe de l'addon.
--- @param msg string
function TC.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[TC]|r " .. tostring(msg))
end

--- Affiche un message de debug si le mode debug est activé.
--- @param msg string
function TC.Debug(msg)
    if TC.db and TC.db.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[TC Debug]|r " .. tostring(msg))
    end
end

-- ============================================================
-- Détection du type de contenu
-- ============================================================

--- Retourne le type de contenu actuel.
--- @return string  "raid", "group" ou "solo"
function TC.GetContentType()
    if IsInRaid() then
        return "raid"
    elseif IsInGroup() then
        return "group"
    else
        return "solo"
    end
end

-- ============================================================
-- Frame d'événements principale
-- ============================================================

local eventFrame = CreateFrame("Frame", "TCEventFrame", UIParent)

-- Flag de combat : toutes les vérifications sont suspendues en combat
TC.inCombat = false

-- Vérification périodique (toutes les 30 secondes, hors combat)
local CHECK_INTERVAL = 30
local timeSinceLastCheck = 0

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    if TC.inCombat then
        timeSinceLastCheck = 0
        return
    end
    timeSinceLastCheck = timeSinceLastCheck + elapsed
    if timeSinceLastCheck >= CHECK_INTERVAL then
        timeSinceLastCheck = 0
        if TC.initialized then
            TC.RunAllChecks()
        end
    end
end)

-- ============================================================
-- Vérification complète
-- ============================================================

--- Lance toutes les vérifications et met à jour les alertes.
--- Ne fait rien en combat.
function TC.RunAllChecks()
    if TC.inCombat then return end

    local contentType = TC.GetContentType()
    TC.Debug("RunAllChecks — contenu : " .. contentType)
    TC.AlertUI.UpdateAll(contentType)
end

-- ============================================================
-- Gestion des événements
-- ============================================================

local function OnAddonLoaded(addonName)
    if addonName ~= "TalentSentry" then return end

    TC.SavedVars.Init()
    TC.ConfigUI.Init()

    TC.Debug("ADDON_LOADED — SavedVars initialisées.")
end

local function OnPlayerLogin()
    TC.AlertUI.Init()
    TC.AlertUI.SetLocked(TC.SavedVars.IsLocked())

    TC.initialized = true

    C_Timer.After(2, function()
        TC.RunAllChecks()
    end)

    TC.Debug("Addon initialisé pour " .. UnitName("player"))
end

local function OnPlayerEnteringWorld()
    if not TC.initialized then return end
    C_Timer.After(1, function()
        TC.RunAllChecks()
    end)
end

local function OnPlayerRegenDisabled()
    TC.inCombat = true
    if TC.initialized then
        TC.AlertUI.HideAll()
    end
    TC.Debug("Combat débuté — alertes suspendues.")
end

local function OnPlayerRegenEnabled()
    TC.inCombat = false
    TC.Debug("Combat terminé — reprise des vérifications.")
    if TC.initialized then
        C_Timer.After(1.5, function()
            TC.RunAllChecks()
        end)
    end
end

local function OnTalentConfigUpdated()
    if not TC.initialized then return end
    TC.Debug("Talents modifiés, relance du check.")
    C_Timer.After(0.5, function()
        TC.RunAllChecks()
    end)
end

local function OnPlayerSpecializationChanged()
    if not TC.initialized then return end
    TC.Debug("Spécialisation changée, relance du check.")
    C_Timer.After(0.5, function()
        TC.RunAllChecks()
    end)
end

-- ============================================================
-- Enregistrement des événements
-- ============================================================

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld()
    elseif event == "TRAIT_CONFIG_UPDATED" then
        OnTalentConfigUpdated()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        OnPlayerSpecializationChanged()
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnPlayerRegenDisabled()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnPlayerRegenEnabled()
    end
end)

-- ============================================================
-- Commandes slash
-- ============================================================

SLASH_TALENTSENTRY1 = "/talentsentry"

SlashCmdList["TALENTSENTRY"] = function(args)
    local cmd = args and args:match("^%s*(%S*)") or ""
    cmd = cmd:lower()

    if cmd == "config" then
        TC.ConfigUI.Open()
    elseif cmd == "debug" then
        local current = TC.SavedVars.IsDebug()
        TC.SavedVars.SetDebug(not current)
        TC.Print(not current and TC_L.DEBUG_ON or TC_L.DEBUG_OFF)
    elseif cmd == "lock" then
        local locked = not TC.SavedVars.IsLocked()
        TC.SavedVars.SetLocked(locked)
        TC.AlertUI.SetLocked(locked)
        TC.Print(locked and TC_L.CONFIG_LOCKED_ON or TC_L.CONFIG_LOCKED_OFF)
    elseif cmd == "reset" then
        TC.SavedVars.ResetPositions()
        TC.AlertUI.ResetPositions()
        TC.Print(TC_L.CONFIG_RESET_POS)
    elseif cmd == "check" then
        TC.RunAllChecks()
    else
        TC.Print(TC_L.SLASH_HELP)
    end
end
