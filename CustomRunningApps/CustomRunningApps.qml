import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
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
    readonly property real horizontalPadding: (barConfig?.noBackground ?? false) ? 2 : Theme.spacingM
    property Item windowRoot: (Window.window ? Window.window.contentItem : null)

    // Smart pill width: available bar width for horizontal layout
    readonly property real availableBarWidth: isVertical ? 0 : (barBounds.width > 0 ? barBounds.width : (parentScreen?.width ?? 1920))

    // Fixed overhead per pill: left padding + icon + right padding + text spacing
    readonly property real pillOverhead: Theme.spacingS + 24 + Theme.spacingS + Theme.spacingS

    // Update trigger for width recalculation
    property int _widthUpdateTrigger: 0

    // Debug info for smart pill width
    property string debugInfo: ""

    // Debug: check these values if width issues occur
    property string debugWidthInfo: debugInfo + " | avail:" + Math.round(availableBarWidth) + " calc:" + Math.round(calculatedSize) + " content:" + Math.round(contentSize)

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
    property int _toplevelsUpdateTrigger: 0

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
        target: PluginService
        function onPluginDataChanged(pluginId, key) {
            if (pluginId === "CustomRunningApps" && key === "stripAppName") {
                root.stripAppName = PluginService.loadPluginData("CustomRunningApps", "stripAppName", true)
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
        const result = []
        const isGrouped = SettingsData.runningAppsGroupByApp
        const items = isGrouped ? groupedWindows : sortedToplevels
        if (!items) return result
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (isGrouped) {
                result.push(item.appId)
            } else {
                result.push(item?.address ?? i.toString())
            }
        }
        return result
    }
    readonly property real contentSize: layoutLoader.item ? (isVertical ? layoutLoader.item.implicitHeight : layoutLoader.item.implicitWidth) : 0
    readonly property real calculatedSize: contentSize + horizontalPadding * 2

    width: windowCount > 0 ? (isVertical ? barThickness : calculatedSize) : 0
    height: windowCount > 0 ? (isVertical ? calculatedSize : barThickness) : 0
    visible: windowCount > 0

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
            originalWidths[idx] = naturalWidth
            recalculate()
        }

        function unregister(idx) {
            delete originalWidths[idx]
            delete constrainedWidths[idx]
            recalculate()
        }

        function recalculate() {
            recalcTimer.restart()
        }

        function doRecalculate() {
            // Only include items that are actually visible (filter by visibleStableIds)
            const validIds = root.visibleStableIds
            const indices = Object.keys(originalWidths).filter(idx => validIds.includes(idx))
            if (indices.length === 0) { constrainedWidths = {}; return }

            // Calculate total natural width
            const spacing = (indices.length - 1) * Theme.spacingS
            const padding = root.horizontalPadding * 2
            let totalWidth = spacing + padding
            let totalTextWidth = 0

            for (const idx of indices) {
                totalWidth += root.pillOverhead + originalWidths[idx]
                totalTextWidth += originalWidths[idx]
            }

            // If fits, no constraint
            if (totalWidth <= root.availableBarWidth || root.availableBarWidth <= 0) {
                const result = {}
                for (const idx of indices) result[idx] = -1
                constrainedWidths = result
                root._widthUpdateTrigger++
                root.debugInfo = "FITS avail:" + Math.round(root.availableBarWidth) + " total:" + Math.round(totalWidth)
                return
            }

            // Need to shrink - calculate available space for text
            const availableForText = root.availableBarWidth - spacing - padding - (indices.length * root.pillOverhead)
            root.debugInfo = "SHRINK n:" + indices.length + " forText:" + Math.round(availableForText) + " txtSum:" + Math.round(totalTextWidth) + " validIds:" + validIds.length
            constrainedWidths = redistributeNonLinear(originalWidths, availableForText, 2, indices)
            root._widthUpdateTrigger++
        }

        // Shrinkage-based distribution: larger items absorb more shrinkage
        function redistributeNonLinear(widths, available, exponent, filteredIndices) {
            const indices = filteredIndices || Object.keys(widths)

            let totalOriginal = 0
            for (const idx of indices) totalOriginal += widths[idx]

            // If fits, no shrinking
            if (totalOriginal <= available) {
                const result = {}
                for (const idx of indices) result[idx] = widths[idx]
                return result
            }

            const totalShrinkage = totalOriginal - available

            // Calculate weights: larger items get higher weight = more shrinkage
            let totalWeight = 0
            const weights = {}
            for (const idx of indices) {
                weights[idx] = Math.pow(widths[idx], exponent)
                totalWeight += weights[idx]
            }

            // Distribute shrinkage proportionally to weight
            const result = {}
            let resultSum = 0
            for (const idx of indices) {
                const shrink = (weights[idx] / totalWeight) * totalShrinkage
                result[idx] = widths[idx] - shrink
                resultSum += result[idx]
            }

            root.debugInfo += " resultSum:" + Math.round(resultSum)
            return result
        }
    }

    Timer {
        id: recalcTimer
        interval: 16  // ~1 frame
        onTriggered: widthManager.doRecalculate()
    }

    // Smart app name stripping: handles versions, instances, and partial names
    function stripAppNameFromTitle(title, appName) {
        if (!title || !appName) return title

        const escapedName = appName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

        // Version/instance suffix: [N] and/or X.X.X
        const suffixPattern = '(?:\\s*\\[\\d+\\])?(?:\\s+v?\\d+(?:\\.\\d+)*(?:-\\w+)?)?'
        // Separator: hyphen, en-dash, em-dash
        const sepPattern = '\\s+[-–—]\\s+'
        // Brand words before app name (e.g., "Google" before "Chrome")
        const brandPattern = '(?:[A-Z][a-zA-Z]*\\s+)*'

        // Pattern 1: separator + optional brand + appName + suffixes
        const fullRegex = new RegExp(
            sepPattern + brandPattern + escapedName + suffixPattern + '\\s*$', 'i'
        )
        if (fullRegex.test(title)) {
            return title.replace(fullRegex, '').trim()
        }

        // Pattern 2: no separator, just trailing app name
        const noSepRegex = new RegExp(
            '\\s+' + brandPattern + escapedName + suffixPattern + '\\s*$', 'i'
        )
        if (noSepRegex.test(title)) {
            return title.replace(noSepRegex, '').replace(/\s*[-–—]\s*$/, '').trim()
        }

        return title
    }

    // Smart text shortening with regex: "(.+) - .{2,}$"
    // If match: shorten prefix before " - "
    // If no match: shorten whole string
    function shortenTextSmart(text, maxWidth, metrics) {
        if (!text || maxWidth <= 0) return text

        metrics.text = text
        if (metrics.width <= maxWidth) return text

        // Check for pattern: prefix " - " suffix (at least 2 chars in suffix)
        const dashIdx = text.lastIndexOf(' - ')
        if (dashIdx > 0 && text.length - dashIdx - 3 >= 2) {
            const prefix = text.substring(0, dashIdx)
            const suffix = text.substring(dashIdx)  // " - Something"

            metrics.text = suffix
            const suffixWidth = metrics.width
            metrics.text = '…'
            const ellipsisWidth = metrics.width

            const availableForPrefix = maxWidth - suffixWidth - ellipsisWidth
            if (availableForPrefix > 20) {
                const shortened = truncateToWidth(prefix, availableForPrefix, metrics)
                return shortened + '…' + suffix
            }
        }

        // No match or insufficient space - shorten whole string
        metrics.text = '…'
        const ellipsisWidth = metrics.width
        return truncateToWidth(text, maxWidth - ellipsisWidth, metrics) + '…'
    }

    function truncateToWidth(text, maxWidth, metrics) {
        if (maxWidth <= 0) return ''

        // Binary search for optimal truncation point
        let low = 0, high = text.length
        while (low < high) {
            const mid = Math.ceil((low + high) / 2)
            metrics.text = text.substring(0, mid)
            if (metrics.width <= maxWidth) low = mid
            else high = mid - 1
        }
        return text.substring(0, low)
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
        Row {
            spacing: Theme.spacingS

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
                    property string windowTitle: {
                        const title = toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)"
                        if (!root.stripAppName) return title
                        root._desktopEntriesUpdateTrigger
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : ""
                        return root.stripAppNameFromTitle(title, appName) || title
                    }
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : "Unknown";

                        // DEBUG: show width info
                        const debugInfo = " [" + root.debugWidthInfo + " nat:" + Math.round(naturalTextWidth) + " eff:" + Math.round(effectiveTextWidth) + " max:" + Math.round(maxTextWidth) + "]";

                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)" + debugInfo;
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "") + debugInfo;
                    }

                    // Stable identifier for width management (index is not stable when items are removed)
                    readonly property string stableId: isGrouped ? appId : (modelData?.address ?? index.toString())

                    // Smart pill width: natural text width (unconstrained)
                    readonly property real naturalTextWidth: hiddenText.implicitWidth

                    // Get constrained width from manager (-1 = no constraint)
                    readonly property real maxTextWidth: {
                        root._widthUpdateTrigger  // reactive dependency
                        const w = widthManager.constrainedWidths[stableId]
                        return w !== undefined ? w : -1
                    }

                    // Effective text width for layout
                    readonly property real effectiveTextWidth: maxTextWidth >= 0 ? Math.min(naturalTextWidth, maxTextWidth) : naturalTextWidth

                    // Display text (shortened if needed)
                    readonly property string displayText: {
                        if (maxTextWidth < 0 || maxTextWidth >= naturalTextWidth) return windowTitle
                        return root.shortenTextSmart(windowTitle, maxTextWidth, textMetrics)
                    }

                    // Register/unregister with manager
                    Component.onCompleted: widthManager.register(stableId, naturalTextWidth)
                    Component.onDestruction: widthManager.unregister(stableId)
                    onNaturalTextWidthChanged: widthManager.register(stableId, naturalTextWidth)

                    // Hidden text for measuring natural width
                    Text {
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

                    readonly property real visualWidth: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? 24 : (Theme.spacingS + 24 + Theme.spacingS + (effectiveTextWidth > 0 ? effectiveTextWidth + Theme.spacingS : 120))

                    width: visualWidth
                    height: root.barThickness

                    Rectangle {
                        id: visualContent
                        width: delegateItem.visualWidth
                        height: parent.height
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: {
                            if (isFocused) {
                                return Theme.surfaceContainerHighest;
                            } else {
                                return mouseArea.containsMouse ? Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.7) : "transparent";
                            }
                        }

                        // App icon
                        IconImage {
                            id: iconImg
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - 24) / 2) : Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            source: {
                                root._desktopEntriesUpdateTrigger;
                                if (!appId)
                                    return "";
                                const desktopEntry = DesktopEntries.heuristicLookup(appId);
                                return Paths.getAppIcon(appId, desktopEntry);
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
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - 24) / 2) : Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            size: 24
                            name: "sports_esports"
                            color: Theme.widgetTextColor
                            visible: {
                                const moddedId = Paths.moddedAppId(appId);
                                return moddedId.toLowerCase().includes("steam_app");
                            }
                        }

                        // Fallback text if no icon found
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
                            color: Theme.widgetTextColor
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

                        // Window title text (only visible in expanded mode)
                        StyledText {
                            id: titleText
                            anchors.left: iconImg.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !(widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                            text: displayText
                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                            color: Theme.widgetTextColor
                            maximumLineCount: 1
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
                                        const yPos = root.barThickness + root.barSpacing - 7;
                                        windowContextMenuLoader.item.showAt(relativeX, yPos, false, "top");
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
    }

    Component {
        id: columnLayout
        Column {
            spacing: Theme.spacingS

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
                    property string windowTitle: {
                        const title = toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)"
                        if (!root.stripAppName) return title
                        root._desktopEntriesUpdateTrigger
                        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null
                        const appName = appId ? Paths.getAppName(appId, desktopEntry) : ""
                        return root.stripAppNameFromTitle(title, appName) || title
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
                    readonly property real visualWidth: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? 24 : (Theme.spacingS + 24 + Theme.spacingS + (titleText.implicitWidth > 0 ? titleText.implicitWidth + Theme.spacingS : 120))

                    width: root.barThickness
                    height: 24

                    Rectangle {
                        id: visualContent
                        width: root.isVertical ? root.barThickness : delegateItem.visualWidth
                        height: parent.height
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: {
                            if (isFocused) {
                                return Theme.surfaceContainerHighest;
                            } else {
                                return mouseArea.containsMouse ? Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.7) : "transparent";
                            }
                        }

                        IconImage {
                            id: iconImg
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            source: {
                                root._desktopEntriesUpdateTrigger;
                                if (!appId)
                                    return "";
                                const desktopEntry = DesktopEntries.heuristicLookup(appId);
                                return Paths.getAppIcon(appId, desktopEntry);
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
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - 24) / 2) : Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            size: 24
                            name: "sports_esports"
                            color: Theme.widgetTextColor
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
                            color: Theme.widgetTextColor
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
                            color: Theme.widgetTextColor
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
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
                                        const yPos = root.barThickness + root.barSpacing - 7;
                                        windowContextMenuLoader.item.showAt(relativeX, yPos, false, "top");
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

    // DEBUG: visible width info
    /*
    Rectangle {
        anchors.centerIn: parent
        color: "black"
        width: debugText.width + 10
        height: debugText.height + 6
        z: 9999

        Text {
            id: debugText
            anchors.centerIn: parent
            text: root.debugWidthInfo
            font.pixelSize: 14
            font.bold: true
            color: "yellow"
        }
    }
    */

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
