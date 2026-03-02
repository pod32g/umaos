import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0d1f3f"

    TextConstants {
        id: textConstants
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorMessage.color = "#8de1ff"
            errorMessage.text = textConstants.loginSucceeded
        }

        function onLoginFailed() {
            errorMessage.color = "#ffd6e8"
            errorMessage.text = textConstants.loginFailed
            password.text = ""
            password.focus = true
        }
    }

    Image {
        id: background
        anchors.fill: parent
        source: config.Background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        id: loginCard
        width: 560
        height: 460
        radius: 24
        anchors.centerIn: parent
        color: "#7a0f2c55"
        border.color: "#66ffffff"
        border.width: 1
    }

    Text {
        id: title
        text: "UmaOS"
        color: "#ffffff"
        font.pixelSize: 42
        font.bold: true
        anchors.top: loginCard.top
        anchors.topMargin: 26
        anchors.horizontalCenter: loginCard.horizontalCenter
    }

    Column {
        id: fields
        anchors.top: title.bottom
        anchors.topMargin: 18
        anchors.left: loginCard.left
        anchors.right: loginCard.right
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        spacing: 8

        Text {
            text: textConstants.userName
            color: "#d9e8ff"
            font.bold: true
            font.pixelSize: 14
        }

        TextBox {
            id: name
            width: parent.width
            height: 36
            text: userModel.lastUser
            font.pixelSize: 16
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(name.text, password.text, session.index)
                    event.accepted = true
                }
            }
        }

        Text {
            text: textConstants.password
            color: "#d9e8ff"
            font.bold: true
            font.pixelSize: 14
        }

        PasswordBox {
            id: password
            width: parent.width
            height: 36
            font.pixelSize: 16
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(name.text, password.text, session.index)
                    event.accepted = true
                }
            }
        }

        Text {
            text: textConstants.session
            color: "#d9e8ff"
            font.bold: true
            font.pixelSize: 14
        }

        ComboBox {
            id: session
            width: parent.width
            height: 36
            model: sessionModel
            index: sessionModel.lastIndex
        }

        Text {
            id: errorMessage
            width: parent.width
            text: sddm.errorMessage
            wrapMode: Text.WordWrap
            color: "#ffd6e8"
            font.pixelSize: 13
        }
    }

    Row {
        anchors.bottom: loginCard.bottom
        anchors.bottomMargin: 26
        anchors.horizontalCenter: loginCard.horizontalCenter
        spacing: 10

        Button {
            id: loginButton
            text: textConstants.login
            width: 150
            onClicked: sddm.login(name.text, password.text, session.index)
        }

        Button {
            id: rebootButton
            text: textConstants.reboot
            width: 120
            onClicked: sddm.reboot()
        }

        Button {
            id: shutdownButton
            text: textConstants.shutdown
            width: 120
            onClicked: sddm.powerOff()
        }
    }

    Component.onCompleted: {
        if (name.text === "") {
            name.focus = true
        } else {
            password.focus = true
        }
    }
}
