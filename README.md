# Custom DankMaterialShell Plugins

Modified copies of DMS built-in widgets. The code is copied from DankMaterialShell's default widgets with specific customizations applied.

## Upstream Revision

**Last synced:** 2026-09-19
**Base commit:** `b5415caa` (bar: stop hidden pills from catching clicks (#3488)) — `upstream/master` tip
**Repository:** https://github.com/AvengeMedia/DankMaterialShell

> Local clone lives at `~/code/_forks/DankMaterialShell` (branch `feature/ddc-controls`, HEAD `48402bba` = `upstream/master` + fork DDC commits; `upstream/master` verified as an ancestor). **The running build is current:** `dms run` resolves through `~/.local/bin/dms` to a `dms-shell-1.7-beta+date=2026-09-19_dirty` store path built from that HEAD, and `git diff upstream/master HEAD -- quickshell/Modules/DankBar/Widgets/ quickshell/Modules/Plugins/` is empty, so every file we fork is byte-identical to `upstream/master` (verified this sync). `dms-debug-srv.service` runs its own `dms-shell-1.7-beta+date=2026-09-19_b5415ca` store path. The Nix *profile* (`/etc/profiles/per-user/srb/bin/dms`) still ships only the Go CLI — `~/.local/bin` has to stay ahead of the profile on `PATH`.

### Applied in this sync (since `0f565361`)

93 upstream commits. One of them — the `8e9cd3f4` squash — rewrote the whole bar widget
layer, so this sync is much larger than usual: `BasePill` became a one-line alias for the new
`qs.Modules.SurfaceWidgets.BarPill`, per-compositor logic moved into `CompositorService` +
`Common/WorkspaceModel.js`, tray and running-apps menus moved onto `DankPopout` /
`DankContextMenu`, and config version 18 moved 17 global settings into per-widget options.

**First, a breakage fix.** Config v18 migration *deletes* the old globals from `settings.json`,
so four widgets were silently reading `undefined`: CustomWorkspaceSwitcher lost its app icons
(`showWorkspaceApps` falsy, `maxWorkspaceIcons` undefined makes `slice(0, undefined)` return `[]`)
plus drag reorder, the focused border, and a NaN `appIconSize` via
`-6 + workspaceAppIconSizeOffset`; CustomRunningApps lost compact mode; CustomMedia's scroll
handling went dead; CustomFocusedApp lost compact mode. Everything now goes through
`SettingsData.widgetOption(<widgetType>, widgetData, key)`. The user's migrated values are
unrecoverable, and DMS defaults turn the workspace app icons off, so CustomWorkspaceSwitcher
carries an `optionDefaults` map (`showWorkspaceApps`, `showWorkspaceIndex`,
`showWorkspacePadding` all true) consulted by its `opt()` helper.

- **CustomNetworkMonitor** — `Ref`-based `DgopService` refcount (released when the widget or its
  window is hidden, instead of held for the shell's lifetime), `contentThickness`, `contentColor`.
- **CustomFocusedApp** (672 → 529 lines) — `resolveSortedWindow`, `resolveActiveWindowPid`,
  `isWindowAlive`, `getNiriFocusedWindow` and the per-compositor bodies of `updateActiveWindow` /
  `hasWindowsOnCurrentWorkspace` all collapse into `CompositorService.activeWindowForScreen`,
  `windowPid` and `windowOnActiveWorkspace`, which also brings Aqueous support (`b9365610`).
  `minTooltipY` and `isAutoHideBar` now come from `BasePill`.
- **CustomMedia** — `surfaceContext`/`contentScale`, `BarMetrics.mediaControlSize` sizing,
  upstream's `PlayButton` (`DankIconButton`, filled + checkable), `StateLayer` prev/next,
  `surfaceLive` gating on the visualiser and the scrolling title. The inline
  `setTriggerPosition` calls stay: upstream could drop them because `SurfaceWidgetFactory`
  positions the dash popout in its own `onClicked`, which plugin widgets never reach.
- **CustomSystemTrayBar** — taken wholesale from `upstream/master` and re-customised, since
  `65fb97d2` (menus → `DankPopout`, -837/+440) and the squash's `BarPillSurface`/`TrayItemIcon`
  delegates left no common structure. Also picks up `1bf35426` and `2bf2754a`, and upstream
  fixes the fork never had: the `DismissZone` overflow mask, the window-local `mapToItem` popup
  placement fix for non-primary monitors, `WlrLayershell.Overlay`, `StyledText` instead of a raw
  `Text`, and popup drag reordering. Auto-overflow / "Keep in Bar" is kept out by pinning
  `useAutomaticOverflow: false` rather than by surgery — that empties `autoOverflowBarItems` and
  makes `isAutoOverflowTrayItem()` always false, so every branch that would introduce it is dead
  while the file stays diff-friendly.
- **CustomRunningApps** (2074 → 1862 lines) — patched rather than taken wholesale, because
  upstream's 1600 → 545 rewrite drops the dynamic title width, the per-state colour system and
  the full-height pills this fork exists for. Ported: the 230-line hand-rolled `PanelWindow`
  context menu → `DankContextMenu` positioned through `BasePill.contextMenuAnchor()`, with
  `a3a9fe13`'s scratchpad entries; `windowModelKey` per compositor (the fork keyed ungrouped
  windows by `"address"`, which only Hyprland sets, so on niri every row shared an undefined
  key); `skipSwitcher` filtering in scroll switching.
- **CustomWorkspaceSwitcher** (2222 → 1572 lines) — data layer moved onto
  `CompositorService.currentWorkspaceKey` / `workspacesForScreen` / `isCurrentWorkspace` /
  `workspaceOccupied` / `workspaceUrgent` / `windowsOnWorkspace` / `switchToWorkspace` /
  `stepWorkspace` / `workspaceSecondaryAction` / `focusWindow`. Ext-workspace data now comes
  from `Quickshell.WindowManager` screen projections. Brings `workspacePaddingCount`
  (`e5d8d031`), special-workspace hyprland slot keys (`72326ec5`), special workspaces with the
  `inbox` icon (`a3a9fe13`) and Aqueous (`b9365610`).

**Not applicable:** `f6c53993` (`selectedContainer` instead of `primaryContainer` in
RunningApps) — our focused/unfocused colours come from the PluginService colour modes.
`014c69b0` (workspace tile colour restyle) — same reason.

### Drive-by fixes in this sync

- `PluginService.pluginDataChanged` only ever carried the plugin id, but all four plugins
  declared `onPluginDataChanged(pluginId, key)` and branched on `key`. No plugin setting has
  ever applied without a `dms restart`. All four handlers now match on the id and reload every
  value.
- `Theme.onSecondary` has not existed for some time; the five no-icon first-letter fallbacks
  across CustomFocusedApp, CustomRunningApps and CustomWorkspaceSwitcher now use
  `Theme.widgetTextColor`, like upstream.
- CustomMedia's `SettingsData.audioScrollEnabled` fallback was already dead at the previous
  base, so `scrollMode` resolved to `"nothing"` regardless.
- CustomWorkspaceSwitcher's `padding` mirrored `BarPill`'s old formula (default 12, plus
  `removeWidgetPadding`). `BarPill` now defaults to 8 and has dropped `removeWidgetPadding`.

### Applied in the 2026-09-07 sync (since `c1f1da1d`)
Exactly one of the 37 upstream commits touched our six widgets. No changes to `CustomFocusedApp`,
`CustomMedia`, `CustomNetworkMonitor`, `CustomRunningApps`, `CustomSystemTrayBar`,
`Modules/Plugins/BasePill.qml` or `AudioVisualization.qml`.

- **CustomWorkspaceSwitcher** — `3d6e45f4` "bar: focus workspace icons on any workspace and wire island overview loader", *adapted*. Both per-icon `MouseArea`s (`rowAppMouseArea`, `colAppMouseArea`) were gated on `enabled: isActive`, so an app icon on a non-active workspace could not be clicked to focus its window; worse, on the active workspace they swallowed the press that the outer `mouseArea` needs. Upstream deletes both and hit-tests from the workspace delegate instead: new `windowIdAt(x, y)` maps the press into the icon layout and reads `childAt(...)?.windowId`, and `focusWindowAt(x, y)` focuses that window and returns `true`, which the delegate's left-button `onReleased` checks before falling through to the workspace switch. Each icon delegate now exposes `readonly property var windowId: modelData.windowId`.

  **Adaptation:** upstream aliases `iconsLayout: contentRow.item`, which works because its icons are direct children of the row/column. Ours are not — the custom column layout nests them one level deeper inside `colIconsLayout` (the `ColumnLayout` that does the negative-margin overlap for the active icon), so `childAt` on the `Column` would return the wrapper `Item` and never find a `windowId`. Instead each layout component names its own container: the `Row` gets `id: rowIconsRow` + `iconsContainer: rowIconsRow`, the `Column` gets `iconsContainer: colIconsLayout`, and `contentRoot` reads `iconsLayout: contentRow.item?.iconsContainer ?? null`.

  Our Hyprland branch keeps `Hyprland.dispatch(\`focuswindow address:${winId}\`)` rather than upstream's `HyprlandService.focusWindow`. Upstream also swapped its icon `MouseArea`s for `HoverHandler`s to preserve hover opacity; we need no replacement, because our icon opacity comes from the PluginService per-state colour system and never read `containsMouse`. Dropping the icons' `cursorShape: Qt.PointingHandCursor` is a no-op — the outer `mouseArea` already sets it for every non-placeholder workspace. Drag-reorder is unaffected: `wasDragging` still returns early before the left-button branch. The `// Custom:` no-grouping, `wsAppIconActive`/`wsAppIconNormal` sizing, per-state colours and spacing preset are untouched. `qmllint` error count is unchanged at 0, with two fewer each of `import`, `unqualified` and `unresolved-type` warnings from the removed code.

- **Not applicable** — `fbffa410` "clock: align the horizontal time block to whole pixels" touches `Clock.qml`, which we do not fork. The other 35 commits went to the launcher, Dank Island, dock, greeter, services, the Go core and translations.

### Applied in the 2026-09-04 sync (since `ed9e01e4`)
Two of the 42 upstream commits touched our six widgets; both were ported. No changes to
`CustomMedia`, `CustomNetworkMonitor`, `CustomSystemTrayBar`, `CustomWorkspaceSwitcher` or
`AudioVisualization.qml`.

- **CustomFocusedApp** — `9a7177f9` "fix(bar): prevent focused app widget from blanking and live-sync (#3258)". The widget used to blank on niri whenever `ToplevelManager.activeToplevel` went null (workspace switch, popout grabbing focus). Adds `isWindowAlive()` and `getNiriFocusedWindow()` helpers; when there is no active toplevel on niri it now falls back to `NiriService.windows.find(w => w.is_focused)` — or `NiriService.lastFocusedWindowId` while the details popout is open — and maps that back to a toplevel through `CompositorService.sortedToplevels[].sourceToplevel`, with an `appId`/`title` match as backup. The `if (!CompositorService.isNiri)` guard on `onActiveToplevelChanged` is gone (niri needs the signal too), `onAllWorkspacesChanged` was added, and the null-active branch now clears only when the window is dead *or* the screen's active workspace is genuinely empty. The popout trigger-position code was extracted into `syncPopoutState()` so `onActiveWindowChanged` can live-update an open popout (double-called via `Qt.callLater` to catch post-layout geometry) or `close()` it when the window goes away; a new `Connections` on `focusedWindowPopoutLoader.item` re-runs `updateActiveWindow()` on `shouldBeVisibleChanged`/`popoutClosed`. `hasWindowsOnCurrentWorkspace` uses the same helper and, with no focused window, now reports whether the screen's active workspace holds any window at all. Icon + title layout, `maxNormalWidth: 99999`, `stripAppName`/`appIconSize`/`iconTitleSpacing` are untouched.
- **CustomRunningApps** — `5142d576` "fix(bar): centre widget content on whole pixels (#3263)". Both copies of the ad-hoc `Math.max(26 + innerPadding * 0.6, Theme.barHeight - 4 - (8 - innerPadding))` bar-thickness math replaced by upstream's new `Theme.barThickness(innerPadding, dpr)`, which rounds to whole device pixels; the DPR comes from `CompositorService.getScreenScale(parentScreen)` for the widget's own `effectiveBarThickness` and from `CompositorService.getScreenScale(contextMenuWindow.screen)` inside the window context menu. Fixes half-pixel blur on fractional-scale outputs. Spacing presets, the PluginService colour system, `appIconSize` and the title-width debounce cache are untouched.

### Applied in the 2026-09-02 sync (since `88750954`)
Nothing to port. Twenty-nine upstream commits landed, but **none touched any of the six widgets we
fork** (`FocusedApp`, `Media`, `NetworkMonitor`, `RunningApps`, `SystemTrayBar`, `WorkspaceSwitcher`)
or `Modules/Plugins/BasePill.qml`. Upstream work went to the Dock, Dank Island, Greeter, Changelog,
services (`IconThemeService`, `PolkitService`, `BluetoothService`, `ClipboardService`), the Go core
and translations. `Modules/Plugins/DesktopPluginWrapper.qml` changed, but it wraps *desktop*-placed
plugins — ours are bar widgets plus one daemon — so it does not apply.

### Applied in the 2026-08-31 sync (since `f89b21a0`)
Five upstream commits touched our widgets. `CustomNetworkMonitor` had no upstream changes.

- **CustomFocusedApp / CustomRunningApps / CustomSystemTrayBar** — `ea0b158e` "bar/island: fix click targets on satellites". `MouseArea { anchors.fill: parent }` replaced by an explicit rect grown by `BasePill`'s `leftMargin`/`rightMargin`/`topMargin`/`bottomMargin`, so clicks landing in the inter-widget gap or at the bar edge still hit the pill. Single-pill `CustomFocusedApp` extends on all four sides (upstream form); the multi-delegate `CustomRunningApps` (2 `MouseArea`s) and `CustomSystemTrayBar` (3 `MouseArea`s) extend on the **cross axis only** — `x`/`width` when vertical, `y`/`height` when horizontal — because side-by-side delegates would otherwise steal each other's clicks.
- **CustomSystemTrayBar** — `3b527f1f` "SystemTrayBar: add configurable icon spacing (#3183)". The spacing feature itself was **already implemented here** and is ahead of upstream: our `iconSpacing` preset comes from `PluginService` under the `"SortedSystemTray"` key, and both drag-shift call sites already use `trayItemSize + iconSpacing`. Only the incidental fix was taken: the inline tray toggle spacer's `visible: width > 0 || height > 0` → `&&` (with `||` a collapsed 0×N spacer stayed visible).
- **CustomSystemTrayBar** — `5b8f083f` "fix(tray): prefer tooltip title in menu (#3181)". Context-menu header now reads `trayItem?.tooltipTitle || trayItem?.id || I18n.tr("Unknown")` instead of the raw D-Bus id. Upstream's `isAutoOverflowTrayItem` / "Keep in Bar" branch is still absent here and was **not** introduced.
- **CustomRunningApps** — `4447d77b` "feat(Dank Island): add new island bar instance". Only the API change taken: `SettingsData.barConfigs[0]?.position` → `SettingsData.getPrimaryBarConfig()?.position` for the window-context-menu `triggerBarPosition`. Indexing `[0]` is wrong once more than one bar instance exists.
- **CustomWorkspaceSwitcher** — `ea0b158e`. Added `property real crossEdgeExtension: 0` (bound automatically by `WidgetHost` once the property exists) and used it in `_topMargin`/`_bottomMargin` for horizontal bars. Inert on a normal bar; correct if the Island bar is ever enabled.
- **CustomWorkspaceSwitcher** — `195ec3bf` "feat(motion): spring-based physics & shell hybrid material animations". The drag-reorder shift's `Behavior on x`/`Behavior on y` (`NumberAnimation`, 150 ms, `OutCubic`) replaced by two `SpringMotion` instances driven from `Theme.springPreset("fast", 150)`, retargeted in `onShiftOffsetChanged`. Also `Theme.isLightColor(bgColor, 0.4)` in place of the inline `0.299r + 0.587g + 0.114b > 0.4` in `getContrastingIconColor`/`getContrastingTextColor` — mathematically identical (`Theme.luminance` uses the same coefficients), and our extra `bgOpacity < 0.1 → Theme.widgetTextColor` guard is kept.
- **CustomMedia** — `44e82c6e` "island: break out more stuff into commonality helpers…". The ~118-line inline scrolling `StyledText` (hold/step/cava-tick/text-change animation) replaced by upstream's `ScrollingText` from `qs.Widgets`, which carries byte-identical logic. `textContainer.width` now reads `mediaText.implicitTextWidth` instead of `mediaText.implicitWidth`, because the component is an `Item` wrapper whose own `implicitWidth` is 0 (this is the same `contentWidth` → `implicitTextWidth` correction upstream made in `c580aa26`). Behaviour difference: with `scrollTitleEnabled` off, overflowing text now elides with `…` instead of hard-clipping. `mediaSize`/`reverseOrder`/`hideIcon` and the unlimited-width path (`textWidth === -1`) are untouched.
- **CustomMedia / AudioVisualization** — `44e82c6e`, *adapted*. Our copy is still the pre-shader `Rectangle`+`Repeater` fork, so only two things carry over: `live` gains `&& enabled`, and the fake `Math.random()` cava fallback `Timer` is gone (upstream deleted it; `CustomMedia` already shows a `music_note` icon whenever cava is unavailable). Drive-by: the `Behavior on height` guarded on `!CavaService.cavaAvailable` went with it — nothing mutates `CavaService.values` while cava is down, so it could no longer fire. Upstream's `idleIconName`/`barColor`/`showBars` properties are not needed, since `CustomMedia` owns its own idle icon.
- **CustomFocusedApp** — `b7034fca` "fix(bar): prevent focused app overlap (#3190)" and `2c471e1c` "clip title overflow horizontally only" **not ported.** Both clamp the pill to `availableWidth`, but `DankBarContent.qml` wires `availableWidth` only for its own built-in `FocusedApp` instance — `WidgetHost`/`PluginComponent` never pass it to plugin widgets. Our property would sit at its stale default of `400`, capping the deliberately unlimited (`maxNormalWidth: 99999`) pill.
- **CustomMedia** — `c580aa26` "fix media text collapse" **not applicable.** The fix targets upstream's `measuredTextWidth`/`adaptiveWidthEnabled` path, which our fork does not have (we size from `textWidth` directly).

### Applied in the 2026-08-22 sync (since `327aad21`)
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

### Known pre-existing issues

- **CustomWorkspaceSwitcher: dwl/mango dead code** — *fixed in the 2026-09-19 sync.* The
  `CompositorService.isDwl` / `DwlService` branches are gone; mango now goes through
  `CompositorService`'s workspace API like every other compositor.
- **CustomWorkspaceSwitcher: named sway workspaces + app icons** — *fixed in the 2026-09-19
  sync.* `getWorkspaceIcons` no longer keys off `.num`; it asks
  `CompositorService.windowsOnWorkspace(record)`.

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
- Right-click context menu (`DankContextMenu`) with Minimize/Restore, scratchpad moves and Close
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
- **Custom hover color**: `Theme.primaryHover` on the four bar-visible hover surfaces (both
  carets, the main delegate, the inline expanded delegate) instead of upstream's `Theme.onSurface`
  state-layer alpha. Menu chrome keeps upstream's styling.
- **Item size is the icon**: `trayItemSize` is `configuredIconSize` with no padding; upstream pads
  it by `spacingXS + spacingXXS`, which would double up with the spacing preset.
- **Drag-and-drop reordering**: Uses upstream's drag-and-drop with spacing-aware slot calculations
- **No auto-overflow**: `useAutomaticOverflow` is pinned `false`, which empties
  `autoOverflowBarItems` and makes `isAutoOverflowTrayItem()` always false — every upstream
  branch that would add auto-overflow or "Keep in Bar" is dead, with no surgery on the file.

## CustomWorkspaceSwitcher

Enhanced workspace indicator with app icons.

Changes:
- Shows individual app icons per workspace (no grouping)
  - Patched: `const key = w.aqueousKey || \`${moddedId}_${i}\`` (unique key per window), and
    `stableIconCount` returns `CompositorService.windowsOnWorkspace(record).length` rather than
    upstream's per-app grouped count
- Active window icons enlarged (36px vs 24px)
- Click on app icon focuses that window, via `windowIdAt`/`focusWindowAt` hit-testing and
  `CompositorService.focusWindow`
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
