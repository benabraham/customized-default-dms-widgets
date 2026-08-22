# Custom DankMaterialShell Plugins

Modified copies of DMS built-in widgets. The code is copied from DankMaterialShell's default widgets with specific customizations applied.

## Upstream Revision

**Last synced:** 2026-08-22
**Base commit:** `f89b21a0` (inputs: consistent usage of Dank* variants, bump qml-common with blink timeout) — `upstream/master` tip
**Repository:** https://github.com/AvengeMedia/DankMaterialShell

> Local clone lives at `~/code/_forks/DankMaterialShell` (branch `feature/ddc-controls`, HEAD `3ed3de71` = `upstream/master` + fork DDC commits). **The running build is older:** `dms run` resolves through `~/.local/bin/dms` to the Nix store path `dms-shell-1.6-beta+date=2026-08-19_c1894a3` (= `327aad21` + DDC), which predates `FocusedWindowContextMenu.qml` — see the CustomFocusedApp note below.

### Applied in this sync (since `327aad21`)
Two upstream commits touched our six widgets; both were ported.

- **CustomFocusedApp** — `a669253c` "feat(bar): add focused window details popout (#3139)". Left-click on the pill now opens upstream's `FocusedWindowContextMenu` popout (window details + PID) via a new `focusedWindowPopoutLoader`; `cursorShape: Qt.PointingHandCursor`; added `resolveSortedWindow()`/`resolveActiveWindowPid()` (niri PID comes from `NiriService.windows[].pid`, added to the service in the same upstream commit). Plugin imports `qs.Modules.DankBar.Widgets` to reach the popout type. Icon + title layout, unlimited width and the strip-app-name setting are untouched. **Requires a DMS build containing `a669253c`** (`quickshell/Modules/DankBar/Widgets/FocusedWindowContextMenu.qml` + `NiriService` `pid`): on the current `c1894a3` store path the plugin fails to load until `dms` is rebuilt from the fork branch.
- **CustomWorkspaceSwitcher** — `90c5f65b` "fix(workspaces/hyprland): recover workspace mapping on monitor hotplug". The hardcoded `{id: 1, name: "1"}` fallback for the per-monitor Hyprland filter replaced by `hyprlandMonitorWorkspaces()`, which falls back to `Hyprland.monitors[].activeWorkspace` (#3133). Hyprland-only path — inert on niri, ported for diff-parity. Individual-icon (`// Custom:`) code, `PluginService` colours and spacing presets untouched.
- No changes to CustomMedia, CustomNetworkMonitor, CustomRunningApps, CustomSystemTrayBar, or `AudioVisualization.qml`.

### Applied in the 2026-08-19 sync (since `ef191bab`)
Three upstream commits touched our six widgets; all three were ported.

- **CustomSystemTrayBar** — `34626070` "fix(tray): don't dismiss click-opened tray menus from hover controller (#2979)". Real bug fix here, not just diff-parity: the running build's `TrayMenuManager.closeHoverMenus()` skips any menu whose `openedByHover !== true`, and our fork had no such property, so `DankBarHoverController` could never dismiss a hover-opened tray menu. Added `openedByHover` to the tray-menu component and threaded a `byHover` argument through both `showForTrayItem()` overloads; `openHoverAtGlobalPoint()` passes `true`, every click path leaves it `undefined`.
- **CustomSystemTrayBar** — `2baf0482` "feat(tray): add IPC action to open tray menus (#2701)". Added the `Connections { target: TrayMenuManager }` block with `onOpenTrayMenuRequested`. `claimMenuRequest()`/`findTrayItem()` both exist in the running build. Independent of our drag-and-drop reordering and of `SessionData.trayItemOrder`; upstream's auto-overflow / "Keep in Bar" is still absent here, as intended.
- **CustomRunningApps** — `b0b9b615` "dock/apps: support minimize". Ported in full across both delegate branches:
  - `isMinimized` readonly property + `opacity: 0.4` on the icon, Steam fallback icon and letter fallback.
  - `.activate()` → `CompositorService.activateToplevel()` (scroll switching, group cycling) and `CompositorService.toggleToplevel()` (single-window click).
  - Window context menu rewritten from a fixed 100×32 close-only rect into a 120-wide `Column` with a conditional Minimize/Restore row plus Close.
  - Context-menu `yPos` for bottom bars stopped using the hardcoded `32` and now reads `windowContextMenuLoader.item.menuHeight`. **This is the part that actually changes behaviour on this machine** — minimize itself is inert on niri, since `DankCommon/Common/Compositor.qml` returns `supportsMinimize: false` whenever `NIRI_SOCKET` is set, which makes `canMinimize()` false and hides the Minimize row.
  - Our customizations were untouched: `appIconSize`, the `PluginService` colour modes via `root.getTextColor(isFocused)`, the debug overlays, the root-level title debounce cache.
- No changes to CustomFocusedApp, CustomMedia, CustomNetworkMonitor, CustomWorkspaceSwitcher, or `AudioVisualization.qml`.

### Applied in the 2026-08-01 sync (since `8bb73963`)
Only one upstream commit touched our six widgets: `c67b1850` "qs: large sweep of dead code removals".

- **CustomWorkspaceSwitcher** — `c67b1850`: local `escapeSwayWorkspaceName()`/`dispatchSwayWorkspace()` (15 lines) deleted in favour of `CompositorService.dispatchSwayWorkspace()`; 3 call sites redirected. Body is byte-identical to the service's, which is present in the running build (`CompositorService.qml:1094`). Sway/scroll/miracle paths only — inert on niri, taken for diff-parity. `I3` import still needed elsewhere in the file.
- **CustomNetworkMonitor** — `c67b1850` **not applicable.** Upstream swapped `formatNetworkSpeed()` for `Format.formatRate()`, but (a) our formatter *is* the customization (figure spaces `\u2007`, `"0 KB/s"`/`"<1 KB/s"`, 3-char right-aligned rounding), and (b) the new `import "../../../Common/Format.js"` is relative to `quickshell/Modules/DankBar/Widgets/` and cannot resolve from the plugins directory.
- **Plugins setting components** — `c67b1850` also refactored `quickshell/Modules/Plugins/*Setting.qml` (`findSettings()` → `QmlUtils.findSettings()`). **No public API change**, and all 11 local slider forks (`SteppedSliderSetting`/`RealSliderSetting`/`LabeledSliderSetting`) carry their own `findSettings()` — unaffected. Same relative-import blocker applies, so not ported.
- No changes to CustomFocusedApp, CustomMedia, CustomRunningApps, CustomSystemTrayBar.

### Applied in the 2026-07-25 sync (since `c44ffae7`)
- **CustomMedia** —
  - `fe1a783e`/`dc924618` stable-metadata centralisation: the local `_stableTitle`/`_stableArtist`/`_syncMeta()` block (26 lines) deleted in favour of `MprisController.stableTitle`/`.stableArtist`; all four `activePlayer.next()` call sites routed through `MprisController.next()`. Our `canGoNext`/`canGoPrevious` scroll guards are unaffected.
  - `2986e354`/`cdaedad9`/`c3fa7b2e` title-scroll rewrite (#2863): the infinite `SequentialAnimation` replaced by `Timer`-driven `stepScroll()` that rides `CavaService.valuesChanged` ticks when the visualizer is live. A running `NumberAnimation` commits a frame every vsync, so two unsynchronized tick sources nearly doubled the surface commit rate. Also gated on window visibility + `_isPlaying`, and `x` rounded to whole pixels.
  - **AudioVisualization** — *adapted, not ported.* Our copy predates upstream's shader rewrite (`bandsA`/`bandsB` vectors), so only the two ideas carry over: a `live` gate (`visible && Window.window?.visible && isPlaying`) on the `Ref` loader, fallback timer and `CavaService` connection; and levels quantized to 1/32 with identical frames dropped before assigning `barHeights`.
- **CustomSystemTrayBar** —
  - `fb2dbced` menu overflow: `rawHeight` capped at `maskHeight - 20` and `menuColumn` wrapped in a `DankFlickable` (`interactive: contentHeight > height`), so long tray menus scroll instead of running off-screen. Our `Theme.primaryHover` hover colours and `SessionData.isHiddenTrayId` visibility logic preserved; upstream's auto-overflow / "Keep in Bar" branch is absent from our copy and was **not** introduced.
  - `1402d231` vbar menu positioning: vertical-orientation branches clamp against window `width`/`height` instead of `maskX`/`maskY` bounds (4 blocks — overflow menu x/y, tray menu x/y).
  - Icon-size token sweep: hardcoded `16`/`14`/`10` → `Theme.iconSizeSmall` and derivations; checkbox `radius: … ? 8 : 2` → `width / 2`.
- **CustomWorkspaceSwitcher** —
  - `4fb69957` Hyprland re-focus fix (#2830): `Connections` on `Hyprland` `rawEvent` calling `updateAllData()` for `activewindow`/`activewindowv2`. **Inert on niri** (`enabled: CompositorService.isHyprland`) — taken for diff-parity with upstream.
  - `296b3a3d` (mango dispatch socket) **not applicable** — our copy has no `mmsg`/overview-toggle button.

### Applied in the 2026-07-10 sync (since `4203148c`)
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
- Left-click opens upstream's `FocusedWindowContextMenu` popout (window details + PID), as in upstream since `a669253c`
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
- Hover tooltips active via `tooltipLoader` (an earlier revision had them commented out)
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
- **Custom icon size**: Configurable via `PluginService.loadPluginData("SortedSystemTray", "iconSize", 18)`
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
