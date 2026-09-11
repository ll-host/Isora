import QtQuick
import QtQuick.Controls
import Isora

TextField {
    id: control
    implicitHeight: Theme.controlHeight
    leftPadding: 13
    rightPadding: 13
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText
    font.pixelSize: 13
    background: Rectangle {
        radius: 16
        color: Theme.surfaceRaised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border
        opacity: control.enabled ? 1 : 0.5
    }
}
