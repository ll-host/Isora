import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Isora
import "../components"

Item {
    id: root
    property bool compact: false
    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 64
        clip: true

        ColumnLayout {
            id: content
            width: parent.width - (root.compact ? 8 : Theme.pageMargin * 2)
            x: root.compact ? 4 : Theme.pageMargin
            y: root.compact ? 40 : 30
            spacing: 20

            PageHeader {
                visible: !root.compact
                title: "Состояние системы"
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 760 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: App.diagnostics
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 82
                        radius: Theme.radiusCard
                        color: Theme.surface
                        border.color: modelData.status === "error" ? Theme.dangerBorder : Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 13

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 10
                                color: modelData.status === "ready" ? Theme.successSurface
                                      : modelData.status === "error" ? Theme.dangerSurface : Theme.surfaceRaised
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.status === "ready" ? "✓" : modelData.status === "error" ? "!" : "i"
                                    color: modelData.status === "ready" ? Theme.success
                                         : modelData.status === "error" ? Theme.danger : Theme.textSecondary
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Theme.text
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: modelData.status === "ready" ? "Готово" : modelData.status === "error" ? "Недоступно" : "Необязательно"
                                        color: modelData.status === "ready" ? Theme.success
                                             : modelData.status === "error" ? Theme.danger : Theme.textSecondary
                                        font.pixelSize: 11
                                    }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Theme.textMuted
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
