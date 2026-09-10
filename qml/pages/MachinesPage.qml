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

        Item {
            Flickable {
                anchors.fill: parent
                visible: root.selectedMachine !== null
                clip: true
                contentHeight: overviewContent.implicitHeight + 64
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: overviewContent
                    width: Math.min(1040, parent.width - 64)
                    x: (parent.width - width) / 2
                    y: 32
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 20
                            color: root.machineColor(root.selectedMachine ? root.selectedMachine.id : "")
                            Label { anchors.centerIn: parent; text: root.machineInitial(); color: "white"; font.pixelSize: 22; font.weight: Font.Bold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label { text: "ВИРТУАЛЬНАЯ МАШИНА"; color: Theme.accent; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.7 }
                            Label { Layout.fillWidth: true; text: root.selectedMachine ? root.selectedMachine.name : ""; color: Theme.text; font.pixelSize: 30; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Label { Layout.fillWidth: true; text: root.selectedMachine ? root.selectedMachine.resources : ""; color: Theme.textMuted; font.pixelSize: 12; elide: Text.ElideRight }
                        }
                        ActionButton { text: "Консоль"; enabled: root.selectedMachine && root.selectedMachine.running && !App.busy; onClicked: App.openConsole(root.selectedMachine.id) }
                        ActionButton {
                            text: root.selectedMachine && root.selectedMachine.running ? "Выключить" : "Запустить"
                            accent: !(root.selectedMachine && root.selectedMachine.running)
                            danger: root.selectedMachine && root.selectedMachine.running
                            enabled: root.selectedMachine && !App.busy
                            onClicked: root.selectedMachine.running ? App.shutdownMachine(root.selectedMachine.id) : App.startMachine(root.selectedMachine.id)
                        }
                    }

                    InlineConfirmation {
                        Layout.fillWidth: true
                        visible: root.pendingAction === "force-stop" || root.pendingAction === "delete-machine"
                        title: root.pendingAction === "force-stop" ? "Принудительно остановить машину?" : "Удалить машину?"
                        detail: root.pendingAction === "force-stop" ? "Несохранённые данные гостевой системы могут быть потеряны." : "Машина будет удалена из Isora. Это действие нельзя отменить."
                        acceptText: root.pendingAction === "force-stop" ? "Остановить" : "Удалить"
                        danger: true
                        extraContent: AppCheckBox { id: removeDiskCheck; visible: root.pendingAction === "delete-machine"; checked: true; text: "Удалить виртуальный диск" }
                        onCancelled: root.pendingAction = ""
                        onAccepted: {
                            if (root.pendingAction === "force-stop")
                                App.forceStopMachine(root.selectedMachine.id)
                            else
                                App.deleteMachine(root.selectedMachine.id, removeDiskCheck.checked)
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 760 ? 4 : 2
                        columnSpacing: 12
                        rowSpacing: 12
                        MetricCard { title: "Состояние"; value: root.selectedMachine ? root.selectedMachine.state : "—"; highlighted: root.selectedMachine && root.selectedMachine.running }
                        MetricCard { title: "Память"; value: root.selectedMachine ? root.memoryText(root.selectedMachine.memoryMiB) : "—" }
                        MetricCard { title: "Процессоры"; value: root.selectedMachine ? String(root.selectedMachine.cpuCount) : "—" }
                        MetricCard { title: "Диск"; value: root.selectedMachine ? root.selectedMachine.diskGiB + " ГиБ" : "—" }
                    }

                    SectionHeading { title: "Управление"; description: "Все действия с машиной сгруппированы по назначению" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 760 ? 2 : 1
                        columnSpacing: 12
                        rowSpacing: 12
                        NavigationCard { title: "Параметры"; description: "Ресурсы, режим экрана и графика"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"; onClicked: root.openSettings() }
                        NavigationCard { title: "Снимки состояния"; description: root.selectedMachine ? root.selectedMachine.snapshots + " " + root.snapshotWord(root.selectedMachine.snapshots) : "Точки восстановления"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/snapshot.svg"; onClicked: root.showSnapshots() }
                        NavigationCard { title: "Резервные копии"; description: "Независимые проверяемые копии диска"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg"; enabled: root.selectedMachine && !root.selectedMachine.running; onClicked: root.openBackups() }
                        NavigationCard { title: root.selectedMachine && root.selectedMachine.running ? "Открыть экран" : "Запустить с диска"; description: root.selectedMachine && root.selectedMachine.running ? "Подключиться через virt-viewer" : "Запустить без установочного ISO"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; onClicked: root.selectedMachine.running ? App.openDisplay(root.selectedMachine.id) : App.startMachineFromDisk(root.selectedMachine.id) }
                    }

                    SectionHeading { title: "Сведения"; description: "Текущая конфигурация и расположение данных" }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: infoColumn.implicitHeight + 32
                        ColumnLayout {
                            id: infoColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 0
                            InfoRow { title: "Загрузка"; value: root.selectedMachine && root.selectedMachine.useEfi ? "UEFI" : "BIOS" }
                            InfoRow { title: "Режим экрана"; value: root.selectedMachine ? root.displayModeText(root.selectedMachine.displayMode) : "—" }
                            InfoRow { title: "Графика"; value: root.selectedMachine && root.selectedMachine.use3d ? "VirtIO с 3D" : "VirtIO" }
                            InfoRow { title: "Файл диска"; value: root.selectedMachine ? root.selectedMachine.diskPath : "—"; mono: true }
                        }
                    }

                    SectionHeading { title: "Опасная зона"; description: "Действия, которые могут привести к потере данных" }
                    Surface {
                        Layout.fillWidth: true
                        implicitHeight: 88
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            ActionButton { visible: root.selectedMachine && root.selectedMachine.running; text: "Перезагрузить"; enabled: !App.busy; onClicked: App.resetMachine(root.selectedMachine.id) }
                            ActionButton { visible: root.selectedMachine && root.selectedMachine.running; text: "Остановить принудительно"; danger: true; enabled: !App.busy; onClicked: root.pendingAction = "force-stop" }
                            Item { Layout.fillWidth: true }
                            ActionButton { visible: root.selectedMachine && !root.selectedMachine.running; text: "Удалить машину"; danger: true; enabled: !App.busy; onClicked: root.pendingAction = "delete-machine" }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: root.selectedMachine === null
                spacing: 18
                EmptyState { iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; title: "Машин пока нет"; description: "Создайте первую машину из ISO-образа или подключите существующий QCOW2-диск." }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    ActionButton { text: "Создать машину"; accent: true; enabled: App.connected && !App.busy; onClicked: root.openCreateDialog() }
                    ActionButton { text: "Подключить диск"; enabled: App.connected && !App.busy; onClicked: root.openImport() }
                }
            }
        }

        Item {
            Flickable {
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
                        GridLayout {
                            id: createResources
                            anchors.fill: parent
                            anchors.margins: 20
                            columns: width >= 680 ? 3 : 1
                            columnSpacing: 16
                            rowSpacing: 8
                            FieldLabel { text: "Оперативная память" }
                            FieldLabel { text: "Процессоры" }
                            FieldLabel { text: "Максимальный размер диска" }
                            AppSpinBox { id: createMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; value: App.defaultMemoryMiB; textFromValue: function(v) { return root.memoryText(v) } }
                            AppSpinBox { id: createCpu; Layout.fillWidth: true; from: 1; to: 256; value: App.defaultCpuCount }
                            AppSpinBox { id: createDisk; Layout.fillWidth: true; from: 8; to: 2048; value: App.defaultDiskGiB; textFromValue: function(v) { return v + " ГиБ" } }
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
                        GridLayout {
                            id: settingsResources
                            anchors.fill: parent
                            anchors.margins: 20
                            columns: width >= 680 ? 3 : 1
                            columnSpacing: 16
                            rowSpacing: 8
                            FieldLabel { text: "Оперативная память" }
                            FieldLabel { text: "Виртуальные процессоры" }
                            FieldLabel { text: "Максимальный размер диска" }
                            AppSpinBox { id: settingsMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; textFromValue: function(v) { return root.memoryText(v) } }
                            AppSpinBox { id: settingsCpu; Layout.fillWidth: true; from: 1; to: 256 }
                            AppSpinBox { id: settingsDisk; Layout.fillWidth: true; to: 2048; textFromValue: function(v) { return v + " ГиБ" } }
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
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 8
                                FieldLabel { text: "Оперативная память" }
                                FieldLabel { text: "Процессоры" }
                                AppSpinBox { id: importMemory; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; value: App.defaultMemoryMiB; textFromValue: function(v) { return root.memoryText(v) } }
                                AppSpinBox { id: importCpu; Layout.fillWidth: true; from: 1; to: 256; value: App.defaultCpuCount }
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

    component MetricCard: Surface {
        id: metricCard
        property string title: ""
        property string value: ""
        property bool highlighted: false
        Layout.fillWidth: true
        implicitHeight: 96
        color: highlighted ? Theme.accentSubtle : Theme.surface
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 5
            Label { text: metricCard.title; color: Theme.textMuted; font.pixelSize: 10 }
            Label { text: metricCard.value; color: metricCard.highlighted ? Theme.accent : Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold }
        }
    }

    component NavigationCard: Button {
        id: navigationCard
        property string title: ""
        property string description: ""
        property url iconSource
        Layout.fillWidth: true
        implicitHeight: 92
        leftPadding: 18
        rightPadding: 18
        contentItem: RowLayout {
            spacing: 14
            Rectangle { Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 14; color: Theme.accentSubtle; Image { anchors.centerIn: parent; width: 22; height: 22; source: navigationCard.iconSource } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { text: navigationCard.title; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                Label { Layout.fillWidth: true; text: navigationCard.description; color: Theme.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
            }
            Label { text: "›"; color: Theme.textSecondary; font.pixelSize: 22 }
        }
        background: Rectangle { radius: Theme.radiusCard; color: navigationCard.hovered ? Theme.surfaceHover : Theme.surface; border.width: navigationCard.activeFocus ? 2 : 0; border.color: Theme.accent }
    }

    component InfoRow: Item {
        id: infoRow
        property string title: ""
        property string value: ""
        property bool mono: false
        Layout.fillWidth: true
        implicitHeight: 62
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            Label { Layout.fillWidth: true; text: infoRow.title; color: Theme.textSecondary; font.pixelSize: 12 }
            Label { Layout.preferredWidth: Math.min(560, parent.width * 0.62); text: infoRow.value; color: Theme.text; font.pixelSize: 11; font.family: infoRow.mono ? "monospace" : ""; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignRight }
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
        else if (testDialogName === "delete-machine") pendingAction = "delete-machine"
        else if (testDialogName === "force-stop") pendingAction = "force-stop"
    }

    function memoryText(value) { if (value <= 0) return "—"; return value % 1024 === 0 ? value / 1024 + " ГиБ" : value + " МиБ" }
    function displayModeText(value) { if (value === "fullscreen") return "Полный экран"; if (value === "borderless") return "Без рамок"; return "В окне" }
    function machineInitial() { return selectedMachine && selectedMachine.name.length > 0 ? selectedMachine.name.charAt(0).toUpperCase() : "VM" }
    function machineColor(id) { const colors = ["#357A50", "#586F4F", "#6D5E3F", "#53636F"]; let hash = 0; for (let index = 0; index < id.length; ++index) hash = (hash + id.charCodeAt(index)) % colors.length; return colors[hash] }
    function snapshotWord(count) { const lastTwo = count % 100; const last = count % 10; if (lastTwo >= 11 && lastTwo <= 14) return "снимков"; if (last === 1) return "снимок"; if (last >= 2 && last <= 4) return "снимка"; return "снимков" }
    function gpuIndex(id) { for (let index = 0; index < App.hostGpuOptions.length; ++index) { if (App.hostGpuOptions[index].id === id) return index } return 0 }
    function formatBackupDate(value) { const date = new Date(value); return isNaN(date.getTime()) ? "Дата неизвестна" : date.toLocaleString(Qt.locale("ru_RU"), Locale.ShortFormat) }
    function localPath(url) { return decodeURIComponent(url.toString().replace(/^file:\/\//, "")) }
}
