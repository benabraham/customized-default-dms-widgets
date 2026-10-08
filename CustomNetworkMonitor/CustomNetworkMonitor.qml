import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Plugins
import qs.Modules.ProcessList
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null

    // Plugin bar entries can't carry widget options, so these live in PluginService data.
    property bool hideWhenIdle: PluginService.loadPluginData("CustomNetworkMonitor", "hideWhenIdle", false)
    property bool compactMode: PluginService.loadPluginData("CustomNetworkMonitor", "compactMode", false)
    readonly property bool shouldHide: hideWhenIdle && widgetData?.enabled !== false && Math.max(DgopService.networkRxRate, DgopService.networkTxRate) < 1024
    readonly property string reserveRate: compactMode ? "888\u2007M" : "888\u2007MB/s"

    width: shouldHide ? 0 : (isVerticalOrientation ? barThickness : visualWidth)
    height: shouldHide ? 0 : (isVerticalOrientation ? visualHeight : barThickness)
    visible: !shouldHide
    opacity: shouldHide ? 0 : 1

    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    // pluginDataChanged carries only the plugin id, so reload every value.
    Connections {
        target: PluginService
        function onPluginDataChanged(pluginId) {
            if (pluginId !== "CustomNetworkMonitor")
                return;
            root.hideWhenIdle = PluginService.loadPluginData("CustomNetworkMonitor", "hideWhenIdle", false);
            root.compactMode = PluginService.loadPluginData("CustomNetworkMonitor", "compactMode", false);
        }
    }

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

    // Compact format: figure-space padded value + single unit letter (K/M/G/T)
    // 0 → "  0K", <1KB → " <1K", 12 KB/s → " 12K", 120 MB/s → "120M"
    // vertical: no padding ("0K", "1K", "12K")
    function formatNetworkSpeedCompact(bytesPerSec, vertical) {
        const units = ["K", "M", "G", "T"];
        let value = bytesPerSec / 1024;
        let unit = 0;
        while (unit < units.length - 1 && Math.round(value) >= 1000) {
            value /= 1024;
            unit++;
        }
        if (vertical)
            return (bytesPerSec > 0 ? Math.max(1, Math.round(value)) : 0) + units[unit];
        if (bytesPerSec === 0)
            return "\u2007\u20070K";
        if (bytesPerSec < 1024)
            return "\u2007<1K";
        return Math.round(value).toString().padStart(3, "\u2007") + units[unit];
    }

    function horizontalRate(rate) {
        return compactMode ? formatNetworkSpeedCompact(rate, false) : formatNetworkSpeed(rate);
    }

    function verticalRate(rate) {
        if (compactMode)
            return formatNetworkSpeedCompact(rate, true);
        if (rate < 1024)
            return rate.toFixed(0);
        if (rate < 1024 * 1024)
            return (rate / 1024).toFixed(0) + "K";
        return (rate / (1024 * 1024)).toFixed(0) + "M";
    }

    Ref {
        service: DgopService
        modules: ["network"]
        active: (root.shouldHide || (root.visible && root.enabled)) && (root.Window.window?.visible ?? false)
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.contentThickness : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : root.contentThickness

            Column {
                id: contentColumn
                anchors.centerIn: parent
                spacing: Theme.spacingXXS
                visible: root.isVerticalOrientation

                DIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.verticalRate(DgopService.networkRxRate)
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    font.features: {
                        "tnum": 1
                    }
                    color: Theme.info
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.verticalRate(DgopService.networkTxRate)
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
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

                DIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "↓"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.info
                    }

                    StyledText {
                        text: root.horizontalRate(DgopService.networkRxRate)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        font.features: {
                            "tnum": 1
                        }
                        color: root.contentColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        StyledTextMetrics {
                            id: rxBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            font.features: {
                                "tnum": 1
                            }
                            text: root.reserveRate
                        }

                        width: Math.max(rxBaseline.width, paintedWidth)
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "↑"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.error
                    }

                    StyledText {
                        text: root.horizontalRate(DgopService.networkTxRate)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        font.features: {
                            "tnum": 1
                        }
                        color: root.contentColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        StyledTextMetrics {
                            id: txBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            font.features: {
                                "tnum": 1
                            }
                            text: root.reserveRate
                        }

                        width: Math.max(txBaseline.width, paintedWidth)
                    }
                }
            }
        }
    }
}
