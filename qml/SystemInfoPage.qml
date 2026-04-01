import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: sysRoot

    property var sysInfo: ({})

    Component.onCompleted: {
        var raw = backend.getSystemInfo()
        sysInfo = JSON.parse(raw)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Label {
            text: "System Info"
            font.pixelSize: 24
            font.bold: true
            color: "#132B4F"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#FFFFFF"
            border.color: "#E0E8F0"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                StatRow {
                    Layout.fillWidth: true
                    label: "GPU"
                    value: sysRoot.sysInfo.gpu || "Detecting..."
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#F0F4F8" }

                StatRow {
                    Layout.fillWidth: true
                    label: "Kernel"
                    value: {
                        var ff = sysRoot.sysInfo.fastfetch
                        if (ff && Array.isArray(ff)) {
                            var k = ff.find(function(m) { return m.type === "Kernel" })
                            return k ? k.result : "Unknown"
                        }
                        return "Unknown"
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#F0F4F8" }

                StatRow {
                    Layout.fillWidth: true
                    label: "Desktop"
                    value: "KDE Plasma 6"
                }

                Item { Layout.fillHeight: true }
            }
        }

        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Button {
                text: "Update System"
                onClicked: backend.runCommand("konsole -e sudo pacman -Syu")
            }
            Button {
                text: "Driver Setup"
                onClicked: backend.runCommand("umao-driver-setup")
            }
            Button {
                text: "Audio Doctor"
                onClicked: backend.runCommand("umao-audio-doctor")
            }
        }
    }
}
