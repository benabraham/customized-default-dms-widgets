# Custom DankMaterialShell Plugins

Modified copies of DMS built-in widgets. The code is copied from DankMaterialShell's default widgets with specific customizations applied.

## Upstream Revision

**Last synced:** 2026-02-23
**Base commit:** `912e3bdf` (dms-greeter: Enable greetd via dms greeter install all-in-one cmd)
**Repository:** https://github.com/AvengeMedia/DankMaterialShell

## CustomFocusedApp

Shows **icon + window title** instead of app name + separator + title.

Changes:
- App name text hidden (`visible: false`)
- Separator dot hidden
- Icon displayed alongside title only
- Settings panel with:
  - "Strip App Name from Title" - Smart removal of app name, version numbers, instance markers, and brand words from titles

## CustomMedia

Configurable media widget with settings panel.

Changes:
- Configurable text width (none/small/medium/unlimited)
- Reverse layout order option
- Hide icon option
- Mouse wheel volume control (when player supports it)
  - Mouse wheel: 5% volume increments
  - Touchpad: smooth 1% increments with accumulator
- Per-widget or global settings via `PluginService.loadPluginData`

## CustomNetworkMonitor

Network speed monitor with fixed-width formatting.

Changes:
- Uses figure spaces (`\u2007`) for consistent width alignment
- Shows `0 KB/s` or `<1 KB/s` for low values
- Color-coded: download (Theme.info/blue), upload (Theme.error/red)
- Padded numbers to 3 digits for stable layout

## CustomRunningApps

Enhanced running apps taskbar.

Changes:
- Scroll wheel switches between windows
- Middle-click closes window
- Right-click context menu with "Close" option
- Grouped windows show badge with count
- Click cycles through grouped windows
- Tooltips disabled by default (commented out)
- **Smart dynamic title width** - Non-linear algorithm shrinks longer titles proportionally more when space is constrained
- **Niri column indicators** - Visual frame around windows in the same Niri column
  - Detects stacked vs tabbed columns (different colors)
  - Frame opacity increases when group has focused window
- **Niri floating indicator** - Line indicator on floating windows
- **Custom background colors** - Separate settings for focused and unfocused pills
  - Color selection from Theme palette (Primary, Secondary, Surface variants, etc.)
  - Individual opacity sliders (0-100%) for each state
- **Custom text colors** - Auto-contrast or manual selection for focused/unfocused states
- **Flat outer edge** - Option to remove rounded corners on the edge facing screen border
- Settings panel with:
  - "Strip App Name from Title" - Removes app name, version numbers, instance markers from window titles
  - "Title Compression" - Configurable ratio for how aggressively longer titles shrink (1=equal, 2=normal, up to 10=extreme)

## CustomSystemTrayBar

System tray with custom icon sizes, spacing, and hover colors. Uses upstream drag-and-drop reordering.

Changes:
- **Custom icon size**: Configurable via `PluginService.loadPluginData("SortedSystemTray", "iconSize", 24)`
- **Custom icon spacing**: Configurable via `PluginService.loadPluginData("SortedSystemTray", "iconSpacing", "M")` (presets: 0, XS, S, M, L, XL)
- **Custom hover color**: `Theme.primaryHover` instead of default `Theme.widgetBaseHoverColor`
- **Drag-and-drop reordering**: Uses upstream's drag-and-drop with spacing-aware slot calculations

## CustomWorkspaceSwitcher

Enhanced workspace indicator with app icons.

Changes:
- Shows individual app icons per workspace (no grouping)
  - Patched: `const key = \`${keyBase}_${i}\`` (unique key per window)
- Active window icons enlarged (36px vs 24px)
- Click on app icon focuses that window
- Workspace index always shown alongside icons
- Steam games show gamepad icon, Quickshell shows themed icon
- **Custom background colors** - Settings for all 4 states (active, unfocused, occupied, urgent)
  - Color selection from Theme palette
  - Individual opacity sliders (0-100%) for each state
- **Custom text/icon colors** - Auto-contrast or manual selection for each state
- **Flat outer edge** - Option to remove rounded corners on the screen-edge side

## dockerManager

Third-party plugin for Docker/Podman container management. See `dockerManager/README.md`.
