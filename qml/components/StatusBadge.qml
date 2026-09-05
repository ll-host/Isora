import QtQuick
import QtQuick.Controls
import Isora

Rectangle {
    property bool good: false
    property string text: ""
    implicitWidth: label.implicitWidth + 20
    implicitHeight: 27
    radius: 9
    color: good ? Theme.successSurface : Theme.surfaceRaised
    border.color: good ? Theme.successBorder : Theme.borderStrong

    Label {
        id: label
        anchors.centerIn: parent
        text: parent.text
        color: parent.good ? Theme.success : Theme.textSecondary
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
}
