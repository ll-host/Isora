import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root

    property var machine: null
    property string pendingAction: ""

    signal openSettings()
    signal openSnapshots()
    signal openBackups()

    onMachineChanged: {
        pendingAction = ""
        resetScroll()
    }
    onVisibleChanged: if (visible) resetScroll()

    ScrollView {
        id: scrollView
        anchors.fill: parent
        visible: root.machine !== null
        clip: true
        contentWidth: availableWidth
        contentHeight: content.implicitHeight + 64
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: content
            width: Math.min(960, scrollView.availableWidth - 64)
            x: Math.max(32, (scrollView.availableWidth - width) / 2)
            y: 32
            spacing: 20

            Item {
                Layout.fillWidth: true
                implicitHeight: summaryContent.implicitHeight
                ColumnLayout {
                    id: summaryContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            radius: 18
                            color: root.machineColor(root.machine ? root.machine.id : "")
                            Label { anchors.centerIn: parent; text: root.machineInitial(); color: "white"; font.pixelSize: 20; font.weight: Font.Bold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: "ВИРТУАЛЬНАЯ МАШИНА"; color: Theme.accent; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.7 }
                            Label { Layout.fillWidth: true; text: root.machine ? root.machine.name : ""; color: Theme.text; font.pixelSize: 26; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Label { Layout.fillWidth: true; text: root.machine ? root.machine.resources : ""; color: Theme.textMuted; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                        ActionButton { text: "Консоль"; enabled: root.machine && root.machine.running && !App.busy; onClicked: App.openConsole(root.machine.id) }
                        ActionButton {
                            text: root.machine && root.machine.running ? "Выключить" : "Запустить"
                            accent: !(root.machine && root.machine.running)
                            danger: root.machine && root.machine.running
                            enabled: root.machine && !App.busy
                            onClicked: root.machine.running ? App.shutdownMachine(root.machine.id) : App.startMachine(root.machine.id)
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Metric { title: "Состояние"; value: root.machine ? root.machine.state : "—"; highlighted: root.machine && root.machine.running }
                        Divider { }
                        Metric { title: "Память"; value: root.machine ? root.memoryText(root.machine.memoryMiB) : "—" }
                        Divider { }
                        Metric { title: "Процессоры"; value: root.machine ? String(root.machine.cpuCount) : "—" }
                        Divider { }
                        Metric { title: "Диск"; value: root.machine ? root.machine.diskGiB + " ГиБ" : "—" }
                    }
                }
            }

            InlineConfirmation {
                Layout.fillWidth: true
                visible: root.pendingAction === "force-stop" || root.pendingAction === "delete-machine"
                title: root.pendingAction === "force-stop" ? "Принудительно остановить машину?" : "Удалить машину?"
                detail: root.pendingAction === "force-stop" ? "Несохранённые данные гостевой системы могут быть потеряны." : "Машина будет удалена из Isora. Это действие нельзя отменить."
                acceptText: root.pendingAction === "force-stop" ? "Остановить" : "Удалить"
                extraContent: AppCheckBox { id: removeDiskCheck; visible: root.pendingAction === "delete-machine"; checked: true; text: "Удалить виртуальный диск" }
                onCancelled: root.pendingAction = ""
                onAccepted: {
                    if (root.pendingAction === "force-stop")
                        App.forceStopMachine(root.machine.id)
                    else
                        App.deleteMachine(root.machine.id, removeDiskCheck.checked)
                    root.pendingAction = ""
                }
            }

            SectionDivider { }
            SectionTitle { title: "Управление" }
            Item {
                Layout.fillWidth: true
                implicitHeight: actionColumn.implicitHeight
                ColumnLayout {
                    id: actionColumn
                    anchors.fill: parent
                    spacing: 0
                    ActionRow { title: "Параметры"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"; onClicked: root.openSettings() }
                    ActionRow { title: "Снимки"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"; onClicked: root.openSnapshots() }
                    ActionRow { title: "Резервные копии"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg"; enabled: root.machine && !root.machine.running; onClicked: root.openBackups() }
                    ActionRow { title: root.machine && root.machine.running ? "Открыть экран" : "Запустить с диска"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; onClicked: root.machine.running ? App.openDisplay(root.machine.id) : App.startMachineFromDisk(root.machine.id) }
                }
            }

            SectionDivider { }
            SectionTitle { title: "Конфигурация" }
            Item {
                Layout.fillWidth: true
                implicitHeight: infoColumn.implicitHeight
                ColumnLayout {
                    id: infoColumn
                    anchors.fill: parent
                    spacing: 0
                    InfoRow { title: "Загрузка"; value: root.machine && root.machine.useEfi ? "UEFI" : "BIOS" }
                    InfoRow { title: "Режим экрана"; value: root.machine ? root.displayModeText(root.machine.displayMode) : "—" }
                    InfoRow { title: "Графика"; value: root.machine && root.machine.use3d ? "VirtIO с 3D" : "VirtIO" }
                    InfoRow { title: "Файл диска"; value: root.machine ? root.machine.diskPath : "—"; mono: true }
                }
            }

            SectionDivider { }
            SectionTitle { title: "Опасная зона" }
            Item {
                Layout.fillWidth: true
                implicitHeight: 52
                RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    ActionButton { visible: root.machine && root.machine.running; text: "Перезагрузить"; enabled: !App.busy; onClicked: App.resetMachine(root.machine.id) }
                    ActionButton { visible: root.machine && root.machine.running; text: "Остановить принудительно"; danger: true; enabled: !App.busy; onClicked: root.pendingAction = "force-stop" }
                    Item { Layout.fillWidth: true }
                    ActionButton { visible: root.machine && !root.machine.running; text: "Удалить машину"; danger: true; enabled: !App.busy; onClicked: root.pendingAction = "delete-machine" }
                }
            }

            Item { Layout.preferredHeight: 12 }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.machine === null
        spacing: 18
        EmptyState { iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; title: "Машин пока нет"; description: "Создайте машину из ISO-образа или подключите существующий QCOW2-диск." }
    }

    component SectionTitle: ColumnLayout {
        property string title: ""
        Label { text: parent.title; color: Theme.text; font.pixelSize: 17; font.weight: Font.DemiBold }
    }

    component Metric: ColumnLayout {
        id: metric
        property string title: ""
        property string value: ""
        property bool highlighted: false
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        Layout.leftMargin: 12
        spacing: 5
        Label { text: metric.title; color: Theme.textMuted; font.pixelSize: 9 }
        Label { text: metric.value; color: metric.highlighted ? Theme.accent : Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 46
        color: Theme.border
    }

    component SectionDivider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.border
    }

    component ActionRow: Button {
        id: actionRow
        property string title: ""
        property url iconSource
        Layout.fillWidth: true
        implicitHeight: 58
        leftPadding: 12
        rightPadding: 12
        contentItem: RowLayout {
            spacing: 14
            Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 11; color: Theme.accentSubtle; Image { anchors.centerIn: parent; width: 19; height: 19; source: actionRow.iconSource } }
            Label { Layout.fillWidth: true; text: actionRow.title; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Label { text: "›"; color: Theme.textSecondary; font.pixelSize: 21 }
        }
        background: Rectangle {
            radius: 0
            color: actionRow.hovered ? Theme.surfaceHover : "transparent"
            border.width: actionRow.activeFocus ? 2 : 0
            border.color: Theme.accent
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
        }
    }

    component InfoRow: Item {
        id: infoRow
        property string title: ""
        property string value: ""
        property bool mono: false
        Layout.fillWidth: true
        implicitHeight: 58
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            Label { Layout.preferredWidth: 150; text: infoRow.title; color: Theme.textSecondary; font.pixelSize: 11 }
            Label { Layout.fillWidth: true; text: infoRow.value; color: Theme.text; font.pixelSize: 11; font.family: infoRow.mono ? "monospace" : ""; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignRight }
        }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border }
    }

    component InlineConfirmation: Surface {
        id: confirmation
        property string title: ""
        property string detail: ""
        property string acceptText: "Продолжить"
        property alias extraContent: extraSlot.data
        signal accepted()
        signal cancelled()
        color: Theme.dangerSurface
        implicitHeight: confirmationContent.implicitHeight + 32
        ColumnLayout {
            id: confirmationContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            Label { Layout.fillWidth: true; text: confirmation.title; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; text: confirmation.detail; color: Theme.textSecondary; font.pixelSize: 11; wrapMode: Text.WordWrap }
            ColumnLayout { id: extraSlot; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: confirmation.cancelled() }
                ActionButton { text: confirmation.acceptText; danger: true; onClicked: confirmation.accepted() }
            }
        }
    }

    function requestAction(action) { pendingAction = action; resetScroll() }
    function resetScroll() { Qt.callLater(function() { if (scrollView.contentItem) scrollView.contentItem.contentY = 0 }) }
    function memoryText(value) { if (value <= 0) return "—"; return value % 1024 === 0 ? value / 1024 + " ГиБ" : value + " МиБ" }
    function displayModeText(value) { if (value === "fullscreen") return "Полный экран"; if (value === "borderless") return "Без рамок"; return "В окне" }
    function machineInitial() { return machine && machine.name.length > 0 ? machine.name.charAt(0).toUpperCase() : "VM" }
    function machineColor(id) { const colors = ["#357A50", "#586F4F", "#6D5E3F", "#53636F"]; let hash = 0; for (let index = 0; index < id.length; ++index) hash = (hash + id.charCodeAt(index)) % colors.length; return colors[hash] }
}
