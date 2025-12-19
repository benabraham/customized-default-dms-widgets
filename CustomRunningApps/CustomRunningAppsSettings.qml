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
}
