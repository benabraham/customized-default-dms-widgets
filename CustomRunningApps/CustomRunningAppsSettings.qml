import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomRunningApps"

    StyledText {
        text: "Custom Running Apps"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Running apps widget with dynamic title width and enhanced features."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ToggleSetting {
        settingKey: "stripAppName"
        label: "Strip App Name from Title"
        description: "Remove app name, version numbers, and instance markers from window titles"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "compressionRatio"
        label: "Title Compression"
        description: "How aggressively longer titles are shortened vs shorter ones (1 = equal, higher = longer titles shrink more)"
        options: [
            {label: "None (Equal)", value: "1"},
            {label: "Light (1.5)", value: "1.5"},
            {label: "Normal (2)", value: "2"},
            {label: "Strong (3)", value: "3"},
            {label: "Heavy (5)", value: "5"},
            {label: "Extreme (10)", value: "10"}
        ]
        defaultValue: "2"
    }
}
