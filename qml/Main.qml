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
    readonly property int navigationWidth: width < 1120 ? 232 : 264
    readonly property bool compactNavigation: height < 720
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
                Layout.preferredWidth: window.navigationWidth
                color: Theme.sidebar
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: window.compactNavigation ? 12 : 16
                    anchors.bottomMargin: window.compactNavigation ? 10 : 14
                    spacing: window.compactNavigation ? 2 : 4

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Layout.bottomMargin: window.compactNavigation ? 10 : 16
                        spacing: 11
                        Rectangle {
                            Layout.preferredWidth: window.compactNavigation ? 34 : 38
                            Layout.preferredHeight: window.compactNavigation ? 34 : 38
                            radius: 12
                            color: Theme.accentSubtle
                            border.color: Theme.accentBorder
                            Image { anchors.centerIn: parent; width: 25; height: 25; source: "qrc:/qt/qml/Isora/qml/assets/icons/app.svg" }
                        }
                        Label { Layout.fillWidth: true; text: "Isora"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    }

                    Button {
                        id: createMachineButton
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 164
                        Layout.preferredHeight: window.compactNavigation ? 38 : 40
                        text: "Создать машину"
                        enabled: App.connected && !App.busy
                        padding: 0
                        leftInset: 0
                        rightInset: 0
                        topInset: 0
                        bottomInset: 0
                        onClicked: {
                            window.currentPage = 0
                            machinesPage.openCreateDialog()
                        }
                        contentItem: Item {
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Label { text: "+"; color: Theme.accentText; font.pixelSize: 18; font.weight: Font.Medium }
                                Label { text: createMachineButton.text; color: Theme.accentText; font.pixelSize: 11; font.weight: Font.DemiBold }
                            }
                        }
                        background: Rectangle {
                            radius: 12
                            color: createMachineButton.down ? Qt.darker(Theme.accent, 1.08) : (createMachineButton.hovered ? Theme.accentHover : Theme.accent)
                            opacity: createMachineButton.enabled ? 1 : 0.42
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: window.compactNavigation ? 12 : 18
                        implicitHeight: window.compactNavigation ? 42 : 44
                        color: searchField.activeFocus ? Theme.surfaceRaised : Theme.surface
                        radius: 14
                        border.width: searchField.activeFocus ? 2 : 0
                        border.color: Theme.accent

                        Image {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: "qrc:/qt/qml/Isora/qml/assets/icons/search.svg"
                        }
                        TextInput {
                            id: searchField
                            anchors.left: parent.left
                            anchors.leftMargin: 43
                            anchors.right: clearSearchButton.visible ? clearSearchButton.left : parent.right
                            anchors.rightMargin: clearSearchButton.visible ? 4 : 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            font.pixelSize: 12
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            Label {
                                anchors.fill: parent
                                visible: searchField.text.length === 0 && !searchField.activeFocus
                                text: "Поиск машин"
                                color: Theme.textMuted
                                font: searchField.font
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Button {
                            id: clearSearchButton
                            visible: searchField.text.length > 0
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            text: "×"
                            onClicked: searchField.clear()
                            contentItem: Label { text: clearSearchButton.text; color: Theme.textSecondary; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 15; color: clearSearchButton.hovered ? Theme.surfaceHover : "transparent" }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: window.compactNavigation ? 12 : 18
                        Layout.leftMargin: 7
                        Layout.rightMargin: 7
                        Label {
                            Layout.fillWidth: true
                            text: "МАШИНЫ"
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
                        Layout.minimumHeight: window.compactNavigation ? 52 : 80
                        model: window.filteredMachines
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Button {
                            required property var modelData
                            width: ListView.view.width
                            height: window.compactNavigation ? 56 : 62
                            leftPadding: 12
                            rightPadding: 11
                            onClicked: {
                                window.selectedMachineId = modelData.id
                                window.currentPage = 0
                                machinesPage.showOverview()
                            }
                            contentItem: Item {
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 11
                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 12
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
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2
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
                                        text: modelData.running ? "Работает" : "Выключена"
                                        color: modelData.running ? Theme.success : Theme.textMuted
                                        elide: Text.ElideRight
                                        font.pixelSize: 9
                                    }
                                }
                                    Rectangle {
                                        Layout.preferredWidth: 7
                                        Layout.preferredHeight: 7
                                        radius: 4
                                        color: modelData.running ? Theme.success : Theme.textMuted
                                    }
                                }
                            }
                            background: Rectangle {
                                radius: 14
                                color: window.currentPage === 0 && window.selectedMachineId === modelData.id ? Theme.surfaceRaised : (parent.hovered ? Theme.surfaceHover : "transparent")
                                Rectangle {
                                    visible: window.currentPage === 0 && window.selectedMachineId === modelData.id
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 30
                                    radius: 2
                                    color: Theme.accent
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: window.compactNavigation ? 6 : 12
                        Layout.bottomMargin: window.compactNavigation ? 6 : 12
                        implicitHeight: 1
                        color: Theme.border
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.bottomMargin: window.compactNavigation ? 2 : 5
                        Label { Layout.fillWidth: true; text: "БИБЛИОТЕКА"; color: Theme.textMuted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.6 }
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
                        Layout.topMargin: window.compactNavigation ? 6 : 12
                        text: "Настройки"
                        selected: window.currentPage === 3
                        iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"
                        onClicked: window.currentPage = 3
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: window.compactNavigation ? 48 : 51
                        leftPadding: 10
                        rightPadding: 10
                        onClicked: window.currentPage = 2
                        contentItem: RowLayout {
                            spacing: 10
                            Image { Layout.preferredWidth: 18; Layout.preferredHeight: 18; source: "qrc:/qt/qml/Isora/qml/assets/icons/shield.svg" }
                            Label { Layout.fillWidth: true; text: "Система"; color: Theme.text; font.pixelSize: 11; font.weight: Font.Medium }
                            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: App.systemReady ? Theme.success : Theme.warning }
                        }
                        background: Rectangle {
                            color: window.currentPage === 2 ? Theme.surfaceRaised : (parent.hovered ? Theme.surfaceHover : "transparent")
                            radius: 14
                            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
                            Rectangle { visible: window.currentPage === 2; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 28; radius: 2; color: Theme.accent }
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
        anchors.topMargin: 20
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
        Layout.fillWidth: true
        implicitHeight: window.compactNavigation ? 40 : 44
        leftPadding: 12
        rightPadding: 12
        contentItem: RowLayout {
            spacing: 10
            Image { Layout.preferredWidth: 18; Layout.preferredHeight: 18; source: sidebarControl.iconSource; opacity: sidebarControl.enabled ? 1 : 0.42 }
            Label { Layout.fillWidth: true; text: sidebarControl.text; color: sidebarControl.enabled ? (sidebarControl.selected ? Theme.text : Theme.textSecondary) : Theme.textMuted; font.pixelSize: 11; font.weight: sidebarControl.selected ? Font.DemiBold : Font.Normal }
            Label { visible: sidebarControl.count >= 0; text: sidebarControl.count; color: Theme.textMuted; font.pixelSize: 9 }
        }
        background: Rectangle {
            radius: 14
            color: sidebarControl.selected ? Theme.surfaceRaised : (sidebarControl.hovered ? Theme.surfaceHover : "transparent")
            border.width: sidebarControl.activeFocus ? 2 : 0
            border.color: Theme.accent
            Rectangle { visible: sidebarControl.selected; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 26; radius: 2; color: Theme.accent }
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
