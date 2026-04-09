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
    locked = false,
    debug  = false,
    -- Builds de talents attendus par type de contenu.
    -- Chaque valeur est une chaîne sérialisée "nodeID:ranks,nodeID:ranks,..."
    -- ou nil si non configuré.
    expectedBuilds = {
        solo  = nil,
        group = nil,
        raid  = nil,
    },
}

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

    TC.db = db
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
-- Accesseurs — Builds de talents
-- ============================================================

--- Retourne le build attendu sérialisé pour un type de contenu.
--- @param contentType string  "solo", "group" ou "raid"
--- @return string|nil
function TC.SavedVars.GetExpectedBuild(contentType)
    return TC.db.expectedBuilds[contentType]
end

--- Sauvegarde le build attendu pour un type de contenu.
--- @param contentType string
--- @param serialized string|nil  Chaîne sérialisée ou nil pour effacer
function TC.SavedVars.SetExpectedBuild(contentType, serialized)
    TC.db.expectedBuilds[contentType] = serialized
end

--- Supprime le build attendu pour un type de contenu.
--- @param contentType string
function TC.SavedVars.ClearExpectedBuild(contentType)
    TC.db.expectedBuilds[contentType] = nil
end
