import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    implicitHeight: settingsColumn.implicitHeight
    height: implicitHeight

    // Helper functions for slider components
    function saveValue(key, value) {
        saveSettings(key, value)
    }
    function loadValue(key, defaultValue) {
        return loadSettings(key, defaultValue)
    }

    Column {
        id: settingsColumn
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: "System Tray Settings"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        SteppedSliderSetting {
            settingKey: "iconSize"
            label: "Icon Size"
            minimum: 8
            maximum: 64
            stepSize: 2
            defaultValue: 18
            unit: "px"
        }

        LabeledSliderSetting {
            settingKey: "iconSpacing"
            label: "Icon Spacing"
            description: "Spacing between tray icons"
            options: [
                { label: "None", value: "0" },
                { label: "XS", value: "XS" },
                { label: "S", value: "S" },
                { label: "M", value: "M" },
                { label: "L", value: "L" },
                { label: "XL", value: "XL" }
            ]
            defaultValue: "M"
        }
    }

    function saveSettings(key, value) {
        if (pluginService) {
            pluginService.savePluginData("SortedSystemTray", key, value);
            pluginService.pluginDataChanged("SortedSystemTray");
        }
    }

    function loadSettings(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData("SortedSystemTray", key, defaultValue);
        }
        return defaultValue;
    }
}
