import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: aboutRoot

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        width: Math.min(parent.width - 80, 480)

        Label {
            text: "UmaOS"
            font.pixelSize: 28
            font.bold: true
            color: "#0e1f14"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "An Arch Linux derivative with Uma Musume spirit."
            font.pixelSize: 14
            color: "#4A6A8A"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E8EEF4"
        }

        Label {
            text: "Legal Notice"
            font.pixelSize: 14
            font.bold: true
            color: "#0e1f14"
        }

        Label {
            text: "Uma Musume: Pretty Derby and related names, characters, logos, " +
                  "and media are owned by Cygames, Inc. and their respective " +
                  "rights holders.\n\n" +
                  "UmaOS is a fan project and is not affiliated with or endorsed " +
                  "by Cygames."
            font.pixelSize: 12
            color: "#4A6A8A"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "GitHub"
                flat: true
                palette.buttonText: "#42a54b"
                onClicked: backend.runCommand("xdg-open https://github.com/pod32g/umaos")
            }
            Button {
                text: "Report Issue"
                flat: true
                palette.buttonText: "#42a54b"
                onClicked: backend.runCommand("xdg-open https://github.com/pod32g/umaos/issues")
            }
        }
    }
}
