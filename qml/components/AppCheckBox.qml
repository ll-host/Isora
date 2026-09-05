import QtQuick
import QtQuick.Controls
import Isora

CheckBox {
    id: control
    spacing: 10
    implicitHeight: 40
    indicator: Rectangle {
        implicitWidth: 22
        implicitHeight: 22
        y: (control.height - height) / 2
        radius: 6
        color: control.checked ? Theme.accent : Theme.surfaceRaised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accentHover : control.checked ? Theme.accent : Theme.borderStrong
        Label { anchors.centerIn: parent; visible: control.checked; text: "✓"; color: Theme.accentText; font.weight: Font.Bold }
    }
    contentItem: Label {
        text: control.text
        color: control.enabled ? Theme.text : Theme.textMuted
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
