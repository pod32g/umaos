import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

Item {
    id: root

    // ── Auth state ──
    property string errorText: ""

    // Background overlay — dark green tint so wallpaper shows dimmed
    Rectangle {
        anchors.fill: parent
        color: "#cc0e1f14"
    }

    // Subtle center glow
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.7
        height: parent.height * 0.7
        radius: width / 2
        color: "#1a3d24"
        opacity: 0.18
    }

    // ── Clock (top center) ──
    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.08
        spacing: 4

        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.pixelSize: Math.max(48, root.height * 0.065)
            font.weight: Font.Light
            font.family: "Noto Sans"
            font.letterSpacing: 2
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#aaffffff"
            font.pixelSize: Math.max(14, root.height * 0.02)
            font.weight: Font.Normal
            font.family: "Noto Sans"
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var now = new Date();
                clockText.text = Qt.formatTime(now, "hh:mm");
                dateText.text = Qt.formatDate(now, "dddd, MMMM d");
            }
        }
    }

    // ── Frosted glass card ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 320
        height: cardColumn.implicitHeight + 60
        radius: 16
        color: "#30ffffff"
        border.color: "#20ffffff"
        border.width: 1

        Column {
            id: cardColumn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30
            width: parent.width - 60
            spacing: 14

            // ── Circular avatar ──
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 80; height: 80

                // User face image (circular crop)
                Rectangle {
                    id: faceClip
                    anchors.fill: parent
                    radius: 40
                    clip: true
                    color: "transparent"
                    visible: faceImage.status === Image.Ready

                    Image {
                        id: faceImage
                        anchors.fill: parent
                        source: typeof kscreenlocker_userImage !== "undefined"
                                ? kscreenlocker_userImage : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                }

                // Fallback green circle with silhouette
                Rectangle {
                    id: avatarFallback
                    anchors.fill: parent
                    radius: 40
                    color: "#42a54b"
                    visible: !faceClip.visible

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.18
                        width: parent.width * 0.34
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        opacity: 0.7
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.58
                        width: parent.width * 0.58
                        height: parent.height * 0.36
                        radius: width / 2
                        color: "#ffffff"
                        opacity: 0.7
                    }
                }

                // Green ring around avatar
                Rectangle {
                    anchors.fill: parent
                    radius: 40
                    color: "transparent"
                    border.color: "#42a54b"
                    border.width: 2
                }
            }

            // ── Username ──
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: typeof kscreenlocker_userName !== "undefined"
                      ? kscreenlocker_userName : "User"
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.family: "Noto Sans"
            }

            // ── Password label ──
            Text {
                text: "Password"
                color: "#aaffffff"
                font.pixelSize: 11
                font.family: "Noto Sans"
            }

            // ── Password input (dark glass) ──
            QQC2.TextField {
                id: passwordInput
                width: parent.width
                height: 42
                echoMode: TextInput.Password
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Noto Sans"
                horizontalAlignment: TextInput.AlignLeft
                leftPadding: 14
                enabled: typeof authenticator !== "undefined" ? !authenticator.busy : true

                background: Rectangle {
                    radius: 10
                    color: passwordInput.activeFocus ? "#25ffffff" : "#20ffffff"
                    border.color: passwordInput.activeFocus ? "#42a54b" : "#30ffffff"
                    border.width: 1
                }

                Keys.onReturnPressed: startAuth()
                Keys.onEnterPressed: startAuth()
            }

            // ── Error message ──
            Text {
                id: errorLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.errorText
                color: "#ff6b6b"
                font.pixelSize: 12
                font.family: "Noto Sans"
                visible: text !== ""
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            // ── Unlock button ──
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 40
                radius: 10
                color: unlockMouse.containsMouse ? "#4db85a" : "#42a54b"

                Text {
                    anchors.centerIn: parent
                    text: "Unlock"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.family: "Noto Sans"
                }

                MouseArea {
                    id: unlockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: startAuth()
                }
            }
        }
    }

    // ── Authentication logic ──
    function startAuth() {
        if (typeof authenticator === "undefined") return;
        root.errorText = "";
        authenticator.startAuthenticating();
    }

    Connections {
        target: typeof authenticator !== "undefined" ? authenticator : null

        function onPromptForSecretChanged() {
            if (authenticator.promptForSecret) {
                authenticator.respond(passwordInput.text);
            }
        }

        function onSucceeded() {
            Qt.quit();
        }

        function onFailed() {
            root.errorText = "Authentication failed. Try again.";
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }

        function onInfoMessageChanged() {
            if (authenticator.infoMessage) {
                root.errorText = authenticator.infoMessage;
            }
        }

        function onErrorMessageChanged() {
            if (authenticator.errorMessage) {
                root.errorText = authenticator.errorMessage;
            }
        }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
    }
}
