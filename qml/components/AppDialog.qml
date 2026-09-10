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
    readonly property bool isOpen: dialogPopup.opened

    signal opened()
    signal closed()

    function open() {
        dialogPopup.open()
    }

    function close() {
        dialogPopup.close()
    }

    Popup {
        id: dialogPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: control.width
        height: control.height
        padding: 0
        modal: control.modal
        focus: true
        closePolicy: control.closePolicy
        onOpened: control.opened()
        onClosed: control.closed()
        Overlay.modal: Rectangle {
            color: "#99000000"
        }

        background: Rectangle {
            color: Theme.surfaceRaised
            radius: Theme.radiusCard
            border.color: Theme.borderStrong
            border.width: 1
        }

        contentItem: Item {
            Rectangle {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                implicitHeight: 52
                height: implicitHeight
                color: "transparent"

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
                        radius: Theme.radiusSmall
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
