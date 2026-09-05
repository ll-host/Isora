import QtQuick
import QtQuick.Controls
import Isora

ToolTip {
    id: control
    delay: 450
    timeout: 4500
    padding: 9
    contentItem: Label {
        text: control.text
        color: Theme.text
        font.pixelSize: 12
    }
    background: Rectangle {
        color: Theme.surfaceRaised
        radius: Theme.radiusSmall
        border.color: Theme.borderStrong
    }
}
