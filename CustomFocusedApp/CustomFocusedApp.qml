import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Modules.DBar.Widgets
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowCompactMode")
    readonly property int maxNormalWidth: 99999
    readonly property int maxCompactWidth: 288
    readonly property int maxWidth: compactMode ? maxCompactWidth : maxNormalWidth
    // Custom: the width cap is unlimited, so the bar's flex resolver is what keeps the pill out of
    // the side sections — it shrinks the pill toward minimumPrimarySize before overflowing anything.
    property real allottedPrimarySize: 0
    property int availableWidth: allottedPrimarySize > 0 ? allottedPrimarySize : maxWidth
    readonly property real naturalPrimarySize: isVerticalOrientation ? height : !hasWindowsOnCurrentWorkspace ? 0 : Theme.snap(Math.min(contentItem?.naturalWidth ?? 0, maxWidth - horizontalPadding * 2) + horizontalPadding * 2, dpr)
    readonly property real minimumPrimarySize: isVerticalOrientation ? height : Math.min(naturalPrimarySize, Theme.snap((contentItem?.minimumWidth ?? 0) + horizontalPadding * 2, dpr))
    readonly property real effectiveHorizontalWidth: Math.max(0, Math.min(maxWidth, availableWidth))
    readonly property real effectiveHorizontalInnerWidth: Math.max(0, effectiveHorizontalWidth - horizontalPadding * 2)
    property Toplevel activeWindow: null
    property var activeDesktopEntry: null
    property bool isHovered: mouseArea.containsMouse
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

    readonly property string screenName: parentScreen?.name ?? ""
    readonly property bool popoutVisible: focusedWindowPopoutLoader.item?.shouldBeVisible ?? false

    function updateActiveWindow() {
        activeWindow = CompositorService.activeWindowForScreen(parentScreen ? parentScreen.name : null, activeWindow, popoutVisible);
    }

    Component.onCompleted: {
        updateActiveWindow();
        updateDesktopEntry();
    }

    readonly property Toplevel managerActiveToplevel: ToplevelManager.activeToplevel

    onManagerActiveToplevelChanged: updateActiveWindow()

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            root.updateActiveWindow();
        }
        function onWorkspaceStateChanged() {
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
        // pluginDataChanged carries only the plugin id, so reload every value.
        function onPluginDataChanged(pluginId) {
            if (pluginId !== "CustomFocusedApp")
                return;
            root.stripAppName = PluginService.loadPluginData("CustomFocusedApp", "stripAppName", true);
            root.appIconSize = PluginService.loadPluginData("CustomFocusedApp", "appIconSize", 28);
            root.iconTitleSpacingPreset = PluginService.loadPluginData("CustomFocusedApp", "iconTitleSpacing", "S");
        }
    }

    function syncPopoutState() {
        const popout = focusedWindowPopoutLoader.item;
        if (!popout || !activeWindow || !root.parentScreen)
            return;
        popout.currentWindow = activeWindow;
        popout.processId = CompositorService.windowPid(activeWindow);
        root.positionPopout(popout);
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
        CompositorService.windowStateRevision;
        if (!activeWindow || !(activeWindow.title || activeWindow.appId))
            return false;
        return CompositorService.windowOnActiveWorkspace(screenName, activeWindow, popoutVisible);
    }

    width: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? barThickness : (effectiveHorizontalInnerWidth > 0 ? visualWidth : 0)) : 0
    height: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? visualHeight : barThickness) : 0
    visible: hasWindowsOnCurrentWorkspace && (isVerticalOrientation || effectiveHorizontalInnerWidth > 0)

    content: Component {
        Item {
            id: contentRoot
            readonly property bool iconShown: horizontalAppIcon.visible || horizontalFallbackIcon.visible
            readonly property real iconExtent: iconShown ? root.appIconSize + contentRow.spacing : 0
            // Custom: icon + title only — the app name and separator stay hidden
            readonly property real naturalWidth: iconExtent + (titleText.visible ? titleText.implicitWidth : 0)
            readonly property real minimumWidth: iconExtent + Math.min(48, titleText.visible ? titleText.implicitWidth : 0)
            implicitWidth: {
                if (!root.hasWindowsOnCurrentWorkspace)
                    return 0;
                if (root.isVerticalOrientation)
                    return root.widgetThickness - root.horizontalPadding * 2;
                return Math.min(contentRow.implicitWidth, root.effectiveHorizontalInnerWidth);
            }
            width: root.isVerticalOrientation ? root.widgetThickness - root.horizontalPadding * 2 : Math.min(implicitWidth, root.effectiveHorizontalInnerWidth)
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

            DIcon {
                anchors.centerIn: parent
                size: root.appIconSize
                name: "sports_esports"
                color: root.contentColor
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
                    color: root.contentColor
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
                    id: horizontalFallbackIcon
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
                        color: root.contentColor
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
                    color: root.contentColor
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
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    // Custom: keep the title inside the allotted pill; the content Item does not clip
                    width: Math.min(implicitWidth, Math.max(0, root.effectiveHorizontalInnerWidth - contentRoot.iconExtent))
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

            // No context menu from inside the overflow popup; behave like a task switcher.
            const owner = BarWidgetService.registrationForItem(root)?.context?.owner;
            if (owner?.overflowAnchor) {
                CompositorService.activateToplevel(activeWindow);
                owner.overflowSurface?.close();
                return;
            }

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
        sourceComponent: DTooltip {}
    }

    Loader {
        id: focusedWindowPopoutLoader
        active: false
        sourceComponent: FocusedWindowContextMenu {
            onPopoutClosed: root.updateActiveWindow()
        }
    }

    onPopoutVisibleChanged: {
        if (!popoutVisible)
            updateActiveWindow();
    }
}
