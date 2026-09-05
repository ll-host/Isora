import QtQuick
import QtQuick.Controls
import Isora

Switch {
    id: control
    spacing: 10
    implicitHeight: 40
    indicator: Rectangle {
        implicitWidth: 42
        implicitHeight: 24
        x: control.leftPadding
        y: (control.height - height) / 2
        radius: 12
        color: control.checked ? Theme.accent : Theme.surfaceRaised
        border.color: control.checked ? Theme.accent : Theme.borderStrong
        opacity: control.enabled ? 1 : 0.45
        Rectangle {
            x: control.checked ? parent.width - width - 4 : 4
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: control.checked ? Theme.accentText : Theme.textSecondary
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Label {
        text: control.text
        color: control.enabled ? Theme.text : Theme.textMuted
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
