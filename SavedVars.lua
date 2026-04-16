-- SavedVars.lua
-- Centralise la lecture et l'écriture de TalentSentryDB (SavedVariables)

local TC = TC or {}
TC.SavedVars = {}

-- ============================================================
-- Structure par défaut de la base de données
-- ============================================================

local DB_DEFAULTS = {
    positions = {
        talent = { x = 0, y = 100 },
    },
    locked   = false,
    debug    = false,
    -- Builds indexés par personnage puis par spécialisation.
    -- expectedBuilds[charKey][specID] = { solo, dungeon, raid, dungeons, raidInstances }
    -- charKey = "NomPersonnage-Royaume"  (ex : "Kalindra-Ysondre")
    -- specID  = identifiant numérique de la spécialisation WoW
    expectedBuilds = {},
}

-- Valeurs par défaut d'un profil (une spé d'un personnage)
local PROFILE_DEFAULTS = {
    solo          = nil,
    dungeon       = nil,
    raid          = nil,
    dungeons      = {},
    raidInstances = {},
}

-- Contexte actif : alimenté par InitProfile()
local currentCharKey = nil
local currentSpecID  = nil

-- ============================================================
-- Initialisation
-- ============================================================

--- Initialise la base de données en fusionnant les valeurs par défaut
--- avec les données sauvegardées existantes.
function TC.SavedVars.Init()
    -- TalentSentryDB est chargé automatiquement par WoW avant ADDON_LOADED
    if type(TalentSentryDB) ~= "table" then
        TalentSentryDB = {}
    end

    local db = TalentSentryDB

    -- Fusionner récursivement les valeurs par défaut
    TC.SavedVars.MergeDefaults(db, DB_DEFAULTS)

    -- Migration v1 → v2 : ancienne structure à plat directement dans expectedBuilds.
    -- On la supprime : les builds étaient globaux et ne correspondent plus à rien.
    if type(db.expectedBuilds.dungeons) == "table" or
       type(db.expectedBuilds.bosses)   == "table" or
       type(db.expectedBuilds.solo)     == "string" or
       type(db.expectedBuilds.dungeon)  == "string" or
       type(db.expectedBuilds.raid)     == "string" then
        TC.Debug("SavedVars: ancienne structure v1 détectée, réinitialisation de expectedBuilds.")
        db.expectedBuilds = {}
    end

    -- Migration v2 → v3 : renommer "bosses" → "raidInstances" dans chaque profil.
    -- Les builds par boss ne sont plus utilisés ; on les supprime.
    for _, charProfiles in pairs(db.expectedBuilds) do
        if type(charProfiles) == "table" then
            for _, profile in pairs(charProfiles) do
                if type(profile) == "table" and profile.bosses ~= nil then
                    profile.bosses = nil
                    TC.Debug("SavedVars: migration v3 — clé 'bosses' supprimée d'un profil.")
                end
            end
        end
    end

    -- Supprimer le flag testMode s'il subsiste (fonctionnalité retirée)
    db.testMode = nil

    TC.db = db
end

--- Initialise (ou retrouve) le profil pour le personnage et la spécialisation donnés.
--- Doit être appelé après PLAYER_LOGIN et à chaque changement de spécialisation.
--- @param charKey string  "NomPersonnage-Royaume"
--- @param specID  number  Identifiant de spécialisation WoW (ou 0 si aucune spé)
function TC.SavedVars.InitProfile(charKey, specID)
    currentCharKey = charKey
    currentSpecID  = specID

    if not TC.db then return end

    if not TC.db.expectedBuilds[charKey] then
        TC.db.expectedBuilds[charKey] = {}
    end
    if not TC.db.expectedBuilds[charKey][specID] then
        local profile = {}
        TC.SavedVars.MergeDefaults(profile, PROFILE_DEFAULTS)
        TC.db.expectedBuilds[charKey][specID] = profile
    end
end

--- Retourne le profil actif (table interne), ou nil si non initialisé.
--- @return table|nil
local function GetCurrentProfile()
    if not currentCharKey or not currentSpecID or not TC.db then return nil end
    local chars = TC.db.expectedBuilds[currentCharKey]
    if not chars then return nil end
    return chars[currentSpecID]
end

--- Fusionne récursivement les valeurs par défaut dans la table cible.
--- Ne remplace pas les valeurs déjà présentes.
--- @param target table  Table à compléter
--- @param defaults table  Valeurs par défaut
function TC.SavedVars.MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                TC.SavedVars.MergeDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            TC.SavedVars.MergeDefaults(target[k], v)
        end
    end
end

-- ============================================================
-- Accesseurs — Positions
-- ============================================================

--- Retourne la position sauvegardée d'une icône.
--- @param iconKey string  Clé de l'icône ("talent", "flask", etc.)
--- @return number x, number y
function TC.SavedVars.GetPosition(iconKey)
    local pos = TC.db.positions[iconKey]
    if pos then
        return pos.x, pos.y
    end
    local def = TC.DEFAULT_POSITIONS[iconKey]
    return def and def.x or 0, def and def.y or 0
end

--- Sauvegarde la position d'une icône.
--- @param iconKey string
--- @param x number
--- @param y number
function TC.SavedVars.SetPosition(iconKey, x, y)
    if not TC.db.positions[iconKey] then
        TC.db.positions[iconKey] = {}
    end
    TC.db.positions[iconKey].x = x
    TC.db.positions[iconKey].y = y
end

--- Réinitialise toutes les positions aux valeurs par défaut.
function TC.SavedVars.ResetPositions()
    for key, def in pairs(TC.DEFAULT_POSITIONS) do
        TC.db.positions[key] = { x = def.x, y = def.y }
    end
end

-- ============================================================
-- Accesseurs — Verrouillage
-- ============================================================

--- @return boolean
function TC.SavedVars.IsLocked()
    return TC.db.locked == true
end

--- @param locked boolean
function TC.SavedVars.SetLocked(locked)
    TC.db.locked = locked
end

-- ============================================================
-- Accesseurs — Debug
-- ============================================================

--- @return boolean
function TC.SavedVars.IsDebug()
    return TC.db.debug == true
end

--- @param enabled boolean
function TC.SavedVars.SetDebug(enabled)
    TC.db.debug = enabled
end

-- ============================================================
-- Accesseurs — Builds de talents (profil courant)
-- ============================================================

--- Retourne le build attendu sérialisé pour un type de contenu.
--- Opère sur le profil du personnage + spécialisation courants.
--- @param contentType string  "solo", "dungeon" ou "raid"
--- @return string|nil
function TC.SavedVars.GetExpectedBuild(contentType)
    local profile = GetCurrentProfile()
    if not profile then return nil end
    return profile[contentType]
end

--- Sauvegarde le build attendu pour un type de contenu.
--- @param contentType string
--- @param serialized string|nil  Chaîne sérialisée ou nil pour effacer
function TC.SavedVars.SetExpectedBuild(contentType, serialized)
    local profile = GetCurrentProfile()
    if not profile then return end
    profile[contentType] = serialized
end

--- Supprime le build attendu pour un type de contenu.
--- @param contentType string
function TC.SavedVars.ClearExpectedBuild(contentType)
    local profile = GetCurrentProfile()
    if not profile then return end
    profile[contentType] = nil
end

-- ============================================================
-- Accesseurs — Builds spécifiques (donjon ou boss, profil courant)
-- ============================================================

--- Retourne le build sérialisé pour un donjon ou boss spécifique.
--- @param category string  "dungeons" ou "raidInstances"
--- @param id string        Identifiant du donjon/boss
--- @return string|nil
function TC.SavedVars.GetSpecificBuild(category, id)
    local profile = GetCurrentProfile()
    if not profile then return nil end
    local tbl = profile[category]
    return tbl and tbl[id]
end

--- Sauvegarde le build pour un donjon ou boss spécifique.
--- @param category string
--- @param id string
--- @param serialized string
function TC.SavedVars.SetSpecificBuild(category, id, serialized)
    local profile = GetCurrentProfile()
    if not profile then return end
    if not profile[category] then
        profile[category] = {}
    end
    profile[category][id] = serialized
end

--- Supprime le build pour un donjon ou boss spécifique.
--- @param category string
--- @param id string
function TC.SavedVars.ClearSpecificBuild(category, id)
    local profile = GetCurrentProfile()
    if not profile then return end
    local tbl = profile[category]
    if tbl then tbl[id] = nil end
end
