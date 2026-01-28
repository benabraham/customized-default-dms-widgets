import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var widgetData: null
    property var barConfig: null
    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "left"
    property var parentScreen
    property var hoveredItem: null
    property var topBar: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property bool isAutoHideBar: false
    property bool stripAppName: PluginService.loadPluginData("CustomRunningApps", "stripAppName", true)
    // Compression bias: UI value -50 to 50, converted to exponent 0.01 to 100
    // Formula: exponent = 100^(bias/50)
    // -50 → 0.01 (favor large), 0 → 1 (equal), 50 → 100 (favor small)
    property real compressionBias: parseFloat(PluginService.loadPluginData("CustomRunningApps", "compressionBias", "0"))
    property real compressionRatio: Math.pow(100, Math.max(-50, Math.min(50, compressionBias)) / 50)
    onCompressionBiasChanged: widthManager.recalculate()
    property int titleDebounce: parseInt(PluginService.loadPluginData("CustomRunningApps", "titleDebounce", "300"))
    property bool debugMode: PluginService.loadPluginData("CustomRunningApps", "debugMode", false)
    property bool showStackingTabbing: PluginService.loadPluginData("CustomRunningApps", "showStackingTabbing", true)
    property bool flatOuterEdge: PluginService.loadPluginData("CustomRunningApps", "flatOuterEdge", false)
    property string focusedColorMode: PluginService.loadPluginData("CustomRunningApps", "focusedColorMode", "surfaceContainerHighest")
    property string unfocusedColorMode: PluginService.loadPluginData("CustomRunningApps", "unfocusedColorMode", "surfaceContainerHighest")
    property real focusedOpacity: parseFloat(PluginService.loadPluginData("CustomRunningApps", "focusedOpacity", "100"))
    property real unfocusedOpacity: parseFloat(PluginService.loadPluginData("CustomRunningApps", "unfocusedOpacity", "0"))

    function themeColorFromMode(mode) {
        switch (mode) {
        case "primary": return Theme.primary
        case "secondary": return Theme.secondary
        case "surface": return Theme.surface
        case "surfaceContainer": return Theme.surfaceContainer
        case "surfaceContainerHigh": return Theme.surfaceContainerHigh
        case "surfaceContainerHighest": return Theme.surfaceContainerHighest
        case "surfaceText": return Theme.surfaceText
        case "surfaceTextAlpha": return Theme.surfaceTextAlpha
        case "onSurface": return Theme.onSurface
        case "widgetText": return Theme.widgetTextColor
        case "auto": return null
        default: return Theme.primary
        }
    }

    readonly property color unfocusedColor: themeColorFromMode(unfocusedColorMode)
    readonly property color focusedColor: themeColorFromMode(focusedColorMode)

    property string focusedTextColorMode: PluginService.loadPluginData("CustomRunningApps", "focusedTextColorMode", "auto")
    property string unfocusedTextColorMode: PluginService.loadPluginData("CustomRunningApps", "unfocusedTextColorMode", "auto")

    function contrastTextColor(bgColor, bgOpacity) {
        if (bgOpacity < 0.1)
            return Theme.widgetTextColor
        const luminance = 0.299 * bgColor.r + 0.587 * bgColor.g + 0.114 * bgColor.b
        return luminance > 0.5 ? Theme.onSurface : Theme.widgetTextColor
    }

    // Corner radii based on bar edge (flat on outer edge when enabled)
    readonly property real cornerRadius: Theme.cornerRadius
    readonly property real topLeftRadius: flatOuterEdge && (axis?.edge === "top" || axis?.edge === "left") ? 0 : cornerRadius
    readonly property real topRightRadius: flatOuterEdge && (axis?.edge === "top" || axis?.edge === "right") ? 0 : cornerRadius
    readonly property real bottomLeftRadius: flatOuterEdge && (axis?.edge === "bottom" || axis?.edge === "left") ? 0 : cornerRadius
    readonly property real bottomRightRadius: flatOuterEdge && (axis?.edge === "bottom" || axis?.edge === "right") ? 0 : cornerRadius

    function getTextColor(isFocused) {
        const mode = isFocused ? root.focusedTextColorMode : root.unfocusedTextColorMode
        if (mode === "auto") {
            const bgColor = isFocused ? root.focusedColor : root.unfocusedColor
            const bgOpacity = isFocused ? root.focusedOpacity : root.unfocusedOpacity
            return contrastTextColor(bgColor, bgOpacity / 100)
        }
        return themeColorFromMode(mode)
    }

    // Configurable sizes and spacing
    property real appIconSize: PluginService.loadPluginData("CustomRunningApps", "appIconSize", 24)
    property string pillSpacingPreset: PluginService.loadPluginData("CustomRunningApps", "pillSpacing", "S")
    property string widgetPaddingPreset: PluginService.loadPluginData("CustomRunningApps", "widgetPadding", "M")
    property string iconTitleSpacingPreset: PluginService.loadPluginData("CustomRunningApps", "iconTitleSpacing", "S")

    function spacerValue(preset) {
        switch (preset) {
            case "0": return 0
            case "XS": return Theme.spacingXS
            case "S": return Theme.spacingS
            case "M": return Theme.spacingM
            case "L": return Theme.spacingL
            case "XL": return Theme.spacingXL
            default: return Theme.spacingS
        }
    }

    readonly property real pillSpacing: spacerValue(pillSpacingPreset)
    readonly property real iconTitleSpacing: spacerValue(iconTitleSpacingPreset)
    readonly property real pillPadding: spacerValue(widgetPaddingPreset)
    readonly property real horizontalPadding: (barConfig?.noBackground ?? false) ? 2 : Theme.spacingM
    property Item windowRoot: (Window.window ? Window.window.contentItem : null)

    // Smart pill width: available bar width for horizontal layout
    readonly property real availableBarWidth: isVertical ? 0 : (barBounds.width > 0 ? barBounds.width : (parentScreen?.width ?? 1920))

    // Fixed overhead per pill: left padding + icon + right padding + text spacing
    readonly property real pillOverhead: pillPadding + appIconSize + pillPadding + iconTitleSpacing

    // Update trigger for width recalculation
    property int _widthUpdateTrigger: 0

    // Debug info for smart pill width
    property string debugInfo: ""

    // Debug: check these values if width issues occur
    property string debugWidthInfo: {
        _widthUpdateTrigger;  // force re-evaluate when constraints change
        const n = visibleStableIds.length;
        // Calculate full natural width (unconstrained) from width manager
        const origWidths = widthManager.originalWidths;
        const conWidths = widthManager.constrainedWidths;
        let totalTextWidth = 0;
        let totalEffective = 0;
        for (const k of Object.keys(origWidths)) {
            if (visibleStableIds.includes(k)) {
                const nat = origWidths[k];
                totalTextWidth += nat;
                const c = conWidths[k];
                // Match effectiveTextWidth logic: min(natural, constrained) when constrained >= 0
                const eff = (c !== undefined && c >= 0) ? Math.min(nat, c) : nat;
                totalEffective += eff;
            }
        }
        const fullNat = n * pillOverhead + (n - 1) * pillSpacing + horizontalPadding * 2 + totalTextWidth;
        const expectedCalc = n * pillOverhead + (n - 1) * pillSpacing + horizontalPadding * 2 + totalEffective;
        const status = root.forceCompactMode ? "ICON-ONLY " : (root.debugInfo.startsWith("SHRINK") ? "SHRINK " : "");
        const info = status + "n:" + n + " avail:" + Math.round(availableBarWidth) + " fullNat:" + Math.round(fullNat) + " expectedCalc:" + Math.round(expectedCalc) + " actualCalc:" + Math.round(calculatedSize) + " exp:" + compressionRatio;
        if (root.debugMode)
            console.warn("WIDTH DEBUG: " + info);
        return info;
    }

    // Hidden reference text to measure minimum pill width
    TextMetrics {
        id: minPillMetrics
        text: "Bash"
        font.pixelSize: Theme.barTextSize(root.barThickness, barConfig?.fontScale)
        font.family: Theme.fontFamily
    }
    readonly property real minPillWidth: pillPadding + appIconSize + pillPadding + minPillMetrics.width + iconTitleSpacing

    // Auto-compact mode: force icon-only when items can't fit with minimum text
    readonly property bool forceCompactMode: {
        if (isVertical)
            return false;
        const itemCount = visibleStableIds.length;
        if (itemCount === 0)
            return false;
        // Check if minimum possible size (using reference "Bash" pill) would fit
        // spacing between pills = (itemCount - 1) gaps
        const totalMinWidth = itemCount * minPillWidth + (itemCount - 1) * pillSpacing + horizontalPadding * 2;
        return totalMinWidth > availableBarWidth;
    }

    readonly property real effectiveBarThickness: {
        if (barThickness > 0 && barSpacing > 0) {
            return barThickness + barSpacing;
        }
        const innerPadding = barConfig?.innerPadding ?? 4;
        const spacing = barConfig?.spacing ?? 4;
        return Math.max(26 + innerPadding * 0.6, Theme.barHeight - 4 - (8 - innerPadding)) + spacing;
    }

    readonly property var barBounds: {
        if (!parentScreen || !barConfig) {
            return {
                "x": 0,
                "y": 0,
                "width": 0,
                "height": 0,
                "wingSize": 0
            };
        }
        const barPosition = axis.edge === "left" ? 2 : (axis.edge === "right" ? 3 : (axis.edge === "top" ? 0 : 1));
        return SettingsData.getBarBounds(parentScreen, effectiveBarThickness, barPosition, barConfig);
    }

    readonly property real barY: barBounds.y

    readonly property real minTooltipY: {
        if (!parentScreen || !isVertical) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            return effectiveBarThickness;
        }

        return 0;
    }

    property int _desktopEntriesUpdateTrigger: 0
    property int _appIdSubstitutionsTrigger: 0
    property int _toplevelsUpdateTrigger: 0

    // Title debounce cache (lives at root so it survives delegate recreation)
    // Maps stableId -> { debounced: "visible title", pending: "latest raw title" }
    property var _titleCache: ({})
    property int _titleCacheTrigger: 0

    function requestTitleUpdate(stableId, rawTitle) {
        const entry = _titleCache[stableId]
        if (!entry) {
            _titleCache[stableId] = { debounced: rawTitle, pending: rawTitle }
            _titleCacheTrigger++
            return
        }
        if (entry.pending === rawTitle)
            return
        entry.pending = rawTitle
        _titleDebounceTimer.restart()
    }

    function getCachedTitle(stableId) {
        return _titleCache[stableId]?.debounced || ""
    }

    Timer {
        id: _titleDebounceTimer
        interval: root.titleDebounce
        onTriggered: {
            let changed = false
            for (const id in root._titleCache) {
                const entry = root._titleCache[id]
                if (entry.debounced !== entry.pending) {
                    entry.debounced = entry.pending
                    changed = true
                }
            }
            if (changed)
                root._titleCacheTrigger++
        }
    }

    // Niri column/floating indicators
    readonly property bool isNiri: CompositorService.isNiri

    // Map niri window ID → full niri window object (with layout, is_floating)
    readonly property var niriWindowsMap: {
        if (!isNiri) return {}
        const windows = NiriService.windows || []
        const map = {}
        for (const w of windows) {
            map[w.id] = w
        }
        return map
    }

    // Column grouping data: { "wsId-colIndex": { windows: [...], isTabbed: bool } }
    readonly property var columnGroups: {
        if (!isNiri) return {}
        const windows = NiriService.windows || []
        const groups = {}

        // First pass: group windows by workspace + column, find reference heights
        const refHeights = {}  // wsId -> reference full height from single-window columns
        for (const w of windows) {
            if (!w.layout?.pos_in_scrolling_layout) continue
            const col = w.layout.pos_in_scrolling_layout[0]
            const wsId = w.workspace_id
            const key = `${wsId}-${col}`
            const height = w.layout.tile_size?.[1] || 0

            if (!groups[key]) {
                groups[key] = { windows: [], sumHeight: 0, maxHeight: 0, wsId, col }
            }
            groups[key].windows.push(w)
            groups[key].sumHeight += height
            groups[key].maxHeight = Math.max(groups[key].maxHeight, height)
        }

        // Find reference height per workspace from single-window columns
        for (const key in groups) {
            const g = groups[key]
            if (g.windows.length === 1) {
                const wsId = g.wsId
                const height = g.maxHeight
                if (!refHeights[wsId] || height > refHeights[wsId]) {
                    refHeights[wsId] = height
                }
            }
        }

        // Second pass: determine if each column is tabbed
        // TABBED: each window has ~full height (windows overlap)
        // STACKED: each window has fraction of full height (windows share space)
        for (const key in groups) {
            const g = groups[key]
            if (g.windows.length <= 1) {
                g.isTabbed = false
                continue
            }
            const refHeight = refHeights[g.wsId] || g.maxHeight
            const avgHeight = g.sumHeight / g.windows.length
            // If average window height is close to reference full height, they're tabbed (overlapping)
            g.isTabbed = avgHeight > refHeight * 0.8
        }

        return groups
    }

    function getNiriWindow(toplevel) {
        if (!isNiri || !toplevel?.niriWindowId) return null
        return niriWindowsMap[toplevel.niriWindowId] || null
    }

    readonly property var sortedToplevels: {
        _toplevelsUpdateTrigger;
        const toplevels = CompositorService.sortedToplevels;
        if (!toplevels || toplevels.length === 0)
            return [];

        if (SettingsData.runningAppsCurrentWorkspace) {
            return CompositorService.filterCurrentWorkspace(toplevels, parentScreen?.name) || [];
        }
        return toplevels;
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            _toplevelsUpdateTrigger++;
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++;
        }
    }

    Connections {
        target: SettingsData
        function onAppIdSubstitutionsChanged() {
            _appIdSubstitutionsTrigger++;
        }
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(pluginId, key) {
            if (pluginId === "CustomRunningApps") {
                if (key === "stripAppName") {
                    root.stripAppName = PluginService.loadPluginData("CustomRunningApps", "stripAppName", true);
                } else if (key === "compressionBias") {
                    root.compressionBias = parseFloat(PluginService.loadPluginData("CustomRunningApps", "compressionBias", "0"));
                } else if (key === "titleDebounce") {
                    root.titleDebounce = parseInt(PluginService.loadPluginData("CustomRunningApps", "titleDebounce", "300"));
                } else if (key === "debugMode") {
                    root.debugMode = PluginService.loadPluginData("CustomRunningApps", "debugMode", false);
                } else if (key === "appIconSize") {
                    root.appIconSize = PluginService.loadPluginData("CustomRunningApps", "appIconSize", 24);
                } else if (key === "pillSpacing") {
                    root.pillSpacingPreset = PluginService.loadPluginData("CustomRunningApps", "pillSpacing", "S");
                } else if (key === "widgetPadding") {
                    root.widgetPaddingPreset = PluginService.loadPluginData("CustomRunningApps", "widgetPadding", "M");
                } else if (key === "iconTitleSpacing") {
                    root.iconTitleSpacingPreset = PluginService.loadPluginData("CustomRunningApps", "iconTitleSpacing", "S");
                } else if (key === "showStackingTabbing") {
                    root.showStackingTabbing = PluginService.loadPluginData("CustomRunningApps", "showStackingTabbing", true);
                } else if (key === "flatOuterEdge") {
                    root.flatOuterEdge = PluginService.loadPluginData("CustomRunningApps", "flatOuterEdge", false);
                } else if (key === "focusedColorMode") {
                    root.focusedColorMode = PluginService.loadPluginData("CustomRunningApps", "focusedColorMode", "surfaceContainerHighest");
                } else if (key === "unfocusedColorMode") {
                    root.unfocusedColorMode = PluginService.loadPluginData("CustomRunningApps", "unfocusedColorMode", "transparent");
                } else if (key === "focusedOpacity") {
                    root.focusedOpacity = parseFloat(PluginService.loadPluginData("CustomRunningApps", "focusedOpacity", "100"));
                } else if (key === "unfocusedOpacity") {
                    root.unfocusedOpacity = parseFloat(PluginService.loadPluginData("CustomRunningApps", "unfocusedOpacity", "0"));
                } else if (key === "focusedTextColorMode") {
                    root.focusedTextColorMode = PluginService.loadPluginData("CustomRunningApps", "focusedTextColorMode", "auto");
                } else if (key === "unfocusedTextColorMode") {
                    root.unfocusedTextColorMode = PluginService.loadPluginData("CustomRunningApps", "unfocusedTextColorMode", "auto");
                }
            }
        }
    }
    readonly property var groupedWindows: {
        if (!SettingsData.runningAppsGroupByApp) {
            return [];
        }
        try {
            if (!sortedToplevels || sortedToplevels.length === 0) {
                return [];
            }
            const appGroups = new Map();
            sortedToplevels.forEach((toplevel, index) => {
                if (!toplevel)
                    return;
                const appId = toplevel?.appId || "unknown";
                if (!appGroups.has(appId)) {
                    appGroups.set(appId, {
                        "appId": appId,
                        "windows": []
                    });
                }
                appGroups.get(appId).windows.push({
                    "toplevel": toplevel,
                    "windowId": index,
                    "windowTitle": toplevel?.title || "(Unnamed)"
                });
            });
            return Array.from(appGroups.values());
        } catch (e) {
            return [];
        }
    }
    readonly property int windowCount: SettingsData.runningAppsGroupByApp ? (groupedWindows?.length || 0) : (sortedToplevels?.length || 0)

    // Get list of valid stableIds for current visible items
    readonly property var visibleStableIds: {
        const result = [];
        const isGrouped = SettingsData.runningAppsGroupByApp;
        const items = isGrouped ? groupedWindows : sortedToplevels;
        if (!items)
            return result;
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (isGrouped) {
                result.push(item.appId);
            } else {
                result.push(item?.address ?? i.toString());
            }
        }
        return result;
    }
    readonly property real contentSize: layoutLoader.item ? (isVertical ? layoutLoader.item.implicitHeight : layoutLoader.item.implicitWidth) : 0
    readonly property real calculatedSize: contentSize + horizontalPadding * 2

    width: windowCount > 0 ? (isVertical ? barThickness : calculatedSize) : 0
    height: windowCount > 0 ? (isVertical ? calculatedSize : barThickness) : 0
    visible: windowCount > 0

    // Debug: root widget background
    Rectangle {
        visible: root.debugMode
        anchors.fill: parent
        color: "salmon"
        z: -1
    }

    Item {
        id: visualBackground
        width: root.isVertical ? root.barThickness : root.calculatedSize
        height: root.isVertical ? root.calculatedSize : root.barThickness
        anchors.centerIn: parent
        clip: false

        Rectangle {
            id: outline
            anchors.centerIn: parent
            width: {
                const borderWidth = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return parent.width + borderWidth * 2;
            }
            height: {
                const borderWidth = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return parent.height + borderWidth * 2;
            }
            radius: (barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
            color: "transparent"
            border.width: {
                if (barConfig?.widgetOutlineEnabled ?? false) {
                    return barConfig?.widgetOutlineThickness ?? 1;
                }
                return 0;
            }
            border.color: {
                if (!(barConfig?.widgetOutlineEnabled ?? false)) {
                    return "transparent";
                }
                const colorOption = barConfig?.widgetOutlineColor || "primary";
                const opacity = barConfig?.widgetOutlineOpacity ?? 1.0;
                switch (colorOption) {
                case "surfaceText":
                    return Theme.withAlpha(Theme.surfaceText, opacity);
                case "secondary":
                    return Theme.withAlpha(Theme.secondary, opacity);
                case "primary":
                    return Theme.withAlpha(Theme.primary, opacity);
                default:
                    return Theme.withAlpha(Theme.primary, opacity);
                }
            }
        }

        Rectangle {
            id: background
            anchors.fill: parent
            radius: (barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
            color: {
                if (windowCount === 0) {
                    return "transparent";
                }

                if ((barConfig?.noBackground ?? false)) {
                    return "transparent";
                }

                const baseColor = Theme.widgetBaseBackgroundColor;
                const transparency = (root.barConfig && root.barConfig.widgetTransparency !== undefined) ? root.barConfig.widgetTransparency : 1.0;
                if (Theme.widgetBackgroundHasAlpha) {
                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * transparency);
                }
                return Theme.withAlpha(baseColor, transparency);
            }
        }
    }

    // Smart pill width: centralized width management
    QtObject {
        id: widthManager

        property var originalWidths: ({})      // index -> natural text width
        property var constrainedWidths: ({})   // index -> max allowed text width (-1 = unconstrained)

        function register(idx, naturalWidth) {
            const prev = originalWidths[idx]
            // Skip recalc if width changed by less than 3px (filters oscillating titles)
            if (prev !== undefined && Math.abs(prev - naturalWidth) < 3)
                return
            originalWidths[idx] = naturalWidth
            recalculate()
        }

        function unregister(idx) {
            delete originalWidths[idx];
            delete constrainedWidths[idx];
            recalculate();
        }

        function recalculate() {
            recalcTimer.restart();
        }

        function doRecalculate() {
            if (root.debugMode)
                console.warn("RECALC: called, exp=" + root.compressionRatio);
            // Skip calculation when in forced compact mode (icon-only)
            if (root.forceCompactMode) {
                constrainedWidths = {};
                if (root.debugMode)
                    console.warn("RECALC: skipped - forceCompactMode");
                return;
            }

            // Only include items that are actually visible (filter by visibleStableIds)
            const validIds = root.visibleStableIds;
            const indices = Object.keys(originalWidths).filter(idx => validIds.includes(idx));
            if (indices.length === 0) {
                constrainedWidths = {};
                return;
            }

            // Calculate total natural width
            const spacing = (indices.length - 1) * root.pillSpacing;
            const padding = root.horizontalPadding * 2;
            let totalWidth = spacing + padding;
            let totalTextWidth = 0;

            for (const idx of indices) {
                totalWidth += root.pillOverhead + originalWidths[idx];
                totalTextWidth += originalWidths[idx];
            }

            // If fits, no constraint
            if (totalWidth <= root.availableBarWidth || root.availableBarWidth <= 0) {
                const result = {};
                for (const idx of indices)
                    result[idx] = -1;
                constrainedWidths = result;
                root._widthUpdateTrigger++;
                root.debugInfo = "FITS";
                if (root.debugMode)
                    console.warn("RECALC: FITS - no shrink needed");
                return;
            }

            // Need to shrink - calculate available space for text
            const availableForText = root.availableBarWidth - spacing - padding - (indices.length * root.pillOverhead);
            root.debugInfo = "SHRINK avail4txt:" + Math.round(availableForText);
            const result = redistributeNonLinear(originalWidths, availableForText, root.compressionRatio, indices);
            // Set constraints BEFORE incrementing trigger
            constrainedWidths = result;
            root._widthUpdateTrigger++;
            Qt.callLater(() => {
                root._widthUpdateTrigger++;
            });
        }

        // Iterative redistribution: short items keep natural, long items e by same ratio
        function redistributeNonLinear(widths, available, exponent, filteredIndices) {
            const indices = filteredIndices || Object.keys(widths);
            const result = {};

            // Start with all items needing distribution
            let remaining = [...indices];
            let remainingSpace = available;

            // Iterate: items with natural <= fair share keep natural, redistribute rest
            let changed = true;
            while (changed && remaining.length > 0) {
                changed = false;
                const fairShare = remainingSpace / remaining.length;
                const stillNeed = [];

                for (const idx of remaining) {
                    if (widths[idx] <= fairShare) {
                        // Small item: keep natural width
                        result[idx] = widths[idx];
                        remainingSpace -= widths[idx];
                        changed = true;
                    } else {
                        stillNeed.push(idx);
                    }
                }
                remaining = stillNeed;
            }

            // Remaining items share space using allocation-based distribution
            // exponent=1: proportional (all shrink same ratio)
            // exponent>1: smaller items get relatively more (larger items compress more)
            // Uses 1/exponent to guarantee order preservation (larger items always stay larger)
            if (remaining.length > 0) {
                let active = [...remaining]
                let spaceLeft = remainingSpace

                while (active.length > 0) {
                    let totalAllocWeight = 0
                    const allocWeights = {}

                    for (const idx of active) {
                        // Inverted exponent: higher exp = smaller items get relatively more
                        // but larger items ALWAYS get more absolute space (order preserved)
                        allocWeights[idx] = Math.pow(widths[idx], 1 / exponent)
                        totalAllocWeight += allocWeights[idx]
                    }

                    // Directly allocate space (guarantees order preservation)
                    let anyHitZero = false
                    const stillActive = []

                    for (const idx of active) {
                        const newVal = (allocWeights[idx] / totalAllocWeight) * spaceLeft
                        if (newVal <= 0) {
                            result[idx] = 0
                            anyHitZero = true
                        } else {
                            stillActive.push(idx)
                            if (!anyHitZero) {
                                result[idx] = newVal
                            }
                        }
                    }

                    if (!anyHitZero)
                        break

                    active = stillActive
                }
            }

            if (root.debugMode) {
                let resultSum = 0;
                let shrunkCount = 0;
                let sampleValues = [];
                for (const idx of indices) {
                    resultSum += result[idx];
                    if (result[idx] < widths[idx]) {
                        shrunkCount++;
                        if (sampleValues.length < 3) {
                            sampleValues.push(Math.round(widths[idx]) + "→" + Math.round(result[idx]));
                        }
                    }
                }
                console.warn("REDIST: n=" + indices.length + " shrunk=" + shrunkCount + " exp=" + exponent + " samples:" + sampleValues.join(","));
            }
            return result;
        }
    }

    Timer {
        id: recalcTimer
        interval: 200  // debounce for animated titles (Claude Code, etc.)
        onTriggered: widthManager.doRecalculate()
    }

    // Smart app name stripping: handles versions, instances, and partial names
    function stripAppNameFromTitle(title, appName) {
        if (!title || !appName)
            return title;

        const escapedName = appName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

        // Version/instance suffix: [N] and/or X.X.X
        const suffixPattern = '(?:\\s*\\[\\d+\\])?(?:\\s+v?\\d+(?:\\.\\d+)*(?:-\\w+)?)?';
        // Separator: hyphen, en-dash, em-dash
        const sepPattern = '\\s+[-–—]\\s+';
        // Brand words before app name (e.g., "Google" before "Chrome")
        const brandPattern = '(?:[A-Z][a-zA-Z]*\\s+)*';

        // Pattern 1: separator + optional brand + appName + suffixes
        const fullRegex = new RegExp(sepPattern + brandPattern + escapedName + suffixPattern + '\\s*$', 'i');
        if (fullRegex.test(title)) {
            return title.replace(fullRegex, '').trim();
        }

        // Pattern 2: no separator, just trailing app name
        const noSepRegex = new RegExp('\\s+' + brandPattern + escapedName + suffixPattern + '\\s*$', 'i');
        if (noSepRegex.test(title)) {
            return title.replace(noSepRegex, '').replace(/\s*[-–—]\s*$/, '').trim();
        }

        return title;
    }

    // Smart text shortening with regex: "(.+) - .{2,}$"
    // If match: shorten prefix before " - "
    // If no match: shorten whole string
    function shortenTextSmart(text, maxWidth, metrics) {
        if (!text || maxWidth <= 0)
            return text;

        metrics.text = text;
        if (metrics.width <= maxWidth)
            return text;

        // Check for pattern: prefix " - " suffix (at least 2 chars in suffix)
        const dashIdx = text.lastIndexOf(' - ');
        if (dashIdx > 0 && text.length - dashIdx - 3 >= 2) {
            const prefix = text.substring(0, dashIdx);
            const suffix = text.substring(dashIdx);  // " - Something"

            metrics.text = suffix;
            const suffixWidth = metrics.width;
            metrics.text = '…';
            const ellipsisWidth = metrics.width;

            const availableForPrefix = maxWidth - suffixWidth - ellipsisWidth;
            if (availableForPrefix > 20) {
                const shortened = truncateToWidth(prefix, availableForPrefix, metrics);
                return shortened + '…' + suffix;
            }
        }

        // No match or insufficient space - shorten whole string
        metrics.text = '…';
        const ellipsisWidth = metrics.width;
        return truncateToWidth(text, maxWidth - ellipsisWidth, metrics) + '…';
    }

    function truncateToWidth(text, maxWidth, metrics) {
        if (maxWidth <= 0)
            return '';

        // Binary search for optimal truncation point
        let low = 0, high = text.length;
        while (low < high) {
            const mid = Math.ceil((low + high) / 2);
            metrics.text = text.substring(0, mid);
            if (metrics.width <= maxWidth)
                low = mid;
            else
                high = mid - 1;
        }
        return text.substring(0, low);
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        property real scrollAccumulator: 0
        property real touchpadThreshold: 500

        onWheel: wheel => {
            const deltaY = wheel.angleDelta.y;
            const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            const windows = root.sortedToplevels;
            if (windows.length < 2) {
                return;
            }

            if (isMouseWheel) {
                // Direct mouse wheel action
                let currentIndex = -1;
                for (var i = 0; i < windows.length; i++) {
                    if (windows[i].activated) {
                        currentIndex = i;
                        break;
                    }
                }

                let nextIndex;
                if (deltaY < 0) {
                    if (currentIndex === -1) {
                        nextIndex = 0;
                    } else {
                        nextIndex = Math.min(currentIndex + 1, windows.length - 1);
                    }
                } else {
                    if (currentIndex === -1) {
                        nextIndex = windows.length - 1;
                    } else {
                        nextIndex = Math.max(currentIndex - 1, 0);
                    }
                }

                const nextWindow = windows[nextIndex];
                if (nextWindow) {
                    nextWindow.activate();
                }
            } else {
                // Touchpad - accumulate small deltas
                scrollAccumulator += deltaY;

                if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                    let currentIndex = -1;
                    for (var i = 0; i < windows.length; i++) {
                        if (windows[i].activated) {
                            currentIndex = i;
                            break;
                        }
                    }

                    let nextIndex;
                    if (scrollAccumulator < 0) {
                        if (currentIndex === -1) {
                            nextIndex = 0;
                        } else {
                            nextIndex = Math.min(currentIndex + 1, windows.length - 1);
                        }
                    } else {
                        if (currentIndex === -1) {
                            nextIndex = windows.length - 1;
                        } else {
                            nextIndex = Math.max(currentIndex - 1, 0);
                        }
                    }

                    const nextWindow = windows[nextIndex];
                    if (nextWindow) {
                        nextWindow.activate();
                    }

                    scrollAccumulator = 0;
                }
            }

            wheel.accepted = true;
        }
    }

    Loader {
        id: layoutLoader
        anchors.centerIn: parent
        sourceComponent: root.isVertical ? columnLayout : rowLayout
    }

    Component {
        id: rowLayout
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight

            Row {
                id: pillRow
                spacing: root.pillSpacing

                Repeater {
                    id: windowRepeater
                    model: ScriptModel {
                        values: SettingsData.runningAppsGroupByApp ? groupedWindows : sortedToplevels
                        objectProp: SettingsData.runningAppsGroupByApp ? "appId" : "address"
                    }

                    delegate: Item {
                    id: delegateItem

                    property bool isGrouped: SettingsData.runningAppsGroupByApp
                    property var groupData: isGrouped ? modelData : null
                    property var toplevelData: isGrouped ? (modelData.windows.length > 0 ? modelData.windows[0].toplevel : null) : modelData
                    property bool isFocused: toplevelData ? toplevelData.activated : false
                    property string appId: isGrouped ? modelData.appId : (modelData.appId || "")
                    // Raw title from compositor (updates immediately, may flash briefly to defaults like "bash")
                    readonly property string rawTitle: {
                        const title = toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)";
                        if (!root.stripAppName)
                            return title;
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : "";
                        return root.stripAppNameFromTitle(title, appName) || title;
                    }
                    // Debounced title via root-level cache (survives delegate recreation)
                    readonly property string windowTitle: {
                        root._titleCacheTrigger
                        return root.getCachedTitle(stableId) || rawTitle
                    }
                    onRawTitleChanged: root.requestTitleUpdate(stableId, rawTitle)
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : "Unknown";

                        // DEBUG: show width info (only when debugMode enabled)
                        const debugInfo = root.debugMode ? " [" + root.debugWidthInfo + " nat:" + Math.round(naturalTextWidth) + " eff:" + Math.round(effectiveTextWidth) + " max:" + Math.round(maxTextWidth) + "]" : "";

                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)" + debugInfo;
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "") + debugInfo;
                    }

                    // Stable identifier for width management (index is not stable when items are removed)
                    readonly property string stableId: isGrouped ? appId : (modelData?.address ?? index.toString())

                    // Niri window data (layout, floating status)
                    readonly property var niriWindow: root.getNiriWindow(toplevelData)
                    readonly property int columnIndex: niriWindow?.layout?.pos_in_scrolling_layout?.[0] ?? -1
                    readonly property int rowIndex: niriWindow?.layout?.pos_in_scrolling_layout?.[1] ?? -1
                    readonly property bool isFloating: niriWindow?.is_floating ?? false

                    // Column grouping
                    readonly property string columnKey: niriWindow ?
                        `${niriWindow.workspace_id}-${columnIndex}` : ''
                    readonly property var columnGroup: columnKey ? root.columnGroups[columnKey] : null
                    readonly property bool columnHasMultiple: (columnGroup?.windows?.length ?? 0) > 1
                    readonly property bool isTabbed: columnGroup?.isTabbed ?? false

                    // Position within column (sorted by row index)
                    readonly property int positionInColumn: {
                        if (!columnGroup || !niriWindow) return -1
                        const sorted = columnGroup.windows.slice().sort((a, b) =>
                            (a.layout?.pos_in_scrolling_layout?.[1] || 0) -
                            (b.layout?.pos_in_scrolling_layout?.[1] || 0)
                        )
                        return sorted.findIndex(w => w.id === niriWindow.id)
                    }
                    readonly property bool isFirstInColumn: positionInColumn === 0
                    readonly property bool isLastInColumn: columnGroup ?
                        positionInColumn === columnGroup.windows.length - 1 : false

                    // Frame visibility (skip when grouping by app is enabled)
                    readonly property bool showColumnFrame: root.isNiri && !SettingsData.runningAppsGroupByApp && columnHasMultiple
                    readonly property bool showLeftLine: showColumnFrame && isFirstInColumn
                    readonly property bool showRightLine: showColumnFrame && isLastInColumn
                    readonly property bool showTopLine: showColumnFrame
                    readonly property bool showBottomLine: showColumnFrame
                    readonly property color frameColor: isTabbed ? Theme.warning : Theme.primary

                    // Smart pill width: natural text width (unconstrained)
                    readonly property real naturalTextWidth: hiddenText.implicitWidth

                    // Get constrained width from manager (-1 = no constraint)
                    readonly property real maxTextWidth: {
                        root._widthUpdateTrigger;  // reactive dependency
                        const w = widthManager.constrainedWidths[stableId];
                        return w !== undefined ? w : -1;
                    }

                    // Effective text width for layout
                    readonly property real effectiveTextWidth: maxTextWidth >= 0 ? Math.min(naturalTextWidth, maxTextWidth) : naturalTextWidth

                    // Display text (shortened if needed) - use elide instead of smart shorten to avoid binding loop
                    readonly property string displayText: windowTitle

                    // Smart dash-split for titles like "Document - Firefox"
                    // Matches: hyphen-minus (-), en-dash (–), em-dash (—), minus sign (−)
                    readonly property int dashIndex: {
                        const dashes = [' - ', ' – ', ' — ', ' − '];
                        let maxIdx = -1;
                        for (const d of dashes) {
                            const idx = windowTitle.lastIndexOf(d);
                            if (idx > maxIdx)
                                maxIdx = idx;
                        }
                        return maxIdx;
                    }
                    readonly property int dashLength: {
                        if (dashIndex < 0)
                            return 0;
                        const dashes = [' - ', ' – ', ' — ', ' − '];
                        for (const d of dashes) {
                            if (windowTitle.indexOf(d, dashIndex) === dashIndex)
                                return d.length;
                        }
                        return 3;
                    }
                    readonly property bool hasDashPattern: dashIndex > 0 && windowTitle.length - dashIndex - dashLength >= 2
                    readonly property string prefixText: hasDashPattern ? windowTitle.substring(0, dashIndex) : windowTitle
                    readonly property string suffixText: hasDashPattern ? windowTitle.substring(dashIndex) : ""

                    // Register/unregister with manager
                    Component.onCompleted: {
                        root.requestTitleUpdate(stableId, rawTitle)
                        widthManager.register(stableId, naturalTextWidth)
                    }
                    Component.onDestruction: widthManager.unregister(stableId)
                    onNaturalTextWidthChanged: widthManager.register(stableId, naturalTextWidth)

                    // Hidden text for measuring natural width (using StyledText to match display)
                    StyledText {
                        id: hiddenText
                        visible: false
                        text: windowTitle
                        font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                    }

                    // TextMetrics for smart shortening
                    TextMetrics {
                        id: textMetrics
                        font: hiddenText.font
                    }

                    // Suffix width for dash-split calculation
                    readonly property real suffixWidth: {
                        if (!hasDashPattern)
                            return 0;
                        textMetrics.text = suffixText;
                        return textMetrics.width;
                    }

                    // Only split if there's room for prefix (at least 50% of suffix width for prefix)
                    readonly property bool useDashSplit: hasDashPattern && effectiveTextWidth >= suffixWidth * 1.5

                    readonly property real visualWidth: {
                        const compact = root.forceCompactMode || (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode);

                        // Text width: 0 if compact, otherwise effective (constrained) text width + spacing
                        const textWidth = compact ? 0 : (effectiveTextWidth > 0 ? effectiveTextWidth + root.pillPadding : 0);
                        return root.pillPadding + root.appIconSize + root.iconTitleSpacing + textWidth;
                    }

                    width: visualWidth
                    height: root.barThickness

                    // Debug: pill background
                    Rectangle {
                        visible: root.debugMode
                        anchors.fill: parent
                        color: "navy"
                        z: -1
                    }
                    Rectangle {
                        visible: root.debugMode && isFocused
                        anchors.fill: parent
                        color: "yellow"
                        z: 0
                    }

                    // Debug: pill width info
                    Rectangle {
                        visible: root.debugMode && !root.forceCompactMode
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        color: "black"
                        width: pillDebugText.width + 6
                        height: pillDebugText.height + 2
                        z: 9999

                        Text {
                            id: pillDebugText
                            anchors.centerIn: parent
                            text: {
                                const nat = Math.round(naturalTextWidth)
                                const eff = Math.round(effectiveTextWidth)
                                if (nat === eff)
                                    return nat
                                const pct = Math.round((eff / nat) * 100)
                                const mode = useDashSplit ? ' SPLIT' : (hasDashPattern ? ' END (NO SPACE FOR SPLIT)' : ' END')
                                return nat + '→' + eff + ' (' + pct + '%)' + mode
                            }
                            font.pixelSize: 9
                            color: "white"
                        }
                    }

                    Rectangle {
                        id: visualContent
                        width: delegateItem.visualWidth
                        height: parent.height
                        anchors.centerIn: parent
                        topLeftRadius: root.topLeftRadius
                        topRightRadius: root.topRightRadius
                        bottomLeftRadius: root.bottomLeftRadius
                        bottomRightRadius: root.bottomRightRadius
                        color: {
                            if (isFocused)
                                return Theme.withAlpha(root.focusedColor, root.focusedOpacity / 100)
                            const unfocusedOp = root.unfocusedOpacity / 100
                            if (mouseArea.containsMouse)
                                return Theme.withAlpha(root.unfocusedColor, Math.max(unfocusedOp, 0.1))
                            return Theme.withAlpha(root.unfocusedColor, unfocusedOp)
                        }

                        // App icon
                        IconImage {
                            id: iconImg
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - root.appIconSize) / 2) : root.pillPadding
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.appIconSize
                            height: root.appIconSize
                            source: {
                                root._desktopEntriesUpdateTrigger;
                                root._appIdSubstitutionsTrigger;
                                if (!appId)
                                    return "";
                                const moddedId = Paths.moddedAppId(appId);
                                const desktopEntry = DesktopEntries.heuristicLookup(moddedId);
                                return Paths.getAppIcon(moddedId, desktopEntry);
                            }
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: appId === "org.quickshell"
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                saturation: 0
                                colorization: 1
                                colorizationColor: Theme.primary
                            }
                        }

                        DankIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - root.appIconSize) / 2) : root.pillPadding
                            anchors.verticalCenter: parent.verticalCenter
                            size: root.appIconSize
                            name: "sports_esports"
                            color: root.getTextColor(isFocused)
                            visible: {
                                const moddedId = Paths.moddedAppId(appId);
                                return moddedId.toLowerCase().includes("steam_app");
                            }
                        }

                        // Fallback icon if no icon found
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - root.appIconSize) / 2) : root.pillPadding
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.appIconSize
                            height: root.appIconSize
                            radius: 4
                            color: Theme.secondary
                            visible: {
                                const moddedId = Paths.moddedAppId(appId);
                                const isSteamApp = moddedId.toLowerCase().includes("steam_app");
                                return !iconImg.visible && !isSteamApp;
                            }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    root._desktopEntriesUpdateTrigger;
                                    if (!appId)
                                        return "?";

                                    const desktopEntry = DesktopEntries.heuristicLookup(appId);
                                    const appName = Paths.getAppName(appId, desktopEntry);
                                    return appName.charAt(0).toUpperCase();
                                }
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: Theme.onSecondary
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? -2 : 2
                            anchors.bottomMargin: -2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.primary
                            visible: isGrouped && windowCount > 1
                            z: 10

                            StyledText {
                                anchors.centerIn: parent
                                text: windowCount > 9 ? "9+" : windowCount
                                font.pixelSize: 9
                                color: Theme.surface
                            }
                        }

                        // Debug: icon overlay
                        Rectangle {
                            visible: root.debugMode
                            anchors.fill: iconImg
                            color: "deepskyblue"
                            opacity: 0.5
                            z: 0
                        }

                        // Window title text (only visible in expanded mode)
                        Row {
                            id: titleRow
                            anchors.left: iconImg.right
                            anchors.leftMargin: root.iconTitleSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !(root.forceCompactMode || (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode))
                            clip: true
                            width: effectiveTextWidth

                            StyledText {
                                id: prefixTitleText
                                text: useDashSplit ? prefixText : windowTitle
                                width: useDashSplit ? Math.max(0, parent.width - suffixWidth) : parent.width
                                font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                color: root.getTextColor(isFocused)
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                elide: useDashSplit ? Text.ElideRight : Text.ElideMiddle
                            }
                            StyledText {
                                id: suffixTitleText
                                visible: useDashSplit
                                text: suffixText
                                font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                color: root.getTextColor(isFocused)
                                maximumLineCount: 1
                            }
                        }

                        // Floating indicator - line on top
                        Rectangle {
                            visible: root.showStackingTabbing && delegateItem.isFloating
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: -2
                            height: 2
                            radius: 1
                            color: Theme.warning
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (isGrouped && windowCount > 1) {
                                    let currentIndex = -1;
                                    for (var i = 0; i < groupData.windows.length; i++) {
                                        if (groupData.windows[i].toplevel.activated) {
                                            currentIndex = i;
                                            break;
                                        }
                                    }
                                    const nextIndex = (currentIndex + 1) % groupData.windows.length;
                                    groupData.windows[nextIndex].toplevel.activate();
                                } else if (toplevelObject) {
                                    toplevelObject.activate();
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }
                                tooltipLoader.active = false;

                                windowContextMenuLoader.active = true;
                                if (windowContextMenuLoader.item) {
                                    windowContextMenuLoader.item.currentWindow = toplevelObject;
                                    // Pass bar context
                                    windowContextMenuLoader.item.triggerBarConfig = root.barConfig;
                                    windowContextMenuLoader.item.triggerBarPosition = root.axis.edge === "left" ? 2 : (root.axis.edge === "right" ? 3 : (root.axis.edge === "top" ? 0 : 1));
                                    windowContextMenuLoader.item.triggerBarThickness = root.barThickness;
                                    windowContextMenuLoader.item.triggerBarSpacing = root.barSpacing;
                                    if (root.isVertical) {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                        const relativeY = globalPos.y - screenY;
                                        // Add minTooltipY offset to account for top bar
                                        const adjustedY = relativeY + root.minTooltipY;
                                        const xPos = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                        windowContextMenuLoader.item.showAt(xPos, adjustedY, true, root.axis?.edge);
                                    } else {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const relativeX = globalPos.x - screenX;
                                        const isBottom = root.axis?.edge === "bottom";
                                        const yPos = isBottom
                                            ? (root.parentScreen.height - root.barThickness - root.barSpacing + 7)
                                            : (root.barThickness + root.barSpacing - 7);
                                        windowContextMenuLoader.item.showAt(relativeX, yPos, false, isBottom ? "bottom" : "top");
                                    }
                                }
                            } else if (mouse.button === Qt.MiddleButton) {
                                if (toplevelObject) {
                                    if (typeof toplevelObject.close === "function") {
                                        toplevelObject.close();
                                    }
                                }
                            }
                        }
                        onEntered: {
                            root.hoveredItem = delegateItem;
                            // tooltipLoader.active = true;  // disabled
                            if (tooltipLoader.item) {
                                if (root.isVertical) {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                    const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                    const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                    const relativeY = globalPos.y - screenY;
                                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS) : (root.parentScreen.width - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS);
                                    const isLeft = root.axis?.edge === "left";
                                    const adjustedY = relativeY + root.minTooltipY;
                                    const finalX = screenX + tooltipX;
                                    tooltipLoader.item.show(delegateItem.tooltipText, finalX, adjustedY, root.parentScreen, isLeft, !isLeft);
                                } else {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height);
                                    const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                    const isBottom = root.axis?.edge === "bottom";
                                    const tooltipY = isBottom ? (screenHeight - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS - 35) : (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS);
                                    tooltipLoader.item.show(delegateItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false);
                                }
                            }
                        }
                        onExited: {
                            if (root.hoveredItem === delegateItem) {
                                root.hoveredItem = null;
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }

                                tooltipLoader.active = false;
                            }
                        }
                    }
                }
            }
            }

            // Frame overlay - renders on top of all pills
            Repeater {
                model: {
                    // Build list of column groups that need frames
                    if (!root.showStackingTabbing || !root.isNiri || SettingsData.runningAppsGroupByApp) return []
                    const groups = root.columnGroups
                    const result = []
                    for (const key in groups) {
                        const g = groups[key]
                        if (g.windows.length > 1) {
                            result.push({ key: key, windows: g.windows, isTabbed: g.isTabbed, wsId: g.wsId, col: g.col })
                        }
                    }
                    return result
                }

                delegate: Rectangle {
                    id: frameRect
                    readonly property var group: modelData
                    readonly property color baseColor: (group && group.isTabbed) ? Theme.secondary : Theme.primary

                    // Check if any window in the group is focused
                    readonly property bool groupHasFocus: {
                        if (!group || !group.windows) return false
                        const toplevels = root.sortedToplevels
                        for (const niriWin of group.windows) {
                            const toplevel = toplevels.find(t => t.niriWindowId === niriWin.id)
                            if (toplevel && toplevel.activated) return true
                        }
                        return false
                    }

                    readonly property color frameColor: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, groupHasFocus ? 0.75 : 0.5)

                    // Calculate frame bounds from actual pill positions
                    readonly property var frameBounds: {
                        root._widthUpdateTrigger  // react to width changes
                        const toplevels = root.sortedToplevels
                        const items = SettingsData.runningAppsGroupByApp ? root.groupedWindows : toplevels
                        if (!items || items.length === 0) return { x: 0, width: 0 }

                        let startX = 0
                        let endX = 0
                        let foundFirst = false

                        let currentX = 0
                        for (let i = 0; i < items.length; i++) {
                            const item = items[i]
                            const toplevel = item
                            const niriWin = root.getNiriWindow(toplevel)

                            // Calculate this pill's width
                            const stableId = toplevel?.address ?? i.toString()
                            const naturalWidth = widthManager.originalWidths[stableId] || 0
                            const maxWidth = widthManager.constrainedWidths[stableId]
                            const effectiveTextWidth = (maxWidth !== undefined && maxWidth >= 0) ? Math.min(naturalWidth, maxWidth) : naturalWidth
                            const compact = root.forceCompactMode || (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                            const textWidth = compact ? 0 : (effectiveTextWidth > 0 ? effectiveTextWidth + root.pillPadding : 0)
                            const pillWidth = root.pillPadding + root.appIconSize + root.iconTitleSpacing + textWidth

                            // Check if this pill belongs to current group
                            if (niriWin) {
                                const col = niriWin.layout?.pos_in_scrolling_layout?.[0] ?? -1
                                const pillKey = `${niriWin.workspace_id}-${col}`
                                if (pillKey === group.key) {
                                    if (!foundFirst) {
                                        startX = currentX
                                        foundFirst = true
                                    }
                                    endX = currentX + pillWidth
                                }
                            }

                            currentX += pillWidth + root.pillSpacing
                        }

                        return { x: startX, width: endX - startX }
                    }

                    x: frameBounds.x
                    width: frameBounds.width
                    y: 0
                    height: pillRow.height
                    color: "transparent"
                    border.width: 2
                    border.color: frameColor
                    radius: Theme.cornerRadius
                    visible: frameBounds.width > 0
                    z: 10
                }
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            spacing: root.pillSpacing

            Repeater {
                id: windowRepeater
                model: ScriptModel {
                    values: SettingsData.runningAppsGroupByApp ? groupedWindows : sortedToplevels
                    objectProp: SettingsData.runningAppsGroupByApp ? "appId" : "address"
                }

                delegate: Item {
                    id: delegateItem

                    property bool isGrouped: SettingsData.runningAppsGroupByApp
                    property var groupData: isGrouped ? modelData : null
                    property var toplevelData: isGrouped ? (modelData.windows.length > 0 ? modelData.windows[0].toplevel : null) : modelData
                    property bool isFocused: toplevelData ? toplevelData.activated : false
                    property string appId: isGrouped ? modelData.appId : (modelData.appId || "")
                    readonly property string rawTitle: {
                        const title = toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)";
                        if (!root.stripAppName)
                            return title;
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : "";
                        return root.stripAppNameFromTitle(title, appName) || title;
                    }
                    // Debounced title via root-level cache (survives delegate recreation)
                    readonly property string windowTitle: {
                        root._titleCacheTrigger
                        const id = isGrouped ? appId : (modelData?.address ?? index.toString())
                        return root.getCachedTitle(id) || rawTitle
                    }
                    onRawTitleChanged: {
                        const id = isGrouped ? appId : (modelData?.address ?? index.toString())
                        root.requestTitleUpdate(id, rawTitle)
                    }
                    Component.onCompleted: {
                        const id = isGrouped ? appId : (modelData?.address ?? index.toString())
                        root.requestTitleUpdate(id, rawTitle)
                    }
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : "Unknown";

                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)";
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "");
                    }
                    readonly property real visualWidth: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? root.appIconSize : (root.pillPadding + root.appIconSize + root.iconTitleSpacing + (titleText.implicitWidth > 0 ? titleText.implicitWidth + root.pillPadding : 120))

                    // Niri window data (layout, floating status)
                    readonly property var niriWindow: root.getNiriWindow(toplevelData)
                    readonly property int columnIndex: niriWindow?.layout?.pos_in_scrolling_layout?.[0] ?? -1
                    readonly property int rowIndex: niriWindow?.layout?.pos_in_scrolling_layout?.[1] ?? -1
                    readonly property bool isFloating: niriWindow?.is_floating ?? false

                    // Column grouping
                    readonly property string columnKey: niriWindow ?
                        `${niriWindow.workspace_id}-${columnIndex}` : ''
                    readonly property var columnGroup: columnKey ? root.columnGroups[columnKey] : null
                    readonly property bool columnHasMultiple: (columnGroup?.windows?.length ?? 0) > 1
                    readonly property bool isTabbed: columnGroup?.isTabbed ?? false

                    // Position within column (sorted by row index)
                    readonly property int positionInColumn: {
                        if (!columnGroup || !niriWindow) return -1
                        const sorted = columnGroup.windows.slice().sort((a, b) =>
                            (a.layout?.pos_in_scrolling_layout?.[1] || 0) -
                            (b.layout?.pos_in_scrolling_layout?.[1] || 0)
                        )
                        return sorted.findIndex(w => w.id === niriWindow.id)
                    }
                    readonly property bool isFirstInColumn: positionInColumn === 0
                    readonly property bool isLastInColumn: columnGroup ?
                        positionInColumn === columnGroup.windows.length - 1 : false

                    // Frame visibility (skip when grouping by app is enabled)
                    readonly property bool showColumnFrame: root.isNiri && !SettingsData.runningAppsGroupByApp && columnHasMultiple
                    readonly property bool showTopLine: showColumnFrame && isFirstInColumn
                    readonly property bool showBottomLine: showColumnFrame && isLastInColumn
                    readonly property bool showLeftLine: showColumnFrame
                    readonly property bool showRightLine: showColumnFrame
                    readonly property color frameColor: isTabbed ? Theme.warning : Theme.primary

                    width: root.barThickness
                    height: root.appIconSize

                    // Debug: pill background
                    Rectangle {
                        visible: root.debugMode
                        anchors.fill: parent
                        color: "deepskyblue"
                        z: -1
                    }
                    Rectangle {
                        visible: root.debugMode && isFocused
                        anchors.fill: parent
                        color: "darkgreen"
                        z: 0
                    }

                    Rectangle {
                        id: visualContent
                        width: root.isVertical ? root.barThickness : delegateItem.visualWidth
                        height: parent.height
                        anchors.centerIn: parent
                        topLeftRadius: root.topLeftRadius
                        topRightRadius: root.topRightRadius
                        bottomLeftRadius: root.bottomLeftRadius
                        bottomRightRadius: root.bottomRightRadius
                        color: {
                            if (isFocused)
                                return Theme.withAlpha(root.focusedColor, root.focusedOpacity / 100)
                            const unfocusedOp = root.unfocusedOpacity / 100
                            if (mouseArea.containsMouse)
                                return Theme.withAlpha(root.unfocusedColor, Math.max(unfocusedOp, 0.1))
                            return Theme.withAlpha(root.unfocusedColor, unfocusedOp)
                        }

                        IconImage {
                            id: iconImg
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.appIconSize
                            height: root.appIconSize
                            source: {
                                root._desktopEntriesUpdateTrigger;
                                root._appIdSubstitutionsTrigger;
                                if (!appId)
                                    return "";
                                const moddedId = Paths.moddedAppId(appId);
                                const desktopEntry = DesktopEntries.heuristicLookup(moddedId);
                                return Paths.getAppIcon(moddedId, desktopEntry);
                            }
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: appId === "org.quickshell"
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                saturation: 0
                                colorization: 1
                                colorizationColor: Theme.primary
                            }
                        }

                        // Debug: icon overlay
                        Rectangle {
                            visible: root.debugMode
                            anchors.fill: iconImg
                            color: "crimson"
                            z: 1
                        }

                        DankIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - root.appIconSize) / 2) : root.pillPadding
                            anchors.verticalCenter: parent.verticalCenter
                            size: root.appIconSize
                            name: "sports_esports"
                            color: root.getTextColor(isFocused)
                            visible: {
                                const moddedId = Paths.moddedAppId(appId);
                                return moddedId.toLowerCase().includes("steam_app");
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: {
                                const moddedId = Paths.moddedAppId(appId);
                                const isSteamApp = moddedId.toLowerCase().includes("steam_app");
                                return !iconImg.visible && !isSteamApp;
                            }
                            text: {
                                root._desktopEntriesUpdateTrigger;
                                if (!appId)
                                    return "?";

                                const desktopEntry = DesktopEntries.heuristicLookup(appId);
                                const appName = Paths.getAppName(appId, desktopEntry);
                                return appName.charAt(0).toUpperCase();
                            }
                            font.pixelSize: 10
                            color: root.getTextColor(isFocused)
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? -2 : 2
                            anchors.bottomMargin: -2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.primary
                            visible: isGrouped && windowCount > 1
                            z: 10

                            StyledText {
                                anchors.centerIn: parent
                                text: windowCount > 9 ? "9+" : windowCount
                                font.pixelSize: 9
                                color: Theme.surface
                            }
                        }

                        StyledText {
                            anchors.left: iconImg.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !(widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                            text: windowTitle
                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                            color: root.getTextColor(isFocused)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Floating indicator - line on left side for vertical bar
                        Rectangle {
                            visible: root.showStackingTabbing && delegateItem.isFloating
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: -2
                            width: 2
                            radius: 1
                            color: Theme.warning
                        }
                    }

                    // Column frame - top line (first in column only)
                    Rectangle {
                        visible: delegateItem.showTopLine
                        anchors.top: visualContent.top
                        anchors.topMargin: -4
                        x: visualContent.x + (delegateItem.showLeftLine ? -4 : 0)
                        width: visualContent.width + (delegateItem.showLeftLine ? 4 : 0) + (delegateItem.showRightLine ? 4 : 0)
                        height: 2
                        radius: 1
                        color: delegateItem.frameColor
                    }

                    // Column frame - bottom line (last in column only)
                    Rectangle {
                        visible: delegateItem.showBottomLine
                        anchors.bottom: visualContent.bottom
                        anchors.bottomMargin: -4
                        x: visualContent.x + (delegateItem.showLeftLine ? -4 : 0)
                        width: visualContent.width + (delegateItem.showLeftLine ? 4 : 0) + (delegateItem.showRightLine ? 4 : 0)
                        height: 2
                        radius: 1
                        color: delegateItem.frameColor
                    }

                    // Column frame - left line (all in column)
                    Rectangle {
                        visible: delegateItem.showLeftLine
                        anchors.left: visualContent.left
                        anchors.top: visualContent.top
                        anchors.bottom: visualContent.bottom
                        anchors.leftMargin: -4
                        anchors.topMargin: delegateItem.showTopLine ? -4 : 0
                        anchors.bottomMargin: delegateItem.showBottomLine ? -4 : 0
                        width: 2
                        radius: 1
                        color: delegateItem.frameColor
                    }

                    // Column frame - right line (all in column)
                    Rectangle {
                        visible: delegateItem.showRightLine
                        anchors.right: visualContent.right
                        anchors.top: visualContent.top
                        anchors.bottom: visualContent.bottom
                        anchors.rightMargin: -4
                        anchors.topMargin: delegateItem.showTopLine ? -4 : 0
                        anchors.bottomMargin: delegateItem.showBottomLine ? -4 : 0
                        width: 2
                        radius: 1
                        color: delegateItem.frameColor
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (isGrouped && windowCount > 1) {
                                    let currentIndex = -1;
                                    for (var i = 0; i < groupData.windows.length; i++) {
                                        if (groupData.windows[i].toplevel.activated) {
                                            currentIndex = i;
                                            break;
                                        }
                                    }
                                    const nextIndex = (currentIndex + 1) % groupData.windows.length;
                                    groupData.windows[nextIndex].toplevel.activate();
                                } else if (toplevelObject) {
                                    toplevelObject.activate();
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }
                                tooltipLoader.active = false;

                                windowContextMenuLoader.active = true;
                                if (windowContextMenuLoader.item) {
                                    windowContextMenuLoader.item.currentWindow = toplevelObject;
                                    // Pass bar context
                                    windowContextMenuLoader.item.triggerBarConfig = root.barConfig;
                                    windowContextMenuLoader.item.triggerBarPosition = root.axis.edge === "left" ? 2 : (root.axis.edge === "right" ? 3 : (root.axis.edge === "top" ? 0 : 1));
                                    windowContextMenuLoader.item.triggerBarThickness = root.barThickness;
                                    windowContextMenuLoader.item.triggerBarSpacing = root.barSpacing;
                                    if (root.isVertical) {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                        const relativeY = globalPos.y - screenY;
                                        // Add minTooltipY offset to account for top bar
                                        const adjustedY = relativeY + root.minTooltipY;
                                        const xPos = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                        windowContextMenuLoader.item.showAt(xPos, adjustedY, true, root.axis?.edge);
                                    } else {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const relativeX = globalPos.x - screenX;
                                        const isBottom = root.axis?.edge === "bottom";
                                        const yPos = isBottom
                                            ? (root.parentScreen.height - root.barThickness - root.barSpacing + 7)
                                            : (root.barThickness + root.barSpacing - 7);
                                        windowContextMenuLoader.item.showAt(relativeX, yPos, false, isBottom ? "bottom" : "top");
                                    }
                                }
                            }
                        }
                        onEntered: {
                            root.hoveredItem = delegateItem;
                            // tooltipLoader.active = true;  // disabled
                            if (tooltipLoader.item) {
                                if (root.isVertical) {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                    const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                    const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                    const relativeY = globalPos.y - screenY;
                                    const tooltipX = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                    const isLeft = root.axis?.edge === "left";
                                    const adjustedY = relativeY + root.minTooltipY;
                                    const finalX = screenX + tooltipX;
                                    tooltipLoader.item.show(delegateItem.tooltipText, finalX, adjustedY, root.parentScreen, isLeft, !isLeft);
                                } else {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height);
                                    const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                    const isBottom = root.axis?.edge === "bottom";
                                    const tooltipY = isBottom ? (screenHeight - root.barThickness - root.barSpacing - Theme.spacingXS - 35) : (root.barThickness + root.barSpacing + Theme.spacingXS);
                                    tooltipLoader.item.show(delegateItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false);
                                }
                            }
                        }
                        onExited: {
                            if (root.hoveredItem === delegateItem) {
                                root.hoveredItem = null;
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }

                                tooltipLoader.active = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // DEBUG: visible width info (click to copy)
    Rectangle {
        id: debugRect
        visible: root.debugMode
        anchors.left: parent.left
        anchors.top: parent.top
        color: debugMouseArea.containsMouse ? "#333" : "black"
        width: debugText.width + 10
        height: debugText.height + 4
        z: 9999

        property bool justCopied: false

        Text {
            id: debugText
            anchors.centerIn: parent
            text: debugRect.justCopied ? "Copied!" : root.debugWidthInfo
            font.pixelSize: 12
            color: debugRect.justCopied ? "lime" : "white"
        }

        MouseArea {
            id: debugMouseArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                debugCopyProc.running = true;
                debugRect.justCopied = true;
                debugCopyTimer.restart();
            }
        }

        Timer {
            id: debugCopyTimer
            interval: 1000
            onTriggered: debugRect.justCopied = false
        }

        Process {
            id: debugCopyProc
            command: ["wl-copy", root.debugWidthInfo]
        }
    }

    Loader {
        id: tooltipLoader

        active: false

        sourceComponent: DankTooltip {}
    }

    Loader {
        id: windowContextMenuLoader
        active: false
        sourceComponent: PanelWindow {
            id: contextMenuWindow

            property var currentWindow: null
            property bool isVisible: false
            property point anchorPos: Qt.point(0, 0)
            property bool isVertical: false
            property string edge: "top"

            // New properties for bar context
            property int triggerBarPosition: (SettingsData.barConfigs[0]?.position ?? SettingsData.Position.Top)
            property real triggerBarThickness: 0
            property real triggerBarSpacing: 0
            property var triggerBarConfig: null

            readonly property real effectiveBarThickness: {
                if (triggerBarThickness > 0 && triggerBarSpacing > 0) {
                    return triggerBarThickness + triggerBarSpacing;
                }
                return Math.max(26 + (barConfig?.innerPadding ?? 4) * 0.6, Theme.barHeight - 4 - (8 - (barConfig?.innerPadding ?? 4))) + (barConfig?.spacing ?? 4);
            }

            property var barBounds: {
                if (!contextMenuWindow.screen || !triggerBarConfig) {
                    return {
                        "x": 0,
                        "y": 0,
                        "width": 0,
                        "height": 0,
                        "wingSize": 0
                    };
                }
                return SettingsData.getBarBounds(contextMenuWindow.screen, effectiveBarThickness, triggerBarPosition, triggerBarConfig);
            }

            property real barY: barBounds.y

            function showAt(x, y, vertical, barEdge) {
                screen = root.parentScreen;
                anchorPos = Qt.point(x, y);
                isVertical = vertical ?? false;
                edge = barEdge ?? "top";
                isVisible = true;
                visible = true;
            }

            function close() {
                isVisible = false;
                visible = false;
                windowContextMenuLoader.active = false;
            }

            implicitWidth: 100
            implicitHeight: 40
            visible: false
            color: "transparent"

            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: contextMenuWindow.close()
            }

            Rectangle {
                x: {
                    if (contextMenuWindow.isVertical) {
                        if (contextMenuWindow.edge === "left") {
                            return Math.min(contextMenuWindow.width - width - 10, contextMenuWindow.anchorPos.x);
                        } else {
                            return Math.max(10, contextMenuWindow.anchorPos.x - width);
                        }
                    } else {
                        const left = 10;
                        const right = contextMenuWindow.width - width - 10;
                        const want = contextMenuWindow.anchorPos.x - width / 2;
                        return Math.max(left, Math.min(right, want));
                    }
                }
                y: {
                    if (contextMenuWindow.isVertical) {
                        const top = Math.max(barY, 10);
                        const bottom = contextMenuWindow.height - height - 10;
                        const want = contextMenuWindow.anchorPos.y - height / 2;
                        return Math.max(top, Math.min(bottom, want));
                    } else {
                        return contextMenuWindow.anchorPos.y;
                    }
                }
                width: 100
                height: 32
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: closeMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: I18n.tr("Close")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenuWindow.currentWindow) {
                            contextMenuWindow.currentWindow.close();
                        }
                        contextMenuWindow.close();
                    }
                }
            }
        }
    }
}
