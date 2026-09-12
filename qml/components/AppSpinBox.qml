import QtQuick
import QtQuick.Controls
import Isora

SpinBox {
    id: control
    implicitHeight: 48
    implicitWidth: 166
    editable: true
    hoverEnabled: true
    font.pixelSize: 15
    contentItem: TextInput {
        z: 2
        text: control.displayText
        leftPadding: 48
        rightPadding: 48
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        onEditingFinished: control.value = control.valueFromText(text, control.locale)
    }
    up.indicator: Rectangle {
        x: control.width - width - 4
        y: 4
        width: 40
        height: 40
        radius: 20
        color: control.up.pressed || control.up.hovered ? Theme.surfaceHover : "transparent"
        Label { anchors.centerIn: parent; text: "+"; color: Theme.textSecondary; font.pixelSize: 18 }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    down.indicator: Rectangle {
        x: 4
        y: 4
        width: 40
        height: 40
        radius: 20
        color: control.down.pressed || control.down.hovered ? Theme.surfaceHover : "transparent"
        Label { anchors.centerIn: parent; text: "−"; color: Theme.textSecondary; font.pixelSize: 18 }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    background: Rectangle {
        radius: 24
        color: Theme.surfaceRaised
        border.width: control.activeFocus ? 2 : 0
        border.color: Theme.accent
    }
}
