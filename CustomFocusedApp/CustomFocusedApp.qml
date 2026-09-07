import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Plugins
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: widgetData?.focusedWindowCompactMode !== undefined ? widgetData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode
    property int availableWidth: 400
    // Custom: WidgetHost injects this through a duck-typed Binding (WidgetHost.qml) for any widget
    // that declares it, plugins included — same mechanism as crossEdgeExtension. For the centre
    // section DankBarContent feeds it the live gap between the left and right sections. Without it
    // the pill grew unbounded and painted over — and swallowed clicks for — the side widget groups.
    property real sectionAvailablePrimarySize: 0
    property var barCenterSection: null
    property var barCenterWrapper: null
    property var barLeftSection: null
    property var barRightSection: null
    // Custom: width the other centre-section widgets already claim. Read from our siblings rather
    // than from the section's own width, so the expression never depends on our width (binding loop).
    // Each wrapper carries itemSpacing, and there are exactly as many siblings as inter-widget gaps.
    // Our own chain is BasePill -> WidgetHost(Loader) -> wrapper Item -> CenterSection, so the
    // sibling set is the section's children minus the wrapper we sit under.
    readonly property real centerSiblingsWidth: {
        const section = root.barCenterSection;
        const wrapper = root.barCenterWrapper;
        if (!section?.children || !wrapper)
            return 0;
        let total = 0;
        for (let i = 0; i < section.children.length; i++) {
            const child = section.children[i];
            if (child === wrapper || !child.visible || child.width <= 0)
                continue;
            total += child.width + (child.itemSpacing ?? 0);
        }
        return total;
    }
    // Custom: CenterSection is the full bar width and centres its content on the bar centre, not on
    // the gap between the side sections. The gap is off-centre whenever the two sides differ in
    // width, so clamping to sectionAvailablePrimarySize alone still overruns the narrower side.
    // The real limit is twice the smaller half-gap, less what the centre siblings already take.
    readonly property bool barSectionsResolved: !!(root.barCenterSection && root.barLeftSection && root.barRightSection)
    readonly property real centerHalfGap: {
        if (!root.barSectionsResolved)
            return 0;
        const centreX = root.barCenterSection.width / 2;
        const leftEnd = root.barLeftSection.x + root.barLeftSection.width;
        const rightStart = root.barRightSection.x;
        return Math.max(0, Math.min(centreX - leftEnd, rightStart - centreX));
    }
    readonly property int maxNormalWidth: {
        if (root.isVerticalOrientation)
            return 99999;
        // A resolved-but-zero half-gap means a side section already reaches past the bar centre.
        // Fall back to the floor then, never to the wider sectionAvailablePrimarySize.
        if (root.barSectionsResolved)
            return Math.max(120, Math.floor(2 * root.centerHalfGap - root.centerSiblingsWidth));
        if (root.sectionAvailablePrimarySize > 0)
            return Math.max(120, Math.floor(root.sectionAvailablePrimarySize - root.centerSiblingsWidth));
        return 99999;
    }
    readonly property int maxCompactWidth: 288
    // Custom: keep the title inside the clamped pill; the content Item does not clip
    readonly property real maxTitleWidth: compactMode ? 280 : Math.max(40, root.maxNormalWidth - root.horizontalPadding * 2 - root.appIconSize - root.iconTitleSpacing)
    property Toplevel activeWindow: null
    property var activeDesktopEntry: null
    property bool isHovered: mouseArea.containsMouse
    property bool isAutoHideBar: false
    property bool stripAppName: PluginService.loadPluginData("CustomFocusedApp", "stripAppName", true)
    property real appIconSize: PluginService.loadPluginData("CustomFocusedApp", "appIconSize", 28)
    property string iconTitleSpacingPreset: PluginService.loadPluginData("CustomFocusedApp", "iconTitleSpacing", "S")

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

    readonly property real iconTitleSpacing: spacerValue(iconTitleSpacingPreset)

    function resolveSortedWindow() {
        const sortedWindows = CompositorService.sortedToplevels || [];
        const exactMatch = sortedWindows.find(window => window === activeWindow || window.wayland === activeWindow || window.sourceToplevel === activeWindow);
        if (exactMatch)
            return exactMatch;

        const titleMatches = sortedWindows.filter(window => window.appId === activeWindow.appId && window.title === activeWindow.title);
        return titleMatches.length === 1 ? titleMatches[0] : null;
    }

    function resolveActiveWindowPid() {
        if (!activeWindow)
            return 0;
        if (CompositorService.isNiri) {
            const sortedWindow = resolveSortedWindow();
            return sortedWindow?.niriWindowId !== undefined ? NiriService.windows.find(w => w.id === sortedWindow.niriWindowId)?.pid || 0 : 0;
        }
        if (CompositorService.isHyprland) {
            const hyprWindow = Array.from(Hyprland.toplevels?.values || []).find(t => t.wayland === activeWindow);
            return hyprWindow?.lastIpcObject?.pid || 0;
        }
        if (CompositorService.isMango) {
            const sortedWindow = resolveSortedWindow();
            return sortedWindow?.mangoWindowId !== undefined ? MangoService.windows.find(w => w.id === sortedWindow.mangoWindowId)?.pid || 0 : 0;
        }
        return activeWindow.pid || 0;
    }

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            return barThickness + (barSpacing || 4);
        }

        return 0;
    }

    function isWindowAlive(win) {
        if (!win)
            return false;
        const alive = ToplevelManager.toplevels?.values;
        return !!alive && Array.from(alive).some(t => t === win);
    }

    function getNiriFocusedWindow() {
        if (!CompositorService.isNiri)
            return null;
        const focused = NiriService.windows.find(w => w.is_focused);
        if (focused)
            return focused;
        if (!focusedWindowPopoutLoader.item?.shouldBeVisible || NiriService.lastFocusedWindowId === null)
            return null;
        return NiriService.windows.find(w => w.id === NiriService.lastFocusedWindowId) || null;
    }

    function updateActiveWindow() {
        let active = ToplevelManager.activeToplevel;

        if (!active && CompositorService.isNiri) {
            const focusedWin = getNiriFocusedWindow();
            if (focusedWin) {
                const screenWsIds = new Set(NiriService.allWorkspaces.filter(ws => ws.output === (parentScreen?.name ?? "")).map(ws => ws.id));
                if (screenWsIds.has(focusedWin.workspace_id)) {
                    const sortedMatch = (CompositorService.sortedToplevels || []).find(st => st.niriWindowId === focusedWin.id);
                    active = sortedMatch?.sourceToplevel || (Array.from(ToplevelManager.toplevels?.values || []).find(t => t.appId === focusedWin.app_id && (!focusedWin.title || t.title === focusedWin.title)) || null);
                }
            }
        }

        if (!active) {
            if (activeWindow) {
                if (CompositorService.isNiri) {
                    const currentWs = NiriService.allWorkspaces.find(ws => ws.output === (parentScreen?.name ?? "") && ws.is_active);
                    const wsWindows = currentWs ? NiriService.windows.filter(w => w.workspace_id === currentWs.id) : [];
                    if (!isWindowAlive(activeWindow) || wsWindows.length === 0)
                        activeWindow = null;
                } else if (!isWindowAlive(activeWindow)) {
                    activeWindow = null;
                }
            }
            return;
        }

        if (!parentScreen || CompositorService.filterCurrentDisplay([active], parentScreen?.name)?.length > 0) {
            activeWindow = active;
        } else if (!isWindowAlive(activeWindow)) {
            activeWindow = null;
        }
    }

    Component.onCompleted: {
        updateActiveWindow();
        updateDesktopEntry();
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            root.updateActiveWindow();
        }
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            root.updateActiveWindow();
        }
    }

    Connections {
        target: CompositorService.isNiri ? NiriService : null
        function onWindowsChanged() {
            root.updateActiveWindow();
        }
        function onCurrentOutputChanged() {
            root.updateActiveWindow();
        }
        function onAllWorkspacesChanged() {
            root.updateActiveWindow();
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.updateDesktopEntry();
        }
    }

    Connections {
        target: SettingsData
        function onAppIdSubstitutionsChanged() {
            root.updateDesktopEntry();
        }
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(pluginId, key) {
            if (pluginId === "CustomFocusedApp") {
                if (key === "stripAppName") {
                    root.stripAppName = PluginService.loadPluginData("CustomFocusedApp", "stripAppName", true);
                } else if (key === "appIconSize") {
                    root.appIconSize = PluginService.loadPluginData("CustomFocusedApp", "appIconSize", 28);
                } else if (key === "iconTitleSpacing") {
                    root.iconTitleSpacingPreset = PluginService.loadPluginData("CustomFocusedApp", "iconTitleSpacing", "S");
                }
            }
        }
    }

    function syncPopoutState() {
        const popout = focusedWindowPopoutLoader.item;
        if (!popout || !activeWindow || !root.parentScreen)
            return;
        popout.currentWindow = activeWindow;
        popout.processId = root.resolveActiveWindowPid();
        const globalPos = root.visualContent.mapToItem(null, 0, 0);
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const position = SettingsData.getPopupTriggerPosition(globalPos, root.parentScreen, root.barThickness, root.visualWidth, root.barSpacing, barPosition, root.barConfig);
        popout.setTriggerPosition(position.x, position.y, position.width, root.section, root.parentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
    }

    Connections {
        target: root
        function onActiveWindowChanged() {
            root.updateDesktopEntry();
            if (focusedWindowPopoutLoader.item?.shouldBeVisible) {
                if (root.activeWindow) {
                    root.syncPopoutState();
                    Qt.callLater(() => root.syncPopoutState());
                } else {
                    focusedWindowPopoutLoader.item.close();
                }
            }
        }
    }

    function updateDesktopEntry() {
        if (activeWindow && activeWindow.appId) {
            const moddedId = Paths.moddedAppId(activeWindow.appId);
            activeDesktopEntry = DesktopEntries.heuristicLookup(moddedId);
        } else {
            activeDesktopEntry = null;
        }
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
    readonly property bool hasWindowsOnCurrentWorkspace: {
        if (CompositorService.isNiri) {
            if (!activeWindow || !(activeWindow.title || activeWindow.appId))
                return false;
            if (NiriService.currentOutput !== (parentScreen?.name ?? ""))
                return true;
            const focusedWin = getNiriFocusedWindow();
            if (!focusedWin) {
                const currentWs = NiriService.allWorkspaces.find(ws => ws.output === (parentScreen?.name ?? "") && ws.is_active);
                return !!currentWs && NiriService.windows.some(w => w.workspace_id === currentWs.id);
            }
            const screenWsIds = new Set(
                NiriService.allWorkspaces.filter(ws => ws.output === (parentScreen?.name ?? "")).map(ws => ws.id)
            );
            return screenWsIds.has(focusedWin.workspace_id);
        }

        if (CompositorService.isHyprland) {
            if (!Hyprland.focusedWorkspace || !activeWindow || !(activeWindow.title || activeWindow.appId)) {
                return false;
            }

            try {
                if (!Hyprland.toplevels)
                    return false;
                const hyprlandToplevels = Array.from(Hyprland.toplevels.values);
                const activeHyprToplevel = hyprlandToplevels.find(t => t?.wayland === activeWindow);

                if (!activeHyprToplevel || !activeHyprToplevel.workspace) {
                    return false;
                }

                return activeHyprToplevel.workspace.id === Hyprland.focusedWorkspace.id;
            } catch (e) {
                return false;
            }
        }

        return activeWindow && (activeWindow.title || activeWindow.appId);
    }

    width: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? barThickness : visualWidth) : 0
    height: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? visualHeight : barThickness) : 0
    visible: hasWindowsOnCurrentWorkspace

    content: Component {
        Item {
            implicitWidth: {
                if (!root.hasWindowsOnCurrentWorkspace)
                    return 0;
                if (root.isVerticalOrientation)
                    return root.widgetThickness - root.horizontalPadding * 2;
                const baseWidth = contentRow.implicitWidth;
                return compactMode ? Math.min(baseWidth, maxCompactWidth - root.horizontalPadding * 2) : Math.min(baseWidth, maxNormalWidth - root.horizontalPadding * 2);
            }
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2
            clip: false

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: root.appIconSize
                height: root.appIconSize
                visible: root.isVerticalOrientation && activeWindow && status === Image.Ready
                source: {
                    if (!activeWindow || !activeWindow.appId)
                        return "";
                    return Paths.getAppIcon(activeWindow.appId, activeDesktopEntry);
                }
                smooth: true
                mipmap: true
                asynchronous: true
                layer.enabled: activeWindow && (activeWindow.appId === "org.quickshell" || activeWindow.appId === "com.danklinux.dms")
                layer.smooth: true
                layer.mipmap: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: Theme.primary
                }
            }

            DankIcon {
                anchors.centerIn: parent
                size: root.appIconSize
                name: "sports_esports"
                color: Theme.widgetTextColor
                visible: {
                    if (!root.isVerticalOrientation || !activeWindow || !activeWindow.appId)
                        return false;
                    const moddedId = Paths.moddedAppId(activeWindow.appId);
                    return moddedId.toLowerCase().includes("steam_app");
                }
            }

            // Fallback icon if no icon found
            Rectangle {
                anchors.centerIn: parent
                width: root.appIconSize
                height: root.appIconSize
                radius: 4
                color: Theme.secondary
                visible: {
                    if (!root.isVerticalOrientation || !activeWindow || !activeWindow.appId)
                        return false;
                    if (appIcon.status === Image.Ready)
                        return false;
                    const moddedId = Paths.moddedAppId(activeWindow.appId);
                    return !moddedId.toLowerCase().includes("steam_app");
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (!activeWindow || !activeWindow.appId)
                            return "?";
                        const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                        return appName.charAt(0).toUpperCase();
                    }
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Theme.onSecondary
                }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: root.iconTitleSpacing
                visible: !root.isVerticalOrientation

                IconImage {
                    id: horizontalAppIcon
                    width: root.appIconSize
                    height: root.appIconSize
                    visible: !compactMode && activeWindow && status === Image.Ready
                    source: activeWindow && activeWindow.appId ? Paths.getAppIcon(activeWindow.appId, activeDesktopEntry) : ""
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Fallback icon for horizontal mode
                Rectangle {
                    width: root.appIconSize
                    height: root.appIconSize
                    radius: 4
                    color: Theme.secondary
                    anchors.verticalCenter: parent.verticalCenter
                    visible: {
                        if (compactMode || !activeWindow || !activeWindow.appId)
                            return false;
                        if (horizontalAppIcon.status === Image.Ready)
                            return false;
                        const moddedId = Paths.moddedAppId(activeWindow.appId);
                        return !moddedId.toLowerCase().includes("steam_app");
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!activeWindow || !activeWindow.appId)
                                return "?";
                            const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                            return appName.charAt(0).toUpperCase();
                        }
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.onSecondary
                    }
                }

                StyledText {
                    id: appText
                    text: {
                        if (!activeWindow || !activeWindow.appId)
                            return "";
                        return Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, compactMode ? 80 : 99999)
                    visible: false  // Patched: use icon instead
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: false  // Patched: no dot with icon
                }

                StyledText {
                    id: titleText
                    text: {
                        const title = activeWindow && activeWindow.title ? activeWindow.title : "";
                        const appName = appText.text;
                        if (compactMode && (!title || title === appName))
                            return title || appName;
                        if (!root.stripAppName)
                            return title;
                        const stripped = root.stripAppNameFromTitle(title, appName);
                        if (compactMode && !stripped)
                            return appName;
                        return stripped;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, root.maxTitleWidth)
                    visible: text.length > 0
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        hoverEnabled: root.isVerticalOrientation
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (root.isVerticalOrientation && activeWindow && activeWindow.appId && root.parentScreen) {
                tooltipLoader.active = true;
                if (tooltipLoader.item) {
                    const localPos = mapToItem(null, width / 2, height / 2);
                    const currentScreen = root.parentScreen;
                    // Add minTooltipY offset to account for top bar
                    const adjustedY = localPos.y + root.minTooltipY;
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS);

                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    const title = activeWindow.title || "";
                    const tooltipText = appName + (title ? " • " + title : "");

                    const isLeft = root.axis?.edge === "left";
                    tooltipLoader.item.show(tooltipText, tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }

        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (!activeWindow || !root.parentScreen)
                return;
            if (tooltipLoader.item)
                tooltipLoader.item.hide();
            tooltipLoader.active = false;

            focusedWindowPopoutLoader.active = true;
            if (!focusedWindowPopoutLoader.item)
                return;

            root.syncPopoutState();
            focusedWindowPopoutLoader.item.toggle();
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: focusedWindowPopoutLoader
        active: false
        sourceComponent: FocusedWindowContextMenu {}
    }

    Connections {
        target: focusedWindowPopoutLoader.item
        function onShouldBeVisibleChanged() {
            if (!focusedWindowPopoutLoader.item?.shouldBeVisible)
                root.updateActiveWindow();
        }
        function onPopoutClosed() {
            root.updateActiveWindow();
        }
    }

    // Custom: the pill has to know where the neighbouring bar sections end, and DankBarContent
    // exposes no such property to plugin widgets, so resolve them by walking our own parent chain.
    // Read-only: nothing here mutates DMS-owned state.
    function findBarAncestor(name) {
        let node = root.parent;
        while (node) {
            if (node.objectName === name)
                return node;
            node = node.parent;
        }
        return null;
    }

    function findBarSibling(stack, name) {
        if (!stack?.children)
            return null;
        for (let i = 0; i < stack.children.length; i++) {
            if (stack.children[i].objectName === name)
                return stack.children[i];
        }
        return null;
    }

    function findCenterWrapper() {
        let node = root.parent;
        while (node?.parent) {
            if (node.parent.objectName === "centerSection")
                return node;
            node = node.parent;
        }
        return null;
    }

    // root.parent is still null when Component.onCompleted fires (WidgetHost parents the item
    // after construction), so poll briefly until the sections are reachable.
    Timer {
        id: barSectionAttachTimer
        interval: 250
        repeat: true
        running: true
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (attempts > 40) {
                running = false;
                return;
            }
            const section = root.findBarAncestor("centerSection");
            if (!section)
                return;
            root.barCenterSection = section;
            root.barCenterWrapper = root.findCenterWrapper();
            root.barLeftSection = root.findBarSibling(section.parent, "leftSection");
            root.barRightSection = root.findBarSibling(section.parent, "rightSection");
            running = false;
        }
    }
}
