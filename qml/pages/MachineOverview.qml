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
        width: Math.min(632, parent.width - 40)
        x: 24
        y: 40
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
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
                spacing: 4
                HeaderActionButton {
                    visible: root.machine && root.machine.running
                    Layout.preferredWidth: 156
                    text: "Завершить"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/power.svg"
                    first: true
                    enabled: root.machine && !App.busy
                    onClicked: App.shutdownMachine(root.machine.id)
                }
                HeaderActionButton {
                    visible: root.machine && root.machine.running
                    Layout.preferredWidth: 120
                    text: "Убить"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/stop-on-danger.svg"
                    danger: true
                    last: true
                    enabled: root.machine && !App.busy
                    onClicked: App.forceStopMachine(root.machine.id)
                }
                HeaderActionButton {
                    visible: root.machine && !root.machine.running
                    Layout.preferredWidth: 148
                    text: "Запустить"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/play-on-accent.svg"
                    accent: true
                    first: true
                    last: true
                    enabled: root.machine && !App.busy
                    onClicked: App.startMachine(root.machine.id)
                }
            }
        }

        Rectangle {
            Layout.topMargin: 4
            Layout.alignment: Qt.AlignLeft
            implicitWidth: stateContent.implicitWidth + 32
            implicitHeight: 40
            radius: 20
            color: Theme.surface
            RowLayout {
                id: stateContent
                anchors.centerIn: parent
                spacing: 8
                Image {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    source: root.machine && root.machine.running
                        ? "qrc:/qt/qml/Isora/qml/assets/icons/play.svg"
                        : "qrc:/qt/qml/Isora/qml/assets/icons/power.svg"
                }
                Label {
                    text: root.machine && root.machine.running ? "Работает" : "Выключена"
                    color: Theme.textSecondary
                    font.pixelSize: 16
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.topMargin: 40
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.topMargin: 28
            Layout.preferredWidth: Math.min(674, parent.width)
            Layout.alignment: Qt.AlignLeft
            Layout.preferredHeight: 104
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
            font.pixelSize: 22
            font.weight: Font.Bold
        }

        ColumnLayout {
            Layout.topMargin: 7
            Layout.fillWidth: true
            spacing: 4
            ActionRow { title: "Оборудование"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/memory.svg"; first: true; onClicked: root.openSettings() }
            ActionRow { title: "Снимки"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"; onClicked: root.openSnapshots() }
            ActionRow {
                title: "Загрузить ISO"
                iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                last: true
                onClicked: App.startMachineFromDisk(root.machine.id)
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

    component HeaderActionButton: Button {
        id: headerAction
        property url iconSource
        property bool accent: false
        property bool danger: false
        property bool first: false
        property bool last: false
        implicitHeight: 60
        leftInset: 0
        rightInset: 0
        topInset: 0
        bottomInset: 0
        leftPadding: 20
        rightPadding: 20
        hoverEnabled: true
        HoverHandler {
            enabled: headerAction.enabled
            cursorShape: Qt.PointingHandCursor
        }
        contentItem: Item {
            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: headerAction.iconSource }
                Label {
                    text: headerAction.text
                    color: headerAction.danger ? Theme.dangerText : (headerAction.accent ? Theme.accentText : Theme.secondaryContainerText)
                    font.pixelSize: 17
                    font.weight: Font.Normal
                }
            }
        }
        background: Rectangle {
            topLeftRadius: headerAction.first ? 30 : 4
            bottomLeftRadius: headerAction.first ? 30 : 4
            topRightRadius: headerAction.last ? 30 : 4
            bottomRightRadius: headerAction.last ? 30 : 4
            color: headerAction.danger
                ? (headerAction.down ? Qt.darker(Theme.dangerSurface, 1.12) : (headerAction.hovered ? Qt.lighter(Theme.dangerSurface, 1.14) : Theme.dangerSurface))
                : headerAction.accent
                    ? (headerAction.down ? Qt.darker(Theme.accent, 1.08) : (headerAction.hovered ? Theme.accentHover : Theme.accent))
                    : (headerAction.down ? Theme.surfaceHover : (headerAction.hovered ? Qt.lighter(Theme.secondaryContainer, 1.12) : Theme.secondaryContainer))
            Behavior on color { ColorAnimation { duration: 110 } }
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
        leftInset: 0
        rightInset: 0
        topInset: 0
        bottomInset: 0
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
