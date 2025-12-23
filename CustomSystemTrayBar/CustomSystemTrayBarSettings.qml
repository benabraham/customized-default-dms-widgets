import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    implicitHeight: settingsColumn.implicitHeight
    height: implicitHeight

    // Load rules from storage, sorted by order
    property var orderRules: {
        const rules = loadSettings("trayIconOrder", []);
        return rules.sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
    }
    property bool hasUnsavedChanges: false
    property bool isLoaded: false

    Component.onCompleted: {
        Qt.callLater(() => {
            isLoaded = true;
        });
    }

    Column {
        id: settingsColumn
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: "Sorted System Tray"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: "Configure regex patterns to sort tray icons. Drag to reorder. Patterns match id, title, or tooltip."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineMedium
        }

        // Current tray items preview
        Column {
            spacing: 8
            width: parent.width - 32

            StyledText {
                text: "Current Tray Items (sorted):"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: 4

                Repeater {
                    model: getSortedTrayItems()

                    Rectangle {
                        width: parent.width
                        height: itemCol.implicitHeight + 12
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)

                        Column {
                            id: itemCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            spacing: 2

                            Row {
                                spacing: 8

                                StyledText {
                                    text: "[" + modelData.order + "]"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    font.family: "monospace"
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: "id: " + modelData.id
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "monospace"
                                    color: Theme.surfaceText
                                }
                            }

                            StyledText {
                                text: "title: " + (modelData.title || "(empty)")
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: "monospace"
                                color: Theme.surfaceTextMedium
                                visible: modelData.title !== modelData.id
                            }

                            StyledText {
                                text: "tooltip: " + (modelData.tooltipTitle || "(empty)")
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: "monospace"
                                color: Theme.surfaceVariantText
                                visible: modelData.tooltipTitle && modelData.tooltipTitle !== ""
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineMedium
        }

        // Order rules section
        Column {
            spacing: 12
            width: parent.width - 32

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "Order Rules"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: hasUnsavedChanges ? "(unsaved)" : ""
                    font.pixelSize: 12
                    color: "#FFA726"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 320
                    height: 1
                }

                Rectangle {
                    width: 80
                    height: 32
                    radius: 4
                    color: addArea.containsMouse ? "#4CAF50" : "#388E3C"

                    Text {
                        anchors.centerIn: parent
                        text: "+ Add"
                        font.pixelSize: 12
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const newRules = [...orderRules];
                            newRules.push({
                                pattern: "^new-app",
                                order: 50,
                                note: ""
                            });
                            orderRules = newRules;
                            hasUnsavedChanges = true;
                        }
                    }
                }

                Rectangle {
                    width: 80
                    height: 32
                    radius: 4
                    color: !hasUnsavedChanges ? "#555" : (applyArea.containsMouse ? "#2196F3" : "#1976D2")
                    opacity: hasUnsavedChanges ? 1.0 : 0.5

                    Text {
                        anchors.centerIn: parent
                        text: "Apply"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: hasUnsavedChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (hasUnsavedChanges) {
                                saveSettings("trayIconOrder", orderRules);
                                hasUnsavedChanges = false;
                            }
                        }
                    }
                }
            }

            // Rules list
            Column {
                id: rulesColumn
                spacing: 8
                width: parent.width

                Repeater {
                    model: orderRules

                    Item {
                        id: delegateItem
                        property bool held: dragArea.pressed
                        property real originalY: y

                        width: parent.width
                        height: ruleBackground.implicitHeight + 4
                        z: held ? 2 : 1

                        Rectangle {
                            id: ruleBackground
                            width: parent.width - 4
                            implicitHeight: contentRow.implicitHeight
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: Theme.cornerRadius
                            color: delegateItem.held ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                            border.width: delegateItem.held ? 1 : 0
                            border.color: Theme.primary

                            Row {
                                id: contentRow
                                width: parent.width
                                spacing: 0

                                // Drag handle
                                Item {
                                    width: 32
                                    height: contentColumn.implicitHeight

                                    Text {
                                        anchors.centerIn: parent
                                        text: "⋮"
                                        font.pixelSize: Theme.fontSizeLarge
                                        color: Theme.outline
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.SizeVerCursor
                                        drag.target: delegateItem.held ? delegateItem : undefined
                                        drag.axis: Drag.YAxis
                                        drag.minimumY: -delegateItem.height
                                        drag.maximumY: rulesColumn.height
                                        preventStealing: true

                                        onPressed: {
                                            delegateItem.z = 2;
                                            delegateItem.originalY = delegateItem.y;
                                        }
                                        onReleased: {
                                            delegateItem.z = 1;
                                            if (drag.active) {
                                                var newIndex = Math.round(delegateItem.y / (delegateItem.height + rulesColumn.spacing));
                                                newIndex = Math.max(0, Math.min(newIndex, orderRules.length - 1));
                                                if (newIndex !== index) {
                                                    var newRules = [...orderRules];
                                                    var draggedItem = newRules.splice(index, 1)[0];
                                                    newRules.splice(newIndex, 0, draggedItem);
                                                    // Auto-assign order values based on position
                                                    for (var i = 0; i < newRules.length; i++) {
                                                        newRules[i].order = (i + 1) * 10;
                                                    }
                                                    orderRules = newRules;
                                                    hasUnsavedChanges = true;
                                                }
                                            }
                                            delegateItem.x = 0;
                                            delegateItem.y = delegateItem.originalY;
                                        }
                                    }
                                }

                                // Content
                                Column {
                                    id: contentColumn
                                    width: parent.width - 32
                                    padding: 8
                                    spacing: 8

                                    Row {
                                        width: parent.width - 16
                                        spacing: 12

                                        // Pattern input
                                        Column {
                                            spacing: Theme.spacingXS
                                            width: parent.width - 50

                                            StyledText {
                                                text: "Pattern (regex)"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            DankTextField {
                                                id: patternInput
                                                width: parent.width
                                                text: modelData.pattern || ""
                                                font.family: "monospace"
                                                placeholderText: "^app-name$"

                                                onTextEdited: {
                                                    if (isLoaded && orderRules[index]) {
                                                        orderRules[index].pattern = text;
                                                        hasUnsavedChanges = true;
                                                    }
                                                }
                                            }
                                        }

                                        // Delete button
                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: Theme.cornerRadius
                                            color: deleteArea.containsMouse ? Theme.error : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                            anchors.bottom: parent.bottom

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                font.pixelSize: Theme.fontSizeLarge
                                                color: Theme.surfaceText
                                            }

                                            MouseArea {
                                                id: deleteArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const newRules = [...orderRules];
                                                    newRules.splice(index, 1);
                                                    orderRules = newRules;
                                                    hasUnsavedChanges = true;
                                                }
                                            }
                                        }
                                    }

                                    // Note input
                                    Column {
                                        spacing: Theme.spacingXS
                                        width: parent.width - 50

                                        StyledText {
                                            text: "Note"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        DankTextField {
                                            id: noteInput
                                            width: parent.width
                                            text: modelData.note || ""
                                            placeholderText: "Description..."

                                            onTextEdited: {
                                                if (isLoaded && orderRules[index]) {
                                                    orderRules[index].note = text;
                                                    hasUnsavedChanges = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Behavior on y {
                            enabled: !dragArea.held && !dragArea.drag.active
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: orderRules.length === 0
                text: "No order rules defined. Click '+ Add' to create one."
                font.pixelSize: 12
                color: "#88FFFFFF"
                font.italic: true
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineMedium
        }

        // Help section
        Column {
            spacing: 8
            width: parent.width - 32
            bottomPadding: 24

            Text {
                text: "Pattern Examples:"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#FFFFFF"
            }

            Text {
                text: "Patterns match against: id OR title OR tooltip"
                font.pixelSize: 11
                color: "#88FFFFFF"
                font.italic: true
            }

            Column {
                spacing: 4
                leftPadding: 16

                Text {
                    text: "• ^telegram → starts with 'telegram'"
                    font.pixelSize: 12
                    color: "#CCFFFFFF"
                }

                Text {
                    text: "• discord → contains 'discord'"
                    font.pixelSize: 12
                    color: "#CCFFFFFF"
                }

                Text {
                    text: "• applet$ → ends with 'applet'"
                    font.pixelSize: 12
                    color: "#CCFFFFFF"
                }

                Text {
                    text: "• ^(slack|teams)$ → exactly 'slack' or 'teams'"
                    font.pixelSize: 12
                    color: "#CCFFFFFF"
                }
            }
        }
    }

    function saveSettings(key, value) {
        if (pluginService) {
            pluginService.savePluginData("SortedSystemTray", key, value);
            pluginService.pluginDataChanged("SortedSystemTray");
        }
    }

    function loadSettings(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData("SortedSystemTray", key, defaultValue);
        }
        return defaultValue;
    }

    // Get order value for a tray item (matches id, title, tooltipTitle)
    function getTrayItemOrder(item) {
        if (!item)
            return 50;
        const id = (item.id || "").toLowerCase();
        const title = (item.title || "").toLowerCase();
        const tooltip = (item.tooltipTitle || "").toLowerCase();

        for (const rule of orderRules) {
            try {
                const regex = new RegExp(rule.pattern, 'i');
                if (regex.test(id) || regex.test(title) || regex.test(tooltip)) {
                    return rule.order ?? 50;
                }
            } catch (e) {
                // Invalid regex, skip
            }
        }
        return 0;
    }

    // Get sorted tray items for preview
    function getSortedTrayItems() {
        const items = SystemTray.items.values.map(item => ({
                    id: item?.id || "unknown",
                    title: item?.title || "",
                    tooltipTitle: item?.tooltipTitle || "",
                    order: getTrayItemOrder(item)
                }));
        return items.sort((a, b) => a.order - b.order);
    }
}
