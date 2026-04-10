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

-- ============================================================
-- Contenu de la saison 1 — Midnight
-- Chargé après les Locales ; les labels référencent TC_L.
-- ============================================================

-- ============================================================
-- Détection d'instance — correspondances instanceID → clé interne
-- Couvre donjons (instanceType "party") et raids (instanceType "raid").
-- Source : BigWigs/LittleWigs + Wowhead. À valider en jeu via :
--   /run print(select(8, GetInstanceInfo()))
-- ============================================================

TC.INSTANCE_IDS = {
    -- Donjons Saison 1
    [2811] = "magisters-terrace",
    [2874] = "maisara-caverns",
    [2915] = "nexus-point-xenas",
    [2805] = "windrunner-spire",
    [2526] = "algethar-academy",
    [1753] = "seat-of-triumvirate",
    [1209] = "skyreach",
    [658]  = "pit-of-saron",
    -- Raids Saison 1
    [2912] = "the-voidspire",
    [2913] = "march-on-queldanas",
    [2939] = "the-dreamrift",
}

-- ============================================================
-- Détection de boss par NPC ID (extrait du GUID de nameplate).
-- Plusieurs NPC IDs peuvent pointer vers le même boss (phases/formes).
-- Source : BigWigs (RegisterEnableMob) + Wowhead.
-- ============================================================

TC.BOSS_NPC_IDS = {
    -- The Voidspire
    [240435] = "imperator-averzian",
    [240434] = "vorasius",
    [240432] = "fallen-king-salhadaar",
    [242056] = "vaelgor-ezzorak",        -- Vaelgor
    [244552] = "vaelgor-ezzorak",        -- Ezzorak
    [240431] = "lightblinded-vanguard",  -- General Amias Bellamy
    [240437] = "lightblinded-vanguard",  -- Commander Venel Lightblood
    [240438] = "lightblinded-vanguard",  -- War Chaplain Senn
    [240430] = "crown-of-cosmos",        -- Alleria (forme combat)
    [243805] = "crown-of-cosmos",        -- Morium
    [243810] = "crown-of-cosmos",        -- Demiar
    [243811] = "crown-of-cosmos",        -- Vorelus
    -- March on Quel'Danas
    [240387] = "beloren",
    [240391] = "midnight-falls",
    -- The Dreamrift
    [245569] = "chimaerus",              -- forme déclencheur / phase 2
    [256116] = "chimaerus",              -- forme principale
}

TC.DUNGEONS = {
    { id = "magisters-terrace",   label = TC_L.DUNGEON_MAGISTERS_TERRACE   },
    { id = "maisara-caverns",     label = TC_L.DUNGEON_MAISARA_CAVERNS     },
    { id = "nexus-point-xenas",   label = TC_L.DUNGEON_NEXUS_POINT_XENAS   },
    { id = "windrunner-spire",    label = TC_L.DUNGEON_WINDRUNNER_SPIRE    },
    { id = "algethar-academy",    label = TC_L.DUNGEON_ALGETHAR_ACADEMY    },
    { id = "seat-of-triumvirate", label = TC_L.DUNGEON_SEAT_OF_TRIUMVIRATE },
    { id = "skyreach",            label = TC_L.DUNGEON_SKYREACH            },
    { id = "pit-of-saron",        label = TC_L.DUNGEON_PIT_OF_SARON        },
}

TC.RAID_BOSSES = {
    { id = "imperator-averzian",    label = TC_L.BOSS_IMPERATOR_AVERZIAN    },
    { id = "vorasius",              label = TC_L.BOSS_VORASIUS              },
    { id = "fallen-king-salhadaar", label = TC_L.BOSS_FALLEN_KING_SALHADAAR },
    { id = "vaelgor-ezzorak",       label = TC_L.BOSS_VAELGOR_EZZORAK       },
    { id = "lightblinded-vanguard", label = TC_L.BOSS_LIGHTBLINDED_VANGUARD },
    { id = "crown-of-cosmos",       label = TC_L.BOSS_CROWN_OF_COSMOS       },
    { id = "chimaerus",             label = TC_L.BOSS_CHIMAERUS             },
    { id = "beloren",               label = TC_L.BOSS_BELOREN               },
    { id = "midnight-falls",        label = TC_L.BOSS_MIDNIGHT_FALLS        },
}
