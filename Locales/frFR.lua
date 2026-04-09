-- Locales/frFR.lua
-- Localisation française pour TalentSentry

TC_L = {
    -- Général
    ADDON_NAME            = "TalentSentry",
    DEBUG_ON              = "[TC] Mode debug activé.",
    DEBUG_OFF             = "[TC] Mode debug désactivé.",

    -- Alertes
    ALERT_TALENTS         = "Talents incorrects",
    ALERT_TALENTS_TIP     = "Vos talents ne correspondent pas au profil attendu pour ce type de contenu.",

    -- Types de contenu
    CONTENT_SOLO          = "Solo",
    CONTENT_GROUP         = "Groupe (5 joueurs)",
    CONTENT_RAID          = "Raid",

    -- Interface de configuration
    CONFIG_TITLE          = "TalentSentry",
    CONFIG_SUBTITLE       = "Configuration des builds de talents attendus",
    CONFIG_DESC           = "Pour chaque type de contenu, chargez votre build de talents\npuis cliquez sur « Capturer » pour l'enregistrer comme référence.",
    CONFIG_CAPTURE        = "Capturer le build actuel",
    CONFIG_CLEAR          = "Effacer",
    CONFIG_NOT_SET        = "Aucun build configuré",
    CONFIG_NODES_COUNT    = "%d nœuds de talent actifs",
    CONFIG_CAPTURE_OK     = "Build capturé (%d nœuds).",
    CONFIG_CLEAR_OK       = "Build effacé.",
    CONFIG_NO_TALENTS     = "Impossible de lire les talents actifs.",
    CONFIG_NO_SPEC        = "Aucune spécialisation active.",
    CONFIG_LOCKED_ON      = "[TC] Icônes verrouillées.",
    CONFIG_LOCKED_OFF     = "[TC] Icônes déverrouillées.",
    CONFIG_RESET_POS      = "[TC] Positions réinitialisées.",
    CONFIG_SECTION_LOCK   = "Verrouiller les icônes",
    CONFIG_SECTION_LOCK_DESC = "Empêche le déplacement des icônes d'alerte.",
    CONFIG_RESET_BTN      = "Réinitialiser les positions",
    CONFIG_RESET_BTN_DESC = "Remet toutes les icônes à leur position par défaut.",

    -- Menu contextuel (clic droit sur icône)
    MENU_LOCK             = "Verrouiller les icônes",
    MENU_UNLOCK           = "Déverrouiller les icônes",
    MENU_RESET            = "Réinitialiser la position",
    MENU_CONFIG           = "Ouvrir la configuration",

    -- Commandes slash
    SLASH_HELP            = "Commandes disponibles :\n  /tc config  — Ouvrir la configuration\n  /tc debug   — Activer/désactiver le debug\n  /tc lock    — Verrouiller/déverrouiller les icônes\n  /tc reset   — Réinitialiser les positions",
    SLASH_UNKNOWN         = "Commande inconnue. Tapez /tc pour l'aide.",
}
