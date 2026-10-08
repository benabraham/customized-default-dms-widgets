import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomNetworkMonitor"

    ToggleSetting {
        settingKey: "hideWhenIdle"
        label: "Hide When Idle"
        description: "Hide the widget while both download and upload are below 1 KB/s"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "compactMode"
        label: "Compact Mode"
        description: "Show shorter rates (e.g. 12M instead of 12 MB/s)"
        defaultValue: false
    }
}
