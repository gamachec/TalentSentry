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
-- Cache d'instance et détection de boss
-- ============================================================

-- Type d'instance courant ("party", "raid", "none" …) — mis à jour sur les
-- événements de zone pour servir de garde dans les handlers de nameplate.
TC.currentInstanceType = "none"
TC.currentInstanceID   = 0

-- Clé du boss actuellement visible dans les nameplates (ex: "imperator-averzian").
-- nil si aucun boss connu n'est visible.
TC.currentBossKey = nil

-- NPC ID du mannequin d'entraînement utilisé en mode test.
local TEST_DUMMY_NPC_ID = 243168
local TEST_DUMMY_KEY    = "test-dummy"

--- Met à jour le cache d'instance et réinitialise la clé de boss.
--- Appelé sur PLAYER_ENTERING_WORLD et ZONE_CHANGED_NEW_AREA.
local function UpdateInstanceCache()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    TC.currentInstanceType = instanceType or "none"
    TC.currentInstanceID   = instanceID   or 0
    TC.currentBossKey      = nil

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
        TC.Debug("Hors instance (type=" .. TC.currentInstanceType .. ")")
    end
end

--- Extrait le NPC ID d'un GUID de créature WoW.
--- Format : "Creature-0-serverID-instanceID-zoneUID-npcID-spawnUID"
--- @param guid string
--- @return number|nil
local function GuidToNpcID(guid)
    if not guid then return nil end
    return tonumber(guid:match("Creature%-0%-%d+%-%d+%-%d+%-(%d+)"))
end

--- Parcourt toutes les nameplates visibles et met à jour currentBossKey
--- si un boss connu est trouvé.
--- En mode normal : ignoré hors raid.
--- En mode test   : actif partout ; reconnaît le mannequin d'entraînement.
--- Pas de garde de combat : on met à jour l'état indépendamment du combat ;
--- c'est RunAllChecks() qui se bloque pendant les combats.
function TC.ScanNameplatesForBoss()
    local testMode = TC.db and TC.db.testMode
    if TC.currentInstanceType ~= "raid" and not testMode then return end

    TC.currentBossKey = nil
    local plates = C_NameplateUnits.GetNameplates()
    if not plates then
        TC.Debug("ScanNameplates: aucune nameplate trouvée.")
        return
    end

    TC.Debug("ScanNameplates: " .. #plates .. " nameplate(s) visible(s).")

    for _, np in ipairs(plates) do
        local guid  = UnitGUID(np.namePlateUnitToken)
        local npcID = GuidToNpcID(guid)
        TC.Debug(string.format("  nameplate %s → guid=%s npcID=%s",
            tostring(np.namePlateUnitToken), tostring(guid), tostring(npcID)))
        if npcID then
            -- En mode test, le mannequin d'entraînement est traité comme un boss
            if testMode and npcID == TEST_DUMMY_NPC_ID then
                TC.currentBossKey = TEST_DUMMY_KEY
                TC.Debug("Boss (test) détecté — mannequin d'entraînement : " .. TEST_DUMMY_KEY)
                return
            end
            local bossKey = TC.BOSS_NPC_IDS and TC.BOSS_NPC_IDS[npcID]
            if bossKey then
                TC.currentBossKey = bossKey
                TC.Debug("Boss détecté (scan) : " .. bossKey)
                return
            end
        end
    end

    TC.Debug("ScanNameplates: aucun boss connu trouvé.")
end

-- Alias local pour usage interne
local ScanNameplatesForBoss = TC.ScanNameplatesForBoss

-- ============================================================
-- Détection du type de contenu
-- ============================================================

--- Retourne la clé de contenu précise pour le contexte courant.
--- Exemples : "solo", "dungeon", "dungeon:skyreach",
---            "raid", "raid:imperator-averzian", "raid:test-dummy"
--- @return string
function TC.GetContentType()
    -- Mode test : si un boss (ou mannequin) est détecté, simuler un contexte raid
    -- indépendamment de l'instance réelle, pour pouvoir tester hors instance.
    if TC.db and TC.db.testMode and TC.currentBossKey then
        return "raid:" .. TC.currentBossKey
    end

    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

    if instanceType == "party" then
        local key = TC.INSTANCE_IDS and TC.INSTANCE_IDS[instanceID]
        return key and ("dungeon:" .. key) or "dungeon"

    elseif instanceType == "raid" then
        if TC.currentBossKey then
            return "raid:" .. TC.currentBossKey
        end
        return "raid"

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
        ScanNameplatesForBoss()
        TC.RunAllChecks()
    end)
end

local function OnZoneChanged()
    if not TC.initialized then return end
    UpdateInstanceCache()
    C_Timer.After(0.5, function()
        ScanNameplatesForBoss()
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
            -- Rescanner les nameplates : le boss a pu être tué ou être toujours là
            ScanNameplatesForBoss()
            TC.RunAllChecks()
        end)
    end
end

local function OnNamePlateAdded(unitToken)
    -- Pas de garde de combat : on met à jour currentBossKey même pendant le combat
    -- afin que l'état soit correct dès la sortie du combat.
    local testMode = TC.db and TC.db.testMode
    if TC.currentInstanceType ~= "raid" and not testMode then return end

    local guid  = UnitGUID(unitToken)
    local npcID = GuidToNpcID(guid)
    if not npcID then return end

    -- Mode test : mannequin d'entraînement
    if testMode and npcID == TEST_DUMMY_NPC_ID then
        TC.currentBossKey = TEST_DUMMY_KEY
        TC.Debug("Boss (test) apparu — mannequin : " .. TEST_DUMMY_KEY)
        TC.RunAllChecks()
        return
    end

    local bossKey = TC.BOSS_NPC_IDS and TC.BOSS_NPC_IDS[npcID]
    if not bossKey then return end

    TC.currentBossKey = bossKey
    TC.Debug("Boss détecté (nameplate) : " .. bossKey)
    TC.RunAllChecks()
end

local function OnNamePlateRemoved(unitToken)
    -- Même logique : mise à jour d'état sans garde de combat.
    local testMode = TC.db and TC.db.testMode
    if TC.currentInstanceType ~= "raid" and not testMode then return end
    if not TC.currentBossKey then return end

    -- Rescanner les nameplates restantes pour voir si un autre boss est encore visible
    local previousKey = TC.currentBossKey
    ScanNameplatesForBoss()

    if TC.currentBossKey ~= previousKey then
        TC.Debug("Boss disparu : " .. (previousKey or "?"))
        TC.RunAllChecks()
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
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

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
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        OnNamePlateAdded(...)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        OnNamePlateRemoved(...)
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
        ScanNameplatesForBoss()
        TC.RunAllChecks()
    elseif cmd == "scan" then
        -- Diagnostic : affiche tous les NPC IDs visibles dans les nameplates,
        -- indépendamment de l'instance ou du mode test.
        local plates = C_NameplateUnits.GetNameplates()
        if not plates or #plates == 0 then
            TC.Print("Aucune nameplate visible. Active les nameplates ennemies dans les options WoW.")
        else
            TC.Print(#plates .. " nameplate(s) visible(s) :")
            for _, np in ipairs(plates) do
                local guid  = UnitGUID(np.namePlateUnitToken)
                local npcID = GuidToNpcID(guid)
                local name  = UnitName(np.namePlateUnitToken) or "?"
                local known = npcID and TC.BOSS_NPC_IDS and TC.BOSS_NPC_IDS[npcID]
                TC.Print(string.format("  %s — npcID=%s%s",
                    name,
                    tostring(npcID),
                    known and ("  ← boss connu : " .. known) or ""))
            end
        end
    elseif cmd == "testboss" then
        local enabled = not TC.SavedVars.IsTestMode()
        TC.SavedVars.SetTestMode(enabled)
        if enabled then
            TC.Print(TC_L.TESTMODE_ON)
        else
            TC.currentBossKey = nil
            TC.Print(TC_L.TESTMODE_OFF)
        end
        ScanNameplatesForBoss()
        TC.RunAllChecks()
    else
        TC.Print(TC_L.SLASH_HELP)
    end
end
