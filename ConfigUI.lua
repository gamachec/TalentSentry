-- ConfigUI.lua
-- Page de configuration accessible depuis Interface > AddOns.
-- Permet de capturer le build de talents attendu pour chaque type de contenu.

local TC = TC or {}
TC.ConfigUI = {}

-- Références aux éléments UI mis à jour dynamiquement
local statusTexts = {}
local importEditBoxes = {}
local settingsCategory = nil
local previewCheckbox = nil

-- ============================================================
-- Construction du panneau
-- ============================================================

--- Crée un bouton WoW standard avec texte.
--- @param parent Frame
--- @param width number
--- @param height number
--- @param label string
--- @param onClick function
--- @return Button
local function CreateButton(parent, width, height, label, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

--- Crée un séparateur horizontal.
--- @param parent Frame
--- @param width number
--- @return Texture
local function CreateSeparator(parent, width)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetWidth(width)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    return sep
end

--- Crée un champ de saisie WoW standard.
--- @param parent Frame
--- @param width number
--- @param height number
--- @return EditBox
local function CreateEditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, height)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(512)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

--- Construit le panneau principal de configuration.
--- @return Frame
local function BuildConfigPanel()
    local PANEL_WIDTH    = 620
    local PANEL_HEIGHT   = 560   -- hauteur visible dans la fenêtre Settings
    local CONTENT_WIDTH  = 584   -- largeur du contenu défilable (moins la scrollbar)
    local CONTENT_HEIGHT = 720   -- hauteur totale du contenu
    local MARGIN         = 20

    -- Frame principale enregistrée dans Settings (taille = zone visible)
    local panel = CreateFrame("Frame", "TCConfigPanel", UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)

    -- ScrollFrame couvrant tout le panel (sauf 26px à droite pour la scrollbar)
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     panel, "TOPLEFT",     4,   -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26,  4)

    -- Frame enfant défilable : contient tous les éléments UI
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(CONTENT_WIDTH, CONTENT_HEIGHT)
    scrollFrame:SetScrollChild(content)

    -- ── Titre ──────────────────────────────────────────────────────────────
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    title:SetText(TC_L.CONFIG_TITLE)

    local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText(TC_L.CONFIG_SUBTITLE)
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(CONTENT_WIDTH - MARGIN * 2)
    desc:SetJustifyH("LEFT")
    desc:SetText(TC_L.CONFIG_DESC)
    desc:SetTextColor(0.7, 0.7, 0.7)

    local sep0 = CreateSeparator(content, CONTENT_WIDTH - MARGIN * 2)
    sep0:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)

    -- ── Sections Talents ────────────────────────────────────────────────────

    local contentTypes = {
        { key = "solo",  label = TC_L.CONTENT_SOLO  },
        { key = "group", label = TC_L.CONTENT_GROUP },
        { key = "raid",  label = TC_L.CONTENT_RAID  },
    }

    local anchorRef = sep0
    local anchorOff = -16

    for _, ct in ipairs(contentTypes) do
        local key = ct.key

        -- En-tête de section
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", anchorRef, "BOTTOMLEFT", 0, anchorOff)
        header:SetText(ct.label)
        header:SetTextColor(1, 0.82, 0)

        -- Texte de statut (mis à jour dynamiquement)
        local status = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -6)
        status:SetWidth(CONTENT_WIDTH - MARGIN * 2 - 8)
        status:SetJustifyH("LEFT")
        status:SetText(TC_L.CONFIG_NOT_SET)
        status:SetTextColor(0.6, 0.6, 0.6)
        statusTexts[key] = status

        -- Bouton Capturer
        local captureBtn = CreateButton(content, 200, 26, TC_L.CONFIG_CAPTURE, function()
            TC.ConfigUI.CaptureBuild(key)
        end)
        captureBtn:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -4, -8)

        -- Bouton Effacer
        local clearBtn = CreateButton(content, 90, 26, TC_L.CONFIG_CLEAR, function()
            TC.ConfigUI.ClearBuild(key)
        end)
        clearBtn:SetPoint("LEFT", captureBtn, "RIGHT", 8, 0)

        -- Label import
        local importLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        importLabel:SetPoint("TOPLEFT", captureBtn, "BOTTOMLEFT", 4, -10)
        importLabel:SetText(TC_L.IMPORT_LABEL)
        importLabel:SetTextColor(0.7, 0.7, 0.7)

        -- Champ de saisie pour la chaîne d'exportation
        local importBox = CreateEditBox(content, 350, 20)
        importBox:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", -4, -6)
        importEditBoxes[key] = importBox

        -- Bouton Importer (capture importBox directement pour éviter le lookup de table)
        local importBtn = CreateButton(content, 100, 26, TC_L.IMPORT_BTN, function()
            local ok, err = pcall(TC.ConfigUI.ImportBuild, key, importBox)
            if not ok then
                TC.Print("|cffff4444[TC] Erreur Lua :|r " .. tostring(err))
            end
        end)
        importBtn:SetPoint("LEFT", importBox, "RIGHT", 8, 0)

        -- Séparateur bas de section
        local sep = CreateSeparator(content, CONTENT_WIDTH - MARGIN * 2)
        sep:SetPoint("TOPLEFT", importBox, "BOTTOMLEFT", 0, -14)

        anchorRef = sep
        anchorOff = -16
    end

    -- ── Section Options ─────────────────────────────────────────────────────
    local optHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", anchorRef, "BOTTOMLEFT", 0, anchorOff)
    optHeader:SetText("Options")
    optHeader:SetTextColor(1, 0.82, 0)

    -- Option : afficher l'icône pour repositionnement
    local previewCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    previewCheck:SetSize(24, 24)
    previewCheck:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -6)
    previewCheck:SetChecked(false)
    previewCheck:SetScript("OnClick", function(self)
        TC.AlertUI.SetPreviewMode(self:GetChecked())
    end)

    local previewLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("LEFT", previewCheck, "RIGHT", 2, 0)
    previewLabel:SetText(TC_L.CONFIG_PREVIEW_ICON)

    previewCheckbox = previewCheck

    -- Verrouillage
    local lockLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockLabel:SetPoint("TOPLEFT", previewCheck, "BOTTOMLEFT", 4, -10)
    lockLabel:SetText(TC_L.CONFIG_SECTION_LOCK)

    local lockBtn = CreateButton(content, 160, 26, "", function()
        local locked = not TC.SavedVars.IsLocked()
        TC.SavedVars.SetLocked(locked)
        TC.AlertUI.SetLocked(locked)
        TC.Print(locked and TC_L.CONFIG_LOCKED_ON or TC_L.CONFIG_LOCKED_OFF)
        TC.ConfigUI.RefreshStatus()
    end)
    lockBtn:SetPoint("LEFT", lockLabel, "RIGHT", 10, 0)
    panel.lockBtn = lockBtn

    -- Réinitialiser les positions
    local resetBtn = CreateButton(content, 200, 26, TC_L.CONFIG_RESET_BTN, function()
        TC.SavedVars.ResetPositions()
        TC.AlertUI.ResetPositions()
        TC.Print(TC_L.CONFIG_RESET_POS)
    end)
    resetBtn:SetPoint("TOPLEFT", lockLabel, "BOTTOMLEFT", -4, -8)

    -- ── Rafraîchissement à l'affichage ─────────────────────────────────────
    panel:SetScript("OnShow", function()
        TC.ConfigUI.RefreshStatus()
        if previewCheck:GetChecked() then
            TC.AlertUI.SetPreviewMode(true)
        end
    end)

    panel:SetScript("OnHide", function()
        if previewCheck:GetChecked() then
            previewCheck:SetChecked(false)
            TC.AlertUI.SetPreviewMode(false)
        end
    end)

    return panel
end

-- ============================================================
-- Logique de capture / suppression
-- ============================================================

--- Met à jour le texte de statut pour un type de contenu.
--- @param key string
local function UpdateStatusText(key)
    local st = statusTexts[key]
    if not st then return end

    local saved = TC.SavedVars.GetExpectedBuild(key)
    if not saved then
        st:SetText(TC_L.CONFIG_NOT_SET)
        st:SetTextColor(0.6, 0.6, 0.6)
    else
        local count = TC.TalentSentry.CountNodes(saved)
        st:SetText(string.format(TC_L.CONFIG_NODES_COUNT, count))
        st:SetTextColor(0.2, 1, 0.2)
    end
end

--- Capture le build de talents actuel et le sauvegarde pour un type de contenu.
--- @param contentType string  "solo", "group" ou "raid"
function TC.ConfigUI.CaptureBuild(contentType)
    local serialized = TC.TalentSentry.GetCurrentBuildSerialized()
    if not serialized then
        TC.Print(TC_L.CONFIG_NO_TALENTS)
        return
    end
    if serialized == "" then
        TC.Print(TC_L.CONFIG_NO_SPEC)
        return
    end

    TC.SavedVars.SetExpectedBuild(contentType, serialized)
    local count = TC.TalentSentry.CountNodes(serialized)
    TC.Print(string.format(TC_L.CONFIG_CAPTURE_OK, count))
    UpdateStatusText(contentType)
    TC.RunAllChecks()
end

--- Importe un build depuis la chaîne d'exportation saisie dans le champ correspondant.
--- @param contentType string  "solo", "group" ou "raid"
--- @param editBoxArg EditBox  référence directe au champ (prioritaire sur la table)
function TC.ConfigUI.ImportBuild(contentType, editBoxArg)
    local editBox = editBoxArg or importEditBoxes[contentType]
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
        -- Erreur Lua dans le parseur — affiche le détail pour le debug
        TC.Print("|cffff4444[TC] Erreur interne :|r " .. tostring(serializedOrErr))
        return
    end
    local serialized, err = serializedOrErr, parseErr
    if not serialized or serialized == "" then
        TC.Print("|cffff4444[TC]|r " .. (err or TC_L.IMPORT_ERROR_INVALID))
        return
    end

    TC.SavedVars.SetExpectedBuild(contentType, serialized)
    editBox:SetText("")
    editBox:ClearFocus()
    local count = TC.TalentSentry.CountNodes(serialized)
    TC.Print(string.format(TC_L.IMPORT_OK, count))
    UpdateStatusText(contentType)
    TC.RunAllChecks()
end

--- Efface le build configuré pour un type de contenu.
--- @param contentType string
function TC.ConfigUI.ClearBuild(contentType)
    TC.SavedVars.ClearExpectedBuild(contentType)
    TC.Print(TC_L.CONFIG_CLEAR_OK)
    UpdateStatusText(contentType)
    TC.RunAllChecks()
end

--- Rafraîchit tous les textes de statut et boutons du panneau.
function TC.ConfigUI.RefreshStatus()
    UpdateStatusText("solo")
    UpdateStatusText("group")
    UpdateStatusText("raid")

    -- Mettre à jour le libellé du bouton de verrouillage si la panel existe
    local panel = _G["TCConfigPanel"]
    if panel and panel.lockBtn then
        panel.lockBtn:SetText(
            TC.SavedVars.IsLocked() and TC_L.MENU_UNLOCK or TC_L.MENU_LOCK
        )
    end
end

-- ============================================================
-- Enregistrement dans le menu Interface > AddOns
-- ============================================================

--- Initialise et enregistre le panneau de configuration WoW.
function TC.ConfigUI.Init()
    local panel = BuildConfigPanel()

    -- API Settings moderne (WoW 10.x+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, TC_L.CONFIG_TITLE)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        settingsCategory = category
    else
        -- Fallback pour versions plus anciennes (ne devrait pas se produire en 12.x)
        panel.name = TC_L.CONFIG_TITLE
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        end
    end
end

--- Ouvre le panneau de configuration.
function TC.ConfigUI.Open()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(TC_L.CONFIG_TITLE)
    end
end
