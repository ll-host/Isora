import QtQuick
import QtQuick.Controls
import Isora

SpinBox {
    id: control
    implicitHeight: Theme.controlHeight
    implicitWidth: 132
    editable: true
    font.pixelSize: 13
    contentItem: TextInput {
        z: 2
        text: control.displayText
        leftPadding: 12
        rightPadding: 72
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        onEditingFinished: control.value = control.valueFromText(text, control.locale)
    }
    up.indicator: Rectangle {
        x: control.width - width
        width: 36
        height: control.height
        radius: Theme.radiusControl
        color: control.up.pressed || control.up.hovered ? Theme.surfaceHover : "transparent"
        Label { anchors.centerIn: parent; text: "+"; color: Theme.textSecondary; font.pixelSize: 18 }
    }
    down.indicator: Rectangle {
        x: control.width - 72
        width: 36
        height: control.height
        radius: Theme.radiusControl
        color: control.down.pressed || control.down.hovered ? Theme.surfaceHover : "transparent"
        Label { anchors.centerIn: parent; text: "−"; color: Theme.textSecondary; font.pixelSize: 18 }
    }
    background: Rectangle {
        radius: Theme.radiusControl
        color: Theme.surfaceRaised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 36; width: 1; height: parent.height; color: Theme.border }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 72; width: 1; height: parent.height; color: Theme.border }
    }
}
