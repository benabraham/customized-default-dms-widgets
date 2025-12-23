import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Plugins
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

BasePill {
    id: root

    // Fixed-width format: 0 → "0 KB/s", <1KB → "<1 KB/s", else normal
    function formatNetworkSpeed(bytesPerSec) {
        if (bytesPerSec === 0) {
            return "\u2007\u20070\u2007KB/s";  // "  0 KB/s"
        }
        if (bytesPerSec < 1024) {
            return "\u2007<1\u2007KB/s";
        }
        let value, unit;
        if (bytesPerSec < 1024 * 1024) {
            value = bytesPerSec / 1024;
            unit = "\u2007KB/s";
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            value = bytesPerSec / (1024 * 1024);
            unit = "\u2007MB/s";
        } else {
            value = bytesPerSec / (1024 * 1024 * 1024);
            unit = "\u2007GB/s";
        }
        return Math.round(value).toString().padStart(3, "\u2007") + unit;
    }

    Component.onCompleted: {
        DgopService.addRef(["network"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["network"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: contentColumn
                anchors.centerIn: parent
                spacing: 2
                visible: root.isVerticalOrientation

                DankIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const rate = DgopService.networkRxRate;
                        if (rate < 1024)
                            return rate.toFixed(0);
                        if (rate < 1024 * 1024)
                            return (rate / 1024).toFixed(0) + "K";
                        return (rate / (1024 * 1024)).toFixed(0) + "M";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    font.features: {
                        "tnum": 1
                    }
                    color: Theme.info
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const rate = DgopService.networkTxRate;
                        if (rate < 1024)
                            return rate.toFixed(0);
                        if (rate < 1024 * 1024)
                            return (rate / 1024).toFixed(0) + "K";
                        return (rate / (1024 * 1024)).toFixed(0) + "M";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    font.features: {
                        "tnum": 1
                    }
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !root.isVerticalOrientation

                DankIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    StyledText {
                        text: "↓"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.info
                    }

                    StyledText {
                        text: root.formatNetworkSpeed(DgopService.networkRxRate)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        StyledTextMetrics {
                            id: rxBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                            font.features: {
                                "tnum": 1
                            }
                            text: "888\u2007MB/s"
                        }

                        width: Math.max(rxBaseline.width, paintedWidth)

                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    StyledText {
                        text: "↑"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.error
                    }

                    StyledText {
                        text: root.formatNetworkSpeed(DgopService.networkTxRate)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        StyledTextMetrics {
                            id: txBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                            font.features: {
                                "tnum": 1
                            }
                            text: "888\u2007MB/s"
                        }

                        width: Math.max(txBaseline.width, paintedWidth)

                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
