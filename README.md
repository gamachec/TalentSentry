# TalentSentry

A World of Warcraft addon (compatible with interface 12.0.1+) that monitors your active talent build and displays a visual alert when it does not match the expected profile for your current content type.

## Features

TalentSentry detects what kind of content you are currently doing — **Solo**, **Group (5-man)**, or **Raid** — and compares your active talent build against the expected build you configured for that context. If they do not match, a pulsing alert icon appears on your screen to remind you to switch builds before it is too late.

Checks are automatically suspended while in combat to avoid unnecessary overhead.

## Alert Icon

- Displayed only when a mismatch is detected
- Features a **pulsing golden glow** effect
- Freely **draggable** anywhere on screen
- Position is **saved** between sessions
- **Right-click** opens a context menu with options to lock, reset position, or open the configuration panel

## Setup

1. For each content type (Solo, Group, Raid), equip the talent build you want to use.
2. Open the configuration panel via `/talentsentry config` or through **Interface > AddOns > TalentSentry**.
3. Click **Save current build** next to the relevant content type.
4. TalentSentry will now alert you whenever your active talents differ from the saved build for that context.

## Slash Commands

| Command | Description |
|---|---|
| `/talentsentry config` | Open the configuration panel |
| `/talentsentry debug` | Toggle debug mode |
| `/talentsentry lock` | Lock / unlock the alert icon position |
| `/talentsentry reset` | Reset the icon to its default position |
| `/talentsentry check` | Manually re-run the talent check |

The shorthand `/ts` is also available as an alias.

## Compatibility

- **Interface**: 12.0.1+ (Midnight)
- **WoW API**: Modern API only (no deprecated pre-10.x functions)
- **Dependencies**: None — no external libraries required (no LibStub, no AceAddon)

## File Structure

```
TalentSentry/
├── TalentSentry.toc   # Addon manifest
├── Core.lua           # Entry point, event registration, coordination
├── TalentSentry.lua   # Talent check logic (reads C_Traits, serializes and compares builds)
├── AlertUI.lua        # Alert icon frame, glow animation, drag & drop
├── SavedVars.lua      # Read/write access to TalentSentryDB (SavedVariables)
├── Config.lua         # Constants (icon path, default position, icon size)
├── ConfigUI.lua       # Configuration panel (Interface > AddOns)
└── Locales/
    └── frFR.lua       # French localization
```
