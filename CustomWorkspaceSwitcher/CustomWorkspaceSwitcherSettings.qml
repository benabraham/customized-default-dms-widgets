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

    ToggleSetting {
        settingKey: "flatOuterEdge"
        label: "Flat Outer Edge"
        description: "Remove rounded corners on the edge facing the screen border"
        defaultValue: false
    }

    // Active (focused) workspace colors
    SelectionSetting {
        settingKey: "activeColorMode"
        label: "Active Background"
        description: "Background color for active (focused) workspace"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Error", value: "error" },
            { label: "Surface", value: "surface" },
            { label: "Container", value: "surfaceContainer" },
            { label: "High", value: "surfaceContainerHigh" },
            { label: "Highest", value: "surfaceContainerHighest" },
            { label: "Text", value: "surfaceText" },
            { label: "TextAlpha", value: "surfaceTextAlpha" }
        ]
        defaultValue: "primary"
    }

    RealSliderSetting {
        settingKey: "activeOpacity"
        label: "Active Opacity"
        description: "Opacity of active workspace background"
        defaultValue: 100
        minimum: 0
        maximum: 100
        stepSize: 5
        decimals: 0
    }

    SelectionSetting {
        settingKey: "activeTextColorMode"
        label: "Active Text Color"
        description: "Text/icon color for active workspace"
        options: [
            { label: "Auto", value: "auto" },
            { label: "Widget Text", value: "widgetText" },
            { label: "On Surface", value: "onSurface" },
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" },
            { label: "Surface Text", value: "surfaceText" }
        ]
        defaultValue: "auto"
    }

    // Unfocused workspace colors
    SelectionSetting {
        settingKey: "unfocusedColorMode"
        label: "Unfocused Background"
        description: "Background color for unfocused workspaces"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Error", value: "error" },
            { label: "Surface", value: "surface" },
            { label: "Container", value: "surfaceContainer" },
            { label: "High", value: "surfaceContainerHigh" },
            { label: "Highest", value: "surfaceContainerHighest" },
            { label: "Text", value: "surfaceText" },
            { label: "TextAlpha", value: "surfaceTextAlpha" }
        ]
        defaultValue: "surfaceTextAlpha"
    }

    RealSliderSetting {
        settingKey: "unfocusedOpacity"
        label: "Unfocused Opacity"
        description: "Opacity of unfocused workspace background"
        defaultValue: 100
        minimum: 0
        maximum: 100
        stepSize: 5
        decimals: 0
    }

    SelectionSetting {
        settingKey: "unfocusedTextColorMode"
        label: "Unfocused Text Color"
        description: "Text/icon color for unfocused workspaces"
        options: [
            { label: "Auto", value: "auto" },
            { label: "Widget Text", value: "widgetText" },
            { label: "On Surface", value: "onSurface" },
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" },
            { label: "Surface Text", value: "surfaceText" }
        ]
        defaultValue: "auto"
    }

    // Occupied workspace colors
    SelectionSetting {
        settingKey: "occupiedColorMode"
        label: "Occupied Background"
        description: "Background color for workspaces with windows"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Error", value: "error" },
            { label: "Surface", value: "surface" },
            { label: "Container", value: "surfaceContainer" },
            { label: "High", value: "surfaceContainerHigh" },
            { label: "Highest", value: "surfaceContainerHighest" },
            { label: "Text", value: "surfaceText" },
            { label: "TextAlpha", value: "surfaceTextAlpha" }
        ]
        defaultValue: "surfaceTextAlpha"
    }

    RealSliderSetting {
        settingKey: "occupiedOpacity"
        label: "Occupied Opacity"
        description: "Opacity of occupied workspace background"
        defaultValue: 100
        minimum: 0
        maximum: 100
        stepSize: 5
        decimals: 0
    }

    SelectionSetting {
        settingKey: "occupiedTextColorMode"
        label: "Occupied Text Color"
        description: "Text/icon color for occupied workspaces"
        options: [
            { label: "Auto", value: "auto" },
            { label: "Widget Text", value: "widgetText" },
            { label: "On Surface", value: "onSurface" },
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" },
            { label: "Surface Text", value: "surfaceText" }
        ]
        defaultValue: "auto"
    }

    // Urgent workspace colors
    SelectionSetting {
        settingKey: "urgentColorMode"
        label: "Urgent Background"
        description: "Background color for urgent workspaces"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Error", value: "error" },
            { label: "Surface", value: "surface" },
            { label: "Container", value: "surfaceContainer" },
            { label: "High", value: "surfaceContainerHigh" },
            { label: "Highest", value: "surfaceContainerHighest" },
            { label: "Text", value: "surfaceText" },
            { label: "TextAlpha", value: "surfaceTextAlpha" }
        ]
        defaultValue: "error"
    }

    RealSliderSetting {
        settingKey: "urgentOpacity"
        label: "Urgent Opacity"
        description: "Opacity of urgent workspace background"
        defaultValue: 100
        minimum: 0
        maximum: 100
        stepSize: 5
        decimals: 0
    }

    SelectionSetting {
        settingKey: "urgentTextColorMode"
        label: "Urgent Text Color"
        description: "Text/icon color for urgent workspaces"
        options: [
            { label: "Auto", value: "auto" },
            { label: "Widget Text", value: "widgetText" },
            { label: "On Surface", value: "onSurface" },
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" },
            { label: "Surface Text", value: "surfaceText" }
        ]
        defaultValue: "auto"
    }
}
