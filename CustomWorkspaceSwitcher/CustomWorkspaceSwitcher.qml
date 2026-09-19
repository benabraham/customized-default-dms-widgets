import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.WindowManager
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string screenName: parentScreen?.name ?? ""
    property real widgetHeight: 30
    property real barThickness: 48
    property var barConfig: null
    property var blurBarWindow: null
    property var hyprlandOverviewLoader: null
    property var parentScreen: null
    property real crossEdgeExtension: 0
    property var widgetData: null

    // Upstream config v18 moved these from SettingsData globals into per-widget
    // options; the migration deleted the globals, so our own defaults live here.
    readonly property var optionDefaults: ({
            "showWorkspaceApps": true,
            "showWorkspaceIndex": true,
            "showWorkspacePadding": true
        })

    function opt(key) {
        return widgetData?.[key] ?? optionDefaults[key] ?? SettingsData.widgetOption("workspaceSwitcher", widgetData, key);
    }

    readonly property real _leftMargin: {
        if (isVertical)
            return 0;
        root.x;
        if (!root.parent)
            return 0;
        const gap = root.mapToItem(null, 0, 0).x;
        return (gap > 0 && gap < 30) ? gap + 5 : 0;
    }
    readonly property real _rightMargin: {
        if (isVertical)
            return 0;
        root.x;
        root.width;
        if (!root.parent || !blurBarWindow)
            return 0;
        const gap = blurBarWindow.width - root.mapToItem(null, root.width, 0).x;
        return (gap > 0 && gap < 30) ? gap + 5 : 0;
    }
    readonly property real _topMargin: {
        if (!isVertical)
            return axis?.edge === "top" ? crossEdgeExtension : 0;
        root.y;
        if (!root.parent)
            return 0;
        const gap = root.mapToItem(null, 0, 0).y;
        return (gap > 0 && gap < 30) ? gap + 5 : 0;
    }
    readonly property real _bottomMargin: {
        if (!isVertical)
            return axis?.edge === "bottom" ? crossEdgeExtension : 0;
        root.y;
        root.height;
        if (!root.parent || !blurBarWindow)
            return 0;
        const gap = blurBarWindow.height - root.mapToItem(null, 0, root.height).y;
        return (gap > 0 && gap < 30) ? gap + 5 : 0;
    }

    property int _desktopEntriesUpdateTrigger: 0
    readonly property var sortedToplevels: {
        return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
    }

    readonly property string effectiveScreenName: {
        if (!root.opt("workspaceFollowFocus"))
            return root.screenName;
        return BarWidgetService.getFocusedScreenName() || root.screenName;
    }

    readonly property bool useAqueous: CompositorService.isAqueous && AqueousService.available && Quickshell.env("DMS_FORCE_EXTWS") !== "1"

    readonly property var extProjection: (useExtWorkspace && parentScreen) ? WindowManager.screenProjection(CompositorService.isAqueous ? Quickshell.screens.find(s => s.name === effectiveScreenName) || parentScreen : parentScreen) : null
    readonly property bool useExtWorkspace: {
        if (useAqueous)
            return false;
        if (Quickshell.env("DMS_FORCE_EXTWS") === "1")
            return (WindowManager.windowsets?.length ?? 0) > 0;
        if (!CompositorService.compositorDetected || CompositorService.hasWorkspaceIpc)
            return false;
        return (WindowManager.windowsets?.length ?? 0) > 0;
    }
    readonly property bool useNativeWorkspaces: useAqueous || (!useExtWorkspace && CompositorService.hasWorkspaceIpc)
    readonly property bool workspacesHiddenByOverview: CompositorService.workspacesHiddenByOverview(effectiveScreenName)

    readonly property string compositorName: CompositorService.compositor

    onCompositorNameChanged: {
        _placeholderPool = [];
        _hyprSlotPool = {};
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++;
        }
    }

    property var currentWorkspace: {
        if (useExtWorkspace)
            return getExtWorkspaceActiveWorkspace();
        if (!useNativeWorkspaces)
            return 1;
        return CompositorService.currentWorkspaceKey(root.screenName, root.opt("workspaceFollowFocus"));
    }

    property var workspaceList: {
        if (useExtWorkspace) {
            const baseList = getExtWorkspaceWorkspaces();
            return root.opt("showWorkspacePadding") ? padWorkspaces(baseList) : baseList;
        }
        if (!useNativeWorkspaces)
            return [1];
        if (root.workspacesHiddenByOverview)
            return [];

        const baseList = CompositorService.workspacesForScreen(root.screenName, root.opt("workspaceFollowFocus"), {
            "occupiedOnly": root.opt("showOccupiedWorkspacesOnly"),
            "showAllTags": root.opt("dwlShowAllTags"),
            "minCount": root.opt("showWorkspacePadding") ? root.opt("workspacePaddingCount") : 0,
            "showSpecial": root.opt("showSpecialWorkspaces")
        });
        if (CompositorService.ephemeralWorkspaces)
            return hyprlandSlotList(baseList);
        if (!root.opt("showWorkspacePadding") || CompositorService.supportsPersistentWorkspaces || (root.useAqueous && baseList.length === 0))
            return baseList;
        return padWorkspaces(baseList);
    }

    function getWorkspaceIcons(ws) {
        _desktopEntriesUpdateTrigger;
        if (!root.opt("showWorkspaceApps") || !ws || !root.useNativeWorkspaces || ws.placeholder) {
            return [];
        }

        const byApp = {};

        CompositorService.windowsOnWorkspace(ws).forEach((w, i) => {
            const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown");
            const moddedId = Paths.moddedAppId(keyBase);
            // Custom: never group icons - each window gets its own entry
            const key = w.aqueousKey || `${moddedId}_${i}`;

            if (!byApp[key]) {
                const isQuickshell = keyBase === "org.quickshell" || keyBase === "com.danklinux.dms";
                const isSteamApp = Paths.isSteamApp(moddedId);
                const desktopEntry = DesktopEntries.heuristicLookup(moddedId);
                const icon = Paths.getAppIcon(moddedId, desktopEntry);
                const appName = Paths.getAppName(moddedId, desktopEntry);
                byApp[key] = {
                    "type": "icon",
                    "icon": icon,
                    "isQuickshell": isQuickshell,
                    "isSteamApp": isSteamApp,
                    "active": !!(w.activated || w.is_focused),
                    "count": 1,
                    "windowId": w.address || w.id,
                    "windowSession": useAqueous ? w.aqueousSession : "",
                    "fallbackText": appName || ""
                };
            } else {
                byApp[key].count++;
                if (w.activated || w.is_focused) {
                    byApp[key].active = true;
                }
            }
        });

        return Object.values(byApp);
    }

    // Hyprland creates/destroys workspaces on empty enter/leave; slots keyed by id keep delegate identity so pills animate instead of popping
    property var _hyprSlotPool: ({})

    Component {
        id: hyprSlotComponent

        QtObject {
            property var ws: null
        }
    }

    function recordOf(entry) {
        if (!entry || entry.ws === undefined)
            return entry;
        return entry.ws;
    }

    function _hyprSlot(key, ws) {
        let slot = root._hyprSlotPool[key];
        if (!slot) {
            slot = hyprSlotComponent.createObject(root);
            root._hyprSlotPool[key] = slot;
        }
        if (slot.ws !== ws)
            slot.ws = ws;
        return slot;
    }

    function hyprlandSlotList(raw) {
        return raw.map(ws => _hyprSlot(ws.id > 0 ? ws.id : (ws.special ? "special:" : "name:") + (ws.name ?? ""), ws));
    }

    // Stable placeholder instances so ScriptModel (identity-diffed) reuses padding delegates instead of recreating them on workspace churn
    property var _placeholderPool: []

    // Mirrors WorkspaceModel.placeholder(); plugins cannot import the shell's Common/*.js.
    function makePlaceholder() {
        return {
            "id": null,
            "idx": null,
            "name": "",
            "output": "",
            "active": false,
            "placeholder": true
        };
    }

    function padWorkspaces(list) {
        const padded = list.slice();
        const minCount = root.opt("workspacePaddingCount");
        let slot = 0;
        while (padded.length < minCount) {
            if (root._placeholderPool.length <= slot)
                root._placeholderPool.push(root.makePlaceholder());
            padded.push(root._placeholderPool[slot]);
            slot++;
        }
        return padded;
    }

    function getExtWorkspaceWorkspaces() {
        const fallback = [
            {
                "id": "1",
                "name": "1",
                "active": false
            }
        ];
        if (!extProjection)
            return fallback;

        let visible = extProjection.windowsets.filter(ws => ws.shouldDisplay);

        const hasValidCoordinates = visible.some(ws => ws.coordinates && ws.coordinates.length > 0);
        if (hasValidCoordinates) {
            visible = visible.slice().sort((a, b) => {
                const coordsA = a.coordinates || [0, 0];
                const coordsB = b.coordinates || [0, 0];
                if (coordsA[0] !== coordsB[0])
                    return coordsA[0] - coordsB[0];
                return coordsA[1] - coordsB[1];
            });
        }

        return visible.length > 0 ? visible : fallback;
    }

    function getExtWorkspaceActiveWorkspace() {
        if (!extProjection)
            return "";
        const activeWs = extProjection.windowsets.find(ws => ws.active);
        return activeWs || null;
    }

    readonly property real dpr: parentScreen ? CompositorService.getScreenScale(parentScreen) : 1
    // Mirrors BarPill.horizontalPadding; upstream dropped removeWidgetPadding and moved the
    // default from 12 to 8, so keeping the old formula would make this widget pad differently
    // from every other pill on the bar.
    readonly property real padding: Theme.snap((root.barConfig?.widgetPadding ?? 8) * (widgetHeight / 30), dpr)
    readonly property real visualWidth: isVertical ? widgetHeight : (workspaceRow.implicitWidth + padding * 2)
    readonly property real visualHeight: isVertical ? (workspaceRow.implicitHeight + padding * 2) : widgetHeight
    readonly property real appIconSize: Theme.barIconSize(barThickness, -6 + root.opt("workspaceAppIconSizeOffset"), root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)

    // Custom: configurable icon sizes from PluginService (rounded to steps of 2)
    function roundToStep2(val) { return Math.round(val / 2) * 2 }
    property real wsAppIconNormal: roundToStep2(PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsAppIconNormal", 24))
    property real wsAppIconActive: roundToStep2(PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsAppIconActive", 36))
    property real wsNameIconSize: roundToStep2(PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsNameIconSize", 24))
    property bool debugMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "debugMode", false)
    property string wsGapPreset: PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsGapPreset", "XL")
    property bool flatOuterEdge: PluginService.loadPluginData("CustomWorkspaceSwitcher", "flatOuterEdge", false)

    // Custom: corner radii based on bar edge (flat on outer edge when enabled)
    readonly property real cornerRadius: Theme.cornerRadius
    readonly property real topLeftRadius: flatOuterEdge && (axis?.edge === "top" || axis?.edge === "left") ? 0 : cornerRadius
    readonly property real topRightRadius: flatOuterEdge && (axis?.edge === "top" || axis?.edge === "right") ? 0 : cornerRadius
    readonly property real bottomLeftRadius: flatOuterEdge && (axis?.edge === "bottom" || axis?.edge === "left") ? 0 : cornerRadius
    readonly property real bottomRightRadius: flatOuterEdge && (axis?.edge === "bottom" || axis?.edge === "right") ? 0 : cornerRadius

    // Custom: color settings for each state
    property string activeColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "activeColorMode", "primary")
    property real activeOpacity: parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "activeOpacity", "100"))
    property string activeTextColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "activeTextColorMode", "auto")

    property string unfocusedColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "unfocusedColorMode", "surfaceTextAlpha")
    property real unfocusedOpacity: parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "unfocusedOpacity", "100"))
    property string unfocusedTextColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "unfocusedTextColorMode", "auto")

    property string occupiedColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "occupiedColorMode", "surfaceTextAlpha")
    property real occupiedOpacity: parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "occupiedOpacity", "100"))
    property string occupiedTextColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "occupiedTextColorMode", "auto")

    property string urgentColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "urgentColorMode", "error")
    property real urgentOpacity: parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "urgentOpacity", "100"))
    property string urgentTextColorMode: PluginService.loadPluginData("CustomWorkspaceSwitcher", "urgentTextColorMode", "auto")

    function themeColorFromMode(mode) {
        switch (mode) {
        case "primary": return Theme.primary
        case "secondary": return Theme.secondary
        case "error": return Theme.error
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

    readonly property color wsActiveColor: themeColorFromMode(activeColorMode)
    readonly property color wsUnfocusedColor: themeColorFromMode(unfocusedColorMode)
    readonly property color wsOccupiedColor: themeColorFromMode(occupiedColorMode)
    readonly property color wsUrgentColor: themeColorFromMode(urgentColorMode)

    // Custom: gap preset conversion
    readonly property real wsGap: {
        switch (wsGapPreset) {
            case "0": return 0
            case "XS": return Theme.spacingXS
            case "S": return Theme.spacingS
            case "M": return Theme.spacingM
            case "L": return Theme.spacingL
            case "XL": return Theme.spacingXL
            default: return Theme.spacingXL
        }
    }
    readonly property real wsAppIconSizeDiff: wsAppIconActive - wsAppIconNormal

    // Custom: gap for app icon column layout (UI value can be negative, clamped to valid range)
    property real wsAppIconGapRaw: PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsAppIconGap", 0)
    property real wsAppIconGap: Math.max(-wsAppIconSizeDiff / 2, Math.min(32, wsAppIconGapRaw))
    readonly property real wsAppIconGapInternal: wsAppIconGap + wsAppIconSizeDiff / 2

    // Custom: PluginService Connections for dynamic settings reload
    Connections {
        target: PluginService
        // pluginDataChanged carries only the plugin id, so reload every value.
        function onPluginDataChanged(pluginId) {
            if (pluginId !== "CustomWorkspaceSwitcher")
                return;
            root.wsAppIconNormal = roundToStep2(PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsAppIconNormal", 24));
            root.wsAppIconActive = roundToStep2(PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsAppIconActive", 36));
            root.wsNameIconSize = roundToStep2(PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsNameIconSize", 24));
            root.wsAppIconGapRaw = PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsAppIconGap", 0);
            root.debugMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "debugMode", false);
            root.wsGapPreset = PluginService.loadPluginData("CustomWorkspaceSwitcher", "wsGapPreset", "XL");
            root.flatOuterEdge = PluginService.loadPluginData("CustomWorkspaceSwitcher", "flatOuterEdge", false);
            root.activeColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "activeColorMode", "primary");
            root.activeOpacity = parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "activeOpacity", "100"));
            root.activeTextColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "activeTextColorMode", "auto");
            root.unfocusedColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "unfocusedColorMode", "surfaceTextAlpha");
            root.unfocusedOpacity = parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "unfocusedOpacity", "100"));
            root.unfocusedTextColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "unfocusedTextColorMode", "auto");
            root.occupiedColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "occupiedColorMode", "surfaceTextAlpha");
            root.occupiedOpacity = parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "occupiedOpacity", "100"));
            root.occupiedTextColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "occupiedTextColorMode", "auto");
            root.urgentColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "urgentColorMode", "error");
            root.urgentOpacity = parseFloat(PluginService.loadPluginData("CustomWorkspaceSwitcher", "urgentOpacity", "100"));
            root.urgentTextColorMode = PluginService.loadPluginData("CustomWorkspaceSwitcher", "urgentTextColorMode", "auto");
        }
    }

    function toggleHyprlandOverview() {
        const overview = root.hyprlandOverviewLoader?.item;
        if (!overview)
            return;
        overview.overviewOpen = !overview.overviewOpen;
    }

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => ws && !root.recordOf(ws).placeholder);
    }

    function switchToWorkspaceByModelData(entry) {
        const data = root.recordOf(entry);
        if (!data || data.placeholder)
            return;
        if (root.useNativeWorkspaces) {
            CompositorService.switchToWorkspace(data, root.effectiveScreenName);
            return;
        }
        if (root.useExtWorkspace && typeof data.activate === "function")
            data.activate();
    }

    function findClosestWorkspaceIndex(localX, localY) {
        if (workspaceRepeater.count === 0)
            return -1;

        let closestIdx = -1;
        let closestDist = Infinity;

        for (let i = 0; i < workspaceRepeater.count; i++) {
            const item = workspaceRepeater.itemAt(i);
            if (!item)
                continue;
            const center = item.mapToItem(root, item.width / 2, item.height / 2);
            const dist = isVertical ? Math.abs(localY - center.y) : Math.abs(localX - center.x);
            if (dist < closestDist) {
                closestDist = dist;
                closestIdx = i;
            }
        }
        return closestIdx;
    }

    function switchWorkspace(direction) {
        if (useAqueous) {
            const workspaces = getRealWorkspaces();
            const index = workspaces.findIndex(w => w.id === currentWorkspace);
            const next = Math.max(0, Math.min(workspaces.length - 1, index + (direction > 0 ? 1 : -1)));
            if (next !== index)
                CompositorService.switchToWorkspace(workspaces[next]);
            return;
        }
        if (useExtWorkspace) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2)
                return;

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex)
                return;

            const nextWorkspace = realWorkspaces[nextIndex];
            if (typeof nextWorkspace.activate === "function")
                nextWorkspace.activate();
            return;
        }
        if (!useNativeWorkspaces)
            return;
        // specials are overlays you toggle, not positions you scroll to
        CompositorService.stepWorkspace(getRealWorkspaces().map(ws => root.recordOf(ws)).filter(ws => ws.special !== true), root.currentWorkspace, direction);
    }

    function getWorkspaceIndexFallback(modelData, index) {
        if (root.useExtWorkspace)
            return index + 1;
        if (!root.useNativeWorkspaces)
            return modelData - 1;
        return modelData?.idx ?? modelData?.name ?? "";
    }

    function getWorkspaceIndex(modelData, index) {
        if (modelData?.placeholder === true)
            return index + 1;

        let workspaceName = "";
        if (root.opt("showWorkspaceName")) {
            workspaceName = modelData?.name ?? "";

            if (workspaceName && workspaceName !== "") {
                if (root.isVertical) {
                    workspaceName = workspaceName.charAt(0);
                }
            } else {
                workspaceName = "";
            }
        }

        if (workspaceName) {
            if (root.opt("showWorkspaceIndex")) {
                const indexLabel = getWorkspaceIndexFallback(modelData, index);
                return indexLabel ? `${indexLabel}: ${workspaceName}` : workspaceName;
            }
            return workspaceName;
        }

        return getWorkspaceIndexFallback(modelData, index);
    }

    readonly property bool hasWorkspaces: getRealWorkspaces().length > 0
    readonly property bool shouldShow: useNativeWorkspaces || (useExtWorkspace && hasWorkspaces)

    width: shouldShow ? (isVertical ? barThickness : visualWidth) : 0
    height: shouldShow ? (isVertical ? visualHeight : barThickness) : 0
    visible: shouldShow

    Item {
        id: visualBackground
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent

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
                if ((barConfig?.noBackground ?? false))
                    return "transparent";
                const baseColor = Theme.widgetBaseBackgroundColor;
                const transparency = (root.barConfig && root.barConfig.widgetTransparency !== undefined) ? root.barConfig.widgetTransparency : 1.0;
                if (Theme.widgetBackgroundHasAlpha) {
                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * transparency);
                }
                return Theme.withAlpha(baseColor, transparency);
            }
        }
    }

    MouseArea {
        id: edgeMouseArea
        z: -1
        x: -root._leftMargin
        y: -root._topMargin
        width: root.width + root._leftMargin + root._rightMargin
        height: root.height + root._topMargin + root._bottomMargin
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property real touchpadAccumulator: 0
        property real mouseAccumulator: 0
        property bool scrollInProgress: false

        Timer {
            id: scrollCooldown
            interval: 100
            onTriggered: parent.scrollInProgress = false
        }

        onClicked: mouse => {
            const rootPos = edgeMouseArea.mapToItem(root, mouse.x, mouse.y);
            switch (mouse.button) {
            case Qt.RightButton:
                CompositorService.workspaceSecondaryAction(null, root.effectiveScreenName);
                root.toggleHyprlandOverview();
                break;
            case Qt.LeftButton:
                const idx = root.findClosestWorkspaceIndex(rootPos.x, rootPos.y);
                if (idx >= 0)
                    root.switchToWorkspaceByModelData(root.workspaceList[idx]);
                break;
            }
        }

        onWheel: wheel => {
            if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) {
                wheel.accepted = false;
                return;
            }

            if (scrollInProgress)
                return;

            const delta = wheel.angleDelta.y;
            const isTouchpad = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
            const reverse = root.opt("reverseScrolling") ? -1 : 1;

            if (isTouchpad) {
                touchpadAccumulator += delta;
                if (Math.abs(touchpadAccumulator) < 500)
                    return;
                const direction = touchpadAccumulator * reverse < 0 ? 1 : -1;
                root.switchWorkspace(direction);
                scrollInProgress = true;
                scrollCooldown.restart();
                touchpadAccumulator = 0;
                return;
            }

            mouseAccumulator += delta;
            if (Math.abs(mouseAccumulator) < 120)
                return;
            const direction = mouseAccumulator * reverse < 0 ? 1 : -1;
            root.switchWorkspace(direction);
            scrollInProgress = true;
            scrollCooldown.restart();
            mouseAccumulator = 0;
        }
    }

    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property bool suppressShiftAnimation: false

    onWorkspaceListChanged: {
        if (dragSourceIndex >= 0) {
            dragSourceIndex = -1;
            dragTargetIndex = -1;
            suppressShiftAnimation = false;
        }
    }

    Flow {
        id: workspaceRow

        x: isVertical ? visualBackground.x : (parent.width - implicitWidth) / 2
        y: isVertical ? (parent.height - implicitHeight) / 2 : visualBackground.y
        // Custom: use configurable gap
        spacing: root.wsGap
        flow: isVertical ? Flow.TopToBottom : Flow.LeftToRight

        Repeater {
            id: workspaceRepeater
            model: ScriptModel {
                values: root.workspaceList
            }

            Item {
                id: delegateRoot

                property bool isDropTarget: root.dragTargetIndex === index

                z: dragHandler.dragging ? 1000 : 1

                property real shiftOffset: {
                    if (root.dragSourceIndex < 0 || index === root.dragSourceIndex)
                        return 0;
                    const dragIdx = root.dragSourceIndex;
                    const dropIdx = root.dragTargetIndex;
                    if (dropIdx < 0)
                        return 0;
                    const shiftAmount = delegateRoot.width + root.wsGap;
                    if (dragIdx < dropIdx && index > dragIdx && index <= dropIdx)
                        return -shiftAmount;
                    if (dragIdx > dropIdx && index >= dropIdx && index < dragIdx)
                        return shiftAmount;
                    return 0;
                }

                readonly property var shiftSpringParams: Theme.springPreset("fast", 150)

                SpringMotion {
                    id: shiftXSpring
                    enabled: !root.suppressShiftAnimation
                    positionEpsilon: 0.05
                    velocityEpsilon: 0.05
                    stiffness: delegateRoot.shiftSpringParams.stiffness
                    damping: delegateRoot.shiftSpringParams.damping
                    value: delegateRoot.shiftOffset

                    Component.onCompleted: snapTo(delegateRoot.shiftOffset)
                }

                SpringMotion {
                    id: shiftYSpring
                    enabled: !root.suppressShiftAnimation
                    positionEpsilon: 0.05
                    velocityEpsilon: 0.05
                    stiffness: delegateRoot.shiftSpringParams.stiffness
                    damping: delegateRoot.shiftSpringParams.damping
                    value: delegateRoot.shiftOffset

                    Component.onCompleted: snapTo(delegateRoot.shiftOffset)
                }

                onShiftOffsetChanged: {
                    shiftXSpring.retarget(shiftOffset);
                    shiftYSpring.retarget(shiftOffset);
                }

                transform: Translate {
                    x: root.isVertical ? 0 : shiftXSpring.value
                    y: root.isVertical ? shiftYSpring.value : 0
                }

                readonly property var record: root.recordOf(modelData)
                property bool isActive: {
                    if (root.useExtWorkspace || !root.useNativeWorkspaces)
                        return modelData === root.currentWorkspace;
                    return CompositorService.isCurrentWorkspace(record, root.currentWorkspace);
                }
                property bool isOccupied: root.useNativeWorkspaces && CompositorService.workspaceOccupied(record)
                property bool isPlaceholder: !!(record && record.placeholder)
                property bool isHovered: mouseArea.containsMouse

                // Custom: colors from PluginService
                readonly property color unfocusedColor: root.wsUnfocusedColor
                readonly property color activeColor: root.wsActiveColor
                readonly property color occupiedColor: root.wsOccupiedColor
                readonly property color urgentColor: root.wsUrgentColor

                // Custom: colors with opacity from PluginService
                readonly property color requestedColor: {
                    if (isActive)
                        return Theme.withAlpha(activeColor, root.activeOpacity / 100)
                    if (isUrgent)
                        return Theme.withAlpha(urgentColor, root.urgentOpacity / 100)
                    if (isPlaceholder)
                        return Theme.surfaceTextLight
                    if (isHovered)
                        return Theme.withAlpha(unfocusedColor, Math.max(root.unfocusedOpacity / 100, 0.1))
                    if (isOccupied)
                        return Theme.withAlpha(occupiedColor, root.occupiedOpacity / 100)
                    return Theme.withAlpha(unfocusedColor, root.unfocusedOpacity / 100)
                }

                property bool colorAnimationReady: false

                readonly property color displayColor: pillColor.value

                DankColorAnimation {
                    id: pillColor
                    to: delegateRoot.requestedColor
                    animated: delegateRoot.colorAnimationReady
                }

                property var loadedWorkspaceData: null
                property bool loadedIsUrgent: false
                property bool isUrgent: root.useNativeWorkspaces ? CompositorService.workspaceUrgent(record, loadedIsUrgent) : (modelData?.urgent ?? false)
                readonly property var loadedIconData: {
                    if (isPlaceholder)
                        return null;
                    const name = record?.name;
                    if (!name)
                        return null;
                    const custom = SettingsData.getWorkspaceNameIcon(name);
                    if (custom || record.special !== true)
                        return custom;
                    return {
                        "type": "icon",
                        "value": "inbox"
                    };
                }
                readonly property bool loadedHasIcon: loadedIconData !== null
                property var loadedIcons: []

                readonly property int stableIconCount: {
                    if (!root.opt("showWorkspaceApps") || isPlaceholder)
                        return 0;

                    if (root.useAqueous)
                        return loadedIcons.length;

                    if (!root.useNativeWorkspaces)
                        return 0;

                    // Custom: always count individual windows (no grouping)
                    return CompositorService.windowsOnWorkspace(record).length;
                }

                readonly property real baseWidth: root.isVertical ? root.barThickness : Theme.spacingS
                readonly property real baseHeight: root.isVertical ? Theme.spacingS : (root.opt("showWorkspaceApps") ? widgetHeight * 1.0 : widgetHeight * 0.5)

                readonly property real iconsExtraWidth: {
                    if (!root.isVertical && root.opt("showWorkspaceApps") && stableIconCount > 0) {
                        const numIcons = Math.min(stableIconCount, root.opt("maxWorkspaceIcons"));
                        // Custom: use wsAppIconNormal/wsAppIconActive sizes
                        return (numIcons > 0 ? (numIcons - 1) * root.wsAppIconNormal + root.wsAppIconActive : 0) + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0);
                    }
                    return 0;
                }
                readonly property real iconsExtraHeight: {
                    if (root.isVertical && root.opt("showWorkspaceApps") && stableIconCount > 0) {
                        const numIcons = Math.min(stableIconCount, root.opt("maxWorkspaceIcons"));
                        // Custom: use column layout sizing with negative margins
                        const baseHeight = numIcons * root.wsAppIconNormal + (numIcons - 1) * root.wsAppIconGapInternal;
                        const activeNetChange = root.wsAppIconSizeDiff - 2 * Math.min(root.wsAppIconGapInternal, root.wsAppIconSizeDiff / 2);
                        return baseHeight + activeNetChange;
                    }
                    return 0;
                }

                readonly property real visualWidth: baseWidth + iconsExtraWidth
                readonly property real visualHeight: Math.max(root.wsAppIconActive, baseHeight + iconsExtraHeight + root.wsAppIconNormal + 4 + (loadedHasIcon ? root.wsAppIconNormal + 4 : 0))

                // Custom: text color helper functions
                function getContrastingIconColor(bgColor, bgOpacity) {
                    if (bgOpacity < 0.1)
                        return Theme.widgetTextColor
                    return Theme.isLightColor(bgColor, 0.4) ? Qt.rgba(0.15, 0.15, 0.15, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                }
                function getContrastingTextColor(bgColor, bgOpacity) {
                    if (bgOpacity < 0.1)
                        return Theme.widgetTextColor
                    return Theme.isLightColor(bgColor, 0.4) ? Qt.rgba(0.05, 0.05, 0.05, 0.95) : Qt.rgba(0.95, 0.95, 0.95, 0.95)
                }

                function getTextColorForState(state) {
                    let mode, bgColor, bgOpacity
                    switch (state) {
                    case "active":
                        mode = root.activeTextColorMode
                        bgColor = activeColor
                        bgOpacity = root.activeOpacity / 100
                        break
                    case "urgent":
                        mode = root.urgentTextColorMode
                        bgColor = urgentColor
                        bgOpacity = root.urgentOpacity / 100
                        break
                    case "occupied":
                        mode = root.occupiedTextColorMode
                        bgColor = occupiedColor
                        bgOpacity = root.occupiedOpacity / 100
                        break
                    default:
                        mode = root.unfocusedTextColorMode
                        bgColor = unfocusedColor
                        bgOpacity = root.unfocusedOpacity / 100
                    }
                    if (mode === "auto")
                        return getContrastingTextColor(bgColor, bgOpacity)
                    return root.themeColorFromMode(mode)
                }

                readonly property color quickshellIconActiveColor: getContrastingIconColor(activeColor, root.activeOpacity / 100)
                readonly property color quickshellIconInactiveColor: getContrastingIconColor(unfocusedColor, root.unfocusedOpacity / 100)

                // Custom: per-state text colors
                readonly property color activeTextColor: getTextColorForState("active")
                readonly property color unfocusedTextColor: getTextColorForState("unfocused")
                readonly property color occupiedTextColor: getTextColorForState("occupied")
                readonly property color urgentTextColor: getTextColorForState("urgent")

                readonly property color focusedBorderColor: {
                    switch (root.opt("workspaceFocusedBorderColor")) {
                    case "surfaceText":
                        return Theme.surfaceText;
                    case "secondary":
                        return Theme.secondary;
                    default:
                        return Theme.primary;
                    }
                }

                Item {
                    id: dragHandler
                    anchors.fill: parent
                    property bool dragging: false
                    property point dragStartPos: Qt.point(0, 0)
                    property real dragAxisOffset: 0

                    Connections {
                        target: root
                        function onWorkspaceListChanged() {
                            if (dragHandler.dragging) {
                                dragHandler.dragging = false;
                                dragHandler.dragAxisOffset = 0;
                                mouseArea.mousePressed = false;
                            }
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : (dragHandler.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor)
                    enabled: !isPlaceholder
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    property bool mousePressed: false

                    onPressed: mouse => {
                        if (mouse.button === Qt.LeftButton && CompositorService.isNiri && root.opt("workspaceDragReorder") && !isPlaceholder) {
                            mousePressed = true;
                            dragHandler.dragStartPos = Qt.point(mouse.x, mouse.y);
                        }
                    }

                    onPositionChanged: mouse => {
                        if (!mousePressed || !CompositorService.isNiri || !root.opt("workspaceDragReorder") || isPlaceholder)
                            return;

                        if (!dragHandler.dragging) {
                            const distance = root.isVertical ? Math.abs(mouse.y - dragHandler.dragStartPos.y) : Math.abs(mouse.x - dragHandler.dragStartPos.x);
                            if (distance > 5) {
                                dragHandler.dragging = true;
                                root.dragSourceIndex = index;
                                root.dragTargetIndex = index;
                            }
                        }

                        if (!dragHandler.dragging)
                            return;

                        const rawAxisOffset = root.isVertical ? (mouse.y - dragHandler.dragStartPos.y) : (mouse.x - dragHandler.dragStartPos.x);

                        const itemSize = (root.isVertical ? delegateRoot.height : delegateRoot.width) + root.wsGap;
                        const maxOffsetPositive = (root.workspaceList.length - 1 - index) * itemSize;
                        const maxOffsetNegative = -index * itemSize;
                        const axisOffset = Math.max(maxOffsetNegative, Math.min(maxOffsetPositive, rawAxisOffset));
                        dragHandler.dragAxisOffset = axisOffset;

                        const slotOffset = Math.round(axisOffset / itemSize);
                        const newTargetIndex = Math.max(0, Math.min(root.workspaceList.length - 1, index + slotOffset));

                        if (newTargetIndex !== root.dragTargetIndex) {
                            root.dragTargetIndex = newTargetIndex;
                        }
                    }

                    onReleased: mouse => {
                        const wasDragging = dragHandler.dragging;
                        const didReorder = wasDragging && root.dragTargetIndex >= 0 && root.dragTargetIndex !== root.dragSourceIndex;

                        if (didReorder) {
                            const sourceWs = root.workspaceList[root.dragSourceIndex];
                            const targetWs = root.workspaceList[root.dragTargetIndex];

                            if (sourceWs && targetWs && sourceWs.id !== undefined && targetWs.idx !== undefined) {
                                root.suppressShiftAnimation = true;
                                NiriService.moveWorkspaceToIndex(sourceWs.id, targetWs.idx);
                                Qt.callLater(() => root.suppressShiftAnimation = false);
                            }
                        }

                        mousePressed = false;
                        dragHandler.dragging = false;
                        dragHandler.dragAxisOffset = 0;
                        root.dragSourceIndex = -1;
                        root.dragTargetIndex = -1;

                        if (wasDragging || isPlaceholder)
                            return;

                        if (mouse.button === Qt.LeftButton) {
                            // Custom: an app icon under the cursor focuses that window instead of switching
                            if (delegateRoot.focusWindowAt(mouse.x, mouse.y))
                                return;
                            root.switchToWorkspaceByModelData(modelData);
                        } else if (mouse.button === Qt.RightButton) {
                            CompositorService.workspaceSecondaryAction(delegateRoot.record, root.effectiveScreenName);
                            root.toggleHyprlandOverview();
                        }
                    }
                }

                Timer {
                    id: dataUpdateTimer
                    interval: 50
                    onTriggered: {
                        if (isPlaceholder) {
                            delegateRoot.loadedWorkspaceData = null;
                            delegateRoot.loadedIcons = [];
                            delegateRoot.loadedIsUrgent = false;
                            return;
                        }

                        const wsData = delegateRoot.record;
                        delegateRoot.loadedWorkspaceData = wsData;
                        delegateRoot.loadedIsUrgent = CompositorService.loadWorkspaceUrgent(wsData);
                        delegateRoot.loadedIcons = root.opt("showWorkspaceApps") ? root.getWorkspaceIcons(wsData) : [];
                    }
                }

                function updateAllData() {
                    dataUpdateTimer.restart();
                }

                function windowIdAt(x, y) {
                    const layout = appIconsLoader.item?.iconsLayout;
                    if (!layout)
                        return null;
                    const point = layout.mapFromItem(mouseArea, x, y);
                    return layout.childAt(point.x, point.y)?.windowId ?? null;
                }

                function focusWindowAt(x, y) {
                    const winId = delegateRoot.windowIdAt(x, y);
                    if (!winId)
                        return false;
                    return CompositorService.focusWindow(winId);
                }

                width: root.isVertical ? root.widgetHeight : visualWidth
                height: root.isVertical ? visualHeight : root.widgetHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                Rectangle {
                    id: focusedBorderRing
                    x: root.isVertical ? (root.widgetHeight - width) / 2 : (parent.width - width) / 2
                    y: root.isVertical ? (parent.height - height) / 2 : (root.widgetHeight - height) / 2
                    width: {
                        const borderWidth = (root.opt("workspaceFocusedBorderEnabled") && isActive && !isPlaceholder) ? root.opt("workspaceFocusedBorderThickness") : 0;
                        return delegateRoot.visualWidth + borderWidth * 2;
                    }
                    height: {
                        const borderWidth = (root.opt("workspaceFocusedBorderEnabled") && isActive && !isPlaceholder) ? root.opt("workspaceFocusedBorderThickness") : 0;
                        return delegateRoot.visualHeight + borderWidth * 2;
                    }
                    radius: Theme.cornerRadius
                    color: "transparent"
                    border.width: (root.opt("workspaceFocusedBorderEnabled") && isActive && !isPlaceholder) ? root.opt("workspaceFocusedBorderThickness") : 0
                    border.color: (root.opt("workspaceFocusedBorderEnabled") && isActive && !isPlaceholder) ? focusedBorderColor : "transparent"

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on border.width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                Rectangle {
                    id: visualContent
                    width: delegateRoot.visualWidth
                    height: delegateRoot.visualHeight
                    x: root.isVertical ? (root.widgetHeight - width) / 2 : (parent.width - width) / 2
                    y: root.isVertical ? (parent.height - height) / 2 : (root.widgetHeight - height) / 2
                    // Custom: per-corner radius for flat outer edge
                    topLeftRadius: root.topLeftRadius
                    topRightRadius: root.topRightRadius
                    bottomLeftRadius: root.bottomLeftRadius
                    bottomRightRadius: root.bottomRightRadius
                    color: delegateRoot.displayColor
                    opacity: dragHandler.dragging ? 0.8 : 1.0

                    border.width: dragHandler.dragging ? 2 : (isUrgent ? 2 : (isDropTarget ? 2 : 0))
                    border.color: dragHandler.dragging ? Theme.primary : (isUrgent ? urgentColor : (isDropTarget ? Theme.primary : Theme.withAlpha(Theme.primary, 0)))

                    transform: Translate {
                        x: root.isVertical ? 0 : (dragHandler.dragging ? dragHandler.dragAxisOffset : 0)
                        y: root.isVertical ? (dragHandler.dragging ? dragHandler.dragAxisOffset : 0) : 0
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on border.width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Loader {
                        id: appIconsLoader
                        anchors.fill: parent
                        active: root.opt("showWorkspaceApps") || root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName") || loadedHasIcon
                        sourceComponent: Item {
                            id: contentRoot
                            readonly property real contentWidth: contentRow.item?.implicitWidth ?? 0
                            readonly property real contentHeight: contentRow.item?.implicitHeight ?? 0
                            // Custom: icons live one level deeper in the column layout, so each
                            // layout component names its own container instead of aliasing contentRow.item
                            readonly property var iconsLayout: contentRow.item?.iconsContainer ?? null

                            Loader {
                                id: contentRow
                                anchors.centerIn: parent
                                sourceComponent: root.isVertical ? columnLayout : rowLayout
                            }

                            Component {
                                id: rowLayout
                                Row {
                                    id: rowIconsRow
                                    readonly property var iconsContainer: rowIconsRow
                                    spacing: 4
                                    visible: loadedIcons.length > 0 || root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName") || loadedHasIcon

                                    Item {
                                        visible: loadedHasIcon && loadedIconData?.type === "icon"
                                        width: wsIcon.width + (isActive && loadedIcons.length > 0 ? 4 : 0)
                                        height: root.wsAppIconActive

                                        DankIcon {
                                            id: wsIcon
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: loadedIconData?.value ?? ""
                                            // Custom: use wsNameIconSize
                                            size: root.wsNameIconSize
                                            // Custom: per-state text colors
                                            color: isActive ? activeTextColor : isUrgent ? urgentTextColor : isPlaceholder ? Theme.surfaceTextAlpha : isOccupied ? occupiedTextColor : unfocusedTextColor
                                            weight: (isActive && !isPlaceholder) ? 500 : 400
                                        }
                                    }

                                    Item {
                                        visible: loadedHasIcon && loadedIconData?.type === "text"
                                        width: wsText.implicitWidth + (isActive && loadedIcons.length > 0 ? 4 : 0)
                                        height: root.wsAppIconActive

                                        StyledText {
                                            id: wsText
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: loadedIconData?.value ?? ""
                                            // Custom: per-state text colors
                                            color: isActive ? activeTextColor : isUrgent ? urgentTextColor : isPlaceholder ? Theme.surfaceTextAlpha : isOccupied ? occupiedTextColor : unfocusedTextColor
                                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    Item {
                                        visible: ((root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName")) && !loadedHasIcon) || (loadedHasIcon && root.opt("showWorkspaceName") && hasWorkspaceName)
                                        width: wsIndexText.implicitWidth + (isActive && loadedIcons.length > 0 ? 4 : 0)
                                        height: root.wsAppIconActive

                                        StyledText {
                                            id: wsIndexText
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: loadedHasIcon ? (modelData?.name ?? "") : root.getWorkspaceIndex(modelData, index)
                                            // Custom: per-state text colors
                                            color: isActive ? activeTextColor : isUrgent ? urgentTextColor : isPlaceholder ? Theme.surfaceTextAlpha : isOccupied ? occupiedTextColor : unfocusedTextColor
                                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    Repeater {
                                        model: ScriptModel {
                                            values: loadedIcons.slice(0, root.opt("maxWorkspaceIcons"))
                                        }
                                        delegate: Item {
                                            // Custom: use wsAppIconActive/wsAppIconNormal sizes
                                            width: root.wsAppIconActive
                                            height: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                            readonly property var windowId: modelData.windowId

                                            IconImage {
                                                id: rowAppIcon
                                                // Custom: dynamic icon size
                                                width: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                height: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                anchors.centerIn: parent
                                                source: modelData.icon
                                                opacity: 1.0
                                                visible: !modelData.isQuickshell && (!modelData.isSteamApp || modelData.icon)
                                            }

                                            IconImage {
                                                anchors.fill: parent
                                                source: modelData.icon
                                                opacity: 1.0
                                                visible: modelData.isQuickshell
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    saturation: 0
                                                    colorization: 1
                                                    colorizationColor: appHighlightActive ? focusedBorderColor : (isActive ? quickshellIconActiveColor : quickshellIconInactiveColor)
                                                }
                                            }

                                            IconImage {
                                                id: rowSteamIcon
                                                anchors.fill: parent
                                                source: modelData.icon
                                                opacity: 1.0
                                                visible: modelData.isSteamApp && modelData.icon
                                            }

                                            DankIcon {
                                                anchors.centerIn: parent
                                                size: root.wsAppIconNormal
                                                name: "sports_esports"
                                                color: Theme.widgetTextColor
                                                opacity: 1.0
                                                visible: modelData.isSteamApp && !modelData.icon
                                            }

                                            // Custom: fallback icon when no icon found
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                height: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                radius: 4
                                                color: Theme.secondary
                                                visible: !modelData.isSteamApp && !modelData.isQuickshell && rowAppIcon.status !== Image.Ready

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: {
                                                        const fallback = modelData.fallbackText || "";
                                                        if (!fallback) return "?";
                                                        const name = Paths.getAppName(fallback, null);
                                                        return name.charAt(0).toUpperCase();
                                                    }
                                                    font.pixelSize: modelData.active ? 14 : 10
                                                    font.weight: Font.Bold
                                                    color: Theme.widgetTextColor
                                                }
                                            }

                                            Rectangle {
                                                visible: modelData.count > 1 && !isActive
                                                width: root.appIconSize * 0.67
                                                height: root.appIconSize * 0.67
                                                radius: root.appIconSize * 0.33
                                                color: "black"
                                                border.color: "white"
                                                border.width: 1
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                z: 2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.count
                                                    font.pixelSize: root.appIconSize * 0.44
                                                    color: "white"
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Component {
                                id: columnLayout
                                Column {
                                    readonly property var iconsContainer: colIconsLayout
                                    spacing: 4
                                    visible: loadedIcons.length > 0 || root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName") || loadedHasIcon

                                    // Custom: workspace name/number and icon header
                                    Column {
                                        width: root.wsAppIconActive
                                        spacing: 0

                                        StyledText {
                                            visible: root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName")
                                            text: root.getWorkspaceIndex(modelData, index)
                                            // Custom: per-state text colors
                                            color: isActive ? activeTextColor : isUrgent ? urgentTextColor : isPlaceholder ? Theme.surfaceTextAlpha : isOccupied ? occupiedTextColor : unfocusedTextColor
                                            font.pixelSize: root.wsNameIconSize
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        DankIcon {
                                            visible: loadedHasIcon && loadedIconData?.type === "icon"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: loadedIconData?.value ?? ""
                                            // Custom: use wsNameIconSize
                                            size: root.wsNameIconSize
                                            // Custom: per-state text colors
                                            color: isActive ? activeTextColor : isUrgent ? urgentTextColor : isPlaceholder ? Theme.surfaceTextAlpha : isOccupied ? occupiedTextColor : unfocusedTextColor
                                            weight: (isActive && !isPlaceholder) ? 500 : 400
                                        }

                                        StyledText {
                                            visible: loadedHasIcon && loadedIconData?.type === "text"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: loadedIconData?.value ?? ""
                                            // Custom: per-state text colors
                                            color: isActive ? activeTextColor : isUrgent ? urgentTextColor : isPlaceholder ? Theme.surfaceTextAlpha : isOccupied ? occupiedTextColor : unfocusedTextColor
                                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    // Custom: ColumnLayout with negative margins for active icon overlap
                                    Item {
                                        width: colIconsLayout.width
                                        height: colIconsLayout.height

                                        // Custom: debug rectangle
                                        Rectangle {
                                            visible: root.debugMode
                                            anchors.fill: colIconsLayout
                                            color: "salmon"
                                        }

                                        ColumnLayout {
                                            id: colIconsLayout
                                            width: root.wsAppIconActive

                                            property int numIcons: Math.min(loadedIcons.length, root.opt("maxWorkspaceIcons"))
                                            property real activeMargin: -Math.min(root.wsAppIconGapInternal, root.wsAppIconSizeDiff / 2)
                                            property real baseHeight: numIcons * root.wsAppIconNormal + (numIcons - 1) * root.wsAppIconGapInternal
                                            property real activeNetChange: root.wsAppIconSizeDiff - 2 * Math.min(root.wsAppIconGapInternal, root.wsAppIconSizeDiff / 2)
                                            property real totalHeight: baseHeight + activeNetChange

                                            height: totalHeight
                                            spacing: root.wsAppIconGapInternal

                                            Repeater {
                                                model: ScriptModel {
                                                    values: loadedIcons.slice(0, root.opt("maxWorkspaceIcons"))
                                                }
                                                delegate: Item {
                                                    readonly property var windowId: modelData.windowId

                                                    Layout.preferredHeight: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                    Layout.preferredWidth: root.wsAppIconActive
                                                    Layout.topMargin: modelData.active ? colIconsLayout.activeMargin : 0
                                                    Layout.bottomMargin: modelData.active ? colIconsLayout.activeMargin : 0

                                                    // Custom: debug rectangle
                                                    Rectangle {
                                                        visible: root.debugMode
                                                        anchors.fill: parent
                                                        color: modelData.active ? "red" : "blue"
                                                    }

                                                    IconImage {
                                                        id: colAppIcon
                                                        width: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                        height: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                        anchors.centerIn: parent
                                                        source: modelData.icon
                                                        opacity: 1.0
                                                        visible: !modelData.isQuickshell && (!modelData.isSteamApp || modelData.icon)
                                                    }

                                                    // Custom: debug rectangle for icon bounds
                                                    Rectangle {
                                                        visible: root.debugMode
                                                        width: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                        height: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                        anchors.centerIn: parent
                                                        color: modelData.active ? "deepskyblue" : "green"
                                                    }

                                                    IconImage {
                                                        anchors.fill: parent
                                                        source: modelData.icon
                                                        opacity: 1.0
                                                        visible: modelData.isQuickshell
                                                        layer.enabled: true
                                                        layer.effect: MultiEffect {
                                                            saturation: 0
                                                            colorization: 1
                                                            colorizationColor: isActive ? quickshellIconActiveColor : quickshellIconInactiveColor
                                                        }
                                                    }

                                                    IconImage {
                                                        anchors.fill: parent
                                                        source: modelData.icon
                                                        opacity: 1.0
                                                        visible: modelData.isSteamApp && modelData.icon
                                                    }

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        size: root.wsAppIconNormal
                                                        name: "sports_esports"
                                                        color: Theme.widgetTextColor
                                                        opacity: 1.0
                                                        visible: modelData.isSteamApp && !modelData.icon
                                                    }

                                                    // Custom: fallback icon when no icon found
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                        height: modelData.active ? root.wsAppIconActive : root.wsAppIconNormal
                                                        radius: 4
                                                        color: Theme.secondary
                                                        visible: !modelData.isSteamApp && !modelData.isQuickshell && colAppIcon.status !== Image.Ready

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: {
                                                                const fallback = modelData.fallbackText || "";
                                                                if (!fallback) return "?";
                                                                const name = Paths.getAppName(fallback, null);
                                                                return name.charAt(0).toUpperCase();
                                                            }
                                                            font.pixelSize: modelData.active ? 14 : 10
                                                            font.weight: Font.Bold
                                                            color: Theme.widgetTextColor
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: modelData.count > 1 && !isActive
                                                        width: root.appIconSize * 0.67
                                                        height: root.appIconSize * 0.67
                                                        radius: root.appIconSize * 0.33
                                                        color: "black"
                                                        border.color: "white"
                                                        border.width: 1
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        z: 2

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.count
                                                            font.pixelSize: root.appIconSize * 0.44
                                                            color: "white"
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    updateAllData();
                    delegateRoot.colorAnimationReady = true;
                }

                Connections {
                    target: CompositorService
                    function onSortedToplevelsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWorkspaceStateChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                readonly property var rootCurrentWorkspace: root.currentWorkspace
                onRootCurrentWorkspaceChanged: updateAllData()
                Connections {
                    target: SettingsData
                    function onBarConfigsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWorkspaceNameIconsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onAppIdSubstitutionsChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                property var _extWindowsetsTrigger: root.useExtWorkspace ? WindowManager.windowsets : null
                on_ExtWindowsetsTriggerChanged: {
                    if (root.useExtWorkspace)
                        delegateRoot.updateAllData();
                }
            }
        }
    }

    Component.onCompleted: _updateBlurRegistration()

    property bool _blurRegistered: false
    readonly property bool _shouldBlur: BlurService.enabled && blurBarWindow && blurBarWindow.registerBlurWidget && !(barConfig?.noBackground ?? false) && root.visible && root.width > 0

    on_ShouldBlurChanged: _updateBlurRegistration()

    function _updateBlurRegistration() {
        if (_shouldBlur && !_blurRegistered) {
            blurBarWindow.registerBlurWidget(visualBackground);
            _blurRegistered = true;
        } else if (!_shouldBlur && _blurRegistered) {
            if (blurBarWindow && blurBarWindow.unregisterBlurWidget)
                blurBarWindow.unregisterBlurWidget(visualBackground);
            _blurRegistered = false;
        }
    }

    Component.onDestruction: {
        if (_blurRegistered && blurBarWindow && blurBarWindow.unregisterBlurWidget)
            blurBarWindow.unregisterBlurWidget(visualBackground);
    }
}
