import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    property var selectedMachine: null
    property string testDialogName: ""
    signal openMachine(string machineId)
    signal openImport()
    signal openBackups()

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 56
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: Math.min(1020, parent.width - 56)
            x: Math.max(28, (parent.width - width) / 2)
            y: 28
            spacing: 26

            SectionHeader { title: "Виртуальные диски"; actionText: "Подключить диск"; onTriggered: root.openImport() }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(76, Math.min(230, contentHeight))
                model: App.machines
                spacing: 0
                interactive: contentHeight > height
                clip: true
                delegate: StorageRow {
                    required property var modelData
                    title: modelData.name + ".qcow2"
                    detail: modelData.diskGiB + " ГиБ · " + (modelData.running ? "используется" : "подключён")
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                    actionText: "К машине"
                    onTriggered: root.openMachine(modelData.id)
                }
                EmptyState { anchors.centerIn: parent; visible: parent.count === 0; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"; title: "Дисков пока нет"; description: "" }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
            SectionHeader { title: "ISO-образы"; actionText: "Добавить ISO"; onTriggered: images.openPicker() }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                spacing: 24
                ImagesPage {
                    id: images
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    compact: true
                    embedded: true
                    testDialogName: root.testDialogName
                }
                ColumnLayout {
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true
                    spacing: 12
                    Surface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surfaceHover
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                radius: 16
                                color: Theme.accentSubtle
                                Image { anchors.centerIn: parent; width: 24; height: 24; source: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg" }
                            }
                            Label { text: "Резервные копии"; color: Theme.text; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Label { Layout.fillWidth: true; text: root.selectedMachine ? root.selectedMachine.name : "Выберите машину"; color: Theme.textSecondary; font.pixelSize: 12; elide: Text.ElideRight }
                            Item { Layout.fillHeight: true }
                            ActionButton { Layout.fillWidth: true; text: "Создать копию"; enabled: root.selectedMachine !== null && !root.selectedMachine.running; onClicked: root.openBackups() }
                        }
                    }
                }
            }
        }
    }

    component SectionHeader: RowLayout {
        id: section
        property string title
        property string actionText
        property bool actionEnabled: true
        signal triggered()
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: section.title; color: Theme.text; font.pixelSize: 20; font.weight: Font.DemiBold }
        ActionButton { text: section.actionText; enabled: section.actionEnabled; onClicked: section.triggered() }
    }

    component StorageRow: Rectangle {
        id: row
        property string title
        property string detail
        property url iconSource
        property string actionText
        signal triggered()
        width: ListView.view.width
        height: 72
        color: "transparent"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 14
            Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: row.iconSource }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label {
                    Layout.fillWidth: true
                    text: row.title
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: row.detail
                    color: Theme.textMuted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
            ActionButton { text: row.actionText; onClicked: row.triggered() }
        }
    }
}
