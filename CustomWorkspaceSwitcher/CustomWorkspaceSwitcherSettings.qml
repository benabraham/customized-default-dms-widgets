import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomWorkspaceSwitcher"

    // Compute dynamic gap minimum from sibling slider values
    property real sizeDiff: Math.abs(activeSlider.value - normalSlider.value)

    SteppedSliderSetting {
        id: normalSlider
        settingKey: "wsAppIconNormal"
        label: "Normal App Icon Size"
        minimum: 8
        maximum: 64
        stepSize: 2
        defaultValue: 24
        unit: "px"
    }

    SteppedSliderSetting {
        id: activeSlider
        settingKey: "wsAppIconActive"
        label: "Active (Focused App) Icon Size"
        minimum: 8
        maximum: 64
        stepSize: 2
        defaultValue: 36
        unit: "px"
    }

    SteppedSliderSetting {
        settingKey: "wsNameIconSize"
        label: "Workspace Name Icon Size"
        minimum: 8
        maximum: 64
        stepSize: 2
        defaultValue: 24
        unit: "px"
    }

    SteppedSliderSetting {
        id: gapSlider
        settingKey: "wsAppIconGap"
        label: "Icon Gap"
        description: "Spacing between icons (negative will make them move a bit when changing workspaces)"
        minimum: Math.round(-root.sizeDiff / 2)
        maximum: 12
        stepSize: 1
        defaultValue: 0
        unit: "px"
    }

    LabeledSliderSetting {
        settingKey: "wsGapPreset"
        label: "Workspace Gap"
        description: "Spacing between workspace indicators"
        options: [
            {
                label: "None",
                value: "0"
            },
            {
                label: "XS",
                value: "XS"
            },
            {
                label: "S",
                value: "S"
            },
            {
                label: "M",
                value: "M"
            },
            {
                label: "L",
                value: "L"
            },
            {
                label: "XL",
                value: "XL"
            }
        ]
        defaultValue: "XL"
    }

    ToggleSetting {
        settingKey: "debugMode"
        label: "Debug Mode"
        description: "Show colored rectangles to visualize icon wrapper and bounds"
        defaultValue: false
    }
}
