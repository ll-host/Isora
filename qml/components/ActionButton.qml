import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora

Button {
    id: control
    property bool accent: false
    property bool danger: false
    property url iconSource
    property string iconText: ""
    readonly property color foregroundColor: danger ? Theme.dangerText : (accent ? Theme.accentText : Theme.text)

    implicitHeight: Theme.controlHeight
    implicitWidth: contentRow.implicitWidth + 30
    leftPadding: 15
    rightPadding: 15
    font.pixelSize: 13
    font.weight: Font.DemiBold

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8
            Label {
                visible: control.iconText.length > 0
                text: control.iconText
                color: control.foregroundColor
                font.pixelSize: 20
                font.weight: Font.Normal
                Layout.preferredWidth: visible ? implicitWidth : 0
            }
            Image {
                visible: control.iconText.length === 0 && control.iconSource.toString().length > 0
                source: control.iconSource
                sourceSize.width: 18
                sourceSize.height: 18
                Layout.preferredWidth: visible ? 18 : 0
                Layout.preferredHeight: 18
            }
            Label {
                text: control.text
                color: control.foregroundColor
                font: control.font
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: control.down ? (control.accent ? Theme.accent : Theme.surfaceHover)
                            : control.danger ? (control.hovered ? Theme.dangerHover : Theme.dangerSurface)
                            : control.accent ? (control.hovered ? Theme.accentHover : Theme.accent)
                            : (control.hovered ? Theme.surfaceHover : Theme.surfaceRaised)
        border.width: control.activeFocus ? 2 : (control.accent ? 0 : 1)
        border.color: control.activeFocus ? Theme.accentHover : control.accent ? "transparent" : (control.danger ? Theme.dangerBorder : Theme.border)
        opacity: control.enabled ? 1 : 0.42
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
