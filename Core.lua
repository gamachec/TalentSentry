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
-- Cache d'instance
-- ============================================================

--- Met à jour le cache d'instance.
--- Appelé sur PLAYER_ENTERING_WORLD et ZONE_CHANGED_NEW_AREA.
local function UpdateInstanceCache()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

    if instanceType == "party" or instanceType == "raid" then
        local key = TC.INSTANCE_IDS and TC.INSTANCE_IDS[instanceID]
        if key then
            TC.Debug(string.format("Instance connue détectée : [%s] %s (id=%d)",
                instanceType, key, instanceID))
        else
            TC.Debug(string.format("Instance inconnue : type=%s id=%d",
                instanceType, instanceID))
        end
    else
        TC.Debug("Hors instance (type=" .. tostring(instanceType) .. ")")
    end
end

-- ============================================================
-- Détection du type de contenu
-- ============================================================

--- Retourne la clé de contenu précise pour le contexte courant.
--- Exemples : "solo", "dungeon", "dungeon:skyreach",
---            "raid", "raid:the-voidspire"
--- @return string
function TC.GetContentType()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

    if instanceType == "party" then
        local key = TC.INSTANCE_IDS and TC.INSTANCE_IDS[instanceID]
        return key and ("dungeon:" .. key) or "dungeon"

    elseif instanceType == "raid" then
        local key = TC.INSTANCE_IDS and TC.INSTANCE_IDS[instanceID]
        return key and ("raid:" .. key) or "raid"

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
    -- Calcul de la clé personnage (unique par nom + royaume)
    local charName  = UnitName("player") or "Unknown"
    local realmName = GetRealmName()     or "Unknown"
    TC.currentCharKey = charName .. "-" .. realmName

    -- Récupération de la spécialisation active
    local specIndex = GetSpecialization()
    TC.currentSpecID = specIndex and GetSpecializationInfo(specIndex) or 0

    -- Initialisation du profil courant dans les SavedVars
    TC.SavedVars.InitProfile(TC.currentCharKey, TC.currentSpecID)

    TC.AlertUI.Init()
    TC.AlertUI.SetLocked(TC.SavedVars.IsLocked())

    TC.initialized = true

    C_Timer.After(2, function()
        TC.RunAllChecks()
    end)

    TC.Debug(string.format("Addon initialisé pour %s (specID=%d)",
        TC.currentCharKey, TC.currentSpecID))
end

local function OnPlayerEnteringWorld()
    if not TC.initialized then return end
    UpdateInstanceCache()
    C_Timer.After(1, function()
        TC.RunAllChecks()
    end)
end

local function OnZoneChanged()
    if not TC.initialized then return end
    UpdateInstanceCache()
    C_Timer.After(0.5, function()
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

    -- Mise à jour de la spécialisation active
    local specIndex = GetSpecialization()
    TC.currentSpecID = specIndex and GetSpecializationInfo(specIndex) or 0

    if TC.currentCharKey then
        TC.SavedVars.InitProfile(TC.currentCharKey, TC.currentSpecID)
    end

    TC.Debug(string.format("Spécialisation changée → specID=%d, relance du check.",
        TC.currentSpecID))

    -- Notifier le panneau de config si ouvert
    TC.ConfigUI.OnSpecChanged()

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
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        OnZoneChanged()
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
