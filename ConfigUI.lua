-- ConfigUI.lua
-- Page de configuration accessible depuis Interface > AddOns.
-- Permet de capturer le build de talents attendu pour chaque type de contenu.

local TC = TC or {}
TC.ConfigUI = {}

-- Références aux éléments UI mis à jour dynamiquement
local statusTexts = {}
local settingsCategory = nil

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

--- Construit le panneau principal de configuration.
--- @return Frame
local function BuildConfigPanel()
    local PANEL_WIDTH  = 620
    local PANEL_HEIGHT = 560
    local MARGIN       = 20
    local SECTION_H    = 120

    local panel = CreateFrame("Frame", "TCConfigPanel", UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)

    -- ── Titre ──────────────────────────────────────────────────────────────
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    title:SetText(TC_L.CONFIG_TITLE)

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText(TC_L.CONFIG_SUBTITLE)
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(PANEL_WIDTH - MARGIN * 2)
    desc:SetJustifyH("LEFT")
    desc:SetText(TC_L.CONFIG_DESC)
    desc:SetTextColor(0.7, 0.7, 0.7)

    local sep0 = CreateSeparator(panel, PANEL_WIDTH - MARGIN * 2)
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
        local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", anchorRef, "BOTTOMLEFT", 0, anchorOff)
        header:SetText(ct.label)
        header:SetTextColor(1, 0.82, 0)

        -- Texte de statut (mis à jour dynamiquement)
        local status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -6)
        status:SetWidth(PANEL_WIDTH - MARGIN * 2 - 8)
        status:SetJustifyH("LEFT")
        status:SetText(TC_L.CONFIG_NOT_SET)
        status:SetTextColor(0.6, 0.6, 0.6)
        statusTexts[key] = status

        -- Bouton Capturer
        local captureBtn = CreateButton(panel, 200, 26, TC_L.CONFIG_CAPTURE, function()
            TC.ConfigUI.CaptureBuild(key)
        end)
        captureBtn:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -4, -8)

        -- Bouton Effacer
        local clearBtn = CreateButton(panel, 90, 26, TC_L.CONFIG_CLEAR, function()
            TC.ConfigUI.ClearBuild(key)
        end)
        clearBtn:SetPoint("LEFT", captureBtn, "RIGHT", 8, 0)

        -- Séparateur bas de section
        local sep = CreateSeparator(panel, PANEL_WIDTH - MARGIN * 2)
        sep:SetPoint("TOPLEFT", captureBtn, "BOTTOMLEFT", 0, -14)

        anchorRef = sep
        anchorOff = -16
    end

    -- ── Section Options ─────────────────────────────────────────────────────
    local optHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", anchorRef, "BOTTOMLEFT", 0, anchorOff)
    optHeader:SetText("Options")
    optHeader:SetTextColor(1, 0.82, 0)

    -- Verrouillage
    local lockLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockLabel:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 4, -6)
    lockLabel:SetText(TC_L.CONFIG_SECTION_LOCK)

    local lockBtn = CreateButton(panel, 160, 26, "", function()
        local locked = not TC.SavedVars.IsLocked()
        TC.SavedVars.SetLocked(locked)
        TC.AlertUI.SetLocked(locked)
        TC.Print(locked and TC_L.CONFIG_LOCKED_ON or TC_L.CONFIG_LOCKED_OFF)
        TC.ConfigUI.RefreshStatus()
    end)
    lockBtn:SetPoint("LEFT", lockLabel, "RIGHT", 10, 0)
    panel.lockBtn = lockBtn

    -- Réinitialiser les positions
    local resetBtn = CreateButton(panel, 200, 26, TC_L.CONFIG_RESET_BTN, function()
        TC.SavedVars.ResetPositions()
        TC.AlertUI.ResetPositions()
        TC.Print(TC_L.CONFIG_RESET_POS)
    end)
    resetBtn:SetPoint("TOPLEFT", lockLabel, "BOTTOMLEFT", -4, -8)

    -- ── Rafraîchissement à l'affichage ─────────────────────────────────────
    panel:SetScript("OnShow", function()
        TC.ConfigUI.RefreshStatus()
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
        local count = TC.TalentChecker.CountNodes(saved)
        st:SetText(string.format(TC_L.CONFIG_NODES_COUNT, count))
        st:SetTextColor(0.2, 1, 0.2)
    end
end

--- Capture le build de talents actuel et le sauvegarde pour un type de contenu.
--- @param contentType string  "solo", "group" ou "raid"
function TC.ConfigUI.CaptureBuild(contentType)
    local serialized = TC.TalentChecker.GetCurrentBuildSerialized()
    if not serialized then
        TC.Print(TC_L.CONFIG_NO_TALENTS)
        return
    end
    if serialized == "" then
        TC.Print(TC_L.CONFIG_NO_SPEC)
        return
    end

    TC.SavedVars.SetExpectedBuild(contentType, serialized)
    local count = TC.TalentChecker.CountNodes(serialized)
    TC.Print(string.format(TC_L.CONFIG_CAPTURE_OK, count))
    UpdateStatusText(contentType)
end

--- Efface le build configuré pour un type de contenu.
--- @param contentType string
function TC.ConfigUI.ClearBuild(contentType)
    TC.SavedVars.ClearExpectedBuild(contentType)
    TC.Print(TC_L.CONFIG_CLEAR_OK)
    UpdateStatusText(contentType)
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
