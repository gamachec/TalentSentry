-- Config.lua
-- Constantes de configuration : spell IDs, seuils, paramètres globaux

local TC = TC or {}

-- ============================================================
-- Icône d'alerte
-- ============================================================

TC.ALERT_ICONS = {
    talent = "Interface\\Icons\\inv_inscription_talentcodex01",
}

-- ============================================================
-- Positions par défaut des icônes (offsets depuis le centre de l'écran)
-- ============================================================

TC.DEFAULT_POSITIONS = {
    talent = { x = 0, y = 100 },
}

-- Taille des icônes d'alerte (en pixels)
TC.ICON_SIZE = 48

-- ============================================================
-- Debug
-- ============================================================

-- Passer à true temporairement pour afficher les logs de debug
TC.DEBUG_DEFAULT = false
