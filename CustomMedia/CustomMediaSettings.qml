import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "CustomMedia"

    StyledText {
        text: "Custom Media Controls"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Media player widget with unlimited width option. Size 3 = unlimited (shows full track title)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent.width
    }

    SelectionSetting {
        settingKey: "mediaSize"
        label: "Widget Size"
        description: "Controls how much track info is displayed"
        options: [
            {label: "Icon Only", value: "0"},
            {label: "Small (120px)", value: "1"},
            {label: "Large (180px)", value: "2"},
            {label: "Unlimited", value: "3"}
        ]
        defaultValue: "3"
    }

    ToggleSetting {
        settingKey: "reverseOrder"
        label: "Reverse Layout"
        description: "Show controls before title (controls → title → icon)"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "hideIcon"
        label: "Hide Icon"
        description: "Hide the music/visualizer icon"
        defaultValue: false
    }

    StyledText {
        text: "Note: After changing settings, you may need to re-add the widget to the bar for changes to take effect."
        font.pixelSize: Theme.fontSizeSmall
        font.italic: true
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent.width
    }
}
