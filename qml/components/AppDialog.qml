import QtQuick
import QtQuick.Controls
import Isora

Item {
    id: control
    visible: false
    implicitWidth: 480
    implicitHeight: header.implicitHeight + body.implicitHeight + padding * 2

    property string title: ""
    property bool modal: false
    property int standardButtons: Dialog.NoButton
    property int padding: 18
    property int closePolicy: Popup.CloseOnEscape
    property alias contentItem: body.data
    readonly property bool isOpen: dialogWindow.visible
    property bool wasOpened: false

    signal opened()
    signal closed()

    function open() {
        if (!dialogWindow.visible)
            dialogWindow.show()
        dialogWindow.raise()
        dialogWindow.requestActivate()
    }

    function close() {
        dialogWindow.close()
    }

    Window {
        id: dialogWindow
        transientParent: control.Window.window
        width: control.width
        height: control.height
        minimumWidth: Math.min(control.width, 320)
        minimumHeight: Math.min(control.height, 180)
        title: control.title
        color: Theme.surfaceRaised
        modality: control.modal ? Qt.WindowModal : Qt.NonModal
        flags: Qt.Window

        x: transientParent ? transientParent.x + Math.round((transientParent.width - width) / 2) : 0
        y: transientParent ? transientParent.y + Math.round((transientParent.height - height) / 2) : 0

        onVisibleChanged: {
            if (visible) {
                control.wasOpened = true
                control.opened()
            } else if (control.wasOpened) {
                control.wasOpened = false
                control.closed()
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: control.closePolicy !== Popup.NoAutoClose
            onActivated: control.close()
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceRaised
            border.color: Theme.borderStrong

            Rectangle {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                implicitHeight: 52
                height: implicitHeight
                color: Theme.surfaceRaised

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: closeButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.title
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Button {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    text: "×"
                    font.pixelSize: 22
                    onClicked: control.close()
                    contentItem: Label {
                        text: closeButton.text
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font: closeButton.font
                    }
                    background: Rectangle {
                        radius: 9
                        color: closeButton.hovered ? Theme.surfaceHover : "transparent"
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.border
                }
            }

            Item {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.margins: control.padding
                implicitHeight: childrenRect.height
            }
        }
    }
}
