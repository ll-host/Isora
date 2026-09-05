import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora

Button {
    id: control
    property url iconSource
    property bool selected: false

    Layout.fillWidth: true
    implicitHeight: 44
    leftPadding: 13
    rightPadding: 13

    contentItem: RowLayout {
        spacing: 12
        Image {
            source: control.iconSource
            sourceSize.width: 20
            sourceSize.height: 20
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            opacity: control.selected ? 1 : 0.75
        }
        Label {
            Layout.fillWidth: true
            text: control.text
            color: control.selected ? Theme.text : Theme.textSecondary
            font.pixelSize: 13
            font.weight: control.selected ? Font.DemiBold : Font.Normal
        }
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: control.selected ? Theme.accentSubtle : (control.hovered ? Theme.surfaceHover : "transparent")
        border.color: control.activeFocus ? Theme.accent : control.selected ? Theme.accentBorder : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
