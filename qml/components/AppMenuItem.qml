import QtQuick
import QtQuick.Controls
import Isora

MenuItem {
    id: control
    implicitHeight: visible ? 38 : 0
    height: implicitHeight
    leftPadding: 12
    rightPadding: 12
    contentItem: Label {
        text: control.text
        color: control.enabled ? (control.highlighted ? Theme.text : Theme.textSecondary) : Theme.textMuted
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.highlighted ? Theme.surfaceHover : "transparent"
    }
}
