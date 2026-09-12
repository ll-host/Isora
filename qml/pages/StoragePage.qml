import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    property var selectedMachine: null
    property var pendingRemovalImage: null
    property string testDialogName: ""
    property bool wideLayout: width >= 980
    signal openMachine(string machineId)
    signal openImport()
    signal openBackups()

    Component.onCompleted: Qt.callLater(root.loadBackups)
    onSelectedMachineChanged: Qt.callLater(root.loadBackups)

    FileDialog {
        id: isoDialog
        title: "Выберите ISO-файл"
        nameFilters: ["ISO-файлы (*.iso)"]
        onAccepted: App.importIso(selectedFile)
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + 56
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            width: Math.min(1180, parent.width - 92)
            x: 46
            y: 55
            spacing: 0

            SectionHeader {
                title: "Виртуальные диски"
                actionText: "Создать диск"
                accent: true
                onTriggered: root.openImport()
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: App.machines.length > 0 ? App.machines.length * 102 + Math.max(0, App.machines.length - 1) * 4 : 102
                model: App.machines
                spacing: 4
                interactive: false
                clip: true
                delegate: StorageRow {
                    required property var modelData
                    required property int index
                    title: modelData.name + ".qcow2"
                    detail: modelData.diskGiB + " ГБ"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                    first: index === 0
                    last: index === App.machines.length - 1
                    menuText: "Открыть машину"
                    onTriggered: root.openMachine(modelData.id)
                }
                EmptyState {
                    anchors.centerIn: parent
                    visible: App.machines.length === 0
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                    title: "Дисков пока нет"
                    description: ""
                }
            }

            SectionHeader {
                Layout.topMargin: 44
                title: "ISO-образы"
                actionText: "Добавить ISO"
                onTriggered: isoDialog.open()
            }

            Rectangle {
                Layout.topMargin: visible ? 12 : 0
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 72 : 0
                visible: root.pendingRemovalImage !== null
                radius: 20
                color: Theme.dangerSurface
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 10
                    spacing: 10
                    Label {
                        Layout.fillWidth: true
                        text: root.pendingRemovalImage ? "Удалить «" + (root.pendingRemovalImage.fileName || root.pendingRemovalImage.name) + "»?" : ""
                        color: Theme.dangerText
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    ActionButton { text: "Отмена"; onClicked: root.pendingRemovalImage = null }
                    ActionButton {
                        text: "Удалить"
                        danger: true
                        enabled: !App.busy
                        onClicked: {
                            App.removeIso(root.pendingRemovalImage.id)
                            root.pendingRemovalImage = null
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.wideLayout ? 294 : Math.max(102, App.images.length * 102 + Math.max(0, App.images.length - 1) * 4) + 318
                columns: root.wideLayout ? 2 : 1
                columnSpacing: 40
                rowSpacing: 24

                ListView {
                    id: isoList
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.wideLayout ? 294 : Math.max(102, App.images.length * 102 + Math.max(0, App.images.length - 1) * 4)
                    model: App.images
                    spacing: 4
                    interactive: false
                    clip: true
                    delegate: StorageRow {
                        required property var modelData
                        required property int index
                        title: modelData.fileName || modelData.name
                        detail: root.cleanSize(modelData.sizeText)
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                        first: index === 0
                        last: index === App.images.length - 1
                        menuText: "Удалить"
                        onTriggered: root.pendingRemovalImage = modelData
                    }
                    EmptyState {
                        anchors.centerIn: parent
                        visible: App.images.length === 0
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                        title: "ISO пока не добавлены"
                        description: ""
                    }
                }

                ColumnLayout {
                    id: backupColumn
                    Layout.preferredWidth: root.wideLayout ? 336 : -1
                    Layout.fillWidth: !root.wideLayout
                    Layout.preferredHeight: 294
                    Layout.alignment: Qt.AlignTop
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 210
                        topLeftRadius: 28
                        topRightRadius: 28
                        bottomLeftRadius: 8
                        bottomRightRadius: 8
                        color: Theme.surfaceHover
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28
                            spacing: 9
                            Label { text: "Резервные копии"; color: Theme.text; font.pixelSize: 20; font.weight: Font.DemiBold }
                            Label { text: root.backupSummary(); color: Theme.textSecondary; font.pixelSize: 16 }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        enabled: root.selectedMachine !== null && !root.selectedMachine.running && !App.busy
                        onClicked: root.openBackups()
                        leftInset: 0
                        rightInset: 0
                        topInset: 0
                        bottomInset: 0
                        contentItem: RowLayout {
                            spacing: 12
                            Item { Layout.fillWidth: true }
                            Image { Layout.preferredWidth: 26; Layout.preferredHeight: 26; source: "qrc:/qt/qml/Isora/qml/assets/icons/cloud-upload.svg" }
                            Label { text: "Создать копию"; color: Theme.secondaryContainerText; font.pixelSize: 19; font.weight: Font.Medium }
                            Item { Layout.fillWidth: true }
                        }
                        background: Rectangle {
                            topLeftRadius: 8
                            topRightRadius: 8
                            bottomLeftRadius: 28
                            bottomRightRadius: 28
                            color: parent.down ? Theme.surfaceHover : (parent.hovered ? Theme.secondaryContainer : "#46564B")
                            opacity: parent.enabled ? 1 : 0.42
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
        property bool accent: false
        signal triggered()
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        Label {
            Layout.fillWidth: true
            text: section.title
            color: Theme.text
            font.pixelSize: 30
            font.weight: Font.Bold
        }
        ActionButton {
            Layout.preferredWidth: 260
            Layout.preferredHeight: 80
            text: section.actionText
            iconText: "+"
            accent: section.accent
            enabled: !App.busy
            font.pixelSize: 20
            font.weight: Font.Medium
            onClicked: section.triggered()
        }
    }

    component StorageRow: Rectangle {
        id: row
        property string title
        property string detail
        property url iconSource
        property string menuText
        property bool first: false
        property bool last: false
        signal triggered()
        width: ListView.view.width
        height: 102
        topLeftRadius: first ? 28 : 8
        topRightRadius: first ? 28 : 8
        bottomLeftRadius: last ? 28 : 8
        bottomRightRadius: last ? 28 : 8
        color: Theme.surface

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 18
            spacing: 22
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 28
                color: Theme.accentSubtle
                Image { anchors.centerIn: parent; width: 27; height: 27; source: row.iconSource }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { Layout.fillWidth: true; text: row.title; color: Theme.text; font.pixelSize: 20; font.weight: Font.Normal; elide: Text.ElideRight }
                Label { Layout.fillWidth: true; text: row.detail; color: Theme.textSecondary; font.pixelSize: 16; elide: Text.ElideRight }
            }
            ToolButton {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                onClicked: rowMenu.open()
                contentItem: Image { source: "qrc:/qt/qml/Isora/qml/assets/icons/more.svg"; rotation: 90; fillMode: Image.Pad; sourceSize.width: 24; sourceSize.height: 24 }
                background: Rectangle { radius: 24; color: parent.hovered ? Theme.surfaceHover : "transparent" }
                Menu {
                    id: rowMenu
                    y: parent.height
                    MenuItem { text: row.menuText; onTriggered: row.triggered() }
                }
            }
        }
    }

    function loadBackups() {
        if (selectedMachine)
            App.loadBackups(selectedMachine.id)
    }

    function cleanSize(value) {
        return String(value || "—").replace("ГиБ", "ГБ").replace("МиБ", "МБ")
    }

    function backupSummary() {
        const count = App.backupItems.length
        let bytes = 0
        for (let index = 0; index < count; ++index)
            bytes += Number(App.backupItems[index].sizeBytes || App.backupItems[index].size || 0)
        const countText = count % 10 === 1 && count % 100 !== 11 ? "копия" : (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20) ? "копии" : "копий")
        if (bytes <= 0)
            return count + " " + countText
        return count + " " + countText + " · " + (bytes / 1073741824).toLocaleString(Qt.locale("ru_RU"), "f", 1) + " ГБ"
    }
}
