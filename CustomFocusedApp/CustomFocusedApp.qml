import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: widgetData?.focusedWindowCompactMode !== undefined ? widgetData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode
    property int availableWidth: 400
    readonly property int maxNormalWidth: 99999
    readonly property int maxCompactWidth: 288
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
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

    Component.onCompleted: {
        updateDesktopEntry();
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

    Connections {
        target: root
        function onActiveWindowChanged() {
            root.updateDesktopEntry();
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
            let currentWorkspaceId = null;
            for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
                const ws = NiriService.allWorkspaces[i];
                if (ws.is_focused) {
                    currentWorkspaceId = ws.id;
                    break;
                }
            }

            if (!currentWorkspaceId) {
                return false;
            }

            const workspaceWindows = NiriService.windows.filter(w => w.workspace_id === currentWorkspaceId);
            return workspaceWindows.length > 0 && activeWindow && activeWindow.title;
        }

        if (CompositorService.isHyprland) {
            if (!Hyprland.focusedWorkspace || !activeWindow || !activeWindow.title) {
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

        return activeWindow && activeWindow.title;
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
                layer.enabled: activeWindow && activeWindow.appId === "org.quickshell"
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
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, compactMode ? 80 : 99999)
                    visible: false  // Patched: use icon instead
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: false  // Patched: no dot with icon
                }

                StyledText {
                    id: titleText
                    text: {
                        const title = activeWindow && activeWindow.title ? activeWindow.title : "";
                        if (!root.stripAppName)
                            return title;
                        const appName = appText.text;
                        return root.stripAppNameFromTitle(title, appName);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, compactMode ? 280 : 99999)
                    visible: text.length > 0
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.isVerticalOrientation
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (root.isVerticalOrientation && activeWindow && activeWindow.appId && root.parentScreen) {
                tooltipLoader.active = true;
                if (tooltipLoader.item) {
                    const globalPos = mapToGlobal(width / 2, height / 2);
                    const currentScreen = root.parentScreen;
                    const screenX = currentScreen ? currentScreen.x : 0;
                    const screenY = currentScreen ? currentScreen.y : 0;
                    const relativeY = globalPos.y - screenY;
                    // Add minTooltipY offset to account for top bar
                    const adjustedY = relativeY + root.minTooltipY;
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS);

                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    const title = activeWindow.title || "";
                    const tooltipText = appName + (title ? " • " + title : "");

                    const isLeft = root.axis?.edge === "left";
                    tooltipLoader.item.show(tooltipText, screenX + tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }
}
