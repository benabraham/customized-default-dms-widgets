import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomRunningApps"

    SteppedSliderSetting {
        settingKey: "appIconSize"
        label: "App Icon Size"
        minimum: 8
        maximum: 64
        stepSize: 2
        defaultValue: 24
        unit: "px"
    }

    LabeledSliderSetting {
        settingKey: "pillSpacing"
        label: "Pill Spacing"
        description: "Spacing between app pills"
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

    LabeledSliderSetting {
        settingKey: "widgetPadding"
        label: "Pill Padding"
        description: "Left and right padding inside each pill"
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

    ToggleSetting {
        settingKey: "showStackingTabbing"
        label: "Show Stacking and Tabbing"
        description: "Show visual frame around windows in the same Niri column (stacked/tabbed)"
        defaultValue: true
    }

    RealSliderSetting {
        settingKey: "compressionBias"
        label: "Compression Bias"
        description: "Negative = favor larger titles, 0 = equal shrinking, Positive = favor smaller titles"
        defaultValue: 0
        minimum: -50
        maximum: 50
        stepSize: 1
        decimals: 0
    }

    ToggleSetting {
        settingKey: "debugMode"
        label: "Debug Mode"
        description: "Show debug overlay and log width calculations to console"
        defaultValue: false
    }
}
