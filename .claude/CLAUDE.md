# TalentSentry — Consignes de développement

## Présentation du projet

Addon World of Warcraft (compatible 12.0.1+) disponible pour toutes les classes.
Il surveille en temps réel le build de talents actif et affiche une alerte visuelle si celui-ci ne correspond pas au profil attendu pour le type de contenu actuel.

---

## Fonctionnalité

### Alerte — Talents incorrects
- Détecte le type de contenu actuel : **Solo**, **Groupe (5j)**, **Raid**
- Chaque profil de contenu est associé à un build de talents attendu (configurable via l'UI)
- Si les talents actifs ne correspondent pas au build attendu, une icône d'alerte s'affiche
- Les checks sont suspendus en combat pour éviter les erreurs et la charge inutile

---

## UI — Icône d'alerte

- L'alerte est représentée par une **icône avec un halo doré pulsant** (effet glow via `UI-ActionButton-Border`, blend mode ADD)
- L'icône est **déplaçable librement** par glisser-déposer (drag & drop)
- La position est **sauvegardée** entre les sessions via `SavedVariables`
- L'icône ne s'affiche que si la condition d'alerte est active
- Un clic droit propose un menu contextuel (verrouiller, réinitialiser la position, ouvrir la config)

---

## Architecture du code

```
TalentSentry/
├── TalentSentry.toc   # Manifeste de l'addon
├── Core.lua            # Initialisation, events principaux, coordination
├── TalentSentry.lua   # Logique de vérification des talents
├── AlertUI.lua         # Création et gestion de l'icône d'alerte (frame, animation, drag & drop)
├── SavedVars.lua       # Lecture/écriture de TalentSentryDB (SavedVariables)
├── Config.lua          # Constantes (icône, position par défaut, taille)
├── ConfigUI.lua        # Page de configuration (Interface > AddOns)
└── Locales/
    └── frFR.lua        # Localisation française
```

### Rôle de chaque module

| Fichier | Responsabilité |
|---|---|
| `Core.lua` | Point d'entrée, enregistrement des events, appel aux checkers |
| `TalentSentry.lua` | Lit les talents actifs via `C_Traits`, sérialise et compare au profil attendu |
| `AlertUI.lua` | Gère la frame d'alerte, l'animation de halo, le drag & drop |
| `SavedVars.lua` | Centralise l'accès à `TalentSentryDB` (SavedVariables) |
| `Config.lua` | Constantes : icône, position par défaut, taille |
| `ConfigUI.lua` | Panneau de config enregistré via `Settings.RegisterCanvasLayoutCategory` |

---

## Conventions de code Lua / WoW API

- **Namespace** : `TC = TC or {}` (global dans `Core.lua`, `local TC = TC or {}` dans les autres fichiers)
- **Locales** : table globale `TC_L` définie dans `Locales/frFR.lua`
- **Events** : enregistrer uniquement les events nécessaires
- **Commentaires** : documenter chaque fonction publique avec son rôle et ses paramètres
- **Nommage** : `PascalCase` pour les fonctions publiques, `camelCase` pour les variables locales
- **Pas de `print()` en production** : utiliser `TC.Debug()` (conditionnel via `TC.db.debug`)
- Utiliser `C_Timer.After` ou `OnUpdate` avec prudence (éviter les mises à jour trop fréquentes)

---

## Compatibilité

- Interface cible : **12.0.1** et supérieur (Midnight)
- API WoW utilisée : moderne (pas de fonctions dépréciées pre-10.x)
- Pas de dépendance à des librairies externes (LibStub, AceAddon, etc.)

---

## Variables sauvegardées (`SavedVariables`)

Nom de la variable globale : `TalentSentryDB`

Structure :
```lua
TalentSentryDB = {
    positions = {
        talent = { x = 0, y = 100 },
    },
    locked = false,
    debug  = false,
    expectedBuilds = {
        solo  = nil,  -- chaîne sérialisée "nodeID:ranks,..." ou nil
        group = nil,
        raid  = nil,
    },
}
```

---

## Données de référence (`Config.lua`)

- **Icône** : `TC.ALERT_ICONS.talent` — chemin statique de secours
- **Position par défaut** : `TC.DEFAULT_POSITIONS.talent` — offset `{ x = 0, y = 100 }` depuis le centre
- **Taille de l'icône** : `TC.ICON_SIZE = 48`

---

## Points d'attention

- La détection du type de contenu se fait via `IsInRaid()` et `IsInGroup()`
- Les talents sont lus via `C_ClassTalents.GetActiveConfigID()` + `C_Traits.GetNodeInfo()`
- La sérialisation du build : `"nodeID:ranks,nodeID:ranks,..."` trié par nodeID (comparaison stable)
- L'animation de halo utilise `UI-ActionButton-Border` (64×64, centre transparent ~36px) dimensionnée à `iconSize × 2.30`, blend mode `ADD`, alpha pulsant entre 0.15 et 0.65
- Les checks sont bloqués pendant le combat (`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`)

---

## Commandes slash

| Commande | Action |
|---|---|
| `/tc config` | Ouvre le panneau de configuration |
| `/tc debug` | Active/désactive le mode debug |
| `/tc lock` | Verrouille/déverrouille les icônes |
| `/tc reset` | Réinitialise les positions |
| `/tc check` | Relance manuellement les vérifications |
