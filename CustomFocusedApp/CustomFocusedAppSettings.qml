import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomFocusedApp"

    StyledText {
        text: "Custom Focused App"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Focused window widget with icon display and smart title handling."
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
