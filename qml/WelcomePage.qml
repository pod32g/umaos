import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: welcomeRoot

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        width: Math.min(parent.width - 80, 500)

        Label {
            text: "Welcome, Trainer!"
            font.pixelSize: 32
            font.bold: true
            color: "#132B4F"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Version " + backend.getVersion()
            font.pixelSize: 14
            color: "#4A6A8A"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "UmaOS is ready for you."
            font.pixelSize: 16
            color: "#4A6A8A"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E8EEF4"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        Label {
            text: "Quick Links"
            font.pixelSize: 14
            font.bold: true
            color: "#132B4F"
        }

        GridLayout {
            columns: 2
            rowSpacing: 12
            columnSpacing: 16
            Layout.fillWidth: true

            Repeater {
                model: [
                    { label: "Documentation", cmd: "xdg-open https://github.com/pod32g/umaos" },
                    { label: "Report a Bug", cmd: "xdg-open https://github.com/pod32g/umaos/issues" },
                    { label: "Open Terminal", cmd: "konsole" },
                    { label: "System Settings", cmd: "systemsettings" }
                ]

                delegate: Button {
                    text: modelData.label
                    Layout.fillWidth: true
                    flat: true
                    palette.buttonText: "#2F74CC"
                    onClicked: backend.runCommand(modelData.cmd)
                }
            }
        }
    }
}
