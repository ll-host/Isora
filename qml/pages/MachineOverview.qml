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
        width: Math.min(714, parent.width - 48)
        x: 24
        y: 46
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            spacing: 16
            Label {
                Layout.fillWidth: true
                text: root.machine ? root.machine.name : ""
                color: Theme.text
                font.pixelSize: 36
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 3
                ActionButton {
                    Layout.preferredWidth: 166
                    Layout.preferredHeight: 64
                    text: "Консоль"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"
                    enabled: root.machine && root.machine.running && !App.busy
                    onClicked: App.openConsole(root.machine.id)
                }
                ActionButton {
                    Layout.preferredWidth: 136
                    Layout.preferredHeight: 64
                    text: root.machine && root.machine.running ? "Выключить" : "Запустить"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/play.svg"
                    accent: true
                    enabled: root.machine && !App.busy
                    onClicked: root.machine.running ? App.shutdownMachine(root.machine.id) : App.startMachine(root.machine.id)
                }
            }
        }

        StatusBadge {
            Layout.topMargin: 4
            Layout.alignment: Qt.AlignLeft
            text: root.machine && root.machine.running ? "●  Работает" : "⏻  Выключена"
            good: root.machine && root.machine.running
        }

        Rectangle {
            Layout.topMargin: 52
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.topMargin: 28
            Layout.preferredWidth: Math.min(674, parent.width)
            Layout.alignment: Qt.AlignLeft
            Layout.preferredHeight: 120
            spacing: 4
            MetricButton { value: root.machine ? root.memoryText(root.machine.memoryMiB) : "—"; label: "Память"; first: true }
            MetricButton { value: root.machine ? String(root.machine.cpuCount) : "—"; label: "CPU" }
            MetricButton { value: root.machine ? root.machine.diskGiB + " ГБ" : "—"; label: "Диск" }
            MetricButton { value: root.machine ? String(root.machine.snapshots) : "—"; label: "Снимки"; last: true }
        }

        Label {
            Layout.topMargin: 51
            text: "Управление"
            color: Theme.text
            font.pixelSize: 26
            font.weight: Font.Bold
        }

        ColumnLayout {
            Layout.topMargin: 7
            Layout.fillWidth: true
            spacing: 4
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
        implicitHeight: 82
        leftPadding: 18
        rightPadding: 22
        contentItem: RowLayout {
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: 23
                color: Theme.accentSubtle
                Image { anchors.centerIn: parent; width: 24; height: 24; source: actionRow.iconSource }
            }
            Label { Layout.fillWidth: true; text: actionRow.title; color: Theme.text; font.pixelSize: 16; font.weight: Font.Normal }
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
        return value % 1024 === 0 ? value / 1024 + " ГБ" : value + " МБ"
    }
}
