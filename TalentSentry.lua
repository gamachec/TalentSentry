-- TalentSentry.lua
-- Vérifie si les talents actifs du joueur correspondent au profil attendu.

local TC = TC or {}
TC.TalentSentry = {}

-- ============================================================
-- Sérialisation / désérialisation (déclarées ici car utilisées par le parseur)
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
-- Décodage base64 et parseur du format d'exportation WoW
-- ============================================================

-- Table de correspondance base64 → valeur (alphabet standard)
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64Lookup = {}
for i = 1, #BASE64_CHARS do
    b64Lookup[BASE64_CHARS:sub(i, i)] = i - 1
end

--- Convertit une chaîne base64 en tableau de valeurs 6 bits (une par caractère).
--- @param str string
--- @return table|nil
local function Base64ToVals(str)
    str = str:gsub("[^A-Za-z0-9+/]", "")
    local vals = {}
    for i = 1, #str do
        local v = b64Lookup[str:sub(i, i)]
        if not v then return nil end
        vals[#vals + 1] = v
    end
    return vals
end

--- Crée un lecteur de bits LSB-first sur un tableau de valeurs 6 bits.
--- Le format WoW lit le bit le moins significatif de chaque caractère base64 en premier.
--- Les valeurs multi-bits sont construites avec le premier bit lu en position 2^0 (LSB).
--- @param vals table  tableau de valeurs 0-63
--- @return table  lecteur avec méthode :read(n)
local function CreateBitReader(vals)
    local r = { _vals = vals, _pos = 1, _bit = 0 }
    function r:read(n)
        local result = 0
        for i = 0, n - 1 do
            if self._pos > #self._vals then return nil end
            local bitVal = math.floor(self._vals[self._pos] / 2^self._bit) % 2
            result = result + bitVal * (2^i)
            self._bit = self._bit + 1
            if self._bit >= 6 then
                self._bit = 0
                self._pos = self._pos + 1
            end
        end
        return result
    end
    return r
end


--- Parse une chaîne d'exportation de talents WoW (format v2) sans modifier les talents actifs.
--- Retourne une table { [nodeID] = ranksPurchased } ou nil + message d'erreur.
--- Nécessite que la spécialisation active corresponde à celle encodée dans la chaîne.
--- @param exportString string
--- @return table|nil  { [nodeID] = ranks }
--- @return string|nil  message d'erreur
function TC.TalentSentry.ParseExportString(exportString)
    if not exportString or exportString == "" then
        return nil, TC_L.IMPORT_ERROR_EMPTY
    end

    local vals = Base64ToVals(exportString)
    if not vals or #vals < 4 then  -- 4 chars = 24 bits minimum (8 version + 16 specID)
        return nil, TC_L.IMPORT_ERROR_INVALID
    end

    local r = CreateBitReader(vals)

    -- En-tête : 8 bits version + 16 bits specID
    local version = r:read(8)
    if version ~= 2 then
        return nil, string.format(TC_L.IMPORT_ERROR_VERSION, tostring(version))
    end

    local specID = r:read(16)

    -- Vérification que la spé active correspond
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil, TC_L.IMPORT_ERROR_NO_SPEC
    end
    local activeSpecID = GetSpecializationInfo(specIndex)
    if specID ~= activeSpecID then
        return nil, string.format(TC_L.IMPORT_ERROR_WRONG_SPEC, specID, activeSpecID)
    end

    -- Récupération de la configuration active (structure de l'arbre)
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then
        return nil, TC_L.IMPORT_ERROR_NO_CONFIG
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then
        return nil, TC_L.IMPORT_ERROR_CONFIG
    end

    -- Sauter le hash de l'arbre : 16 × 8 bits = 128 bits fixes (format WoW v2)
    for _ = 1, 16 do
        r:read(8)
    end

    local nodes = {}

    for _, treeID in ipairs(configInfo.treeIDs) do
        local treeNodes = C_Traits.GetTreeNodes(treeID)
        if treeNodes then
            for _, nodeID in ipairs(treeNodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo then
                    -- Encodage conditionnel par nœud :
                    -- 1 bit : isSelected
                    -- si sélectionné :
                    --   1 bit : isPurchased (0=accordé, 1=acheté)
                    --   si acheté :
                    --     1 bit : isPartial (0=rang max, 1=rang partiel)
                    --     si partiel : 6 bits : rang
                    --   1 bit : isChoiceNode
                    --   si choix : 2 bits : index d'entrée
                    local isSelected = r:read(1)
                    if isSelected == nil then break end

                    if isSelected == 1 then
                        local isPurchased = r:read(1)
                        if isPurchased == nil then break end

                        if isPurchased == 1 then
                            -- isPartial, isChoiceNode et l'index de choix ne sont
                            -- encodés que pour les nœuds achetés (pas les nœuds accordés).
                            local rank = nodeInfo.maxRanks or 1
                            local isPartial = r:read(1)
                            if isPartial == nil then break end
                            if isPartial == 1 then
                                local rawRank = r:read(6)
                                if rawRank == nil then break end
                                rank = rawRank
                            end

                            local isChoiceNode = r:read(1)
                            if isChoiceNode == nil then break end
                            if isChoiceNode == 1 then
                                r:read(2)  -- index d'entrée (zero-based, ignoré pour la comparaison)
                            end

                            nodes[nodeID] = rank
                        end
                        -- nœuds accordés automatiquement (isPurchased == 0) : aucune donnée supplémentaire
                    end
                end
            end
        end
    end

    return nodes, nil
end

--- Convertit une chaîne d'exportation WoW en format interne sérialisé.
--- @param exportString string
--- @return string|nil  chaîne sérialisée ("nodeID:ranks,...")
--- @return string|nil  message d'erreur
function TC.TalentSentry.ImportFromExportString(exportString)
    local nodes, err = TC.TalentSentry.ParseExportString(exportString)
    if not nodes then
        return nil, err
    end
    return SerializeNodes(nodes), nil
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
