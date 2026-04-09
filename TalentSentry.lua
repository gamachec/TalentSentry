-- TalentSentry.lua
-- Vérifie si les talents actifs du joueur correspondent au profil attendu.

local TC = TC or {}
TC.TalentSentry = {}

-- ============================================================
-- Sérialisation du build actuel
-- ============================================================

--- Sérialise une table de nœuds actifs en chaîne de caractères.
--- Format : "nodeID:ranks,nodeID:ranks,..." trié par nodeID pour comparaison stable.
--- @param nodes table  { [nodeID] = ranks }
--- @return string
local function SerializeNodes(nodes)
    local parts = {}
    for nodeID, ranks in pairs(nodes) do
        table.insert(parts, nodeID .. ":" .. ranks)
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

--- Désérialise une chaîne en table de nœuds.
--- @param str string
--- @return table  { [nodeID] = ranks }
local function DeserializeNodes(str)
    local nodes = {}
    if not str or str == "" then return nodes end
    for entry in str:gmatch("[^,]+") do
        local nodeID, ranks = entry:match("^(%d+):(%d+)$")
        if nodeID and ranks then
            nodes[tonumber(nodeID)] = tonumber(ranks)
        end
    end
    return nodes
end

-- ============================================================
-- Lecture des talents actifs via C_Traits
-- ============================================================

--- Récupère tous les nœuds de talent actifs (ranksPurchased > 0).
--- @return table|nil  { [nodeID] = ranksPurchased } ou nil si impossible
function TC.TalentSentry.GetActiveNodes()
    -- Récupère l'ID de configuration de talents active
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then
        TC.Debug("TalentSentry: Aucun configID actif.")
        return nil
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then
        TC.Debug("TalentSentry: Impossible de lire les infos de config.")
        return nil
    end

    local nodes = {}
    for _, treeID in ipairs(configInfo.treeIDs) do
        local treeNodes = C_Traits.GetTreeNodes(treeID)
        if treeNodes then
            for _, nodeID in ipairs(treeNodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo and nodeInfo.ranksPurchased and nodeInfo.ranksPurchased > 0 then
                    nodes[nodeID] = nodeInfo.ranksPurchased
                end
            end
        end
    end

    return nodes
end

--- Retourne le build actuel sérialisé, ou nil si impossible.
--- @return string|nil
function TC.TalentSentry.GetCurrentBuildSerialized()
    local nodes = TC.TalentSentry.GetActiveNodes()
    if not nodes then return nil end
    return SerializeNodes(nodes)
end

--- Retourne le nombre de nœuds actifs dans un build sérialisé.
--- @param serialized string
--- @return number
function TC.TalentSentry.CountNodes(serialized)
    if not serialized or serialized == "" then return 0 end
    local count = 0
    for _ in serialized:gmatch(",") do count = count + 1 end
    return count + 1
end

-- ============================================================
-- Vérification du build
-- ============================================================

--- Vérifie si le build actuel correspond au build attendu pour le type de contenu.
--- @param contentType string  "solo", "group" ou "raid"
--- @return boolean  true = alerte (talents incorrects), false = OK
function TC.TalentSentry.Check(contentType)
    local expectedSerialized = TC.SavedVars.GetExpectedBuild(contentType)

    -- Aucun build configuré : pas d'alerte
    if not expectedSerialized then
        TC.Debug("TalentSentry: Aucun build configuré pour " .. contentType)
        return false
    end

    local currentSerialized = TC.TalentSentry.GetCurrentBuildSerialized()
    if not currentSerialized then
        -- Impossible de lire les talents (ex: chargement en cours)
        return false
    end

    -- Comparaison exacte nœud par nœud
    local expected = DeserializeNodes(expectedSerialized)
    local current  = DeserializeNodes(currentSerialized)

    -- Vérifier que chaque nœud attendu est présent au bon rang
    for nodeID, expectedRanks in pairs(expected) do
        if current[nodeID] ~= expectedRanks then
            TC.Debug(string.format(
                "TalentSentry: Nœud %d attendu à %d rangs, actuel : %s",
                nodeID, expectedRanks, tostring(current[nodeID])
            ))
            return true  -- alerte
        end
    end

    -- Vérifier qu'aucun nœud actuel n'est absent de l'attendu
    for nodeID, currentRanks in pairs(current) do
        if not expected[nodeID] then
            TC.Debug(string.format(
                "TalentSentry: Nœud %d actif (%d rangs) mais absent du build attendu.",
                nodeID, currentRanks
            ))
            return true  -- alerte
        end
    end

    return false  -- builds identiques
end
