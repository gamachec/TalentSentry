-- Locales/frFR.lua
-- Localisation française pour TalentSentry
-- Chargé après enUS.lua ; écrase uniquement les clés nécessaires.

if GetLocale() ~= "frFR" then return end

TC_L.ADDON_NAME            = "TalentSentry"
TC_L.DEBUG_ON              = "[TC] Mode debug activé."
TC_L.DEBUG_OFF             = "[TC] Mode debug désactivé."

TC_L.ALERT_TALENTS         = "Talents incorrects"
TC_L.ALERT_TALENTS_TIP     = "Vos talents ne correspondent pas au profil attendu pour ce type de contenu."

TC_L.CONTENT_SOLO          = "Solo"
TC_L.CONTENT_GROUP         = "Groupe (5 joueurs)"
TC_L.CONTENT_DUNGEON       = "Donjons"
TC_L.CONTENT_RAID          = "Raid"

TC_L.CONFIG_TITLE          = "TalentSentry"
TC_L.CONFIG_SUBTITLE       = "Configuration des builds de talents attendus"
TC_L.CONFIG_DESC           = "Pour chaque type de contenu, chargez votre build de talents\npuis cliquez sur « Capturer » pour l'enregistrer comme référence."
TC_L.CONFIG_CAPTURE        = "Capturer le build actuel"
TC_L.CONFIG_CLEAR          = "Effacer"
TC_L.CONFIG_NOT_SET        = "Aucun build configuré"
TC_L.CONFIG_NODES_COUNT    = "%d nœuds de talent actifs"
TC_L.CONFIG_CAPTURE_OK     = "Build capturé (%d nœuds)."
TC_L.CONFIG_CLEAR_OK       = "Build effacé."
TC_L.CONFIG_NO_TALENTS     = "Impossible de lire les talents actifs."
TC_L.CONFIG_NO_SPEC        = "Aucune spécialisation active."
TC_L.CONFIG_LOCKED_ON      = "[TC] Icônes verrouillées."
TC_L.CONFIG_LOCKED_OFF     = "[TC] Icônes déverrouillées."
TC_L.CONFIG_RESET_POS      = "[TC] Positions réinitialisées."
TC_L.CONFIG_SECTION_LOCK   = "Verrouiller les icônes"
TC_L.CONFIG_SECTION_LOCK_DESC = "Empêche le déplacement des icônes d'alerte."
TC_L.CONFIG_RESET_BTN      = "Réinitialiser les positions"
TC_L.CONFIG_RESET_BTN_DESC = "Remet toutes les icônes à leur position par défaut."
TC_L.CONFIG_PREVIEW_ICON   = "Afficher l'icône pour repositionnement"

TC_L.MENU_TALENTS          = "Ouvrir les talents"
TC_L.MENU_LOCK             = "Verrouiller les icônes"
TC_L.MENU_UNLOCK           = "Déverrouiller les icônes"
TC_L.MENU_RESET            = "Réinitialiser la position"
TC_L.MENU_CONFIG           = "Ouvrir la configuration"

TC_L.IMPORT_BTN                = "Importer"
TC_L.IMPORT_LABEL              = "ou coller une chaîne d'exportation :"
TC_L.IMPORT_OK                 = "Build importé (%d nœuds)."
TC_L.IMPORT_ERROR_EMPTY        = "La chaîne est vide."
TC_L.IMPORT_ERROR_INVALID      = "Chaîne invalide ou corrompue."
TC_L.IMPORT_ERROR_VERSION      = "Version non supportée : %s."
TC_L.IMPORT_ERROR_NO_SPEC      = "Aucune spécialisation active."
TC_L.IMPORT_ERROR_WRONG_SPEC   = "Cette chaîne est pour la spé %d (spé active : %d)."
TC_L.IMPORT_ERROR_NO_CONFIG    = "Aucune configuration de talents disponible."
TC_L.IMPORT_ERROR_CONFIG       = "Impossible de lire la configuration de talents."

TC_L.CONFIG_CURRENT_PROFILE = "Profil actif : %s — %s"

TC_L.CONFIG_FALLBACK_NOTE  = "Si non configuré, le build par défaut « %s » sera utilisé."

TC_L.DUNGEON_MAGISTERS_TERRACE   = "Terrasse des magistères"
TC_L.DUNGEON_MAISARA_CAVERNS     = "Cavernes de Maisara"
TC_L.DUNGEON_NEXUS_POINT_XENAS   = "Point-nexus Xenas"
TC_L.DUNGEON_WINDRUNNER_SPIRE    = "Flèche de Coursevent"
TC_L.DUNGEON_ALGETHAR_ACADEMY    = "Académie d'Algeth'ar"
TC_L.DUNGEON_SEAT_OF_TRIUMVIRATE = "Siège du triumvirat"
TC_L.DUNGEON_SKYREACH            = "Orée-du-ciel"
TC_L.DUNGEON_PIT_OF_SARON        = "Fosse de Saron"

TC_L.RAID_THE_VOIDSPIRE       = "Flèche du Vide"
TC_L.RAID_MARCH_ON_QUELDANAS  = "Marche sur Quel'Danas"
TC_L.RAID_THE_DREAMRIFT       = "Faille du Rêve"

TC_L.SLASH_HELP            = "Commandes disponibles :\n  /talentsentry config    — Ouvrir la configuration\n  /talentsentry debug     — Activer/désactiver le debug\n  /talentsentry lock      — Verrouiller/déverrouiller les icônes\n  /talentsentry reset     — Réinitialiser les positions\n  /talentsentry check     — Relancer les vérifications"
TC_L.SLASH_UNKNOWN         = "Commande inconnue. Tapez /talentsentry pour l'aide."
