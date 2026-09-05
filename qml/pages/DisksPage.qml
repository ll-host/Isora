import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    signal openMachine(string machineId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Label {
            Layout.fillWidth: true
            text: "Системные QCOW2-диски, подключённые к виртуальным машинам. Запуск диска запускает связанную с ним машину."
            color: Theme.textSecondary
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: diskList
                anchors.fill: parent
                visible: App.machines.length > 0
                model: App.machines
                spacing: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Surface {
                    required property var modelData
                    width: ListView.view.width
                    height: 116

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 13
                            color: Theme.accentSubtle
                            Image {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                source: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Theme.text
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                StatusBadge {
                                    text: modelData.running ? "Используется" : "Подключён"
                                    good: modelData.running
                                }
                                Label {
                                    text: modelData.diskGiB > 0 ? modelData.diskGiB + " ГиБ" : "Размер неизвестен"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                }
                            }
                            Label {
                                text: "Системный диск машины"
                                color: Theme.textMuted
                                font.pixelSize: 9
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.diskPath
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideMiddle
                            }
                        }

                        ActionButton {
                            text: "К машине"
                            enabled: !App.busy
                            onClicked: root.openMachine(modelData.id)
                        }
                        ActionButton {
                            text: modelData.running ? "Открыть экран" : "Запустить с диска"
                            accent: !modelData.running
                            enabled: !App.busy
                            onClicked: modelData.running ? App.openDisplay(modelData.id)
                                                         : App.startMachineFromDisk(modelData.id)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {}
            }

            EmptyState {
                anchors.centerIn: parent
                visible: App.machines.length === 0
                iconSource: "qrc:/qt/qml/Isora/qml/assets/icons/drive.svg"
                title: "Виртуальных дисков пока нет"
                description: "Системный QCOW2-диск появится после создания первой машины."
            }
        }
    }
}
