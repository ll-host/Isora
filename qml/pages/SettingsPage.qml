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
                description: App.platformName + " · версия " + App.version
            }

            Surface {
                Layout.fillWidth: true
                implicitHeight: appearanceContent.implicitHeight + 36
                ColumnLayout {
                    id: appearanceContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14
                    Label { text: "Тема"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Label { text: "Цветовая схема интерфейса"; color: Theme.textMuted; font.pixelSize: 10 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ThemeChoice { Layout.fillWidth: true; mode: "dark"; title: "Тёмная"; selected: Appearance.themeMode === "dark"; onClicked: Appearance.themeMode = "dark" }
                        ThemeChoice { Layout.fillWidth: true; mode: "light"; title: "Светлая"; selected: Appearance.themeMode === "light"; onClicked: Appearance.themeMode = "light" }
                    }
                    Label { text: "Акцентный цвет"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Label { text: "Применяется к кнопкам, выделению и переключателям"; color: Theme.textMuted; font.pixelSize: 10 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        AccentChoice { Layout.fillWidth: true; mode: "teal"; title: "Бирюзовый"; swatchColor: "#168F91" }
                        AccentChoice { Layout.fillWidth: true; mode: "violet"; title: "Фиолетовый"; swatchColor: "#7767E8" }
                        AccentChoice { Layout.fillWidth: true; mode: "blue"; title: "Синий"; swatchColor: "#4D86E8" }
                        AccentChoice { Layout.fillWidth: true; mode: "amber"; title: "Янтарный"; swatchColor: "#C77B22" }
                        AccentChoice { Layout.fillWidth: true; mode: "rose"; title: "Розовый"; swatchColor: "#B04A69" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: "Уменьшить движение интерфейса"; color: Theme.text; font.pixelSize: 12 }
                        AppSwitch { checked: Appearance.reducedMotion; onToggled: Appearance.reducedMotion = checked }
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
                implicitHeight: updateContent.implicitHeight + 36
                ColumnLayout {
                    id: updateContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label { text: "Обновления"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Label { text: Updates.statusText.length > 0 ? Updates.statusText : "Alpha и beta публикуются как prerelease"; color: Theme.textSecondary; font.pixelSize: 12 }
                        }
                        ActionButton { text: "Проверить"; enabled: !Updates.checking; onClicked: Updates.checkNow() }
                        ActionButton { visible: Updates.updateAvailable; text: "Открыть релиз"; accent: true; onClicked: Updates.openReleasePage() }
                    }
                    RowLayout {
                        spacing: 8
                        Label { text: "Канал"; color: Theme.textSecondary; font.pixelSize: 12; Layout.preferredWidth: 96 }
                        ActionButton { text: "Preview"; accent: Updates.channel === "preview"; onClicked: Updates.channel = "preview" }
                        ActionButton { text: "Stable"; accent: Updates.channel === "stable"; onClicked: Updates.channel = "stable" }
                        Item { Layout.fillWidth: true }
                        Label { text: "Проверять автоматически"; color: Theme.text; font.pixelSize: 13 }
                        AppSwitch { checked: Updates.automaticChecks; onToggled: Updates.automaticChecks = checked }
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

    component ThemeChoice: Button {
        id: themeChoice
        property string mode: "dark"
        property string title: ""
        property bool selected: false
        implicitHeight: 96
        contentItem: ColumnLayout {
            spacing: 7
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: themeChoice.mode === "dark" ? "#18191D" : "#F8F9FD"
                Rectangle {
                    x: 7
                    y: 7
                    width: parent.width * 0.3
                    height: parent.height - 14
                    radius: 5
                    color: themeChoice.mode === "dark" ? "#303136" : "#E1E3E8"
                }
                Rectangle {
                    x: parent.width * 0.3 + 13
                    y: 7
                    width: parent.width * 0.7 - 20
                    height: (parent.height - 18) / 2
                    radius: 4
                    color: themeChoice.mode === "dark" ? "#303136" : "#E1E3E8"
                }
                Rectangle {
                    x: parent.width * 0.3 + 13
                    y: parent.height / 2 + 2
                    width: parent.width * 0.7 - 20
                    height: (parent.height - 18) / 2
                    radius: 4
                    color: Theme.accent
                }
            }
            Label {
                text: themeChoice.title
                color: Theme.text
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
        background: Rectangle {
            radius: 12
            color: themeChoice.hovered ? Theme.surfaceHover : "transparent"
            border.width: themeChoice.selected ? 2 : 1
            border.color: themeChoice.selected ? Theme.accent : Theme.border
        }
    }

    component AccentChoice: Button {
        id: accentChoice
        property string mode: "blue"
        property string title: ""
        property color swatchColor: "#4D86E8"
        implicitHeight: 68
        onClicked: Appearance.accentMode = mode
        contentItem: ColumnLayout {
            spacing: 6
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: accentChoice.swatchColor
                Label {
                    anchors.centerIn: parent
                    visible: Appearance.accentMode === accentChoice.mode
                    text: "✓"
                    color: "white"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: accentChoice.title
                color: Theme.textMuted
                font.pixelSize: 8
            }
        }
        background: Rectangle {
            radius: 11
            color: Appearance.accentMode === accentChoice.mode ? Theme.surfaceHover : (accentChoice.hovered ? Theme.surface : "transparent")
            border.color: Appearance.accentMode === accentChoice.mode ? Theme.border : "transparent"
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
