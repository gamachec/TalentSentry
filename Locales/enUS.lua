-- Locales/enUS.lua
-- Default locale for TalentSentry (English)
-- Loaded first; other locale files override only what they need.

TC_L = {
    -- General
    ADDON_NAME            = "TalentSentry",
    DEBUG_ON              = "[TC] Debug mode enabled.",
    DEBUG_OFF             = "[TC] Debug mode disabled.",

    -- Alerts
    ALERT_TALENTS         = "Wrong talents",
    ALERT_TALENTS_TIP     = "Your talents do not match the expected profile for this content type.",

    -- Content types
    CONTENT_SOLO          = "Solo",
    CONTENT_GROUP         = "Group (5 players)",  -- kept for compatibility
    CONTENT_DUNGEON       = "Dungeons",
    CONTENT_RAID          = "Raid",

    -- Configuration UI
    CONFIG_TITLE          = "TalentSentry",
    CONFIG_SUBTITLE       = "Expected talent build configuration",
    CONFIG_DESC           = "For each content type, load your talent build\nthen click \"Capture\" to save it as the reference.",
    CONFIG_CAPTURE        = "Capture current build",
    CONFIG_CLEAR          = "Clear",
    CONFIG_NOT_SET        = "No build configured",
    CONFIG_NODES_COUNT    = "%d active talent nodes",
    CONFIG_CAPTURE_OK     = "Build captured (%d nodes).",
    CONFIG_CLEAR_OK       = "Build cleared.",
    CONFIG_NO_TALENTS     = "Unable to read active talents.",
    CONFIG_NO_SPEC        = "No active specialization.",
    CONFIG_LOCKED_ON      = "[TC] Icons locked.",
    CONFIG_LOCKED_OFF     = "[TC] Icons unlocked.",
    CONFIG_RESET_POS      = "[TC] Positions reset.",
    CONFIG_SECTION_LOCK   = "Lock icons",
    CONFIG_SECTION_LOCK_DESC = "Prevents alert icons from being moved.",
    CONFIG_RESET_BTN      = "Reset positions",
    CONFIG_RESET_BTN_DESC = "Resets all icons to their default position.",
    CONFIG_PREVIEW_ICON   = "Show icon for repositioning",

    -- Context menu (right-click on icon)
    MENU_TALENTS          = "Open talents",
    MENU_LOCK             = "Lock icons",
    MENU_UNLOCK           = "Unlock icons",
    MENU_RESET            = "Reset position",
    MENU_CONFIG           = "Open configuration",

    -- Import from export string
    IMPORT_BTN                = "Import",
    IMPORT_LABEL              = "or paste an export string:",
    IMPORT_OK                 = "Build imported (%d nodes).",
    IMPORT_ERROR_EMPTY        = "The string is empty.",
    IMPORT_ERROR_INVALID      = "Invalid or corrupted string.",
    IMPORT_ERROR_VERSION      = "Unsupported version: %s.",
    IMPORT_ERROR_NO_SPEC      = "No active specialization.",
    IMPORT_ERROR_WRONG_SPEC   = "This string is for spec %d (active spec: %d).",
    IMPORT_ERROR_NO_CONFIG    = "No talent configuration available.",
    IMPORT_ERROR_CONFIG       = "Unable to read talent configuration.",

    -- Tree view
    CONFIG_FALLBACK_NOTE  = "If not configured, the \"%s\" default build will be used.",

    -- Season 1 dungeons
    DUNGEON_MAGISTERS_TERRACE   = "Magisters' Terrace",
    DUNGEON_MAISARA_CAVERNS     = "Maisara Caverns",
    DUNGEON_NEXUS_POINT_XENAS   = "Nexus-Point Xenas",
    DUNGEON_WINDRUNNER_SPIRE    = "Windrunner Spire",
    DUNGEON_ALGETHAR_ACADEMY    = "Algeth'ar Academy",
    DUNGEON_SEAT_OF_TRIUMVIRATE = "The Seat of the Triumvirate",
    DUNGEON_SKYREACH            = "Skyreach",
    DUNGEON_PIT_OF_SARON        = "Pit of Saron",

    -- Season 1 raid bosses
    BOSS_IMPERATOR_AVERZIAN    = "Imperator Averzian",
    BOSS_VORASIUS              = "Vorasius",
    BOSS_FALLEN_KING_SALHADAAR = "Fallen-King Salhadaar",
    BOSS_VAELGOR_EZZORAK       = "Vaelgor & Ezzorak",
    BOSS_LIGHTBLINDED_VANGUARD = "Lightblinded Vanguard",
    BOSS_CROWN_OF_COSMOS       = "Crown of the Cosmos",
    BOSS_CHIMAERUS             = "Chimaerus",
    BOSS_BELOREN               = "Belo'ren, Child of Al'ar",
    BOSS_MIDNIGHT_FALLS        = "Midnight Falls",

    -- Slash commands
    SLASH_HELP            = "Available commands:\n  /talentsentry config  — Open configuration\n  /talentsentry debug   — Toggle debug mode\n  /talentsentry lock    — Lock/unlock icons\n  /talentsentry reset   — Reset positions",
    SLASH_UNKNOWN         = "Unknown command. Type /talentsentry for help.",
}
