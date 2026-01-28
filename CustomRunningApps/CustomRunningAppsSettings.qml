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

    ToggleSetting {
        settingKey: "flatOuterEdge"
        label: "Flat Outer Edge"
        description: "Remove rounded corners on the edge facing the screen border"
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "focusedColorMode"
        label: "Focused Background"
        description: "Background color for focused (active) app pill"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" },
            { label: "Container", value: "surfaceContainer" },
            { label: "High", value: "surfaceContainerHigh" },
            { label: "Highest", value: "surfaceContainerHighest" },
            { label: "Text", value: "surfaceText" },
            { label: "TextAlpha", value: "surfaceTextAlpha" }
        ]
        defaultValue: "surfaceContainerHighest"
    }

    RealSliderSetting {
        settingKey: "focusedOpacity"
        label: "Focused Opacity"
        description: "Opacity of focused background (0 = transparent, 100 = opaque)"
        defaultValue: 100
        minimum: 0
        maximum: 100
        stepSize: 5
        decimals: 0
    }

    SelectionSetting {
        settingKey: "focusedTextColorMode"
        label: "Focused Text Color"
        description: "Text color for focused app pill"
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

    SelectionSetting {
        settingKey: "unfocusedColorMode"
        label: "Unfocused Background"
        description: "Background color for unfocused app pills"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" },
            { label: "Container", value: "surfaceContainer" },
            { label: "High", value: "surfaceContainerHigh" },
            { label: "Highest", value: "surfaceContainerHighest" },
            { label: "Text", value: "surfaceText" },
            { label: "TextAlpha", value: "surfaceTextAlpha" }
        ]
        defaultValue: "surfaceContainerHighest"
    }

    RealSliderSetting {
        settingKey: "unfocusedOpacity"
        label: "Unfocused Opacity"
        description: "Opacity of unfocused background (0 = transparent, 100 = opaque)"
        defaultValue: 0
        minimum: 0
        maximum: 100
        stepSize: 5
        decimals: 0
    }

    SelectionSetting {
        settingKey: "unfocusedTextColorMode"
        label: "Unfocused Text Color"
        description: "Text color for unfocused app pills"
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

    SteppedSliderSetting {
        settingKey: "titleDebounce"
        label: "Title Debounce"
        description: "Delay before updating window titles (filters flickering from terminals)"
        minimum: 0
        maximum: 2000
        stepSize: 50
        defaultValue: 300
        unit: "ms"
    }

    ToggleSetting {
        settingKey: "debugMode"
        label: "Debug Mode"
        description: "Show debug overlay and log width calculations to console"
        defaultValue: false
    }
}
