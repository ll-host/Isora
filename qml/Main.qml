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
    property bool railExpanded: width >= 1160
    readonly property bool compactRail: !railExpanded
    readonly property int railWidth: railExpanded ? 238 : 96
    readonly property bool machinePanelVisible: currentPage === 0 && machinesPage.route === "overview"
    readonly property int machinePanelWidth: width < 1240 ? 340 : 438
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
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 0
                anchors.rightMargin: 14
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 12
                    ToolButton {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        onClicked: window.railExpanded = !window.railExpanded
                        contentItem: Label { text: "☰"; color: Theme.textSecondary; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 20; color: parent.hovered ? Theme.surfaceHover : "transparent" }
                        AppToolTip { visible: parent.hovered; text: window.railExpanded ? "Свернуть меню" : "Развернуть меню" }
                    }
                    Item { Layout.fillWidth: true }
                }

                Item { Layout.preferredHeight: 8 }

                RailButton {
                    text: "Машины"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"
                    selected: window.currentPage === 0
                    onClicked: {
                        window.currentPage = 0
                        machinesPage.showOverview()
                    }
                }
                RailButton {
                    text: "Хранилище"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                    selected: window.currentPage === 1
                    onClicked: window.currentPage = 1
                }
                RailButton {
                    text: "Настройки"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"
                    selected: window.currentPage === 2
                    onClicked: window.currentPage = 2
                }

                Item { Layout.fillHeight: true }

            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: Theme.surface
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 64
                    anchors.rightMargin: 24
                    spacing: 12
                    ToolButton {
                        visible: window.currentPage === 0 && machinesPage.route !== "overview"
                        text: "‹"
                        onClicked: machinesPage.showOverview()
                        contentItem: Label { text: parent.text; color: Theme.text; font.pixelSize: 28; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 20; color: parent.hovered ? Theme.surfaceHover : "transparent" }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: window.pageTitle()
                        color: Theme.text
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    ToolButton {
                        visible: window.currentPage === 0 && machinesPage.route === "overview"
                        text: "+"
                        enabled: App.connected && !App.busy
                        onClicked: machinesPage.openCreateDialog()
                        contentItem: Label { text: parent.text; color: Theme.textSecondary; font.pixelSize: 26; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 20; color: parent.hovered ? Theme.surfaceHover : "transparent"; opacity: parent.enabled ? 1 : 0.42 }
                        AppToolTip { visible: parent.hovered; text: "Новая машина" }
                    }
                    ToolButton {
                        visible: window.currentPage !== 2 && !(window.currentPage === 0 && machinesPage.route === "overview")
                        enabled: !App.busy
                        onClicked: App.refresh()
                        contentItem: Image { anchors.centerIn: parent; width: 20; height: 20; source: "qrc:/qt/qml/Isora/qml/assets/icons/refresh.svg" }
                        background: Rectangle { radius: 20; color: parent.hovered ? Theme.surfaceHover : "transparent" }
                        AppToolTip { visible: parent.hovered; text: "Обновить" }
                    }
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
                    Label { Layout.fillWidth: true; text: App.message; color: Theme.dangerText; font.pixelSize: 12; elide: Text.ElideRight }
                    ActionButton { text: "Закрыть"; onClicked: App.clearMessage() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    visible: window.machinePanelVisible
                    Layout.fillHeight: true
                    Layout.preferredWidth: visible ? window.machinePanelWidth : 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 32
                        anchors.rightMargin: 17
                        anchors.topMargin: 46
                        anchors.bottomMargin: 98
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 32
                            color: searchField.activeFocus ? Theme.surfaceRaised : Theme.surface
                            border.width: searchField.activeFocus ? 2 : 1
                            border.color: searchField.activeFocus ? Theme.accent : Theme.border
                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                source: "qrc:/qt/qml/Isora/qml/assets/icons/search.svg"
                            }
                            TextInput {
                                id: searchField
                                anchors.left: parent.left
                                anchors.leftMargin: 58
                                anchors.right: clearSearch.visible ? clearSearch.left : parent.right
                                anchors.rightMargin: clearSearch.visible ? 4 : 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.text
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentText
                                font.pixelSize: 16
                                clip: true
                                Label {
                                    anchors.fill: parent
                                    visible: searchField.text.length === 0
                                    text: "Поиск"
                                    color: Theme.textMuted
                                    font: searchField.font
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                id: clearSearch
                                visible: searchField.text.length > 0
                                anchors.right: parent.right
                                anchors.rightMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 32
                                text: "×"
                                onClicked: searchField.clear()
                                contentItem: Label { text: clearSearch.text; color: Theme.textSecondary; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 16; color: clearSearch.hovered ? Theme.surfaceHover : "transparent" }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 10
                            model: window.filteredMachines
                            spacing: 4
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: MachineDelegate { }
                            EmptyState {
                                anchors.centerIn: parent
                                visible: parent.count === 0
                                iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"
                                title: searchField.text.length > 0 ? "Ничего не найдено" : "Машин пока нет"
                                description: ""
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 82
                            radius: 22
                            color: Theme.surface
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                spacing: 14
                                Rectangle {
                                    Layout.preferredWidth: 46
                                    Layout.preferredHeight: 46
                                    radius: 23
                                    color: Theme.accentSubtle
                                    Image {
                                        anchors.centerIn: parent
                                        width: 24
                                        height: 24
                                        source: "qrc:/qt/qml/Isora/qml/assets/icons/shield.svg"
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label { text: "Система"; color: Theme.text; font.pixelSize: 16; font.weight: Font.Medium }
                                    Label { text: App.systemReady ? "KVM доступен" : "Требуется проверка"; color: Theme.textSecondary; font.pixelSize: 12 }
                                }
                            }
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
                        onOpenMachine: function(machineId) {
                            window.selectedMachineId = machineId
                            window.currentPage = 0
                            machinesPage.showOverview()
                        }
                        onOpenImport: {
                            window.currentPage = 0
                            machinesPage.openImport()
                        }
                        onOpenBackups: {
                            window.currentPage = 0
                            machinesPage.openBackups()
                        }
                    }
                    SettingsPage { compact: true }
                }
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
                    RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: App.busy }
                }
                Label { Layout.fillWidth: true; text: App.operationTitle; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                Label { text: App.operationProgress >= 0 ? App.operationProgress + "%" : App.operationDetail; color: Theme.textSecondary; font.pixelSize: 12 }
            }
            AppProgress { Layout.fillWidth: true; visible: App.operationProgress >= 0; from: 0; to: 100; value: App.operationProgress }
        }
    }

    component RailButton: Button {
        id: control
        property url iconSource
        property bool selected: false
        Layout.fillWidth: true
        implicitHeight: window.compactRail ? 64 : 64
        leftPadding: window.compactRail ? 0 : 20
        rightPadding: window.compactRail ? 0 : 20
        contentItem: Item {
            RowLayout {
                visible: !window.compactRail
                anchors.fill: parent
                spacing: 12
                Image { Layout.preferredWidth: 21; Layout.preferredHeight: 21; source: control.iconSource }
                Label { Layout.fillWidth: true; text: control.text; color: control.selected ? Theme.secondaryContainerText : Theme.textSecondary; font.pixelSize: 15; font.weight: control.selected ? Font.DemiBold : Font.Normal }
            }
            ColumnLayout {
                visible: window.compactRail
                anchors.centerIn: parent
                spacing: 3
                Image { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 21; Layout.preferredHeight: 21; source: control.iconSource }
                Label { Layout.alignment: Qt.AlignHCenter; text: control.text; color: control.selected ? Theme.secondaryContainerText : Theme.textSecondary; font.pixelSize: 9 }
            }
        }
        background: Rectangle { radius: window.compactRail ? 18 : 32; color: control.selected ? Theme.secondaryContainer : (control.hovered ? Theme.surfaceHover : "transparent"); border.width: control.activeFocus ? 2 : 0; border.color: Theme.accent }
        AppToolTip { visible: window.compactRail && control.hovered; text: control.text }
    }

    component MachineDelegate: Button {
        id: machineControl
        required property var modelData
        width: ListView.view.width
        height: 82
        leftPadding: 18
        rightPadding: 16
        onClicked: {
            window.selectedMachineId = modelData.id
            machinesPage.showOverview()
        }
        contentItem: RowLayout {
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: 23
                color: window.selectedMachineId === machineControl.modelData.id ? "transparent" : Theme.accentSubtle
                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: machineControl.modelData.running
                        ? "qrc:/qt/qml/Isora/qml/assets/icons/activity.svg"
                        : "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label { Layout.fillWidth: true; text: machineControl.modelData.name; color: Theme.text; elide: Text.ElideRight; font.pixelSize: 16; font.weight: Font.Medium }
                Label { Layout.fillWidth: true; text: window.machineResourcesSummary(machineControl.modelData); color: Theme.textSecondary; elide: Text.ElideRight; font.pixelSize: 12 }
            }
        }
        background: Rectangle {
            radius: 18
            color: window.selectedMachineId === machineControl.modelData.id ? Theme.accentSubtle : (machineControl.hovered ? Theme.surfaceHover : Theme.surface)
        }
    }

    function machineById(id) {
        for (let index = 0; index < App.machines.length; ++index) {
            if (App.machines[index].id === id)
                return App.machines[index]
        }
        return null
    }

    function ensureSelection() {
        if (App.machines.length === 0) {
            selectedMachineId = ""
            return
        }
        if (machineById(selectedMachineId) === null)
            selectedMachineId = App.machines[0].id
    }

    function machineColor(id) {
        const colors = ["#357A50", "#53636F", "#6D5E3F", "#625B71"]
        let hash = 0
        for (let index = 0; index < id.length; ++index)
            hash = (hash + id.charCodeAt(index)) % colors.length
        return colors[hash]
    }

    function machineResourcesSummary(machine) {
        const memory = machine.memoryMiB % 1024 === 0
            ? machine.memoryMiB / 1024 + " ГБ"
            : machine.memoryMiB + " МБ"
        return (machine.running ? "Работает" : "Выключена") + " · " + memory + " · " + machine.cpuCount + " CPU"
    }

    function pageTitle() {
        if (currentPage === 1)
            return "Хранилище"
        if (currentPage === 2)
            return "Настройки"
        if (machinesPage.route === "create")
            return "Новая машина"
        if (machinesPage.route === "settings")
            return selectedMachine ? "Оборудование · " + selectedMachine.name : "Оборудование"
        if (machinesPage.route === "snapshots")
            return selectedMachine ? "Снимки · " + selectedMachine.name : "Снимки"
        if (machinesPage.route === "backups")
            return selectedMachine ? "Резервные копии · " + selectedMachine.name : "Резервные копии"
        if (machinesPage.route === "import")
            return "Подключить машину"
        return "Машины"
    }
}
