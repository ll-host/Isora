import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    property var machine: null
    signal openSettings()
    signal openSnapshots()
    signal openBackups()

    ColumnLayout {
        visible: root.machine !== null
        width: Math.min(720, parent.width - 48)
        x: Math.max(24, (parent.width - width) / 2)
        y: 28
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: 16
            Label {
                Layout.fillWidth: true
                text: root.machine ? root.machine.name : ""
                color: Theme.text
                font.pixelSize: 32
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 3
                ActionButton {
                    text: "Консоль"
                    enabled: root.machine && root.machine.running && !App.busy
                    onClicked: App.openConsole(root.machine.id)
                }
                ActionButton {
                    text: root.machine && root.machine.running ? "Выключить" : "Запустить"
                    accent: true
                    enabled: root.machine && !App.busy
                    onClicked: root.machine.running ? App.shutdownMachine(root.machine.id) : App.startMachine(root.machine.id)
                }
            }
        }

        StatusBadge {
            Layout.alignment: Qt.AlignHCenter
            text: root.machine && root.machine.running ? "●  Работает" : "⏻  Выключена"
            good: root.machine && root.machine.running
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            spacing: 3
            MetricButton { value: root.machine ? root.memoryText(root.machine.memoryMiB) : "—"; label: "Память"; first: true }
            MetricButton { value: root.machine ? String(root.machine.cpuCount) : "—"; label: "CPU" }
            MetricButton { value: root.machine ? root.machine.diskGiB + " ГиБ" : "—"; label: "Диск" }
            MetricButton { value: root.machine ? String(root.machine.snapshots) : "—"; label: "Снимки"; last: true }
        }

        Label {
            Layout.topMargin: 12
            text: "Управление"
            color: Theme.text
            font.pixelSize: 22
            font.weight: Font.Bold
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            ActionRow { title: "Оборудование"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"; first: true; onClicked: root.openSettings() }
            ActionRow { title: "Снимки"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"; onClicked: root.openSnapshots() }
            ActionRow {
                title: root.machine && root.machine.running ? "Открыть экран" : "Загрузить ISO"
                iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                last: true
                onClicked: root.machine.running ? App.openDisplay(root.machine.id) : App.startMachineFromDisk(root.machine.id)
            }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        visible: root.machine === null
        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"
        title: "Машин пока нет"
        description: ""
    }

    component MetricButton: Rectangle {
        id: metric
        property string value: ""
        property string label: ""
        property bool first: false
        property bool last: false
        Layout.fillWidth: true
        Layout.fillHeight: true
        topLeftRadius: first ? 28 : 8
        bottomLeftRadius: first ? 28 : 8
        topRightRadius: last ? 28 : 8
        bottomRightRadius: last ? 28 : 8
        color: Theme.surfaceHover
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3
            Label { Layout.alignment: Qt.AlignHCenter; text: metric.value; color: Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold }
            Label { Layout.alignment: Qt.AlignHCenter; text: metric.label; color: Theme.textSecondary; font.pixelSize: 11 }
        }
    }

    component ActionRow: Button {
        id: actionRow
        property string title: ""
        property url iconSource
        property bool first: false
        property bool last: false
        Layout.fillWidth: true
        implicitHeight: 72
        leftPadding: 16
        rightPadding: 18
        contentItem: RowLayout {
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: Theme.accentSubtle
                Image { anchors.centerIn: parent; width: 22; height: 22; source: actionRow.iconSource }
            }
            Label { Layout.fillWidth: true; text: actionRow.title; color: Theme.text; font.pixelSize: 14; font.weight: Font.Medium }
            Label { text: "›"; color: Theme.textSecondary; font.pixelSize: 24 }
        }
        background: Rectangle {
            topLeftRadius: actionRow.first ? 28 : 8
            topRightRadius: actionRow.first ? 28 : 8
            bottomLeftRadius: actionRow.last ? 28 : 8
            bottomRightRadius: actionRow.last ? 28 : 8
            color: actionRow.down ? Theme.surfaceHover : (actionRow.hovered ? Theme.surfaceRaised : Theme.surface)
            scale: actionRow.down ? 0.992 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    function requestAction(action) { }
    function memoryText(value) {
        if (value <= 0)
            return "—"
        return value % 1024 === 0 ? value / 1024 + " ГиБ" : value + " МиБ"
    }
}
