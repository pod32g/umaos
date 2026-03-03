import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0d1f16"

    TextConstants {
        id: textConstants
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorMessage.color = "#8de8a0"
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

    // Dark overlay to improve login card readability over busy artwork
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35
    }

    // Frosted glass login card
    Rectangle {
        id: loginCard
        width: 480
        height: 470
        radius: 20
        anchors.centerIn: parent
        color: "#b00c2418"
        border.color: "#40ffffff"
        border.width: 1

        // Subtle inner glow
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 19
            color: "transparent"
            border.color: "#10ffffff"
            border.width: 1
        }
    }

    Text {
        id: title
        text: "UmaOS"
        color: "#ffffff"
        font.pixelSize: 38
        font.bold: true
        anchors.top: loginCard.top
        anchors.topMargin: 28
        anchors.horizontalCenter: loginCard.horizontalCenter
    }

    Text {
        id: subtitle
        text: "\u30A6\u30DE\u5A18 \u30D7\u30EA\u30C6\u30A3\u30FC\u30C0\u30FC\u30D3\u30FC"
        color: "#ccff91c0"
        font.pixelSize: 12
        anchors.top: title.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: title.horizontalCenter
    }

    Column {
        id: fields
        anchors.top: subtitle.bottom
        anchors.topMargin: 24
        anchors.left: loginCard.left
        anchors.right: loginCard.right
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        spacing: 8

        Text {
            text: textConstants.userName
            color: "#d9f0e0"
            font.bold: true
            font.pixelSize: 13
        }

        TextBox {
            id: name
            width: parent.width
            height: 38
            text: userModel.lastUser
            font.pixelSize: 15
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(name.text, password.text, session.index)
                    event.accepted = true
                }
            }
        }

        Text {
            text: textConstants.password
            color: "#d9f0e0"
            font.bold: true
            font.pixelSize: 13
        }

        PasswordBox {
            id: password
            width: parent.width
            height: 38
            font.pixelSize: 15
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(name.text, password.text, session.index)
                    event.accepted = true
                }
            }
        }

        Text {
            text: textConstants.session
            color: "#d9f0e0"
            font.bold: true
            font.pixelSize: 13
        }

        ComboBox {
            id: session
            width: parent.width
            height: 38
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
        anchors.bottomMargin: 28
        anchors.horizontalCenter: loginCard.horizontalCenter
        spacing: 12

        Button {
            id: loginButton
            text: textConstants.login
            width: 140
            onClicked: sddm.login(name.text, password.text, session.index)
        }

        Button {
            id: rebootButton
            text: textConstants.reboot
            width: 110
            onClicked: sddm.reboot()
        }

        Button {
            id: shutdownButton
            text: textConstants.shutdown
            width: 110
            onClicked: sddm.powerOff()
        }
    }

    // Clock display in bottom-right corner
    Text {
        id: clock
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 24
        color: "#ccffffff"
        font.pixelSize: 14

        property var dateTime: new Date()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                clock.dateTime = new Date()
                clock.text = Qt.formatDateTime(clock.dateTime, "ddd, MMM d  ·  hh:mm AP")
            }
        }

        Component.onCompleted: {
            text = Qt.formatDateTime(dateTime, "ddd, MMM d  ·  hh:mm AP")
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
