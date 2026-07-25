# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Custom QML plugins for DankMaterialShell (a Quickshell-based desktop shell). These are modified copies of DMS built-in widgets with specific customizations applied.

**Upstream:** https://github.com/AvengeMedia/DankMaterialShell
**Original widgets path:** `quickshell/Modules/DankBar/Widgets/`

## Development

No build/lint/test commands - QML plugins are loaded directly by DMS at runtime.

**Testing changes:**
1. Edit QML files
2. `dms restart` to restart the running shell and pick up the changes

**Checking QML syntax without a restart:** `qmlformat <file> >/dev/null` parses the file and fails
loudly on syntax errors. `qmllint` also works but floods the output with unresolved-import warnings,
since `qs.*` imports only resolve inside the running DMS.

## Code Conventions

- **Follow upstream DMS style, not personal/global style rules.** These plugins are modified copies of DMS widgets and must stay diff-friendly against upstream. In particular: **use semicolons** in QML JavaScript (DMS style), even though the global personal style guide says no semicolons — the global rule does NOT apply here.
- JavaScript in QML: semicolons, arrow functions, template literals, single quotes (matching DMS)
- Property bindings for reactive state propagation
- Event-driven updates with debouncing where needed

## Architecture

**Plugin structure:** Each plugin has `PluginName.qml` + `plugin.json` metadata. `plugin.json`'s
`type` field is `widget` for bar widgets and `daemon` for headless plugins (only `Screensaver`).

**Key services:**
- `PluginService` - Plugin data persistence (`loadPluginData`, `savePluginData`)
- `SessionData` - DMS-owned per-session state (tray order, hidden tray IDs) — shared with built-in widgets, unlike `PluginService`
- `SettingsData` - User-facing DMS settings (scroll modes, visualizer toggle, workspace options)
- `CompositorService` - Window/workspace management; `NiriService` for niri-specific calls (`focusWindow`)
- `Theme` - Theming system (colors, spacing, fonts)
- `DesktopEntries` - Application metadata

**PluginService key ≠ directory name.** Every plugin keys its data by its own directory name
*except* `CustomSystemTrayBar`, which uses `"SortedSystemTray"` (a leftover from when it did regex
sorting). Changing that string orphans the user's saved icon size and spacing.

**Data flow:**
```
DankBar (parent) → Plugin Widget → Local state + Services → Reactive UI
```

## Upstream Sync

Use `/sync-with-upstream` slash command to sync with upstream DankMaterialShell changes.

Key customizations to preserve are documented in README.md and `.claude/commands/sync-with-upstream.md`.

## Plugin-Specific Notes

- **CustomRunningApps** - Most complex; has scroll switching, middle-click close, context menu, dynamic title width with a root-level debounce cache that survives delegate recreation. `Theme.warning` vs `Theme.primary` distinguishes tabbed from normal column frames.
- **CustomSystemTrayBar** - Long-press drag-and-drop icon reordering, persisted to `SessionData.trayItemOrder` via `setTrayItemOrder()`. Icon size and spacing come from `PluginService` under the `"SortedSystemTray"` key; hide/show uses `SessionData.hideTrayId`/`showTrayId`.
- **CustomWorkspaceSwitcher** - Individual app icons (no grouping — see the `// Custom:` markers), click-to-focus via `NiriService.focusWindow`
- **Screensaver** - Daemon plugin; multi-stage DDC brightness dimming for OLED burn-in protection (not a bar widget)
- **dockerManager** - Independent plugin with own architecture; see `dockerManager/CLAUDE.md`
