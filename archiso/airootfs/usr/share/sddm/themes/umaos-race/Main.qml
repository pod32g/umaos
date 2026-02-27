import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080

    Image {
        anchors.fill: parent
        source: config.Background
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        width: 520
        height: 420
        radius: 24
        color: "#8013274a"
        border.color: "#55ffffff"
        border.width: 1
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 36
            spacing: 14

            Label {
                text: "UmaOS"
                color: "#ffffff"
                font.pixelSize: 42
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: "Sign in"
                color: "#d8e7ff"
                font.pixelSize: 20
                Layout.alignment: Qt.AlignHCenter
            }

            ComboBox {
                id: userBox
                model: userModel
                textRole: "name"
                Layout.fillWidth: true
            }

            TextField {
                id: password
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                onAccepted: loginButton.clicked()
            }

            Button {
                id: loginButton
                text: "Start Session"
                Layout.fillWidth: true
                onClicked: sddm.login(userBox.currentText, password.text, sessionModel.lastIndex)
            }

            Label {
                id: message
                text: sddm.errorMessage
                color: "#ffd6e8"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
