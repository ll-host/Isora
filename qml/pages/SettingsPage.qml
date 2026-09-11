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
    property string selectedDefaultDisplayMode: App.defaultDisplayMode

    Component.onCompleted: Qt.callLater(function() {
        root.dirty = false
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

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 56
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: Math.min(1000, parent.width - 56)
            x: Math.max(28, (parent.width - width) / 2)
            y: 28
            spacing: 26

            RowLayout {
                Layout.fillWidth: true
                spacing: 32

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Label { text: "Новая машина"; color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        ValueRow { title: "Память"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/activity.svg"; valueText: root.memoryText(memoryBox.value); first: true; onClicked: memoryBox.forceActiveFocus() }
                        AppSpinBox { id: memoryBox; Layout.fillWidth: true; from: 1024; to: 262144; stepSize: 1024; value: App.defaultMemoryMiB; textFromValue: function(v) { return root.memoryText(v) }; onValueModified: root.dirty = true }
                        ValueRow { title: "Процессоры"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/settings.svg"; valueText: String(cpuBox.value); onClicked: cpuBox.forceActiveFocus() }
                        AppSpinBox { id: cpuBox; Layout.fillWidth: true; from: 1; to: 256; value: App.defaultCpuCount; onValueModified: root.dirty = true }
                        ValueRow { title: "Диск"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"; valueText: diskBox.value + " ГиБ"; onClicked: diskBox.forceActiveFocus() }
                        AppSpinBox { id: diskBox; Layout.fillWidth: true; from: 8; to: 2048; value: App.defaultDiskGiB; textFromValue: function(v) { return v + " ГиБ" }; onValueModified: root.dirty = true }
                        ToggleRow { title: "UEFI"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/activity.svg"; last: true; checked: efiSwitch.checked; onClicked: efiSwitch.checked = !efiSwitch.checked }
                        AppSwitch { id: efiSwitch; visible: false; checked: App.defaultUseEfi; onToggled: root.dirty = true }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Label { text: "Поведение"; color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        ToggleRow { title: "Открывать консоль после запуска"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; first: true; checked: autoOpenSwitch.checked; onClicked: autoOpenSwitch.checked = !autoOpenSwitch.checked }
                        AppSwitch { id: autoOpenSwitch; visible: false; checked: App.openDisplayAfterStart; onToggled: root.dirty = true }
                        ToggleRow { title: "3D-ускорение"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; checked: accelerationSwitch.checked; enabled: App.intelRenderAvailable; onClicked: accelerationSwitch.checked = !accelerationSwitch.checked }
                        AppSwitch { id: accelerationSwitch; visible: false; checked: App.defaultUse3d; enabled: App.intelRenderAvailable; onToggled: root.dirty = true }
                        ToggleRow { title: "Полный экран"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/monitor.svg"; last: true; checked: root.selectedDefaultDisplayMode === "fullscreen"; onClicked: { root.selectedDefaultDisplayMode = checked ? "windowed" : "fullscreen"; root.dirty = true } }
                    }
                    ComboBox {
                        id: defaultGpuPicker
                        Layout.fillWidth: true
                        implicitHeight: 56
                        model: App.hostGpuOptions
                        textRole: "name"
                        valueRole: "id"
                        onActivated: root.dirty = true
                    }
                }
            }

            Label { text: "Каталоги"; color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                PathRow { title: "Диски и ISO"; valueText: App.windowsHost ? App.qemuPath : "/var/lib/libvirt/images/isora"; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"; first: true }
                PathRow { title: "Резервные копии"; valueText: root.selectedBackupDirectory; iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/backup.svg"; last: true; onClicked: backupFolderDialog.open() }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ActionButton {
                    text: "Сохранить"
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

    component ValueRow: Button {
        id: row
        property string title: ""
        property string valueText: ""
        property url iconSource
        property bool first: false
        property bool last: false
        Layout.fillWidth: true
        implicitHeight: 72
        leftPadding: 16
        rightPadding: 16
        contentItem: RowLayout {
            spacing: 14
            Image { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: row.iconSource }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: row.title; color: Theme.text; font.pixelSize: 14 }
                Label { text: row.valueText; color: Theme.textSecondary; font.pixelSize: 12 }
            }
            Label { text: "›"; color: Theme.textSecondary; font.pixelSize: 23 }
        }
        background: RowBackground { control: row }
    }

    component ToggleRow: Button {
        id: row
        property string title: ""
        property url iconSource
        property bool first: false
        property bool last: false
        Layout.fillWidth: true
        implicitHeight: 72
        leftPadding: 16
        rightPadding: 16
        contentItem: RowLayout {
            spacing: 14
            Image { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: row.iconSource }
            Label { Layout.fillWidth: true; text: row.title; color: row.enabled ? Theme.text : Theme.textMuted; font.pixelSize: 14; wrapMode: Text.WordWrap }
            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 28
                radius: 14
                color: row.checked ? Theme.accent : Theme.surfaceHover
                border.color: row.checked ? Theme.accent : Theme.borderStrong
                Rectangle { x: row.checked ? parent.width - width - 4 : 4; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; radius: 10; color: row.checked ? Theme.accentText : Theme.textSecondary; Behavior on x { NumberAnimation { duration: 150 } } }
            }
        }
        background: RowBackground { control: row }
    }

    component PathRow: Button {
        id: row
        property string title: ""
        property string valueText: ""
        property url iconSource
        property bool first: false
        property bool last: false
        Layout.fillWidth: true
        implicitHeight: 72
        leftPadding: 16
        rightPadding: 16
        contentItem: RowLayout {
            spacing: 14
            Image { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: row.iconSource }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label { text: row.title; color: Theme.text; font.pixelSize: 14 }
                Label { Layout.fillWidth: true; text: row.valueText; color: Theme.textSecondary; font.pixelSize: 11; elide: Text.ElideMiddle }
            }
            Label { text: "›"; color: Theme.textSecondary; font.pixelSize: 23 }
        }
        background: RowBackground { control: row }
    }

    component RowBackground: Rectangle {
        required property Item control
        topLeftRadius: control.first ? 28 : 8
        topRightRadius: control.first ? 28 : 8
        bottomLeftRadius: control.last ? 28 : 8
        bottomRightRadius: control.last ? 28 : 8
        color: control.hovered ? Theme.surfaceRaised : Theme.surface
    }

    function memoryText(value) {
        return value % 1024 === 0 ? value / 1024 + " ГиБ" : value + " МиБ"
    }

    function gpuIndex(id) {
        for (let index = 0; index < App.hostGpuOptions.length; ++index) {
            if (App.hostGpuOptions[index].id === id)
                return index
        }
        return 0
    }
}
