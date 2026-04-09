-- AlertUI.lua
-- Crée et gère les icônes d'alerte (frames, animations, drag & drop).

local TC = TC or {}
TC.AlertUI = {}

-- Table des frames d'alerte créées
local alerts = {}

-- ============================================================
-- Menu contextuel
-- ============================================================

--- Affiche le menu contextuel au clic droit.
--- @param self Frame  La frame sur laquelle le menu est ouvert
local function ShowContextMenu(self)
    local menu = {
        {
            text = TC.SavedVars.IsLocked() and TC_L.MENU_UNLOCK or TC_L.MENU_LOCK,
            func = function()
                local locked = not TC.SavedVars.IsLocked()
                TC.SavedVars.SetLocked(locked)
                TC.AlertUI.SetLocked(locked)
                TC.Print(locked and TC_L.CONFIG_LOCKED_ON or TC_L.CONFIG_LOCKED_OFF)
            end,
        },
        {
            text = TC_L.MENU_RESET,
            func = function()
                TC.SavedVars.ResetPositions()
                TC.AlertUI.ResetPositions()
                TC.Print(TC_L.CONFIG_RESET_POS)
            end,
        },
        {
            text = TC_L.MENU_CONFIG,
            func = function()
                TC.ConfigUI.Open()
            end,
        },
        { text = "Annuler" },
    }

    EasyMenu(menu, CreateFrame("Frame", "TCContextMenuFrame", UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")
end

-- ============================================================
-- Création d'une icône d'alerte
-- ============================================================

-- Texture de référence pour le glow (anneau avec centre transparent)
local GLOW_TEX = "Interface\\Buttons\\UI-ActionButton-Border"

--- Crée une animation alpha pulsante (BOUNCE) sur une texture.
--- @param tex Texture
--- @param fromAlpha number
--- @param toAlpha number
--- @param duration number
--- @return AnimationGroup
local function AddPulse(tex, fromAlpha, toAlpha, duration)
    local group = tex:CreateAnimationGroup()
    group:SetLooping("BOUNCE")
    local anim = group:CreateAnimation("Alpha")
    anim:SetFromAlpha(fromAlpha)
    anim:SetToAlpha(toAlpha)
    anim:SetDuration(duration)
    anim:SetSmoothing("IN_OUT")
    return group
end

--- Crée une frame d'alerte déplaçable avec icône et effet glow rotatif.
--- @param key string  Identifiant de l'alerte ("talent", "arcane", etc.)
--- @param iconPath string  Chemin de la texture d'icône (fallback)
--- @return Frame
local function CreateAlertFrame(key, iconPath)
    local size = TC.ICON_SIZE

    -- UI-ActionButton-Border est une texture 64×64 dont le centre transparent
    -- fait ~36px. Pour que l'anneau visible encadre notre icône de `size`px,
    -- on dimensionne la texture à size × (64/36) ≈ size × 1.78.
    local haloSize  = math.floor(size * 2.30)

    -- Frame principale (conteneur, cliquable)
    local frame = CreateFrame("Button", "TCAlert_" .. key, UIParent)
    frame:SetSize(size, size)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Ancrage initial depuis les coordonnées sauvegardées
    local x, y = TC.SavedVars.GetPosition(key)
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    -- ── Halo extérieur doux (pulsant) ───────────────────────────────────────
    local halo = frame:CreateTexture(nil, "OVERLAY", nil, -3)
    halo:SetSize(haloSize, haloSize)
    halo:SetPoint("CENTER", frame, "CENTER")
    halo:SetTexture(GLOW_TEX)
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(1, 0.75, 0, 1)   -- doré chaud

    -- ── Animation ───────────────────────────────────────────────────────────
    frame.glowGroups = { AddPulse(halo, 0.15, 0.65, 1.0) }

    -- ── Icône principale ────────────────────────────────────────────────────
    -- (posée après les couches de glow pour être au-dessus dans ARTWORK)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local spellID = TC.ICON_SPELL_IDS and TC.ICON_SPELL_IDS[key]
    local dynamicIcon = spellID and C_Spell.GetSpellTexture(spellID)
    icon:SetTexture(dynamicIcon or iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipTitle or "", 1, 0.2, 0.2)
        if self.tooltipBody and self.tooltipBody ~= "" then
            GameTooltip:AddLine(self.tooltipBody, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Clics
    frame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowContextMenu(self)
        end
    end)

    -- Drag & Drop
    frame:SetScript("OnDragStart", function(self)
        if not TC.SavedVars.IsLocked() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Sauvegarder la position relative au centre de l'écran
        local cx = UIParent:GetWidth()  / 2
        local cy = UIParent:GetHeight() / 2
        local fx = self:GetLeft() + self:GetWidth()  / 2 - cx
        local fy = self:GetTop()  - self:GetHeight() / 2 - cy
        TC.SavedVars.SetPosition(key, fx, fy)
    end)
    frame:RegisterForDrag("LeftButton")

    frame.key = key
    return frame
end

-- ============================================================
-- Initialisation
-- ============================================================

--- Initialise toutes les frames d'alerte.
function TC.AlertUI.Init()
    local frame = CreateAlertFrame("talent", TC.ALERT_ICONS.talent)
    frame.tooltipTitle = TC_L.ALERT_TALENTS
    frame.tooltipBody  = TC_L.ALERT_TALENTS_TIP
    alerts["talent"] = frame
end

-- ============================================================
-- Affichage / masquage des alertes
-- ============================================================

--- Affiche ou masque une alerte spécifique.
--- @param key string
--- @param visible boolean
--- @param tooltipBody string|nil  Texte dynamique du tooltip (ex: liste de noms)
function TC.AlertUI.SetAlert(key, visible, tooltipBody)
    local frame = alerts[key]
    if not frame then return end

    if tooltipBody then
        frame.tooltipBody = tooltipBody
    end

    if visible then
        frame:Show()
        for _, group in ipairs(frame.glowGroups or {}) do
            if not group:IsPlaying() then group:Play() end
        end
    else
        frame:Hide()
        for _, group in ipairs(frame.glowGroups or {}) do
            group:Stop()
        end
    end
end

--- Met à jour toutes les alertes en fonction de l'état actuel des checkers.
--- @param contentType string  "solo", "group" ou "raid"
function TC.AlertUI.UpdateAll(contentType)
    TC.AlertUI.SetAlert("talent", TC.TalentChecker.Check(contentType))
end

--- Masque toutes les alertes.
function TC.AlertUI.HideAll()
    for _, frame in pairs(alerts) do
        frame:Hide()
        for _, group in ipairs(frame.glowGroups or {}) do
            group:Stop()
        end
    end
end

-- ============================================================
-- Verrouillage / déverrouillage
-- ============================================================

--- Applique l'état de verrouillage à toutes les frames.
--- @param locked boolean
function TC.AlertUI.SetLocked(locked)
    for _, frame in pairs(alerts) do
        frame:SetMovable(not locked)
    end
end

-- ============================================================
-- Réinitialisation des positions
-- ============================================================

--- Remet toutes les icônes à leur position par défaut.
function TC.AlertUI.ResetPositions()
    for key, frame in pairs(alerts) do
        local def = TC.DEFAULT_POSITIONS[key]
        if def then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", def.x, def.y)
        end
    end
end
