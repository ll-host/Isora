import QtQuick
import QtQuick.Controls
import Isora

ProgressBar {
    id: control
    implicitHeight: 6
    background: Rectangle { radius: 3; color: Theme.border }
    contentItem: Item {
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, (control.value - control.from) / (control.to - control.from)))
            height: parent.height
            radius: 3
            color: Theme.accent
        }
    }
}
