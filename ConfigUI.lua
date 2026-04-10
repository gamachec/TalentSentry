-- ConfigUI.lua
-- Panneau de configuration accessible depuis Interface > AddOns.
-- Disposition : treeview à gauche (Solo / Donjons / Raids), détail à droite.

local TC = TC or {}
TC.ConfigUI = {}

local settingsCategory  = nil
local selectedKey       = "solo"          -- clé du nœud actuellement sélectionné
local treeRowPool       = {}              -- pool de frames de lignes
local treeScrollContent = nil             -- frame enfant du ScrollFrame de l'arbre

-- Références aux widgets du panneau de détail (mis à jour à chaque sélection)
local detailTitle
local detailFallback
local detailStatus
local detailImportBox

-- Référence au panneau principal (pour lockBtn dans RefreshStatus)
local configPanel

-- ============================================================
-- Widgets helpers
-- ============================================================

local function CreateButton(parent, width, height, label, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function CreateEditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, height)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(512)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

local function CreateSeparator(parent, width)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetWidth(width)
    tex:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    return tex
end

-- ============================================================
-- Analyse des clés de sélection
-- ============================================================

--- Décompose une clé en ses composants.
--- "solo"                        → "solo",    nil,        nil
--- "dungeon"                     → "dungeon", nil,        nil
--- "raid"                        → "raid",    nil,        nil
--- "dungeon:magisters-terrace"   → "dungeon", "dungeons", "magisters-terrace"
--- "raid:imperator-averzian"     → "raid",    "bosses",   "imperator-averzian"
--- @return string base, string|nil category, string|nil id
local function ParseKey(key)
    if key == "solo" or key == "dungeon" or key == "raid" then
        return key, nil, nil
    end
    local base, id = key:match("^(%a+):(.+)$")
    if base == "dungeon" then return "dungeon", "dungeons", id end
    if base == "raid"    then return "raid",    "bosses",   id end
    return key, nil, nil
end

local function GetBuildForKey(key)
    local base, category, id = ParseKey(key)
    if category then return TC.SavedVars.GetSpecificBuild(category, id) end
    return TC.SavedVars.GetExpectedBuild(base)
end

local function SetBuildForKey(key, serialized)
    local base, category, id = ParseKey(key)
    if category then TC.SavedVars.SetSpecificBuild(category, id, serialized)
    else             TC.SavedVars.SetExpectedBuild(base, serialized) end
end

local function ClearBuildForKey(key)
    local base, category, id = ParseKey(key)
    if category then TC.SavedVars.ClearSpecificBuild(category, id)
    else             TC.SavedVars.ClearExpectedBuild(base) end
end

--- Retourne le label localisé d'une clé.
--- @param key string
--- @return string
local function GetKeyLabel(key)
    if key == "solo"    then return TC_L.CONTENT_SOLO end
    if key == "dungeon" then return TC_L.CONTENT_DUNGEON end
    if key == "raid"    then return TC_L.CONTENT_RAID end
    local base, _, id = ParseKey(key)
    if base == "dungeon" then
        for _, d in ipairs(TC.DUNGEONS) do
            if d.id == id then return d.label end
        end
    elseif base == "raid" then
        for _, b in ipairs(TC.RAID_BOSSES) do
            if b.id == id then return b.label end
        end
    end
    return key
end

-- ============================================================
-- Panneau de détail (droite)
-- ============================================================

--- Met à jour le panneau de détail pour la sélection courante.
local function RefreshDetail()
    if not detailTitle then return end

    local key = selectedKey
    local build = GetBuildForKey(key)
    local _, category, _ = ParseKey(key)

    -- Titre
    detailTitle:SetText(GetKeyLabel(key))

    -- Note de fallback pour les entrées spécifiques (donjon/boss)
    if category then
        local parentLabel = (key:match("^dungeon:") and TC_L.CONTENT_DUNGEON) or TC_L.CONTENT_RAID
        detailFallback:SetText(string.format(TC_L.CONFIG_FALLBACK_NOTE, parentLabel))
        detailFallback:Show()
    else
        detailFallback:Hide()
    end

    -- Statut du build
    if build then
        local count = TC.TalentSentry.CountNodes(build)
        detailStatus:SetText(string.format(TC_L.CONFIG_NODES_COUNT, count))
        detailStatus:SetTextColor(0.2, 1, 0.2)
    else
        detailStatus:SetText(TC_L.CONFIG_NOT_SET)
        detailStatus:SetTextColor(0.6, 0.6, 0.6)
    end

    -- Vider le champ d'import
    if detailImportBox then
        detailImportBox:SetText("")
        detailImportBox:ClearFocus()
    end
end

-- ============================================================
-- Treeview (gauche)
-- ============================================================

local TREE_ROW_H = 24

--- Construit la liste plate complète des lignes du treeview (toujours déroulé).
--- @return table
local function BuildFlatRows()
    local rows = {}

    -- Solo
    table.insert(rows, { key = "solo",    label = TC_L.CONTENT_SOLO,    depth = 0 })

    -- Donjons
    table.insert(rows, { key = "dungeon", label = TC_L.CONTENT_DUNGEON, depth = 0 })
    for _, d in ipairs(TC.DUNGEONS) do
        table.insert(rows, { key = "dungeon:" .. d.id, label = d.label, depth = 1 })
    end

    -- Raids
    table.insert(rows, { key = "raid",    label = TC_L.CONTENT_RAID,    depth = 0 })
    for _, b in ipairs(TC.RAID_BOSSES) do
        table.insert(rows, { key = "raid:" .. b.id, label = b.label, depth = 1 })
    end

    return rows
end

--- Redessine l'arbre : positions, textes, highlights.
local function RefreshTree()
    if not treeScrollContent then return end

    local rows = BuildFlatRows()

    for i, rowData in ipairs(rows) do
        local row = treeRowPool[i]
        if not row then break end

        -- Position
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", treeScrollContent, "TOPLEFT", 0, -(i - 1) * TREE_ROW_H)

        -- Label avec indentation
        local indent = rowData.depth * 14
        row.rowLabel:ClearAllPoints()
        row.rowLabel:SetPoint("LEFT", row, "LEFT", indent, 0)
        row.rowLabel:SetText(rowData.label)
        if rowData.depth == 0 then
            row.rowLabel:SetTextColor(1, 0.82, 0)
        elseif rowData.key == selectedKey then
            row.rowLabel:SetTextColor(1, 1, 1)
        else
            row.rowLabel:SetTextColor(0.85, 0.85, 0.85)
        end

        -- Highlight de sélection
        row.selHighlight:SetShown(rowData.key == selectedKey)

        -- Stocker les données pour le OnClick
        row.rowData = rowData
        row:Show()
    end

    -- Masquer les lignes inutilisées du pool
    for i = #rows + 1, #treeRowPool do
        treeRowPool[i]:Hide()
    end

    -- Ajuster la hauteur du contenu scrollable
    treeScrollContent:SetHeight(math.max(#rows * TREE_ROW_H, 1))
end

-- ============================================================
-- Construction du panneau
-- ============================================================

local function BuildConfigPanel()
    local PANEL_W  = 620
    local PANEL_H  = 560
    local TREE_W   = 188   -- largeur de la colonne de l'arbre
    local MAIN_H   = 385   -- hauteur de la zone tree | detail
    local MARGIN   = 10

    -- Frame principale enregistrée dans Settings
    local pnl = CreateFrame("Frame", "TCConfigPanel", UIParent)
    pnl:SetSize(PANEL_W, PANEL_H)
    configPanel = pnl

    -- ── En-tête compact ────────────────────────────────────────────────────
    local subtitle = pnl:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    subtitle:SetText(TC_L.CONFIG_SUBTITLE)
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    local desc = pnl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(PANEL_W - MARGIN * 2)
    desc:SetJustifyH("LEFT")
    desc:SetText(TC_L.CONFIG_DESC)
    desc:SetTextColor(0.6, 0.6, 0.6)

    local topSep = CreateSeparator(pnl, PANEL_W - MARGIN * 2)
    topSep:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6)

    -- ── Colonne gauche : arbre ──────────────────────────────────────────────

    local treeContainer = CreateFrame("Frame", nil, pnl)
    treeContainer:SetSize(TREE_W, MAIN_H)
    treeContainer:SetPoint("TOPLEFT", topSep, "BOTTOMLEFT", 0, -MARGIN)

    -- Fond subtil
    local treeBg = treeContainer:CreateTexture(nil, "BACKGROUND")
    treeBg:SetAllPoints()
    treeBg:SetColorTexture(0, 0, 0, 0.15)

    -- ScrollFrame de l'arbre (laisse 18px pour la scrollbar)
    local treeScroll = CreateFrame("ScrollFrame", nil, treeContainer, "UIPanelScrollFrameTemplate")
    treeScroll:SetPoint("TOPLEFT",     treeContainer, "TOPLEFT",     2,   -2)
    treeScroll:SetPoint("BOTTOMRIGHT", treeContainer, "BOTTOMRIGHT", -18,  2)

    local treeContent = CreateFrame("Frame", nil, treeScroll)
    treeContent:SetWidth(TREE_W - 22)
    treeContent:SetHeight(1)
    treeScroll:SetScrollChild(treeContent)
    treeScrollContent = treeContent

    -- Pré-créer le pool de lignes (max : 2 + 8 + 9 parents/enfants = 21)
    local MAX_ROWS = 22
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, treeContent)
        row:SetHeight(TREE_ROW_H)
        row:SetWidth(TREE_W - 22)

        -- Highlight de sélection (bleu)
        local selHl = row:CreateTexture(nil, "BACKGROUND")
        selHl:SetAllPoints()
        selHl:SetColorTexture(0.25, 0.5, 0.9, 0.25)
        selHl:Hide()
        row.selHighlight = selHl

        -- Highlight de survol (intégré WoW)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        -- Texte de la ligne
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetWidth(TREE_W - 30)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        row.rowLabel = lbl

        -- Clic : sélection directe
        row:SetScript("OnClick", function(self)
            local rd = self.rowData
            if not rd then return end
            selectedKey = rd.key
            RefreshDetail()
            RefreshTree()
        end)

        row:Hide()
        treeRowPool[i] = row
    end

    -- ── Séparateur vertical ────────────────────────────────────────────────
    local vSep = pnl:CreateTexture(nil, "ARTWORK")
    vSep:SetWidth(1)
    vSep:SetHeight(MAIN_H)
    vSep:SetPoint("TOPLEFT", treeContainer, "TOPRIGHT", 8, 0)
    vSep:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- ── Colonne droite : détail ────────────────────────────────────────────
    local DETAIL_W = PANEL_W - TREE_W - MARGIN * 2 - 18  -- ~394px
    local detailContainer = CreateFrame("Frame", nil, pnl)
    detailContainer:SetSize(DETAIL_W, MAIN_H)
    detailContainer:SetPoint("TOPLEFT", vSep, "TOPRIGHT", 8, 0)

    -- Titre du nœud sélectionné
    local dTitle = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dTitle:SetPoint("TOPLEFT", 0, 0)
    dTitle:SetText("")
    detailTitle = dTitle

    -- Note de fallback
    local dFallback = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dFallback:SetPoint("TOPLEFT", dTitle, "BOTTOMLEFT", 0, -4)
    dFallback:SetWidth(DETAIL_W)
    dFallback:SetJustifyH("LEFT")
    dFallback:SetTextColor(0.75, 0.6, 0.2)
    dFallback:Hide()
    detailFallback = dFallback

    -- Statut du build
    local dStatus = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dStatus:SetPoint("TOPLEFT", dFallback, "BOTTOMLEFT", 0, -8)
    dStatus:SetText("")
    detailStatus = dStatus

    -- Boutons Capturer / Effacer
    local capBtn = CreateButton(detailContainer, 200, 26, TC_L.CONFIG_CAPTURE, function()
        TC.ConfigUI.CaptureBuild(selectedKey)
    end)
    capBtn:SetPoint("TOPLEFT", dStatus, "BOTTOMLEFT", 0, -10)

    local clrBtn = CreateButton(detailContainer, 90, 26, TC_L.CONFIG_CLEAR, function()
        TC.ConfigUI.ClearBuild(selectedKey)
    end)
    clrBtn:SetPoint("LEFT", capBtn, "RIGHT", 8, 0)

    -- Label import
    local importLabel = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    importLabel:SetPoint("TOPLEFT", capBtn, "BOTTOMLEFT", 0, -12)
    importLabel:SetText(TC_L.IMPORT_LABEL)
    importLabel:SetTextColor(0.7, 0.7, 0.7)

    -- Champ de saisie
    local importBox = CreateEditBox(detailContainer, 280, 20)
    importBox:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -6)
    detailImportBox = importBox

    -- Bouton Importer
    local importBtn = CreateButton(detailContainer, 100, 26, TC_L.IMPORT_BTN, function()
        local ok, err = pcall(TC.ConfigUI.ImportBuild, selectedKey, importBox)
        if not ok then
            TC.Print("|cffff4444[TC] Erreur Lua :|r " .. tostring(err))
        end
    end)
    importBtn:SetPoint("LEFT", importBox, "RIGHT", 8, 0)

    -- ── Section Options ─────────────────────────────────────────────────────
    local botSep = CreateSeparator(pnl, PANEL_W - MARGIN * 2)
    botSep:SetPoint("TOPLEFT", treeContainer, "BOTTOMLEFT", 0, -MARGIN)

    local optHeader = pnl:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", botSep, "BOTTOMLEFT", 0, -8)
    optHeader:SetText("Options")
    optHeader:SetTextColor(1, 0.82, 0)

    -- Ligne 1 : case à cocher "afficher l'icône pour repositionnement"
    local previewCheck = CreateFrame("CheckButton", nil, pnl, "UICheckButtonTemplate")
    previewCheck:SetSize(24, 24)
    previewCheck:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -4)
    previewCheck:SetChecked(false)
    previewCheck:SetScript("OnClick", function(self)
        TC.AlertUI.SetPreviewMode(self:GetChecked())
    end)

    local previewLabel = pnl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("LEFT", previewCheck, "RIGHT", 2, 0)
    previewLabel:SetText(TC_L.CONFIG_PREVIEW_ICON)

    -- Ligne 2 : verrouillage + réinitialisation
    local lockLabel = pnl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockLabel:SetPoint("TOPLEFT", previewCheck, "BOTTOMLEFT", 4, -4)
    lockLabel:SetText(TC_L.CONFIG_SECTION_LOCK)

    local lockBtn = CreateButton(pnl, 140, 24, "", function()
        local locked = not TC.SavedVars.IsLocked()
        TC.SavedVars.SetLocked(locked)
        TC.AlertUI.SetLocked(locked)
        TC.Print(locked and TC_L.CONFIG_LOCKED_ON or TC_L.CONFIG_LOCKED_OFF)
        TC.ConfigUI.RefreshStatus()
    end)
    lockBtn:SetPoint("LEFT", lockLabel, "RIGHT", 8, 0)
    pnl.lockBtn = lockBtn

    local resetBtn = CreateButton(pnl, 180, 24, TC_L.CONFIG_RESET_BTN, function()
        TC.SavedVars.ResetPositions()
        TC.AlertUI.ResetPositions()
        TC.Print(TC_L.CONFIG_RESET_POS)
    end)
    resetBtn:SetPoint("LEFT", lockBtn, "RIGHT", 12, 0)

    -- ── Events ─────────────────────────────────────────────────────────────
    pnl:SetScript("OnShow", function()
        RefreshTree()
        RefreshDetail()
        TC.ConfigUI.RefreshStatus()
        if previewCheck:GetChecked() then
            TC.AlertUI.SetPreviewMode(true)
        end
    end)

    pnl:SetScript("OnHide", function()
        if previewCheck:GetChecked() then
            previewCheck:SetChecked(false)
            TC.AlertUI.SetPreviewMode(false)
        end
    end)

    return pnl
end

-- ============================================================
-- Logique de capture / import / suppression
-- ============================================================

--- Capture le build de talents actuel pour la clé donnée.
--- @param key string  Clé de sélection (ex : "solo", "dungeon:skyreach")
function TC.ConfigUI.CaptureBuild(key)
    local serialized = TC.TalentSentry.GetCurrentBuildSerialized()
    if not serialized then
        TC.Print(TC_L.CONFIG_NO_TALENTS)
        return
    end
    if serialized == "" then
        TC.Print(TC_L.CONFIG_NO_SPEC)
        return
    end
    SetBuildForKey(key, serialized)
    local count = TC.TalentSentry.CountNodes(serialized)
    TC.Print(string.format(TC_L.CONFIG_CAPTURE_OK, count))
    RefreshDetail()
    TC.RunAllChecks()
end

--- Importe un build depuis la chaîne d'exportation.
--- @param key string
--- @param editBoxArg EditBox
function TC.ConfigUI.ImportBuild(key, editBoxArg)
    local editBox = editBoxArg or detailImportBox
    if not editBox then
        TC.Print(TC_L.IMPORT_ERROR_INVALID)
        return
    end

    local str = editBox:GetText()
    if not str or str == "" then
        TC.Print(TC_L.IMPORT_ERROR_EMPTY)
        return
    end

    local parseOk, serializedOrErr, parseErr = pcall(TC.TalentSentry.ImportFromExportString, str)
    if not parseOk then
        TC.Print("|cffff4444[TC] Erreur interne :|r " .. tostring(serializedOrErr))
        return
    end
    local serialized, err = serializedOrErr, parseErr
    if not serialized or serialized == "" then
        TC.Print("|cffff4444[TC]|r " .. (err or TC_L.IMPORT_ERROR_INVALID))
        return
    end

    SetBuildForKey(key, serialized)
    editBox:SetText("")
    editBox:ClearFocus()
    local count = TC.TalentSentry.CountNodes(serialized)
    TC.Print(string.format(TC_L.IMPORT_OK, count))
    RefreshDetail()
    TC.RunAllChecks()
end

--- Efface le build configuré pour la clé donnée.
--- @param key string
function TC.ConfigUI.ClearBuild(key)
    ClearBuildForKey(key)
    TC.Print(TC_L.CONFIG_CLEAR_OK)
    RefreshDetail()
    TC.RunAllChecks()
end

--- Rafraîchit le statut affiché et le libellé du bouton de verrouillage.
function TC.ConfigUI.RefreshStatus()
    RefreshDetail()
    local pnl = configPanel or _G["TCConfigPanel"]
    if pnl and pnl.lockBtn then
        pnl.lockBtn:SetText(
            TC.SavedVars.IsLocked() and TC_L.MENU_UNLOCK or TC_L.MENU_LOCK
        )
    end
end

-- ============================================================
-- Enregistrement dans le menu Interface > AddOns
-- ============================================================

--- Initialise et enregistre le panneau de configuration WoW.
function TC.ConfigUI.Init()
    local pnl = BuildConfigPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(pnl, TC_L.CONFIG_TITLE)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        settingsCategory = category
    else
        pnl.name = TC_L.CONFIG_TITLE
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(pnl)
        end
    end

    -- Premier rendu de l'arbre (hors affichage, pour initialiser le pool)
    RefreshTree()
    RefreshDetail()
end

--- Ouvre le panneau de configuration.
function TC.ConfigUI.Open()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(TC_L.CONFIG_TITLE)
    end
end
