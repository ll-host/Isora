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
            ImagesPage {
                id: images
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                compact: true
                embedded: true
                testDialogName: root.testDialogName
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
            SectionHeader {
                title: root.selectedMachine ? "Резервные копии · " + root.selectedMachine.name : "Резервные копии"
                actionText: "Открыть"
                actionEnabled: root.selectedMachine !== null && !root.selectedMachine.running
                onTriggered: root.openBackups()
            }
            Surface {
                Layout.fillWidth: true
                implicitHeight: 90
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 17
                    spacing: 14
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 14
                        color: Theme.accentSubtle
                        Image { anchors.centerIn: parent; width: 23; height: 23; source: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: root.selectedMachine ? "Копии системного диска" : "Выберите машину"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Label { Layout.fillWidth: true; text: App.backupDirectory; color: Theme.textMuted; font.pixelSize: 10; elide: Text.ElideMiddle }
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
            ColumnLayout { Layout.fillWidth: true; spacing: 3; Label { Layout.fillWidth: true; text: row.title; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }; Label { Layout.fillWidth: true; text: row.detail; color: Theme.textMuted; font.pixelSize: 10; elide: Text.ElideRight } }
            ActionButton { text: row.actionText; onClicked: row.triggered() }
        }
    }
}
