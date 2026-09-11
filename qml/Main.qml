import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Isora
import "components"
import "pages"

ApplicationWindow {
    id: window
    width: 1420
    height: 860
    minimumWidth: 1024
    minimumHeight: 680
    visible: true
    title: "Isora"
    color: Theme.window
    Material.theme: Material.Dark
    Material.accent: Theme.accent
    Material.primary: Theme.accent
    Material.background: Theme.window
    Material.foreground: Theme.text

    property int currentPage: 0
    property string testDialog: ""
    property string selectedMachineId: ""
    readonly property bool compact: width < 1180
    readonly property int railWidth: compact ? 84 : 208
    readonly property bool machinePanelVisible: currentPage === 0 && machinesPage.route === "overview"
    readonly property int machinePanelWidth: compact ? 252 : 292
    readonly property var selectedMachine: machineById(selectedMachineId)
    readonly property var filteredMachines: {
        const result = []
        const query = searchField.text.trim().toLowerCase()
        for (let index = 0; index < App.machines.length; ++index) {
            const machine = App.machines[index]
            if (query.length === 0 || (machine.name + " " + machine.resources).toLowerCase().indexOf(query) >= 0)
                result.push(machine)
        }
        return result
    }

    Component.onCompleted: Qt.callLater(ensureSelection)

    Connections {
        target: App
        function onMachinesChanged() { window.ensureSelection() }
        function onOperationSucceeded(text) {
            toastText.text = text
            toast.open()
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: {
            window.currentPage = 0
            machinesPage.showOverview()
            searchField.forceActiveFocus()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: window.railWidth
            color: Theme.sidebar

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 12
                        color: Theme.accentSubtle
                        Image { anchors.centerIn: parent; width: 24; height: 24; source: "qrc:/qt/qml/Isora/qml/assets/icons/app.svg" }
                    }
                    Label {
                        visible: !window.compact
                        Layout.fillWidth: true
                        text: "Isora"
                        color: Theme.text
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                }

                RailButton { text: "Машины"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; selected: window.currentPage === 0; onClicked: { window.currentPage = 0; machinesPage.showOverview() } }
                RailButton { text: "Хранилище"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"; selected: window.currentPage === 1; onClicked: window.currentPage = 1 }
                RailButton { text: "Настройки"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"; selected: window.currentPage === 2; onClicked: window.currentPage = 2 }

                Item { Layout.fillHeight: true }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.leftMargin: 12
                    Layout.rightMargin: 10
                    spacing: 11
                    Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 5; color: App.systemReady ? Theme.success : Theme.warning }
                    ColumnLayout {
                        visible: !window.compact
                        Layout.fillWidth: true
                        spacing: 1
                        Label { text: "Система"; color: Theme.text; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Label { text: App.systemReady ? "KVM доступен" : "Требуется проверка"; color: Theme.textMuted; font.pixelSize: 9 }
                    }
                }
            }
        }

        Rectangle {
            visible: window.machinePanelVisible
            Layout.fillHeight: true
            Layout.preferredWidth: visible ? window.machinePanelWidth : 0
            color: Theme.surface
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    Label { Layout.fillWidth: true; text: "Машины"; color: Theme.text; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Label { text: App.machines.length; color: Theme.textSecondary; font.pixelSize: 12 }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 22
                    color: searchField.activeFocus ? Theme.surfaceRaised : Theme.window
                    border.width: searchField.activeFocus ? 2 : 1
                    border.color: searchField.activeFocus ? Theme.accent : Theme.border
                    Image { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; source: "qrc:/qt/qml/Isora/qml/assets/icons/search.svg" }
                    TextInput {
                        id: searchField
                        anchors.left: parent.left
                        anchors.leftMargin: 43
                        anchors.right: clearSearch.visible ? clearSearch.left : parent.right
                        anchors.rightMargin: clearSearch.visible ? 4 : 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.pixelSize: 12
                        clip: true
                        Label { anchors.fill: parent; visible: searchField.text.length === 0; text: "Поиск"; color: Theme.textMuted; font: searchField.font; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        id: clearSearch
                        visible: searchField.text.length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        text: "×"
                        onClicked: searchField.clear()
                        contentItem: Label { text: clearSearch.text; color: Theme.textSecondary; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 15; color: clearSearch.hovered ? Theme.surfaceHover : "transparent" }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: window.filteredMachines
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: MachineDelegate { }
                    EmptyState { anchors.centerIn: parent; visible: parent.count === 0; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; title: searchField.text.length > 0 ? "Ничего не найдено" : "Машин пока нет"; description: "" }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: Theme.window
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 12
                    ActionButton { visible: window.currentPage === 0 && machinesPage.route !== "overview"; text: "Назад"; iconText: "‹"; onClicked: machinesPage.showOverview() }
                    Label { Layout.fillWidth: true; text: window.pageTitle(); color: Theme.text; font.pixelSize: 21; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    ActionButton { visible: window.currentPage === 0 && machinesPage.route === "overview"; text: "Новая машина"; iconText: "+"; accent: true; enabled: App.connected && !App.busy; onClicked: machinesPage.openCreateDialog() }
                    ActionButton { text: "Обновить"; visible: window.currentPage !== 2; enabled: !App.busy; onClicked: App.refresh() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 50 : 0
                visible: App.message.length > 0
                color: Theme.dangerSurface
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 12
                    spacing: 12
                    Label {
                        Layout.fillWidth: true
                        text: App.message
                        color: Theme.dangerText
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    ActionButton {
                        text: "Закрыть"
                        onClicked: App.clearMessage()
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.currentPage
                MachinesPage {
                    id: machinesPage
                    selectedMachine: window.selectedMachine
                    showCreateDialog: window.testDialog === "create" || window.testDialog === "create-settings"
                    initialCreateStep: window.testDialog === "create-settings" ? 1 : 0
                    testDialogName: window.testDialog
                    onOpenImages: window.currentPage = 1
                }
                StoragePage {
                    selectedMachine: window.selectedMachine
                    testDialogName: window.testDialog
                    onOpenMachine: function(machineId) { window.selectedMachineId = machineId; window.currentPage = 0; machinesPage.showOverview() }
                    onOpenImport: { window.currentPage = 0; machinesPage.openImport() }
                    onOpenBackups: { window.currentPage = 0; machinesPage.openBackups() }
                }
                SettingsPage { compact: true }
            }
        }
    }

    Popup {
        id: toast
        x: window.width - width - 24
        y: window.height - height - 24
        width: Math.min(380, toastText.implicitWidth + 48)
        height: 50
        closePolicy: Popup.NoAutoClose
        background: Rectangle { color: Theme.text; radius: Theme.radiusControl }
        contentItem: Label { id: toastText; leftPadding: 18; rightPadding: 18; color: Theme.window; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.weight: Font.DemiBold }
        onOpened: toastTimer.restart()
        Timer { id: toastTimer; interval: 2600; onTriggered: toast.close() }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 84
        anchors.rightMargin: 22
        width: Math.min(420, parent.width - 44)
        height: App.operationProgress >= 0 ? 78 : 62
        radius: 16
        color: Theme.surfaceRaised
        border.color: Theme.borderStrong
        visible: App.busy
        z: 20
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 7
            RowLayout {
                Layout.fillWidth: true
                Image {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: "qrc:/qt/qml/Isora/qml/assets/icons/refresh.svg"
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: App.busy
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: App.operationTitle
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Label {
                    text: App.operationProgress >= 0 ? App.operationProgress + "%" : App.operationDetail
                    color: Theme.textSecondary
                    font.pixelSize: 12
                }
            }
            AppProgress { Layout.fillWidth: true; visible: App.operationProgress >= 0; from: 0; to: 100; value: App.operationProgress }
        }
    }

    component RailButton: Button {
        id: control
        property url iconSource
        property bool selected: false
        Layout.fillWidth: true
        implicitHeight: window.compact ? 58 : 48
        leftPadding: window.compact ? 0 : 14
        rightPadding: window.compact ? 0 : 14
        contentItem: RowLayout {
            spacing: 12
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 21
                Layout.preferredHeight: 21
                source: control.iconSource
            }
            Label {
                visible: !window.compact
                Layout.fillWidth: true
                text: control.text
                color: control.selected ? Theme.text : Theme.textSecondary
                font.pixelSize: 13
                font.weight: control.selected ? Font.DemiBold : Font.Normal
            }
        }
        background: Rectangle { radius: window.compact ? 18 : 16; color: control.selected ? Theme.accentSubtle : (control.hovered ? Theme.surfaceHover : "transparent"); border.width: control.activeFocus ? 2 : 0; border.color: Theme.accent }
        AppToolTip { visible: window.compact && control.hovered; text: control.text }
    }

    component MachineDelegate: Button {
        id: machineControl
        required property var modelData
        width: ListView.view.width
        height: 64
        leftPadding: 10
        rightPadding: 10
        onClicked: { window.selectedMachineId = modelData.id; machinesPage.showOverview() }
        contentItem: RowLayout {
            spacing: 11
            Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 13; color: window.machineColor(machineControl.modelData.id); Label { anchors.centerIn: parent; text: machineControl.modelData.name.length > 0 ? machineControl.modelData.name.charAt(0).toUpperCase() : "VM"; color: "white"; font.pixelSize: 13; font.weight: Font.Bold } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label {
                    Layout.fillWidth: true
                    text: machineControl.modelData.name
                    color: Theme.text
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    text: machineControl.modelData.running ? "Работает" : "Выключена"
                    color: machineControl.modelData.running ? Theme.success : Theme.textMuted
                    elide: Text.ElideRight
                    font.pixelSize: 9
                }
            }
            Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4; color: machineControl.modelData.running ? Theme.success : Theme.textMuted }
        }
        background: Rectangle { radius: 16; color: window.selectedMachineId === machineControl.modelData.id ? Theme.surfaceRaised : (machineControl.hovered ? Theme.surfaceHover : "transparent"); Rectangle { visible: window.selectedMachineId === machineControl.modelData.id; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 32; radius: 2; color: Theme.accent } }
    }

    function machineById(id) {
        for (let index = 0; index < App.machines.length; ++index) {
            if (App.machines[index].id === id)
                return App.machines[index]
        }
        return null
    }
    function ensureSelection() { if (App.machines.length === 0) { selectedMachineId = ""; return }; if (machineById(selectedMachineId) === null) selectedMachineId = App.machines[0].id }
    function machineColor(id) { const colors = ["#357A50", "#53636F", "#6D5E3F", "#625B71"]; let hash = 0; for (let index = 0; index < id.length; ++index) hash = (hash + id.charCodeAt(index)) % colors.length; return colors[hash] }
    function pageTitle() {
        if (currentPage === 1) return "Хранилище"
        if (currentPage === 2) return "Настройки"
        if (machinesPage.route === "create") return "Новая машина"
        if (machinesPage.route === "settings") return selectedMachine ? "Оборудование · " + selectedMachine.name : "Оборудование"
        if (machinesPage.route === "snapshots") return selectedMachine ? "Снимки · " + selectedMachine.name : "Снимки"
        if (machinesPage.route === "backups") return selectedMachine ? "Резервные копии · " + selectedMachine.name : "Резервные копии"
        if (machinesPage.route === "import") return "Подключить машину"
        return "Машины"
    }
}
