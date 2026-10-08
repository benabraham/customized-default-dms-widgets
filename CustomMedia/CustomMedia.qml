import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Common
import qs.Modules.DBar
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    property var surfaceContext: null
    readonly property real contentScale: surfaceContext?.kind === "dock" ? widgetThickness / 40 : 1

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool _hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(activePlayer)
    readonly property bool _isPlaying: !!activePlayer && activePlayer.playbackState === 1 && !_hoverPreview

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

    // Custom: lyrics / cover art come from plugin settings (bar entries cannot carry widget options).
    // pluginDataChanged carries only the plugin id, so reload every value when it matches.
    property bool showLyrics: PluginService.loadPluginData("CustomMedia", "showLyrics", false)
    property bool showCoverArt: PluginService.loadPluginData("CustomMedia", "showCoverArt", false)

    Connections {
        target: PluginService

        function onPluginDataChanged(pluginId) {
            if (pluginId !== "CustomMedia")
                return;
            root.showLyrics = PluginService.loadPluginData("CustomMedia", "showLyrics", false);
            root.showCoverArt = PluginService.loadPluginData("CustomMedia", "showCoverArt", false);
        }
    }

    property real allottedPrimarySize: 0
    readonly property real naturalPrimarySize: isVerticalOrientation ? height : !playerAvailable ? 0 : Theme.snap((contentItem?.naturalContentWidth ?? 0) + horizontalPadding * 2, dpr)
    readonly property real minimumPrimarySize: isVerticalOrientation ? height : !playerAvailable ? 0 : Theme.snap((contentItem?.fixedContentWidth ?? 0) + horizontalPadding * 2, dpr)
    readonly property bool lyricsEnabled: showLyrics && LyricsService.allowed
    readonly property bool coverArtEnabled: showCoverArt
    readonly property string coverArtUrl: coverArtEnabled && activePlayer && TrackArtService.artReadyFor(activePlayer) ? TrackArtService.resolvedArtUrl : ""
    readonly property bool hasCoverArt: coverArtUrl !== ""
    readonly property bool visualizerEnabled: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
    // Custom: hideIcon hides only the icon/visualizer slot; cover art still shows
    readonly property bool showIconSlot: (visualizerEnabled || !hasCoverArt) && !hideIcon
    readonly property real badgeSize: BarMetrics.mediaControlSize * contentScale
    readonly property real badgeExtent: (hasCoverArt ? badgeSize + Theme.spacingXS : 0) + (showIconSlot ? badgeSize + Theme.spacingXS : 0)
    readonly property string trackSummary: [MprisController.stableTitle, MprisController.stableArtist, MprisController.stableAlbum].filter(part => part).join(" • ")
    readonly property bool lyricActive: {
        if (!lyricsEnabled)
            return false;
        const controller = LyricsService.controller;
        if (!controller.enabled || !controller.synced)
            return false;
        const parts = controller.lines[controller.activeIndex]?.parts ?? [];
        return parts.some(part => part.x.trim() !== "");
    }

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
            return contentThickness;
        }
        return 0;
    }
    readonly property int currentContentHeight: {
        if (!isVerticalOrientation) {
            return contentThickness;
        }
        const playButtonHeight = 24 * root.contentScale;
        return badgeExtent + playButtonHeight;
    }

    property real scrollAccumulatorY: 0
    property real touchpadThreshold: 100

    LyricsSubscription {
        active: root.lyricsEnabled && root.playerAvailable
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }

    function showTrackTooltip() {
        if (!root.lyricActive || !root.parentScreen)
            return;
        tooltipLoader.active = true;
        const anchor = root.contextMenuAnchor();
        tooltipLoader.item.show(root.trackSummary, anchor.x, anchor.y, anchor.screen, anchor.isVertical && anchor.edge === "left", anchor.isVertical && anchor.edge === "right");
    }

    function hideTrackTooltip() {
        tooltipLoader.item?.hide();
        tooltipLoader.active = false;
    }

    onClicked: hideTrackTooltip()

    onWheel: function (wheelEvent) {
        const scrollMode = SettingsData.widgetOption("music", widgetData, "audioScrollMode")
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
                    MprisController.next()
                }
            } else {
                scrollAccumulatorY += deltaY
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0 && activePlayer.canGoPrevious) {
                        MprisController.previousOrRewind()
                    } else if (scrollAccumulatorY < 0 && activePlayer.canGoNext) {
                        MprisController.next()
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

    component CoverArt: ClippingRectangle {
        width: root.badgeSize
        height: root.badgeSize
        radius: Theme.cornerRadiusXS
        color: "transparent"
        visible: root.hasCoverArt

        Image {
            anchors.fill: parent
            source: root.coverArtUrl
            sourceSize: Qt.size(Math.round(width * root.dpr), Math.round(height * root.dpr))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    component MediaIcon: Item {
        width: root.badgeSize
        height: root.badgeSize
        visible: root.showIconSlot

        AudioVisualization {
            enabled: root.surfaceLive
            anchors.fill: parent
            visible: root.visualizerEnabled
        }

        DIcon {
            anchors.fill: parent
            name: "music_note"
            size: parent.width
            color: Theme.primary
            visible: !root.visualizerEnabled
        }
    }

    component PlayButton: Item {
        width: Theme.iconSize * root.contentScale
        height: width
        visible: root.playerAvailable

        DIconButton {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            buttonSize: parent.width
            iconSize: 14 * root.contentScale
            radius: pressed ? Theme.cornerRadiusXS : (checked ? Theme.cornerRadiusFull : Theme.cornerRadiusS)
            variant: "filled"
            round: false
            checkable: true
            checked: root._isPlaying
            iconFilled: false
            iconName: root._isPlaying ? "pause" : "play_arrow"
            Accessible.name: root._isPlaying ? I18n.tr("Pause") : I18n.tr("Play")
            enabled: root.activePlayer?.canTogglePlaying ?? false
            onClicked: root.activePlayer.togglePlaying()
        }
    }

    content: Component {
        Item {
            id: contentRoot

            // Natural width of the text slot. Fixed sizes use their pixel width; unlimited mode uses the
            // title's width. While a lyric line shows, the slot keeps that width (a lyric line has no
            // natural width; mediaText stays alive with the title) so the pill does not jump per line.
            readonly property real naturalTextWidth: {
                if (!root.playerAvailable || root.textWidth === 0)
                    return 0;
                return root.textWidth > 0 ? root.textWidth : mediaText.implicitTextWidth;
            }
            readonly property real fixedContentWidth: root.badgeExtent + 64 * root.contentScale + Theme.spacingXS * 2
            readonly property real textBudget: root.allottedPrimarySize > 0 ? Math.max(0, root.allottedPrimarySize - root.horizontalPadding * 2 - fixedContentWidth - Theme.spacingXS) : Infinity
            readonly property real measuredTextWidth: Math.min(naturalTextWidth, textBudget)
            readonly property real naturalContentWidth: fixedContentWidth + (naturalTextWidth > 0 ? naturalTextWidth + Theme.spacingXS : 0)

            implicitWidth: root.playerAvailable ? (root.isVerticalOrientation ? root.currentContentWidth : mediaRow.implicitWidth) : 0
            implicitHeight: root.playerAvailable ? root.currentContentHeight : 0
            opacity: root.playerAvailable ? 1 : 0

            HoverHandler {
                enabled: root.lyricActive
                onHoveredChanged: hovered ? root.showTrackTooltip() : root.hideTrackTooltip()
            }

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
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.badgeSize
                    height: badges.height
                    visible: root.badgeExtent > 0

                    Column {
                        id: badges
                        spacing: Theme.spacingXS

                        CoverArt {}

                        MediaIcon {}
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

                PlayButton {
                    anchors.horizontalCenter: parent.horizontalCenter

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                MprisController.previousOrRewind();
                                return;
                            }
                            MprisController.next();
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
                    anchors.verticalCenter: parent.verticalCenter
                    layoutDirection: root.reverseOrder ? Qt.RightToLeft : Qt.LeftToRight

                    CoverArt {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MediaIcon {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: textContainer
                        readonly property string cachedIdentity: activePlayer ? (activePlayer.identity || "") : ""
                        readonly property string lowerIdentity: cachedIdentity.toLowerCase()
                        readonly property bool isWebMedia: lowerIdentity.includes("firefox") || lowerIdentity.includes("chrome") || lowerIdentity.includes("chromium") || lowerIdentity.includes("edge") || lowerIdentity.includes("safari")

                        property string displayText: {
                            if (!activePlayer || !MprisController.stableTitle)
                                return "";
                            const title = MprisController.stableTitle;
                            const subtitle = isWebMedia ? (MprisController.stableArtist || cachedIdentity) : MprisController.stableArtist;
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: contentRoot.measuredTextWidth
                        height: root.widgetThickness
                        visible: {
                            const size = widgetData?.mediaSize !== undefined ? widgetData.mediaSize : root.pluginMediaSize;
                            return size > 0;
                        }
                        clip: textWidth > 0 || contentRoot.measuredTextWidth < contentRoot.naturalTextWidth
                        color: "transparent"

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                            }
                        }

                        ScrollingText {
                            id: mediaText
                            width: contentRoot.measuredTextWidth
                            height: parent.height
                            visible: !root.lyricActive
                            text: textContainer.displayText
                            color: root.contentColor
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            active: root.surfaceLive && root._isPlaying
                            animateTextChange: true
                        }

                        MediaLyricLine {
                            width: contentRoot.measuredTextWidth
                            height: parent.height
                            visible: root.lyricActive
                            controller: LyricsService.controller
                            color: root.contentColor
                            font.pixelSize: mediaText.font.pixelSize
                            live: root.surfaceLive
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
                        width: BarMetrics.mediaControlSize * root.contentScale
                        height: BarMetrics.mediaControlSize * root.contentScale
                        radius: Theme.cornerRadiusFull
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        visible: root.playerAvailable
                        opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                        DIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 12 * root.contentScale
                            color: root.contentColor
                        }

                        StateLayer {
                            id: prevArea
                            enabled: root.playerAvailable
                            stateColor: root.contentColor
                            onClicked: MprisController.previousOrRewind()
                        }
                    }

                    PlayButton {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: BarMetrics.mediaControlSize * root.contentScale
                        height: BarMetrics.mediaControlSize * root.contentScale
                        radius: Theme.cornerRadiusFull
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        visible: playerAvailable
                        opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                        DIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 12 * root.contentScale
                            color: root.contentColor
                        }

                        StateLayer {
                            id: nextArea
                            enabled: root.playerAvailable
                            stateColor: root.contentColor
                            onClicked: {
                                if (activePlayer) {
                                    MprisController.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
