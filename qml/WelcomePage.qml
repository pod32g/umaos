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
            color: "#0e1f14"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Version " + backend.getVersion()
            font.pixelSize: 14
            color: "#3a5a3a"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "UmaOS is ready for you. Pick a setup profile on the next page,\nor jump straight in with the shortcuts below."
            font.pixelSize: 16
            color: "#3a5a3a"
            horizontalAlignment: Text.AlignHCenter
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
            color: "#0e1f14"
        }

        GridLayout {
            columns: 2
            rowSpacing: 12
            columnSpacing: 16
            Layout.fillWidth: true

            Repeater {
                model: [
                    { label: "\u{1F3AE} Install Uma Musume", cmd: "bash \"/etc/skel/Desktop/Install Uma Musume.sh\"" },
                    { label: "\u{1F6E0} Developer Setup", cmd: "umao-dev-setup" },
                    { label: "\u{1F400} Cursor Themes", cmd: "umao-cursor-switcher" },
                    { label: "\u{1F3A8} Change Wallpaper", cmd: "plasma-open-settings kcm_wallpaper" },
                    { label: "\u{1F4D6} Documentation", cmd: "xdg-open https://github.com/pod32g/umaos" },
                    { label: "\u{1F41B} Report a Bug", cmd: "xdg-open https://github.com/pod32g/umaos/issues" },
                    { label: "\u{2328} Open Terminal", cmd: "konsole" },
                    { label: "\u{2699} System Settings", cmd: "systemsettings" }
                ]

                delegate: Button {
                    text: modelData.label
                    Layout.fillWidth: true
                    flat: true
                    palette.buttonText: "#42a54b"
                    onClicked: backend.runCommand(modelData.cmd)
                }
            }
        }
    }
}
