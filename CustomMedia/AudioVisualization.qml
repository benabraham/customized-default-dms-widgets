import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasActiveMedia: activePlayer !== null
    readonly property bool isPlaying: hasActiveMedia && activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool live: visible && (Window.window?.visible ?? false) && isPlaying

    width: 20
    height: Theme.iconSize

    Loader {
        active: root.live

        sourceComponent: Component {
            Ref {
                service: CavaService
            }
        }
    }

    readonly property real maxBarHeight: Theme.iconSize - 2
    readonly property real minBarHeight: 3
    readonly property real heightRange: maxBarHeight - minBarHeight
    property var barHeights: [minBarHeight, minBarHeight, minBarHeight, minBarHeight, minBarHeight, minBarHeight]

    Timer {
        id: fallbackTimer

        running: !CavaService.cavaAvailable && root.live
        interval: 500
        repeat: true
        onTriggered: {
            CavaService.values = [Math.random() * 20 + 5, Math.random() * 25 + 8, Math.random() * 22 + 6, Math.random() * 20 + 5, Math.random() * 22 + 6, Math.random() * 25 + 8];
        }
    }

    Connections {
        target: CavaService
        enabled: root.live
        // Levels are quantized to 1/32 and identical frames dropped — cava ticks far faster than
        // the bars visibly change, and every assignment forces a surface commit (#2863).
        function onValuesChanged() {
            const newHeights = [];
            let changed = false;
            for (let i = 0; i < 6; i++) {
                const rawLevel = CavaService.values.length > i ? CavaService.values[i] : 0;
                const level = rawLevel <= 0 ? 0 : rawLevel >= 100 ? 1 : Math.sqrt(rawLevel * 0.01);
                const height = root.minBarHeight + Math.round(level * 32) / 32 * root.heightRange;
                if (height !== root.barHeights[i])
                    changed = true;
                newHeights.push(height);
            }
            if (!changed)
                return;
            root.barHeights = newHeights;
        }
    }

    onLiveChanged: {
        if (!live)
            barHeights = [minBarHeight, minBarHeight, minBarHeight, minBarHeight, minBarHeight, minBarHeight];
    }

    Row {
        anchors.centerIn: parent
        spacing: 1.5

        Repeater {
            model: 6

            Rectangle {
                width: 2
                height: root.barHeights[index]
                radius: 1.5
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: root.isPlaying && !CavaService.cavaAvailable
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }
}
