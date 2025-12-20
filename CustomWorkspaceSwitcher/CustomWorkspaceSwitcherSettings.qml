import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomWorkspaceSwitcher"

    StyledText {
        text: "Custom Workspace Switcher"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Workspace switcher with configurable app icon sizes for vertical bar layout."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent.width
    }

    SliderSetting {
        settingKey: "wsAppIconNormal"
        label: "Normal Icon Size"
        description: "Size of inactive/unfocused app icons in pixels"
        minimum: 8
        maximum: 64
        defaultValue: 24
        unit: "px"
    }

    SliderSetting {
        settingKey: "wsAppIconActive"
        label: "Active Icon Size"
        description: "Size of focused app icon in pixels"
        minimum: 8
        maximum: 64
        defaultValue: 36
        unit: "px"
    }

    SliderSetting {
        settingKey: "wsNameIconSize"
        label: "Workspace Name Icon Size"
        description: "Size of workspace name indicator icons in pixels"
        minimum: 8
        maximum: 64
        defaultValue: 24
        unit: "px"
    }

    SliderSetting {
        settingKey: "wsAppIconGap"
        label: "Icon Gap"
        description: "Minimum spacing between app icons in pixels"
        minimum: 0
        maximum: 32
        defaultValue: 1
        unit: "px"
    }
}
