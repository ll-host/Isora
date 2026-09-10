import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    property bool compact: false
    property var selectedImage: null
    property string testDialogName: ""
    property bool confirmingRemoval: false

    Component.onCompleted: Qt.callLater(root.openTestDialogIfReady)
    Connections {
        target: App
        function onImagesChanged() { root.openTestDialogIfReady() }
    }

    FileDialog {
        id: isoDialog
        title: "Выберите ISO-файл"
        nameFilters: ["ISO-файлы (*.iso)"]
        onAccepted: App.importIso(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: root.compact ? 24 : 0
        spacing: 15

        PageHeader {
            visible: !root.compact
            Layout.fillWidth: true
            title: "ISO-образы"
            description: "Установочные образы в локальном хранилище Isora"
        }

        Surface {
            Layout.fillWidth: true
            implicitHeight: 112
            visible: root.confirmingRemoval && root.selectedImage !== null
            color: Theme.dangerSurface
            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: "Удалить ISO-образ?"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Label { Layout.fillWidth: true; text: root.selectedImage ? "Файл «" + root.selectedImage.name + "» будет удалён из хранилища. Машины останутся на месте." : ""; color: Theme.textSecondary; font.pixelSize: 11; wrapMode: Text.WordWrap }
                }
                ActionButton { text: "Отмена"; onClicked: root.confirmingRemoval = false }
                ActionButton { text: "Удалить"; danger: true; enabled: !App.busy; onClicked: { App.removeIso(root.selectedImage.id); root.confirmingRemoval = false } }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 136
            enabled: !App.busy
            onClicked: isoDialog.open()
            contentItem: ColumnLayout {
                spacing: 8
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 10
                    color: Theme.accentSubtle
                    Label { anchors.centerIn: parent; text: "+"; color: Theme.accent; font.pixelSize: 24 }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Добавить ISO-образ"
                    color: Theme.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Выберите файл с диска"
                    color: Theme.textMuted
                    font.pixelSize: 9
                }
            }
            background: Rectangle {
                radius: 12
                color: parent.hovered ? Theme.surfaceHover : Theme.surface
                border.width: 1
                border.color: parent.hovered ? Theme.accent : Theme.borderStrong
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: App.images
            spacing: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 72
                color: "transparent"
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 4
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 11
                        color: Theme.accentSubtle
                        Image {
                            anchors.centerIn: parent
                            width: 21
                            height: 21
                            source: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.text
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.sizeText + " · добавлен " + root.formatDate(modelData.addedAt)
                            color: Theme.textMuted
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                    Label {
                        visible: root.width > 560
                        text: "SHA-256  " + modelData.sha256.substring(0, 12) + "…"
                        color: Theme.textMuted
                        font.pixelSize: 9
                    }
                    ActionButton { text: "Удалить"; danger: true; enabled: !App.busy; onClicked: { root.selectedImage = modelData; root.confirmingRemoval = true } }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: App.images.length === 0
                iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                title: "ISO пока не добавлены"
                description: "Добавленный образ копируется в хранилище Isora."
            }
        }
    }

    function formatDate(value) {
        const date = new Date(value)
        return isNaN(date.getTime()) ? "—" : date.toLocaleDateString(Qt.locale("ru_RU"), Locale.ShortFormat)
    }

    function openTestDialogIfReady() {
        if (root.testDialogName === "delete-image" && App.images.length > 0) {
            root.selectedImage = App.images[0]
            root.confirmingRemoval = true
        }
    }
}
