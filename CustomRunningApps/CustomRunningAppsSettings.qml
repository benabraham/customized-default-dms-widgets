import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomRunningApps"

    ToggleSetting {
        settingKey: "stripAppName"
        label: "Strip App Name from Title"
        description: "Remove app name, version numbers, and instance markers from window titles"
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
