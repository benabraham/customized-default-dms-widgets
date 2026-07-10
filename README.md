# Custom DankMaterialShell Plugins

Modified copies of DMS built-in widgets. The code is copied from DankMaterialShell's default widgets with specific customizations applied.

## Upstream Revision

**Last synced:** 2026-07-10
**Base commit:** `c44ffae7` (fix(media): resolve monochrome album art accents) — `upstream/master` tip
**Repository:** https://github.com/AvengeMedia/DankMaterialShell

> Local clone lives at `~/code/_forks/DankMaterialShell` (branch `feature/ddc-controls`, HEAD `0e8e2c65` = `upstream/master` + 1 fork DDC commit, which is the running build).

### Applied in this sync (since `4203148c`)
- **CustomMedia** — `52ed7194` fix: missing `anchors.verticalCenter` on the `mediaInfo` Row.
- **CustomNetworkMonitor** — `093acdbf` spacing-token sweep: hardcoded `2`/`4` → `Theme.spacingXXS`/`Theme.spacingXS`.
- **CustomRunningApps** — close-button simplification: `BlurService.borderWidth`/`.borderColor` used directly (enabled-check moved inside the service); `"transparent"` → `Theme.withAlpha(..., 0)` for smoother hover animation.
- **CustomSystemTrayBar** —
  - Cosmetic sweep: `Theme.outlineHeavy` replacing hardcoded `Qt.rgba(Theme.outline, 0.2)`, `Theme.spacingXXS`, `closeWithAction()` indirection removed, hover `"transparent"` → `Theme.withAlpha(Theme.primaryHover, 0)`.
  - `fefc0afa` menu boundary clamping: overflow/context menus now clamp against `maskX/Y/Width/Height` instead of raw screen bounds, plus `Region` masks so menu content areas are included in the popup hit region.
  - `HyprlandFocusGrab` → `DankFocusGrab` migration (fixes Hyprland focus-stealing bug #2577), wired through the `KeyboardFocus` singleton (`KeyboardFocus.keyboardFocus()`/`.wantsGrab()`/`.barWindows`) — this also closes a pre-existing gap where the file had hand-rolled focus logic bypassing that singleton entirely.
  - `6bee1b2c` HoverMode hook functions added (`hoverTriggerAtGlobalPoint`, `openHoverAtGlobalPoint`) — purely additive.
- **CustomWorkspaceSwitcher** —
  - `effectiveScreenName` simplified to `BarWidgetService.getFocusedScreenName()`, replacing the manual per-compositor switch (incidentally fixes focus-follow for Mango, which the old switch never had a case for).
  - Sway/Hyprland named-workspace correctness: stripped `<num>:<name>` prefix, stable ordering (numbered first, named after by name), safe dispatch for named workspaces (`workspace "name"` / `workspace name:x`), Hyprland special-workspace filtering.
  - Stable placeholder/slot pooling (`_placeholderPool`, `_hyprSlotPool`) so ScriptModel reuses delegate identity across workspace churn instead of recreating pills (reduces animation jitter); `onCompositorChanged` resets both pools.
  - `DankColorAnimation` swap for the pill's background-color transition (premultiplied-alpha tween instead of plain `ColorAnimation`), applied on top of our own PluginService-based color system — `SettingsData.workspace*ColorMode` is unrelated to us and was not touched.

### Skipped (incompatible with customizations, or not applicable)
- Per-monitor "unfocused monitor appearance" color refactor (`effectiveColorMode`/`effectiveCustomColor`/`workspaceUnfocusedMonitor*`) — CustomWorkspaceSwitcher has its own PluginService-based color system; `SettingsData.workspace*ColorMode` isn't used here at all.
- CustomFocusedApp's new `showIcon` setting + horizontal-icon width recalculation — superseded by our existing "icon + title, unlimited width" customization, which predates and already covers this.
- CustomMedia's prev/next hover-color fix — doesn't apply; we already use a different color scheme (`Theme.primaryHover`) there.

### Known pre-existing issues (found during this sync, not fixed — out of scope)
- **CustomWorkspaceSwitcher: dwl/mango dead code.** `CompositorService.isDwl` and the `DwlService` singleton no longer exist upstream (renamed to `isMango`/`MangoService` some time before this sync's base commit). Every `CompositorService.isDwl` branch and `case "dwl"` in this file is therefore dead — Mango users get no workspace switching from this widget except the one path (`effectiveScreenName`) fixed incidentally above. Needs a dedicated dwl→mango rename pass.
- **CustomWorkspaceSwitcher: named sway workspaces + app icons.** `getWorkspaceIcons` still keys off `.num`, so a purely-named sway workspace (`num === -1`) won't show its per-app icons. This is a DMS-only custom feature with no upstream equivalent to port, so it wasn't touched.

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

## Screensaver

OLED burn-in protection daemon using DDC/I2C hardware brightness control.

Changes:
- **Multi-stage dimming**: active → dimming → holding → blacking → black → DPMS
- **DDC hardware brightness**: Uses I2C/DDC (independent of gamma/night light)
- **Smooth fades**: Ease-out cubic transitions at ~2.5 FPS (within DDC limits)
- **Auto-detect DDC device**: Falls back gracefully if no DDC device found
- **Configurable stages**: All timeouts, brightness levels, and fade durations adjustable
- Settings panel with:
  - Enable/disable toggle
  - Dim timeout (1-10 min)
  - Dim brightness level (5-80%)
  - Hold duration at dim (1-10 min)
  - DPMS delay after black (1-30 min)
  - Fade speed (3-20 sec)

## dockerManager

Third-party plugin for Docker/Podman container management. See `dockerManager/README.md`.
