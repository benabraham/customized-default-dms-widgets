import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool _hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(activePlayer)
    readonly property bool _isPlaying: !!activePlayer && activePlayer.playbackState === 1 && !_hoverPreview

    property string _stableTitle: ""
    property string _stableArtist: ""

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() {
            root._syncMeta();
        }
        function onTrackArtistChanged() {
            root._syncMeta();
        }
    }

    onActivePlayerChanged: _syncMeta()

    function _syncMeta() {
        if (!activePlayer) {
            _stableTitle = "";
            _stableArtist = "";
            return;
        }
        if (MprisController.isFirefoxYoutubeHoverPreview(activePlayer))
            return;
        _stableTitle = activePlayer.trackTitle || "";
        _stableArtist = activePlayer.trackArtist || "";
    }

    readonly property bool __isChromeBrowser: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    property bool compactMode: false
    property var widgetData: null

    // Read mediaSize from plugin settings (default to 3 = unlimited)
    readonly property int pluginMediaSize: {
        const saved = PluginService.loadPluginData("CustomMedia", "mediaSize", "3");
        return parseInt(saved) || 3;
    }
    readonly property bool reverseOrder: PluginService.loadPluginData("CustomMedia", "reverseOrder", false)
    readonly property bool hideIcon: PluginService.loadPluginData("CustomMedia", "hideIcon", false)

    readonly property int textWidth: {
        // Use widgetData if available (per-widget), otherwise plugin setting (global)
        const size = widgetData?.mediaSize !== undefined ? widgetData.mediaSize : pluginMediaSize;
        switch (size) {
        case 0:
            return 0;
        case 2:
            return 180;
        case 3:
            return -1;  // unlimited width
        default:
            return 120;
        }
    }
    readonly property int currentContentWidth: {
        if (isVerticalOrientation) {
            return widgetThickness - horizontalPadding * 2;
        }
        return 0;
    }
    readonly property int currentContentHeight: {
        if (!isVerticalOrientation) {
            return widgetThickness - horizontalPadding * 2;
        }
        const audioVizHeight = 20;
        const playButtonHeight = 24;
        return audioVizHeight + Theme.spacingXS + playButtonHeight;
    }

    property real scrollAccumulatorY: 0
    property real touchpadThreshold: 100

    onWheel: function (wheelEvent) {
        // Support new audioScrollMode API with fallback to old audioScrollEnabled
        const scrollMode = typeof SettingsData.audioScrollMode !== "undefined" ? SettingsData.audioScrollMode : (SettingsData.audioScrollEnabled ? "volume" : "nothing")
        if (scrollMode === "nothing")
            return

        wheelEvent.accepted = true

        const deltaY = wheelEvent.angleDelta.y
        const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0

        if (scrollMode === "song") {
            // Song mode: skip tracks with scroll
            if (isMouseWheelY) {
                if (deltaY > 0 && activePlayer.canGoPrevious) {
                    MprisController.previousOrRewind()
                } else if (deltaY < 0 && activePlayer.canGoNext) {
                    activePlayer.next()
                }
            } else {
                scrollAccumulatorY += deltaY
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0 && activePlayer.canGoPrevious) {
                        MprisController.previousOrRewind()
                    } else if (scrollAccumulatorY < 0 && activePlayer.canGoNext) {
                        activePlayer.next()
                    }
                    scrollAccumulatorY = 0
                }
            }
        } else {
            // Volume mode (default): adjust player volume
            if (!usePlayerVolume)
                return

            const currentVolume = activePlayer.volume * 100

            let newVolume = currentVolume
            if (isMouseWheelY) {
                if (deltaY > 0) {
                    newVolume = Math.min(100, currentVolume + SettingsData.audioWheelScrollAmount)
                } else if (deltaY < 0) {
                    newVolume = Math.max(0, currentVolume - SettingsData.audioWheelScrollAmount)
                }
            } else {
                scrollAccumulatorY += deltaY
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0) {
                        newVolume = Math.min(100, currentVolume + 1)
                    } else {
                        newVolume = Math.max(0, currentVolume - 1)
                    }
                    scrollAccumulatorY = 0
                }
            }

            activePlayer.volume = newVolume / 100
        }
    }

    content: Component {
        Item {
            implicitWidth: root.playerAvailable ? (root.textWidth === -1 ? mediaRow.implicitWidth : root.currentContentWidth) : 0
            implicitHeight: root.playerAvailable ? root.currentContentHeight : 0
            opacity: root.playerAvailable ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Column {
                id: verticalLayout
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Item {
                    width: 20
                    height: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    AudioVisualization {
                        anchors.fill: parent
                        visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                    }

                    DankIcon {
                        anchors.fill: parent
                        name: "music_note"
                        size: 20
                        color: Theme.primary
                        visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            root.triggerRipple(this, mouse.x, mouse.y)
                        }
                        onClicked: {
                            if (root.popoutTarget && root.popoutTarget.setTriggerPosition) {
                                const globalPos = parent.mapToItem(null, 0, 0);
                                const currentScreen = root.parentScreen || Screen;
                                const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
                                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, parent.width, root.barSpacing, barPosition, root.barConfig);
                                root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
                            }
                            root.clicked();
                        }
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root._isPlaying ? Theme.primary : Theme.primaryHover
                    visible: root.playerAvailable
                    opacity: activePlayer ? 1 : 0.3

                    DankIcon {
                        anchors.centerIn: parent
                        name: root._isPlaying ? "pause" : "play_arrow"
                        size: 14
                        color: root._isPlaying ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.playerAvailable
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            if (!activePlayer)
                                return;
                            if (mouse.button === Qt.LeftButton) {
                                activePlayer.togglePlaying();
                            } else if (mouse.button === Qt.MiddleButton) {
                                MprisController.previousOrRewind();
                            } else if (mouse.button === Qt.RightButton) {
                                activePlayer.next();
                            }
                        }
                    }
                }
            }

            Row {
                id: mediaRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                layoutDirection: root.reverseOrder ? Qt.RightToLeft : Qt.LeftToRight

                Row {
                    id: mediaInfo
                    spacing: Theme.spacingXS
                    layoutDirection: root.reverseOrder ? Qt.RightToLeft : Qt.LeftToRight

                    Item {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.hideIcon

                        AudioVisualization {
                            anchors.fill: parent
                            visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                        }

                        DankIcon {
                            anchors.fill: parent
                            name: "music_note"
                            size: 20
                            color: Theme.primary
                            visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                        }
                    }

                    Rectangle {
                        id: textContainer
                        readonly property string cachedIdentity: activePlayer ? (activePlayer.identity || "") : ""
                        readonly property string lowerIdentity: cachedIdentity.toLowerCase()
                        readonly property bool isWebMedia: lowerIdentity.includes("firefox") || lowerIdentity.includes("chrome") || lowerIdentity.includes("chromium") || lowerIdentity.includes("edge") || lowerIdentity.includes("safari")

                        property string displayText: {
                            if (!activePlayer || !root._stableTitle)
                                return "";
                            const title = isWebMedia ? root._stableTitle : (root._stableTitle || "Unknown Track");
                            const subtitle = isWebMedia ? (root._stableArtist || cachedIdentity) : (root._stableArtist || "");
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: textWidth > 0 ? textWidth : mediaText.implicitWidth
                        height: root.widgetThickness
                        visible: {
                            const size = widgetData?.mediaSize !== undefined ? widgetData.mediaSize : root.pluginMediaSize;
                            return size > 0;
                        }
                        clip: textWidth > 0
                        color: "transparent"

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                            }
                        }

                        Item {
                            id: textClip
                            anchors.fill: parent
                            clip: true

                            StyledText {
                                id: mediaText
                                property bool needsScrolling: implicitWidth > textContainer.width && SettingsData.scrollTitleEnabled
                                property real scrollOffset: 0
                                property real textShift: 0

                                anchors.verticalCenter: parent.verticalCenter
                                text: textContainer.displayText
                                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                                color: Theme.widgetTextColor
                                wrapMode: Text.NoWrap
                                x: (needsScrolling ? -scrollOffset : 0) + textShift
                                opacity: 1

                                onTextChanged: {
                                    scrollOffset = 0;
                                    textShift = 0;
                                    scrollAnimation.restart();
                                    textChangeAnimation.restart();
                                }

                                SequentialAnimation {
                                    id: scrollAnimation
                                    running: mediaText.needsScrolling && textContainer.visible
                                    loops: Animation.Infinite

                                    PauseAnimation {
                                        duration: 2000
                                    }

                                    NumberAnimation {
                                        target: mediaText
                                        property: "scrollOffset"
                                        from: 0
                                        to: mediaText.implicitWidth - textContainer.width + 5
                                        duration: Math.max(1000, (mediaText.implicitWidth - textContainer.width + 5) * 60)
                                        easing.type: Easing.Linear
                                    }

                                    PauseAnimation {
                                        duration: 2000
                                    }

                                    NumberAnimation {
                                        target: mediaText
                                        property: "scrollOffset"
                                        to: 0
                                        duration: Math.max(1000, (mediaText.implicitWidth - textContainer.width + 5) * 60)
                                        easing.type: Easing.Linear
                                    }
                                }

                                SequentialAnimation {
                                    id: textChangeAnimation

                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: mediaText
                                            property: "opacity"
                                            from: 0.7
                                            to: 1
                                            duration: Theme.shortDuration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                                        }

                                        NumberAnimation {
                                            target: mediaText
                                            property: "textShift"
                                            from: 4
                                            to: 0
                                            duration: Theme.shortDuration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => {
                                root.triggerRipple(this, mouse.x, mouse.y)
                                if (root.popoutTarget && root.popoutTarget.setTriggerPosition) {
                                    const globalPos = mapToItem(null, 0, 0);
                                    const currentScreen = root.parentScreen || Screen;
                                    const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
                                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, root.width, root.barSpacing, barPosition, root.barConfig);
                                    root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
                                }
                                root.clicked();
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevArea.containsMouse ? Theme.primaryHover : "transparent"
                        visible: root.playerAvailable
                        opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 12
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MprisController.previousOrRewind()
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: root._isPlaying ? Theme.primary : Theme.primaryHover
                        visible: root.playerAvailable
                        opacity: activePlayer ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: root._isPlaying ? "pause" : "play_arrow"
                            size: 14
                            color: root._isPlaying ? Theme.background : Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer) {
                                    activePlayer.togglePlaying();
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextArea.containsMouse ? Theme.primaryHover : "transparent"
                        visible: playerAvailable
                        opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 12
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer) {
                                    activePlayer.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
