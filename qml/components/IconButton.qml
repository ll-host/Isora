import QtQuick
import QtQuick.Controls
import Isora

Button {
    id: control
    property url iconSource
    implicitWidth: 40
    implicitHeight: 40
    padding: 10
    Accessible.name: text
    AppToolTip { visible: control.hovered && control.text.length > 0; text: control.text }
    contentItem: Image {
        source: control.iconSource
        sourceSize.width: 20
        sourceSize.height: 20
        opacity: control.enabled ? 1 : 0.42
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.down ? Theme.surfaceRaised : control.hovered ? Theme.surfaceHover : "transparent"
        border.color: control.activeFocus ? Theme.accent : "transparent"
    }
}
