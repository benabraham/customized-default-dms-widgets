import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomFocusedApp"

    SteppedSliderSetting {
        settingKey: "appIconSize"
        label: "App Icon Size"
        minimum: 8
        maximum: 64
        stepSize: 2
        defaultValue: 28
        unit: "px"
    }

    LabeledSliderSetting {
        settingKey: "iconTitleSpacing"
        label: "Icon-Title Spacing"
        description: "Spacing between icon and title text"
        options: [
            { label: "None", value: "0" },
            { label: "XS", value: "XS" },
            { label: "S", value: "S" },
            { label: "M", value: "M" },
            { label: "L", value: "L" },
            { label: "XL", value: "XL" }
        ]
        defaultValue: "S"
    }

    ToggleSetting {
        settingKey: "stripAppName"
        label: "Strip App Name from Title"
        description: "Remove app name, version numbers, and instance markers from window titles"
        defaultValue: true
    }
}
