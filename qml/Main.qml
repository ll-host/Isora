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
    minimumWidth: 960
    minimumHeight: 640
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

    Component.onCompleted: Qt.callLater(function() {
        ensureSelection()
    })

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
        onActivated: searchField.forceActiveFocus()
    }

    Popup {
        id: toast
        x: window.width - width - 24
        y: window.height - height - 24
        width: Math.min(380, toastText.implicitWidth + 48)
        height: 50
        closePolicy: Popup.NoAutoClose
        background: Rectangle { color: Theme.text; radius: Theme.radiusControl }
        contentItem: RowLayout {
            spacing: 10
            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: Theme.success }
            Label {
                id: toastText
                Layout.fillWidth: true
                color: Theme.window
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
        onOpened: toastTimer.restart()
        Timer { id: toastTimer; interval: 2600; onTriggered: toast.close() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: Theme.sidebar
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 7
                spacing: 9
                Rectangle {
                    Layout.preferredWidth: 29
                    Layout.preferredHeight: 29
                    radius: 9
                    color: Theme.accentSubtle
                    border.color: Theme.accentBorder
                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: "qrc:/qt/qml/Isora/qml/assets/icons/app.svg"
                    }
                }
                Label { text: "Isora"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 58 : 0
            visible: App.message.length > 0
            color: Theme.dangerSurface
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 12
                spacing: 12
                Label { text: "!"; color: Theme.danger; font.pixelSize: 18; font.weight: Font.Bold }
                Label { Layout.fillWidth: true; text: App.message; color: Theme.dangerText; font.pixelSize: 12; elide: Text.ElideRight }
                ActionButton { text: "Закрыть"; onClicked: App.clearMessage() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: window.width < 1120 ? 238 : 284
                color: Theme.sidebar
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 17
                    anchors.bottomMargin: 12
                    spacing: 4

                    ActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: "Новая машина"
                        iconText: "+"
                        accent: true
                        enabled: App.connected && !App.busy
                        onClicked: machinesPage.openCreateDialog()
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        implicitHeight: 42
                        leftPadding: 38
                        rightPadding: 54
                        placeholderText: "Поиск"
                        color: Theme.text
                        placeholderTextColor: Theme.textMuted
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.pixelSize: 12
                        background: Rectangle {
                            color: Theme.window
                            radius: 11
                            border.width: searchField.activeFocus ? 2 : 1
                            border.color: searchField.activeFocus ? Theme.accent : Theme.border
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 13
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⌕"
                                color: Theme.textSecondary
                                font.pixelSize: 22
                            }
                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: 11
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Ctrl F"
                                color: Theme.textMuted
                                font.pixelSize: 9
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        Layout.leftMargin: 7
                        Layout.rightMargin: 7
                        Label {
                            Layout.fillWidth: true
                            text: "ВИРТУАЛЬНЫЕ МАШИНЫ"
                            color: Theme.textSecondary
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                        }
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: Theme.surfaceHover
                            Label { anchors.centerIn: parent; text: App.machines.length; color: Theme.textSecondary; font.pixelSize: 9 }
                        }
                    }

                    ListView {
                        id: machineList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 80
                        model: window.filteredMachines
                        spacing: 3
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Button {
                            required property var modelData
                            width: ListView.view.width
                            height: 59
                            leftPadding: 9
                            rightPadding: 9
                            onClicked: {
                                window.selectedMachineId = modelData.id
                                window.currentPage = 0
                                machinesPage.showOverview()
                            }
                            contentItem: RowLayout {
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 11
                                    color: window.machineColor(modelData.id)
                                    Label {
                                        anchors.centerIn: parent
                                        text: modelData.name.length > 0 ? modelData.name.charAt(0).toUpperCase() : "VM"
                                        color: "white"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Theme.text
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.resources
                                        color: window.selectedMachineId === modelData.id ? Theme.textSecondary : Theme.textMuted
                                        opacity: 0.74
                                        elide: Text.ElideRight
                                        font.pixelSize: 9
                                    }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: modelData.running ? Theme.success : Theme.textMuted
                                    border.width: modelData.running ? 3 : 0
                                    border.color: modelData.running ? Theme.successSurface : "transparent"
                                }
                            }
                            background: Rectangle {
                                radius: 12
                                color: window.selectedMachineId === modelData.id ? Theme.accentSubtle : (parent.hovered ? Theme.surfaceHover : "transparent")
                                border.width: window.selectedMachineId === modelData.id ? 1 : 0
                                border.color: window.selectedMachineId === modelData.id ? Theme.accentBorder : "transparent"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 5
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        implicitHeight: 1
                        color: Theme.border
                    }

                    SidebarButton {
                        Layout.fillWidth: true
                        text: "Виртуальные диски"
                        count: App.machines.length
                        selected: window.currentPage === 4
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                        onClicked: window.currentPage = 4
                    }
                    SidebarButton {
                        Layout.fillWidth: true
                        text: "ISO-образы"
                        count: App.images.length
                        selected: window.currentPage === 1
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg"
                        onClicked: window.currentPage = 1
                    }
                    SidebarButton {
                        Layout.fillWidth: true
                        text: "Снимки"
                        count: window.selectedMachine ? window.selectedMachine.snapshots : 0
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"
                        enabled: window.selectedMachine !== null
                        selected: window.currentPage === 0 && machinesPage.route === "snapshots"
                        onClicked: {
                            window.currentPage = 0
                            machinesPage.showSnapshots()
                        }
                    }

                    SidebarButton {
                        Layout.fillWidth: true
                        text: "Настройки Isora"
                        selected: window.currentPage === 3
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"
                        onClicked: window.currentPage = 3
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 51
                        leftPadding: 10
                        rightPadding: 10
                        onClicked: window.currentPage = 2
                        contentItem: RowLayout {
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: App.systemReady ? Theme.success : Theme.warning
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label { text: "Локальный хост"; color: Theme.text; font.pixelSize: 10; font.weight: Font.DemiBold }
                                Label { text: App.systemReady ? "KVM доступен" : "Нужна проверка"; color: Theme.textMuted; font.pixelSize: 9 }
                            }
                            Label { text: "›"; color: Theme.textMuted; font.pixelSize: 18 }
                        }
                        background: Rectangle {
                            color: parent.hovered ? Theme.surfaceHover : "transparent"
                            radius: 10
                            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
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
                ImagesPage { testDialogName: window.testDialog }
                DiagnosticsPage { }
                SettingsPage { }
                DisksPage {
                    onOpenMachine: function(machineId) {
                        window.selectedMachineId = machineId
                        window.currentPage = 0
                        machinesPage.showOverview()
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 55
        anchors.rightMargin: 22
        width: Math.min(420, parent.width - 44)
        height: App.operationProgress >= 0 ? 78 : 62
        radius: 12
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
            Label { Layout.fillWidth: true; visible: App.operationProgress >= 0; text: App.operationDetail; color: Theme.textMuted; font.pixelSize: 11; elide: Text.ElideMiddle }
        }
    }

    component SidebarButton: Button {
        id: sidebarControl
        property int count: -1
        property url iconSource
        property bool selected: false
        implicitHeight: 42
        leftPadding: 10
        rightPadding: 10
        contentItem: RowLayout {
            spacing: 10
            Image { Layout.preferredWidth: 18; Layout.preferredHeight: 18; source: sidebarControl.iconSource; opacity: sidebarControl.enabled ? 1 : 0.42 }
            Label { Layout.fillWidth: true; text: sidebarControl.text; color: sidebarControl.enabled ? (sidebarControl.selected ? Theme.text : Theme.textSecondary) : Theme.textMuted; font.pixelSize: 11; font.weight: sidebarControl.selected ? Font.DemiBold : Font.Normal }
            Label { visible: sidebarControl.count >= 0; text: sidebarControl.count; color: Theme.textMuted; font.pixelSize: 9 }
        }
        background: Rectangle {
            radius: Theme.radiusControl
            color: sidebarControl.selected ? Theme.accentSubtle : (sidebarControl.hovered ? Theme.surfaceHover : "transparent")
            border.width: sidebarControl.activeFocus ? 2 : 0
            border.color: Theme.accent
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
        const colors = ["#3B79B7", "#7557A6", "#B96532", "#3E8057"]
        let hash = 0
        for (let index = 0; index < id.length; ++index)
            hash = (hash + id.charCodeAt(index)) % colors.length
        return colors[hash]
    }

}
