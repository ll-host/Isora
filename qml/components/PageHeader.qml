import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora

RowLayout {
    id: root
    property string title
    property string description
    default property alias actions: actionSlot.data
    Layout.fillWidth: true
    spacing: 16
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Label { text: root.title; color: Theme.text; font.pixelSize: 28; font.weight: Font.Bold }
        Label { visible: root.description.length > 0; text: root.description; color: Theme.textSecondary; font.pixelSize: 13 }
    }
    RowLayout { id: actionSlot; spacing: 8 }
}
