import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    property bool compact: false
    property bool dirty: false
    property string selectedBackupDirectory: App.backupDirectory
    property string selectedQemuPath: App.qemuPath
    property string selectedDefaultDisplayMode: App.defaultDisplayMode

    Component.onCompleted: Qt.callLater(function() {
        root.dirty = false
        settingsFlickable.contentY = 0
        defaultGpuPicker.currentIndex = root.gpuIndex(App.defaultGpuId)
    })

    FolderDialog {
        id: backupFolderDialog
        title: "Каталог резервных копий"
        onAccepted: {
            root.selectedBackupDirectory = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
            root.dirty = true
        }
    }

    FileDialog {
        id: qemuFileDialog
        title: "Выберите qemu-system-x86_64.exe"
        nameFilters: ["QEMU (qemu-system-x86_64.exe)"]
        onAccepted: {
            root.selectedQemuPath = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            App.saveQemuPath(root.selectedQemuPath)
        }
    }

    Flickable {
        id: settingsFlickable
        anchors.fill: parent
        contentHeight: content.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onVisibleChanged: if (visible) Qt.callLater(function() { settingsFlickable.contentY = 0 })

        ColumnLayout {
            id: content
            width: parent.width - (root.compact ? 8 : Theme.pageMargin * 2)
            x: root.compact ? 4 : Theme.pageMargin
            y: root.compact ? 44 : 28
            spacing: 16

            PageHeader {
                visible: !root.compact
                title: "Настройки"
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: appearanceContent.implicitHeight + 36
                ColumnLayout {
                    id: appearanceContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12
                    Label { text: "Акцент"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 760 ? 5 : (width >= 480 ? 3 : 2)
                        columnSpacing: 10
                        rowSpacing: 10
                        AccentChoice { Layout.fillWidth: true; mode: "mint"; title: "Мятный"; swatchColor: "#9FE0B4" }
                        AccentChoice { Layout.fillWidth: true; mode: "teal"; title: "Бирюзовый"; swatchColor: "#168F91" }
                        AccentChoice { Layout.fillWidth: true; mode: "violet"; title: "Фиолетовый"; swatchColor: "#7767E8" }
                        AccentChoice { Layout.fillWidth: true; mode: "blue"; title: "Синий"; swatchColor: "#4D86E8" }
                        AccentChoice { Layout.fillWidth: true; mode: "amber"; title: "Янтарный"; swatchColor: "#C77B22" }
                    }
                }
            }

            Surface {
                visible: App.windowsHost
                Layout.fillWidth: true
                implicitHeight: windowsContent.implicitHeight + 36
                ColumnLayout {
                    id: windowsContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    Label { text: "QEMU для Windows"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Label { text: "WHPX · отдельное SDL-окно · QCOW2 через qemu-img"; color: Theme.textSecondary; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true
                        AppTextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.selectedQemuPath.length > 0 ? root.selectedQemuPath : "QEMU не найден"
                            AppToolTip { visible: parent.hovered; text: parent.text }
                        }
                        ActionButton { text: "Выбрать QEMU"; onClicked: qemuFileDialog.open() }
                    }
                }
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: machineDefaults.implicitHeight + 36
                ColumnLayout {
                    id: machineDefaults
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14
                    Label { text: "Новая виртуальная машина"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Label { text: "Эти значения подставляются в мастер создания"; color: Theme.textSecondary; font.pixelSize: 12 }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 620 ? 3 : 1
                        columnSpacing: 16
                        rowSpacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Оперативная память"; color: Theme.textSecondary; font.pixelSize: 12 }
                            AppSpinBox { id: memoryBox; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; value: App.defaultMemoryMiB; textFromValue: function(v) { return (v / 1024).toFixed(v % 1024 === 0 ? 0 : 1) + " ГиБ" }; onValueModified: root.dirty = true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Виртуальные процессоры"; color: Theme.textSecondary; font.pixelSize: 12 }
                            AppSpinBox { id: cpuBox; Layout.fillWidth: true; from: 1; to: 256; value: App.defaultCpuCount; onValueModified: root.dirty = true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Максимальный размер диска"; color: Theme.textSecondary; font.pixelSize: 12 }
                            AppSpinBox { id: diskBox; Layout.fillWidth: true; from: 8; to: 2048; value: App.defaultDiskGiB; textFromValue: function(v) { return v + " ГиБ" }; onValueModified: root.dirty = true }
                        }
                    }
                    RowLayout {
                        spacing: 24
                        AppSwitch { id: efiSwitch; text: "Использовать UEFI"; checked: App.defaultUseEfi; onToggled: root.dirty = true }
                        AppSwitch { id: accelerationSwitch; visible: !App.windowsHost; text: "3D-ускорение гостя"; checked: App.defaultUse3d; enabled: App.intelRenderAvailable; onToggled: root.dirty = true }
                        Label { visible: !App.windowsHost && !App.intelRenderAvailable; text: "DRM render-node не найден"; color: Theme.textMuted; font.pixelSize: 11 }
                    }
                    Label { text: "Экран новых машин"; color: Theme.textSecondary; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ActionButton { Layout.fillWidth: true; text: "В окне"; accent: root.selectedDefaultDisplayMode === "windowed"; onClicked: { root.selectedDefaultDisplayMode = "windowed"; root.dirty = true } }
                        ActionButton { Layout.fillWidth: true; text: "Без рамок"; accent: root.selectedDefaultDisplayMode === "borderless"; onClicked: { root.selectedDefaultDisplayMode = "borderless"; root.dirty = true } }
                        ActionButton { Layout.fillWidth: true; text: "Полный экран"; accent: root.selectedDefaultDisplayMode === "fullscreen"; onClicked: { root.selectedDefaultDisplayMode = "fullscreen"; root.dirty = true } }
                    }
                    ComboBox {
                        id: defaultGpuPicker
                        Layout.fillWidth: true
                        model: App.hostGpuOptions
                        textRole: "name"
                        valueRole: "id"
                        implicitHeight: 40
                        onActivated: root.dirty = true
                    }
                }
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: backupContent.implicitHeight + 36
                ColumnLayout {
                    id: backupContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    Label { text: "Резервные копии"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Label { text: "Независимые копии дисков выключенных машин"; color: Theme.textSecondary; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true
                        AppTextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.selectedBackupDirectory
                            AppToolTip { visible: parent.hovered; text: parent.text }
                        }
                        ActionButton { text: "Выбрать каталог"; onClicked: backupFolderDialog.open() }
                    }
                }
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: 96
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Открывать экран после запуска"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Label { text: "После запуска машины сразу открывать virt-viewer"; color: Theme.textSecondary; font.pixelSize: 12 }
                    }
                    AppSwitch { id: autoOpenSwitch; checked: App.openDisplayAfterStart; onToggled: root.dirty = true }
                }
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: 112
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 6
                    Label { text: "Графика"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Label { Layout.fillWidth: true; text: App.windowsHost ? "Предпочтение GPU задаётся через Windows UserGpuPreferences" : (App.intelRenderAvailable ? App.intelRenderName : "3D-ускорение недоступно"); color: Theme.textSecondary; font.pixelSize: 13; elide: Text.ElideRight }
                    Label { Layout.fillWidth: true; text: App.windowsHost ? "Auto, энергосбережение или высокая производительность — применяется при запуске QEMU." : (App.intelRenderAvailable ? App.intelRenderNode : "Машины продолжат работать с обычным VirtIO-видео."); color: Theme.textMuted; font.pixelSize: 11; elide: Text.ElideMiddle }
                }
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: 86
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Isora"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Label { text: "Локальные QEMU-машины на Windows и Linux"; color: Theme.textSecondary; font.pixelSize: 12 }
                    }
                    Label { text: "Версия " + App.version; color: Theme.textSecondary; font.pixelSize: 12 }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton {
                    text: "Сохранить настройки"
                    accent: true
                    enabled: root.dirty
                    onClicked: {
                        App.saveDefaults(memoryBox.value, cpuBox.value, diskBox.value,
                                         efiSwitch.checked, accelerationSwitch.checked,
                                         root.selectedDefaultDisplayMode, defaultGpuPicker.currentValue,
                                         autoOpenSwitch.checked, root.selectedBackupDirectory)
                        root.dirty = false
                    }
                }
            }
        }
    }

    component AccentChoice: Button {
        id: accentChoice
        property string mode: "mint"
        property string title: ""
        property color swatchColor: "#9FE0B4"
        implicitHeight: 54
        onClicked: Appearance.accentMode = mode
        leftPadding: 12
        rightPadding: 12
        contentItem: RowLayout {
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: accentChoice.swatchColor
                Label {
                    anchors.centerIn: parent
                    visible: Appearance.accentMode === accentChoice.mode
                    text: "✓"
                    color: Theme.contrastText(accentChoice.swatchColor)
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
            Label {
                Layout.fillWidth: true
                text: accentChoice.title
                color: Theme.text
                font.pixelSize: 11
                font.weight: Appearance.accentMode === accentChoice.mode ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
        background: Rectangle {
            radius: 14
            color: accentChoice.hovered ? Theme.surfaceHover : Theme.surfaceRaised
            border.width: Appearance.accentMode === accentChoice.mode ? 2 : 1
            border.color: Appearance.accentMode === accentChoice.mode ? accentChoice.swatchColor : Theme.border
        }
    }

    function gpuIndex(id) {
        for (let index = 0; index < App.hostGpuOptions.length; ++index) {
            if (App.hostGpuOptions[index].id === id)
                return index
        }
        return 0
    }
}
