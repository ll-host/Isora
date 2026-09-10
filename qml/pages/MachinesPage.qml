import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    signal openImages()

    property bool showCreateDialog: false
    property int initialCreateStep: 0
    property string testDialogName: ""
    property var selectedMachine: null
    property var selectedSnapshot: null
    property var selectedBackup: null
    property string route: "overview"
    property string pendingAction: ""
    property url importDiskUrl: ""
    property string selectedDisplayMode: "windowed"

    Component.onCompleted: Qt.callLater(root.openTestRouteIfReady)
    onShowCreateDialogChanged: if (showCreateDialog) openCreateDialog()
    onSelectedMachineChanged: {
        pendingAction = ""
        if (!selectedMachine && route !== "create" && route !== "import")
            route = "overview"
    }
    onRouteChanged: Qt.callLater(function() {
        if (route === "create")
            createScroll.contentY = 0
        else if (route === "settings")
            settingsScroll.contentY = 0
        else if (route === "import")
            importScroll.contentY = 0
    })

    Connections {
        target: App
        function onMachinesChanged() { Qt.callLater(root.openTestRouteIfReady) }
        function onOperationSucceeded(text) {
            root.pendingAction = ""
            if (text === "Машина создана" || text === "Машина импортирована" || text === "Машина удалена") {
                root.route = "overview"
                createName.clear()
                importName.clear()
                root.importDiskUrl = ""
            }
        }
    }

    FileDialog {
        id: importDiskPicker
        title: "Выберите существующий диск QCOW2"
        nameFilters: ["QEMU QCOW2 (*.qcow2)", "Все файлы (*)"]
        onAccepted: root.importDiskUrl = selectedFile
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: root.routeIndex(root.route)

        MachineOverview {
            id: overviewPage
            machine: root.selectedMachine
            onOpenSettings: root.openSettings()
            onOpenSnapshots: root.showSnapshots()
            onOpenBackups: root.openBackups()
        }

        Item {
            Flickable {
                id: createScroll
                anchors.fill: parent
                clip: true
                contentHeight: createContent.implicitHeight + 64
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                ColumnLayout {
                    id: createContent
                    width: Math.min(860, parent.width - 64)
                    x: (parent.width - width) / 2
                    y: 32
                    spacing: 20
                    BackHeader { title: "Новая виртуальная машина"; description: "Создание из ISO-образа"; onBack: root.showOverview() }
                    SectionHeading { title: "Основное"; description: "Название и установочный образ" }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: createBasics.implicitHeight + 40
                        ColumnLayout {
                            id: createBasics
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10
                            FieldLabel { text: "Название" }
                            AppTextField { id: createName; Layout.fillWidth: true; placeholderText: "Например, рабочая станция"; selectByMouse: true }
                            FieldLabel { text: "Загрузочный ISO" }
                            ComboBox { id: createImage; Layout.fillWidth: true; implicitHeight: 52; model: App.images; textRole: "name"; valueRole: "id" }
                            ActionButton { visible: App.images.length === 0; text: "Перейти в раздел ISO-образов"; onClicked: root.openImages() }
                        }
                    }
                    SectionHeading { title: "Ресурсы"; description: "Начальные параметры можно изменить позже" }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: createResources.implicitHeight + 40
                        RowLayout {
                            id: createResources
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16
                            FormField {
                                label: "Оперативная память"
                                AppSpinBox { id: createMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; value: App.defaultMemoryMiB; textFromValue: function(v) { return root.memoryText(v) } }
                            }
                            FormField {
                                label: "Процессоры"
                                AppSpinBox { id: createCpu; Layout.fillWidth: true; from: 1; to: 256; value: App.defaultCpuCount }
                            }
                            FormField {
                                label: "Максимальный размер диска"
                                AppSpinBox { id: createDisk; Layout.fillWidth: true; from: 8; to: 2048; value: App.defaultDiskGiB; textFromValue: function(v) { return v + " ГиБ" } }
                            }
                        }
                    }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: 84
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            AppSwitch { id: createEfi; text: "UEFI"; checked: App.defaultUseEfi }
                            AppSwitch { id: create3d; text: "3D-ускорение"; checked: App.defaultUse3d; enabled: App.intelRenderAvailable }
                            Item { Layout.fillWidth: true }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        ActionButton { text: "Подключить существующий QCOW2"; onClicked: root.openImport() }
                        Item { Layout.fillWidth: true }
                        ActionButton { text: "Отмена"; onClicked: root.showOverview() }
                        ActionButton { text: "Создать машину"; accent: true; enabled: createName.text.trim().length > 0 && createImage.currentIndex >= 0 && !App.busy; onClicked: App.createMachine(createName.text, createImage.currentValue, createMemory.value, createCpu.value, createDisk.value, createEfi.checked, create3d.checked) }
                    }
                }
            }
        }

        Item {
            Flickable {
                id: settingsScroll
                anchors.fill: parent
                clip: true
                contentHeight: settingsContent.implicitHeight + 64
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                ColumnLayout {
                    id: settingsContent
                    width: Math.min(900, parent.width - 64)
                    x: (parent.width - width) / 2
                    y: 32
                    spacing: 20
                    BackHeader { title: root.selectedMachine ? "Параметры · " + root.selectedMachine.name : "Параметры"; description: "Ресурсы, экран и графика"; onBack: root.showOverview() }
                    InlineConfirmation {
                        Layout.fillWidth: true
                        visible: root.pendingAction === "restart-config"
                        title: "Применить параметры с перезапуском?"
                        detail: "Работающая машина будет остановлена и запущена заново. Несохранённые данные гостевой системы могут быть потеряны."
                        acceptText: "Применить и перезапустить"
                        danger: true
                        onCancelled: root.pendingAction = ""
                        onAccepted: root.saveMachineSettings(true)
                    }
                    SectionHeading { title: "Ресурсы"; description: "Диск можно только увеличить" }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: settingsResources.implicitHeight + 40
                        RowLayout {
                            id: settingsResources
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16
                            FormField {
                                label: "Оперативная память"
                                AppSpinBox { id: settingsMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; textFromValue: function(v) { return root.memoryText(v) } }
                            }
                            FormField {
                                label: "Виртуальные процессоры"
                                AppSpinBox { id: settingsCpu; Layout.fillWidth: true; from: 1; to: 256 }
                            }
                            FormField {
                                label: "Максимальный размер диска"
                                AppSpinBox { id: settingsDisk; Layout.fillWidth: true; to: 2048; textFromValue: function(v) { return v + " ГиБ" } }
                            }
                        }
                    }
                    SectionHeading { title: "Экран и GPU"; description: "Режим окна гостя и графический адаптер" }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: graphicsContent.implicitHeight + 40
                        ColumnLayout {
                            id: graphicsContent
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 14
                            RowLayout {
                                Layout.fillWidth: true
                                ActionButton { Layout.fillWidth: true; text: "В окне"; accent: root.selectedDisplayMode === "windowed"; onClicked: root.selectedDisplayMode = "windowed" }
                                ActionButton { Layout.fillWidth: true; text: "Без рамок"; accent: root.selectedDisplayMode === "borderless"; onClicked: root.selectedDisplayMode = "borderless" }
                                ActionButton { Layout.fillWidth: true; text: "Полный экран"; accent: root.selectedDisplayMode === "fullscreen"; onClicked: root.selectedDisplayMode = "fullscreen" }
                            }
                            FieldLabel { text: "Графический адаптер хоста" }
                            ComboBox { id: settingsGpu; Layout.fillWidth: true; implicitHeight: 48; model: App.hostGpuOptions; textRole: "name"; valueRole: "id" }
                            AppSwitch { id: settings3d; visible: !App.windowsHost; enabled: App.intelRenderAvailable; text: "3D-ускорение гостя" }
                            Label { Layout.fillWidth: true; text: App.windowsHost ? "Предпочтение GPU применяется к процессу QEMU при следующем запуске." : "Выбранный DRM render-node обслуживает VirtIO 3D."; color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        ActionButton { text: "Отмена"; onClicked: root.showOverview() }
                        ActionButton { text: root.selectedMachine && root.selectedMachine.running ? "Применить" : "Сохранить"; accent: true; enabled: root.selectedMachine && !App.busy; onClicked: root.selectedMachine.running ? root.pendingAction = "restart-config" : root.saveMachineSettings(false) }
                    }
                }
            }
        }

        Item {
            ColumnLayout {
                width: Math.min(900, parent.width - 64)
                height: parent.height - 64
                x: (parent.width - width) / 2
                y: 32
                spacing: 18
                BackHeader { title: root.selectedMachine ? "Снимки · " + root.selectedMachine.name : "Снимки"; description: "Точки восстановления состояния машины"; onBack: root.showOverview() }
                InlineConfirmation {
                    Layout.fillWidth: true
                    visible: root.pendingAction === "restore-snapshot" || root.pendingAction === "delete-snapshot"
                    title: root.pendingAction === "restore-snapshot" ? "Восстановить выбранный снимок?" : "Удалить выбранный снимок?"
                    detail: root.pendingAction === "restore-snapshot" ? "Текущее состояние машины будет заменено сохранённым состоянием." : "Снимок будет удалён без возможности восстановления."
                    acceptText: root.pendingAction === "restore-snapshot" ? "Восстановить" : "Удалить"
                    danger: root.pendingAction === "delete-snapshot"
                    onCancelled: root.pendingAction = ""
                    onAccepted: root.pendingAction === "restore-snapshot" ? App.revertSnapshot(root.selectedMachine.id, root.selectedSnapshot.name) : App.deleteSnapshot(root.selectedMachine.id, root.selectedSnapshot.name)
                }
                RowLayout {
                    Layout.fillWidth: true
                    AppTextField { id: snapshotName; Layout.fillWidth: true; placeholderText: "Название нового снимка" }
                    ActionButton { text: "Создать снимок"; accent: true; enabled: snapshotName.text.trim().length > 0 && !App.busy; onClicked: { App.createSnapshot(root.selectedMachine.id, snapshotName.text); snapshotName.clear() } }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: App.snapshotItems
                    spacing: 10
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Surface {
                        required property var modelData
                        width: ListView.view.width
                        height: 80
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: modelData.name; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Label { text: modelData.createdAt; color: Theme.textMuted; font.pixelSize: 10 }
                            }
                            ActionButton { text: "Восстановить"; enabled: !App.busy; onClicked: { root.selectedSnapshot = modelData; root.pendingAction = "restore-snapshot" } }
                            ActionButton { text: "Удалить"; danger: true; enabled: !App.busy; onClicked: { root.selectedSnapshot = modelData; root.pendingAction = "delete-snapshot" } }
                        }
                    }
                    EmptyState { anchors.centerIn: parent; visible: App.snapshotItems.length === 0; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"; title: "Снимков пока нет"; description: "Создайте точку восстановления перед важными изменениями." }
                }
            }
        }

        Item {
            ColumnLayout {
                width: Math.min(940, parent.width - 64)
                height: parent.height - 64
                x: (parent.width - width) / 2
                y: 32
                spacing: 18
                BackHeader { title: root.selectedMachine ? "Резервные копии · " + root.selectedMachine.name : "Резервные копии"; description: App.backupDirectory; onBack: root.showOverview() }
                InlineConfirmation {
                    Layout.fillWidth: true
                    visible: root.pendingAction === "restore-backup" || root.pendingAction === "delete-backup"
                    title: root.pendingAction === "restore-backup" ? "Восстановить выбранную копию?" : "Удалить выбранную копию?"
                    detail: root.pendingAction === "restore-backup" ? "Текущий диск машины будет заменён проверенной копией." : "Каталог резервной копии будет удалён."
                    acceptText: root.pendingAction === "restore-backup" ? "Восстановить" : "Удалить"
                    danger: root.pendingAction === "delete-backup"
                    onCancelled: root.pendingAction = ""
                    onAccepted: root.pendingAction === "restore-backup" ? App.restoreBackup(root.selectedMachine.id, root.selectedBackup.path) : App.deleteBackup(root.selectedBackup.path)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Независимые копии системного диска с проверкой SHA-256"; color: Theme.textSecondary; font.pixelSize: 12 }
                    ActionButton { text: "Создать копию"; accent: true; enabled: root.selectedMachine && !root.selectedMachine.running && !App.busy; onClicked: App.createBackup(root.selectedMachine.id) }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: App.backupItems
                    spacing: 10
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Surface {
                        required property var modelData
                        width: ListView.view.width
                        height: 84
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: root.formatBackupDate(modelData.createdAt); color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Label { text: modelData.sizeText + " · отдельная копия диска"; color: Theme.textMuted; font.pixelSize: 10 }
                            }
                            ActionButton { text: "Проверить"; enabled: !App.busy; onClicked: App.verifyBackup(modelData.path) }
                            ActionButton { text: "Восстановить"; enabled: !App.busy; onClicked: { root.selectedBackup = modelData; root.pendingAction = "restore-backup" } }
                            ActionButton { text: "Удалить"; danger: true; enabled: !App.busy; onClicked: { root.selectedBackup = modelData; root.pendingAction = "delete-backup" } }
                        }
                    }
                    EmptyState { anchors.centerIn: parent; visible: App.backupItems.length === 0; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg"; title: "Копий пока нет"; description: "Создайте независимую копию диска перед важными изменениями." }
                }
            }
        }

        Item {
            Flickable {
                id: importScroll
                anchors.fill: parent
                clip: true
                contentHeight: importContent.implicitHeight + 64
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: importContent
                    width: Math.min(820, parent.width - 64)
                    x: (parent.width - width) / 2
                    y: 32
                    spacing: 20
                    BackHeader { title: "Подключить существующую машину"; description: "Регистрация QCOW2 без перемещения исходного файла"; onBack: root.showOverview() }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: importFields.implicitHeight + 40
                        ColumnLayout {
                            id: importFields
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12
                            FieldLabel { text: "Название" }
                            AppTextField { id: importName; Layout.fillWidth: true; placeholderText: "Название машины" }
                            FieldLabel { text: "Файл QCOW2" }
                            RowLayout {
                                Layout.fillWidth: true
                                AppTextField { Layout.fillWidth: true; readOnly: true; text: root.importDiskUrl.toString().length > 0 ? root.localPath(root.importDiskUrl) : "Файл не выбран" }
                                ActionButton { text: "Выбрать файл"; onClicked: importDiskPicker.open() }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16
                                FormField {
                                    label: "Оперативная память"
                                    AppSpinBox { id: importMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; value: App.defaultMemoryMiB; textFromValue: function(v) { return root.memoryText(v) } }
                                }
                                FormField {
                                    label: "Процессоры"
                                    AppSpinBox { id: importCpu; Layout.fillWidth: true; from: 1; to: 256; value: App.defaultCpuCount }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        ActionButton { text: "Отмена"; onClicked: root.showOverview() }
                        ActionButton { text: "Подключить"; accent: true; enabled: importName.text.trim().length > 0 && root.importDiskUrl.toString().length > 0 && !App.busy; onClicked: App.importExistingMachine(importName.text, root.importDiskUrl, importMemory.value, importCpu.value) }
                    }
                }
            }
        }
    }

    component SectionHeading: ColumnLayout {
        property string title: ""
        property string description: ""
        spacing: 3
        Label { text: parent.title; color: Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold }
        Label { text: parent.description; color: Theme.textMuted; font.pixelSize: 11 }
    }

    component FieldLabel: Label { color: Theme.textSecondary; font.pixelSize: 12; font.weight: Font.Medium }

    component FormField: ColumnLayout {
        property string label: ""
        default property alias fieldContent: fieldSlot.data
        Layout.fillWidth: true
        spacing: 8
        FieldLabel { text: parent.label }
        ColumnLayout { id: fieldSlot; Layout.fillWidth: true }
    }

    component BackHeader: RowLayout {
        id: backHeader
        property string title: ""
        property string description: ""
        signal back()
        Layout.fillWidth: true
        spacing: 14
        ActionButton { text: "← Назад"; onClicked: backHeader.back() }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Label { Layout.fillWidth: true; text: backHeader.title; color: Theme.text; font.pixelSize: 26; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Label { Layout.fillWidth: true; text: backHeader.description; color: Theme.textMuted; font.pixelSize: 11; elide: Text.ElideMiddle }
        }
    }

    component InlineConfirmation: Surface {
        id: confirmation
        property string title: ""
        property string detail: ""
        property string acceptText: "Продолжить"
        property bool danger: false
        property alias extraContent: extraSlot.data
        signal accepted()
        signal cancelled()
        color: danger ? Theme.dangerSurface : Theme.accentSubtle
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
                ActionButton { text: confirmation.acceptText; danger: confirmation.danger; accent: !confirmation.danger; onClicked: confirmation.accepted() }
            }
        }
    }

    function routeIndex(value) {
        const routes = ["overview", "create", "settings", "snapshots", "backups", "import"]
        const index = routes.indexOf(value)
        return index >= 0 ? index : 0
    }

    function showOverview() { pendingAction = ""; route = "overview" }
    function openCreateDialog() { pendingAction = ""; createImage.currentIndex = App.images.length > 0 ? 0 : -1; route = "create"; Qt.callLater(createName.forceActiveFocus) }
    function openImport() { pendingAction = ""; route = "import"; Qt.callLater(importName.forceActiveFocus) }

    function openSettings() {
        if (!selectedMachine)
            return
        settingsMemory.value = selectedMachine.memoryMiB
        settingsCpu.value = selectedMachine.cpuCount
        settingsDisk.from = selectedMachine.diskGiB
        settingsDisk.value = selectedMachine.diskGiB
        selectedDisplayMode = selectedMachine.displayMode || "windowed"
        settingsGpu.currentIndex = gpuIndex(selectedMachine.gpuId || "auto")
        settings3d.checked = selectedMachine.use3d
        pendingAction = ""
        route = "settings"
    }

    function saveMachineSettings(restart) {
        App.updateMachineConfiguration(selectedMachine.id, settingsMemory.value, settingsCpu.value, settingsDisk.value, selectedDisplayMode, settingsGpu.currentValue, settings3d.checked, restart)
        pendingAction = ""
        route = "overview"
    }

    function showSnapshots() { if (selectedMachine) { pendingAction = ""; route = "snapshots"; App.loadSnapshots(selectedMachine.id) } }
    function openBackups() { if (selectedMachine && !selectedMachine.running) { pendingAction = ""; route = "backups"; App.loadBackups(selectedMachine.id) } }

    function openTestRouteIfReady() {
        if (testDialogName === "create" || testDialogName === "create-settings") { openCreateDialog(); return }
        if (!selectedMachine)
            return
        if (testDialogName === "machine-settings") openSettings()
        else if (testDialogName === "backups") openBackups()
        else if (testDialogName === "snapshots") showSnapshots()
        else if (testDialogName === "delete-machine") overviewPage.requestAction("delete-machine")
        else if (testDialogName === "force-stop") overviewPage.requestAction("force-stop")
    }

    function memoryText(value) { if (value <= 0) return "—"; return value % 1024 === 0 ? value / 1024 + " ГиБ" : value + " МиБ" }
    function gpuIndex(id) { for (let index = 0; index < App.hostGpuOptions.length; ++index) { if (App.hostGpuOptions[index].id === id) return index } return 0 }
    function formatBackupDate(value) { const date = new Date(value); return isNaN(date.getTime()) ? "Дата неизвестна" : date.toLocaleString(Qt.locale("ru_RU"), Locale.ShortFormat) }
    function localPath(url) { return decodeURIComponent(url.toString().replace(/^file:\/\//, "")) }
}
