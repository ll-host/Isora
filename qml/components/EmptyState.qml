import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora

ColumnLayout {
    id: root
    property url iconSource
    property string title: "Пока пусто"
    property string description: ""
    spacing: 10

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 56
        Layout.preferredHeight: 56
        radius: 16
        color: Theme.surfaceRaised
        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: root.iconSource
            opacity: 0.8
        }
    }
    Label {
        Layout.alignment: Qt.AlignHCenter
        text: root.title
        color: Theme.text
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }
    Label {
        Layout.maximumWidth: 430
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.description
        color: Theme.textSecondary
        font.pixelSize: 13
        lineHeight: 1.25
    }
}
