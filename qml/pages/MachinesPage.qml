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
    property int createStep: 0
    property int tabIndex: 0
    property url importDiskUrl: ""
    property string selectedDisplayMode: "windowed"

    FileDialog {
        id: importDiskPicker
        title: "Выберите существующий диск QCOW2"
        nameFilters: ["QEMU QCOW2 (*.qcow2)", "Все файлы (*)"]
        onAccepted: root.importDiskUrl = selectedFile
    }

    onShowCreateDialogChanged: {
        if (showCreateDialog)
            createDialog.open()
    }

    Connections {
        target: App
        function onOperationSucceeded(text) {
            if (text === "Машина создана" && createDialog.isOpen) {
                createDialog.close()
                machineName.clear()
            }
            if (text === "Машина импортирована" && importDialog.isOpen) {
                importDialog.close()
                importName.clear()
                root.importDiskUrl = ""
            }
        }
        function onMachinesChanged() { Qt.callLater(root.openTestDialogIfReady) }
    }

    AppDialog {
        id: importDialog
        anchors.centerIn: parent
        width: Math.min(540, root.width - 48)
        modal: true
        title: "Подключить существующую машину"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 14
            Label {
                Layout.fillWidth: true
                text: "Isora зарегистрирует QCOW2 на текущем месте и не будет перемещать исходный файл. Проверка qemu-img выполняется до импорта."
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            AppTextField { id: importName; Layout.fillWidth: true; placeholderText: "Название машины" }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: root.importDiskUrl.toString().length > 0 ? decodeURIComponent(root.importDiskUrl.toString()).replace("file:///", "") : "QCOW2 не выбран"
                    color: root.importDiskUrl.toString().length > 0 ? Theme.text : Theme.textMuted
                    elide: Text.ElideMiddle
                }
                ActionButton { text: "Выбрать диск"; onClicked: importDiskPicker.open() }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 14
                Label { text: "Оперативная память"; color: Theme.textSecondary; font.pixelSize: 12 }
                Label { text: "Процессоры"; color: Theme.textSecondary; font.pixelSize: 12 }
                AppSpinBox {
                    id: importMemory
                    Layout.fillWidth: true
                    from: 1024; to: 65536; stepSize: 1024; value: 4096; editable: true
                    textFromValue: function(value) { return (value / 1024) + " ГиБ" }
                }
                AppSpinBox { id: importCpu; Layout.fillWidth: true; from: 1; to: 64; value: 4; editable: true }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: importDialog.close() }
                ActionButton {
                    text: "Подключить"
                    accent: true
                    enabled: importName.text.trim().length > 0 && root.importDiskUrl.toString().length > 0 && !App.busy
                    onClicked: App.importExistingMachine(importName.text, root.importDiskUrl, importMemory.value, importCpu.value)
                }
            }
        }
    }

    AppDialog {
        id: createDialog
        anchors.centerIn: parent
        width: Math.min(560, root.width - 48)
        height: Math.min(510, root.height - 48)
        modal: true
        title: "Новая виртуальная машина"
        standardButtons: Dialog.NoButton
        onOpened: Qt.callLater(function() {
            machineName.forceActiveFocus()
            imagePicker.currentIndex = App.images.length > 0 ? 0 : -1
        })

        contentItem: ColumnLayout {
            spacing: 14
            Label {
                Layout.fillWidth: true
                text: "Базовая конфигурация"
                color: Theme.textMuted
                font.pixelSize: 10
            }
            Label { text: "Название"; color: Theme.textSecondary; font.pixelSize: 10; font.weight: Font.DemiBold }
            AppTextField {
                id: machineName
                Layout.fillWidth: true
                placeholderText: "Новая виртуальная машина"
                selectByMouse: true
            }
            ComboBox {
                id: imagePicker
                Layout.fillWidth: true
                implicitHeight: 58
                model: App.images
                textRole: "name"
                valueRole: "id"
                leftPadding: 56
                rightPadding: 34
                font.pixelSize: 11
                contentItem: Column {
                    leftPadding: 0
                    topPadding: 10
                    spacing: 3
                    Label { text: "Загрузочный ISO"; color: Theme.textMuted; font.pixelSize: 8 }
                    Label {
                        width: parent.width
                        text: imagePicker.currentIndex >= 0 ? App.images[imagePicker.currentIndex].name : "ISO-образ не выбран"
                        color: Theme.text
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                    Label {
                        text: imagePicker.currentIndex >= 0 ? App.images[imagePicker.currentIndex].sizeText : "Добавьте образ в библиотеку"
                        color: Theme.textMuted
                        font.pixelSize: 8
                    }
                }
                background: Rectangle {
                    radius: 12
                    color: Theme.surface
                    border.color: imagePicker.activeFocus ? Theme.accent : Theme.border
                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        radius: 10
                        color: Theme.accentSubtle
                        Image { anchors.centerIn: parent; width: 19; height: 19; source: "qrc:/qt/qml/Isora/qml/assets/icons/disc.svg" }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 22
                rowSpacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "CPU"; color: Theme.textSecondary; font.pixelSize: 9 }
                    Label { text: Math.round(cpuSlider.value); color: Theme.text; font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Память"; color: Theme.textSecondary; font.pixelSize: 9 }
                    Label { text: Math.round(memorySlider.value) + " ГиБ"; color: Theme.text; font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                Slider { id: cpuSlider; Layout.fillWidth: true; from: 1; to: 64; stepSize: 1; value: App.defaultCpuCount }
                Slider { id: memorySlider; Layout.fillWidth: true; from: 1; to: 64; stepSize: 1; value: Math.max(1, App.defaultMemoryMiB / 1024) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: "Диск"; color: Theme.textSecondary; font.pixelSize: 9 }
                    AppSpinBox { id: diskBox; Layout.fillWidth: true; from: 8; to: 512; value: App.defaultDiskGiB; textFromValue: function(value) { return value + " ГиБ" } }
                }
                AppSwitch { id: efiSwitch; text: "UEFI"; checked: App.defaultUseEfi }
                AppSwitch {
                    id: accelerationSwitch
                    text: "3D"
                    checked: App.defaultUse3d && App.intelRenderAvailable
                    enabled: App.intelRenderAvailable
                }
            }
            Item { Layout.fillHeight: true }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
            RowLayout {
                Layout.fillWidth: true
                ActionButton {
                    visible: App.images.length === 0
                    text: "Добавить ISO"
                    onClicked: {
                        createDialog.close()
                        root.openImages()
                    }
                }
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: createDialog.close() }
                ActionButton {
                    text: "Создать"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/plus.svg"
                    accent: true
                    enabled: machineName.text.trim().length > 0 && imagePicker.currentIndex >= 0 && !App.busy
                    onClicked: {
                        const image = App.images[imagePicker.currentIndex]
                        App.createMachine(machineName.text, image.id, Math.round(memorySlider.value) * 1024, Math.round(cpuSlider.value),
                                          diskBox.value, efiSwitch.checked, accelerationSwitch.checked)
                    }
                }
            }
        }
    }

    AppDialog {
        id: snapshotsDialog
        anchors.centerIn: parent
        width: Math.min(680, root.width - 48)
        height: Math.min(540, root.height - 48)
        modal: true
        title: root.selectedMachine ? "Снимки состояния — " + root.selectedMachine.name : "Снимки состояния"
        standardButtons: Dialog.NoButton
        onOpened: App.loadSnapshots(root.selectedMachine.id)

        contentItem: ColumnLayout {
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                AppTextField { id: snapshotName; Layout.fillWidth: true; placeholderText: "Название снимка" }
                ActionButton {
                    text: "Создать снимок"
                    accent: true
                    enabled: snapshotName.text.trim().length > 0 && !App.busy
                    onClicked: {
                        App.createSnapshot(root.selectedMachine.id, snapshotName.text)
                        snapshotName.clear()
                    }
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: App.snapshotItems
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 66
                    radius: Theme.radiusControl
                    color: Theme.surface
                    border.color: Theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label { text: modelData.name; color: Theme.text; font.weight: Font.DemiBold }
                            Label { text: modelData.createdAt; color: Theme.textMuted; font.pixelSize: 11 }
                        }
                        ActionButton {
                            text: "Восстановить"
                            enabled: !App.busy
                            onClicked: {
                                root.selectedSnapshot = modelData
                                revertDialog.open()
                            }
                        }
                        ActionButton { text: "Удалить"; danger: true; enabled: !App.busy; onClicked: App.deleteSnapshot(root.selectedMachine.id, modelData.name) }
                    }
                }
                EmptyState {
                    anchors.centerIn: parent
                    visible: App.snapshotItems.length === 0
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"
                    title: "Снимков пока нет"
                    description: "Сохраните состояние машины, чтобы вернуться к нему позже."
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Закрыть"; onClicked: snapshotsDialog.close() }
            }
        }
    }

    AppDialog {
        id: revertDialog
        anchors.centerIn: parent
        width: 450
        modal: true
        title: "Восстановить снимок?"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 18
            Label { Layout.fillWidth: true; text: "Текущее состояние машины будет заменено выбранным снимком."; color: Theme.textSecondary; wrapMode: Text.WordWrap }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: revertDialog.close() }
                ActionButton {
                    text: "Восстановить"
                    accent: true
                    onClicked: {
                        App.revertSnapshot(root.selectedMachine.id, root.selectedSnapshot.name)
                        revertDialog.close()
                    }
                }
            }
        }
    }

    AppDialog {
        id: forceStopDialog
        anchors.centerIn: parent
        width: 450
        modal: true
        title: "Остановить принудительно?"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 18
            Label { Layout.fillWidth: true; text: "Несохранённые данные внутри гостевой системы могут быть потеряны."; color: Theme.textSecondary; wrapMode: Text.WordWrap }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: forceStopDialog.close() }
                ActionButton { text: "Остановить"; danger: true; onClicked: { App.forceStopMachine(root.selectedMachine.id); forceStopDialog.close() } }
            }
        }
    }

    AppDialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: 460
        modal: true
        title: "Удалить машину?"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 16
            Label {
                Layout.fillWidth: true
                text: root.selectedMachine ? "Машина «" + root.selectedMachine.name + "» будет удалена." : ""
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
            }
            AppCheckBox { id: removeDiskCheck; checked: true; text: "Удалить виртуальный диск" }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: deleteDialog.close() }
                ActionButton { text: "Удалить"; danger: true; onClicked: { App.deleteMachine(root.selectedMachine.id, removeDiskCheck.checked); deleteDialog.close() } }
            }
        }
    }

    AppDialog {
        id: machineSettingsDialog
        anchors.centerIn: parent
        width: Math.min(700, root.width - 48)
        modal: true
        title: root.selectedMachine ? "Параметры — " + root.selectedMachine.name : "Параметры машины"
        standardButtons: Dialog.NoButton
        onOpened: {
            resourceMemory.value = root.selectedMachine.memoryMiB
            resourceCpu.value = root.selectedMachine.cpuCount
            resourceDisk.from = root.selectedMachine.diskGiB
            resourceDisk.value = root.selectedMachine.diskGiB
            root.selectedDisplayMode = root.selectedMachine.displayMode || "windowed"
            gpuPicker.currentIndex = root.gpuIndex(root.selectedMachine.gpuId || "auto")
            machine3dSwitch.checked = root.selectedMachine.use3d
        }
        contentItem: ColumnLayout {
            spacing: 16
            Label { text: "Ресурсы"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 14
                rowSpacing: 7
                Label { text: "Оперативная память"; color: Theme.textSecondary; font.pixelSize: 12 }
                Label { text: "Виртуальные процессоры"; color: Theme.textSecondary; font.pixelSize: 12 }
                Label { text: "Максимальный размер диска"; color: Theme.textSecondary; font.pixelSize: 12 }
                AppSpinBox { id: resourceMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; textFromValue: function(v) { return (v / 1024).toFixed(v % 1024 === 0 ? 0 : 1) + " ГиБ" } }
                AppSpinBox { id: resourceCpu; Layout.fillWidth: true; from: 1; to: 256 }
                AppSpinBox { id: resourceDisk; Layout.fillWidth: true; to: 2048; textFromValue: function(v) { return v + " ГиБ" } }
            }
            Surface {
                Layout.fillWidth: true
                implicitHeight: 72
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: root.selectedMachine && root.selectedMachine.useEfi ? "Загрузка: UEFI" : "Загрузка: BIOS"; color: Theme.textSecondary; font.pixelSize: 12 }
                        Label { text: root.selectedMachine && root.selectedMachine.use3d ? "Графика гостя: VirtIO с 3D" : "Графика гостя: VirtIO"; color: Theme.textSecondary; font.pixelSize: 12 }
                    }
                    StatusBadge { text: root.selectedMachine && root.selectedMachine.running ? "Нужен перезапуск" : "Можно применить"; good: !root.selectedMachine || !root.selectedMachine.running }
                }
            }
            Label { text: "Экран и GPU"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionButton { Layout.fillWidth: true; text: "В окне"; accent: root.selectedDisplayMode === "windowed"; onClicked: root.selectedDisplayMode = "windowed" }
                ActionButton { Layout.fillWidth: true; text: "Без рамок"; accent: root.selectedDisplayMode === "borderless"; onClicked: root.selectedDisplayMode = "borderless" }
                ActionButton { Layout.fillWidth: true; text: "Полный экран"; accent: root.selectedDisplayMode === "fullscreen"; onClicked: root.selectedDisplayMode = "fullscreen" }
            }
            ComboBox {
                id: gpuPicker
                Layout.fillWidth: true
                model: App.hostGpuOptions
                textRole: "name"
                valueRole: "id"
                implicitHeight: 40
            }
            Label {
                Layout.fillWidth: true
                text: App.windowsHost
                      ? "Windows применит предпочтение GPU к процессу виртуальной машины при следующем запуске. Это не PCI passthrough."
                      : "Выбранный DRM render-node обслуживает VirtIO 3D; для NVIDIA viewer запускается через prime-run, когда он доступен."
                color: Theme.textMuted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            AppSwitch {
                id: machine3dSwitch
                visible: !App.windowsHost
                enabled: App.intelRenderAvailable
                text: "3D-ускорение гостя"
            }
            Label {
                Layout.fillWidth: true
                text: "Размер диска можно только увеличить. Новое свободное место затем нужно разметить внутри гостевой системы."
                color: Theme.textMuted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: machineSettingsDialog.close() }
                ActionButton {
                    text: root.selectedMachine && root.selectedMachine.running ? "Применить и перезапустить" : "Сохранить"
                    accent: true
                    enabled: !App.busy
                    onClicked: {
                        if (root.selectedMachine.running) {
                            restartGraphicsDialog.open()
                        } else {
                            App.updateMachineConfiguration(root.selectedMachine.id, resourceMemory.value,
                                                           resourceCpu.value, resourceDisk.value,
                                                           root.selectedDisplayMode, gpuPicker.currentValue,
                                                           machine3dSwitch.checked, false)
                            machineSettingsDialog.close()
                        }
                    }
                }
            }
        }
    }

    AppDialog {
        id: restartGraphicsDialog
        anchors.centerIn: parent
        width: Math.min(470, root.width - 48)
        modal: true
        title: "Перезапустить с новой графикой?"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 18
            Label {
                Layout.fillWidth: true
                text: "Isora завершит текущий процесс виртуальной машины и запустит его заново. Несохранённые данные внутри гостевой системы могут быть потеряны."
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: restartGraphicsDialog.close() }
                ActionButton {
                    text: "Перезапустить"
                    danger: true
                    enabled: !App.busy
                    onClicked: {
                        App.updateMachineConfiguration(root.selectedMachine.id, resourceMemory.value,
                                                       resourceCpu.value, resourceDisk.value,
                                                       root.selectedDisplayMode, gpuPicker.currentValue,
                                                       machine3dSwitch.checked, true)
                        restartGraphicsDialog.close()
                        machineSettingsDialog.close()
                    }
                }
            }
        }
    }

    AppDialog {
        id: backupsDialog
        anchors.centerIn: parent
        width: Math.min(700, root.width - 48)
        height: Math.min(540, root.height - 48)
        modal: true
        title: root.selectedMachine ? "Резервные копии — " + root.selectedMachine.name : "Резервные копии"
        standardButtons: Dialog.NoButton
        onOpened: App.loadBackups(root.selectedMachine.id)
        contentItem: ColumnLayout {
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: "Копии хранятся в «" + App.backupDirectory + "»"; color: Theme.textSecondary; font.pixelSize: 12; elide: Text.ElideMiddle }
                ActionButton { text: "Создать копию"; accent: true; enabled: !App.busy; onClicked: App.createBackup(root.selectedMachine.id) }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: App.backupItems
                delegate: Surface {
                    required property var modelData
                    width: ListView.view.width
                    height: 72
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: root.formatBackupDate(modelData.createdAt); color: Theme.text; font.weight: Font.DemiBold }
                            Label { text: modelData.sizeText + "  ·  отдельная копия диска"; color: Theme.textMuted; font.pixelSize: 11 }
                        }
                        ActionButton { text: "Проверить"; enabled: !App.busy; onClicked: App.verifyBackup(modelData.path) }
                        ActionButton {
                            text: "Восстановить"
                            enabled: !App.busy
                            onClicked: { root.selectedBackup = modelData; restoreBackupDialog.open() }
                        }
                        IconButton {
                            text: "Удалить резервную копию"
                            iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/trash.svg"
                            enabled: !App.busy
                            onClicked: { root.selectedBackup = modelData; deleteBackupDialog.open() }
                        }
                    }
                }
                EmptyState {
                    anchors.centerIn: parent
                    visible: App.backupItems.length === 0
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg"
                    title: "Резервных копий пока нет"
                    description: "Создайте независимую копию диска перед важными изменениями."
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Закрыть"; onClicked: backupsDialog.close() }
            }
        }
    }

    AppDialog {
        id: restoreBackupDialog
        anchors.centerIn: parent
        width: 480
        modal: true
        title: "Восстановить резервную копию?"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 16
            Label { Layout.fillWidth: true; text: "Текущий диск машины будет заменён выбранной проверенной копией. Машина должна оставаться выключенной."; color: Theme.textSecondary; wrapMode: Text.WordWrap }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: restoreBackupDialog.close() }
                ActionButton {
                    text: "Восстановить"
                    accent: true
                    onClicked: {
                        App.restoreBackup(root.selectedMachine.id, root.selectedBackup.path)
                        restoreBackupDialog.close()
                        backupsDialog.close()
                    }
                }
            }
        }
    }

    AppDialog {
        id: deleteBackupDialog
        anchors.centerIn: parent
        width: 450
        modal: true
        title: "Удалить резервную копию?"
        standardButtons: Dialog.NoButton
        contentItem: ColumnLayout {
            spacing: 16
            Label { Layout.fillWidth: true; text: "Каталог резервной копии будет удалён без изменения виртуальной машины."; color: Theme.textSecondary; wrapMode: Text.WordWrap }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton { text: "Отмена"; onClicked: deleteBackupDialog.close() }
                ActionButton {
                    text: "Удалить"
                    danger: true
                    onClicked: {
                        App.deleteBackup(root.selectedBackup.path)
                        deleteBackupDialog.close()
                    }
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        visible: root.selectedMachine !== null
        clip: true
        contentHeight: detailContent.implicitHeight + 78
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: detailContent
            width: Math.min(920, parent.width - 64)
            x: (parent.width - width) / 2
            y: 30
            spacing: 17

            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                Rectangle {
                    Layout.preferredWidth: 62
                    Layout.preferredHeight: 62
                    radius: 18
                    color: root.machineColor(root.selectedMachine ? root.selectedMachine.id : "")
                    Label {
                        anchors.centerIn: parent
                        text: root.selectedMachine && root.selectedMachine.name.length > 0 ? root.selectedMachine.name.charAt(0).toUpperCase() : "VM"
                        color: "white"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Label { text: "Виртуальные машины"; color: Theme.accent; font.pixelSize: 10; font.weight: Font.DemiBold }
                    Label {
                        Layout.fillWidth: true
                        text: root.selectedMachine ? root.selectedMachine.name : ""
                        color: Theme.text
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.selectedMachine ? root.selectedMachine.resources : ""
                        color: Theme.textMuted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                ActionButton {
                    text: "Консоль"
                    enabled: root.selectedMachine && root.selectedMachine.running && !App.busy
                    onClicked: App.openConsole(root.selectedMachine.id)
                }
                ActionButton {
                    text: root.selectedMachine && root.selectedMachine.running ? "Выключить" : "Запустить"
                    iconSource: root.selectedMachine && root.selectedMachine.running ? "" : "qrc:/qt/qml/Isora/qml/assets/icons/play.svg"
                    accent: !(root.selectedMachine && root.selectedMachine.running)
                    danger: root.selectedMachine && root.selectedMachine.running
                    enabled: root.selectedMachine && !App.busy
                    onClicked: root.selectedMachine.running ? App.shutdownMachine(root.selectedMachine.id) : App.startMachine(root.selectedMachine.id)
                }
                IconButton {
                    id: machineActionsButton
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    text: "Действия с машиной"
                    iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/more.svg"
                    onClicked: machineActions.open()
                    AppMenu {
                        id: machineActions
                        y: parent.height
                        AppMenuItem { text: "Открыть экран"; visible: root.selectedMachine && root.selectedMachine.running; enabled: !App.busy; onTriggered: App.openDisplay(root.selectedMachine.id) }
                        AppMenuItem { text: "Параметры машины"; enabled: root.selectedMachine && !App.busy; onTriggered: machineSettingsDialog.open() }
                        AppMenuItem { text: "Резервные копии"; visible: root.selectedMachine && !root.selectedMachine.running; enabled: !App.busy; onTriggered: backupsDialog.open() }
                        AppMenuItem { text: "Снимки состояния"; enabled: root.selectedMachine && !App.busy; onTriggered: root.showSnapshots() }
                        MenuSeparator { visible: root.selectedMachine && root.selectedMachine.running; implicitHeight: visible ? 9 : 0; height: implicitHeight; contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
                        AppMenuItem { text: "Перезагрузить"; visible: root.selectedMachine && root.selectedMachine.running; enabled: !App.busy; onTriggered: App.resetMachine(root.selectedMachine.id) }
                        AppMenuItem { text: "Остановить принудительно"; visible: root.selectedMachine && root.selectedMachine.running; enabled: !App.busy; onTriggered: forceStopDialog.open() }
                        MenuSeparator { visible: root.selectedMachine && !root.selectedMachine.running; implicitHeight: visible ? 9 : 0; height: implicitHeight; contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
                        AppMenuItem { text: "Удалить машину"; visible: root.selectedMachine && !root.selectedMachine.running; enabled: !App.busy; onTriggered: deleteDialog.open() }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 8
                Layout.preferredWidth: tabsRow.implicitWidth + 7
                Layout.preferredHeight: 42
                radius: 12
                color: Theme.surface
                border.color: Theme.border
                RowLayout {
                    id: tabsRow
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3
                    TabButton { text: "Обзор"; selected: root.tabIndex === 0; onClicked: root.tabIndex = 0 }
                    TabButton { text: "Конфигурация"; selected: root.tabIndex === 1; onClicked: root.tabIndex = 1 }
                    TabButton { text: "Снимки"; selected: root.tabIndex === 2; onClicked: root.showSnapshots() }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                currentIndex: root.tabIndex

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: statusColumn.implicitHeight + 26
                        ColumnLayout {
                            id: statusColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 10
                                Image { Layout.preferredWidth: 20; Layout.preferredHeight: 20; source: "qrc:/qt/qml/Isora/qml/assets/icons/activity.svg" }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label { text: "Состояние"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Label { text: "Основная информация о виртуальной машине"; color: Theme.textMuted; font.pixelSize: 9 }
                                }
                            }
                            InfoRow { title: "Состояние"; detail: "Текущее состояние гостевой системы"; value: root.selectedMachine ? root.selectedMachine.state : "—"; good: root.selectedMachine && root.selectedMachine.running; badge: true }
                            InfoRow { title: "Оперативная память"; detail: "Выделенная память"; value: root.selectedMachine ? root.memoryText(root.selectedMachine.memoryMiB) : "—" }
                            InfoRow { title: "Процессоры"; detail: "Виртуальные ядра CPU"; value: root.selectedMachine ? root.selectedMachine.cpuCount : "—" }
                            InfoRow { title: "Системный диск"; detail: "Максимальный размер QCOW2"; value: root.selectedMachine ? root.selectedMachine.diskGiB + " ГиБ" : "—" }
                            InfoRow { title: "Файл диска"; detail: "Расположение системного QCOW2"; value: root.selectedMachine ? root.selectedMachine.diskPath : "—" }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: configColumn.implicitHeight + 26
                        ColumnLayout {
                            id: configColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 10
                                Image { Layout.preferredWidth: 20; Layout.preferredHeight: 20; source: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg" }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label { text: "Конфигурация"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Label { text: "Ресурсы, загрузка и графика"; color: Theme.textMuted; font.pixelSize: 9 }
                                }
                                ActionButton { text: "Изменить"; enabled: root.selectedMachine && !App.busy; onClicked: machineSettingsDialog.open() }
                            }
                            InfoRow { title: "Ресурсы"; detail: "Память, процессоры и диск"; value: root.selectedMachine ? root.selectedMachine.resources : "—" }
                            InfoRow { title: "Загрузка"; detail: "Прошивка виртуальной машины"; value: root.selectedMachine && root.selectedMachine.useEfi ? "UEFI" : "BIOS" }
                            InfoRow { title: "Режим экрана"; detail: "Поведение окна гостевой системы"; value: root.selectedMachine ? root.displayModeText(root.selectedMachine.displayMode) : "—" }
                            InfoRow { title: "Графика"; detail: "Ускорение гостевой системы"; value: root.selectedMachine && root.selectedMachine.use3d ? "VirtIO с 3D" : "VirtIO" }
                        }
                    }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: 104
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 13
                            Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Label { text: "Резервные копии"; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Label { text: "Независимые проверяемые копии диска"; color: Theme.textMuted; font.pixelSize: 10 }
                            }
                            ActionButton { text: "Открыть"; enabled: root.selectedMachine && !root.selectedMachine.running && !App.busy; onClicked: backupsDialog.open() }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(180, snapshotsColumn.implicitHeight + 26)
                        ColumnLayout {
                            id: snapshotsColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 10
                                Image { Layout.preferredWidth: 20; Layout.preferredHeight: 20; source: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg" }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label { text: "Снимки"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Label { text: "Точки восстановления состояния машины"; color: Theme.textMuted; font.pixelSize: 9 }
                                }
                                ActionButton { text: "Управление"; accent: true; enabled: root.selectedMachine && !App.busy; onClicked: snapshotsDialog.open() }
                            }
                            Repeater {
                                model: App.snapshotItems
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 68
                                    color: "transparent"
                                    border.color: Theme.border
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 4
                                        spacing: 12
                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: 10
                                            color: Theme.accentSubtle
                                            Image { anchors.centerIn: parent; width: 18; height: 18; source: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg" }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Label { Layout.fillWidth: true; text: modelData.name; color: Theme.text; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                            Label { Layout.fillWidth: true; text: modelData.createdAt; color: Theme.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                                        }
                                        IconButton {
                                            text: "Действия со снимком"
                                            iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/more.svg"
                                            onClicked: snapshotMenu.open()
                                            AppMenu {
                                                id: snapshotMenu
                                                y: parent.height
                                                AppMenuItem { text: "Восстановить"; enabled: !App.busy; onTriggered: { root.selectedSnapshot = modelData; revertDialog.open() } }
                                                AppMenuItem { text: "Удалить"; enabled: !App.busy; onTriggered: App.deleteSnapshot(root.selectedMachine.id, modelData.name) }
                                            }
                                        }
                                    }
                                }
                            }
                            EmptyState {
                                Layout.fillWidth: true
                                Layout.topMargin: 18
                                visible: App.snapshotItems.length === 0
                                iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"
                                title: "Снимков пока нет"
                                description: "Создайте точку восстановления перед важными изменениями."
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.selectedMachine === null
        spacing: 18
        EmptyState {
            iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"
            title: "Машин пока нет"
            description: "Добавьте ISO-образ и создайте первую виртуальную машину."
        }
        ActionButton {
            Layout.alignment: Qt.AlignHCenter
            text: "Создать машину"
            accent: true
            enabled: App.connected && !App.busy
            onClicked: createDialog.open()
        }
    }

    component TabButton: Button {
        id: tabControl
        property bool selected: false
        implicitWidth: Math.max(84, contentItem.implicitWidth + 30)
        implicitHeight: 34
        contentItem: Label {
            text: tabControl.text
            color: tabControl.selected ? Theme.accentText : Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 11
            font.weight: tabControl.selected ? Font.DemiBold : Font.Normal
        }
        background: Rectangle {
            radius: 9
            color: tabControl.selected ? Theme.accentSubtle : (tabControl.hovered ? Theme.surfaceHover : "transparent")
        }
    }

    component InfoRow: Item {
        id: infoRow
        property string title: ""
        property string detail: ""
        property string value: ""
        property bool badge: false
        property bool good: false
        Layout.fillWidth: true
        implicitHeight: 72
        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            spacing: 22
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { text: infoRow.title; color: Theme.text; font.pixelSize: 12; font.weight: Font.Medium }
                Label { text: infoRow.detail; color: Theme.textMuted; font.pixelSize: 10 }
            }
            Item {
                Layout.preferredWidth: Math.min(520, Math.max(260, infoRow.width * 0.58))
                Layout.fillHeight: true
                StatusBadge {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: infoRow.badge
                    text: infoRow.value
                    good: infoRow.good
                }
                Label {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !infoRow.badge
                    text: infoRow.value
                    color: Theme.textSecondary
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    function openCreateDialog() {
        root.createStep = 0
        createDialog.open()
    }

    function showSnapshots() {
        if (!root.selectedMachine)
            return
        root.tabIndex = 2
        App.loadSnapshots(root.selectedMachine.id)
    }

    function memoryText(value) {
        if (value <= 0)
            return "—"
        return value % 1024 === 0 ? value / 1024 + " ГиБ" : value + " МиБ"
    }

    function displayModeText(value) {
        if (value === "fullscreen")
            return "Полный экран"
        if (value === "borderless")
            return "Без рамок"
        return "В окне"
    }

    function machineColor(id) {
        const colors = ["#3B79B7", "#7557A6", "#B96532", "#3E8057"]
        let hash = 0
        for (let index = 0; index < id.length; ++index)
            hash = (hash + id.charCodeAt(index)) % colors.length
        return colors[hash]
    }

    function snapshotWord(count) {
        const lastTwo = count % 100
        const last = count % 10
        if (lastTwo >= 11 && lastTwo <= 14)
            return "снимков"
        if (last === 1)
            return "снимок"
        if (last >= 2 && last <= 4)
            return "снимка"
        return "снимков"
    }

    function gpuIndex(id) {
        for (let index = 0; index < App.hostGpuOptions.length; ++index) {
            if (App.hostGpuOptions[index].id === id)
                return index
        }
        return 0
    }

    function formatBackupDate(value) {
        const date = new Date(value)
        return isNaN(date.getTime()) ? "Дата неизвестна" : date.toLocaleString(Qt.locale("ru_RU"), Locale.ShortFormat)
    }

    function openTestDialogIfReady() {
        if (root.testDialogName.length === 0 || !root.selectedMachine)
            return
        if (root.testDialogName === "machine-settings" && !machineSettingsDialog.isOpen)
            machineSettingsDialog.open()
        else if (root.testDialogName === "backups" && !backupsDialog.isOpen)
            backupsDialog.open()
        else if (root.testDialogName === "snapshots" && !snapshotsDialog.isOpen)
            snapshotsDialog.open()
        else if (root.testDialogName === "delete-machine" && !deleteDialog.isOpen)
            deleteDialog.open()
        else if (root.testDialogName === "force-stop" && !forceStopDialog.isOpen)
            forceStopDialog.open()
    }
}
