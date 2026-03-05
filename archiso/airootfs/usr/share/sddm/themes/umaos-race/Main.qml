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

    // Dark overlay for readability
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35
    }

    // ── Top-left branding ──
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 36
        anchors.leftMargin: 40
        spacing: 4

        Text {
            text: "UmaOS"
            color: "#ffffff"
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            text: "\u30A6\u30DE\u5A18 \u30D7\u30EA\u30C6\u30A3\u30FC\u30C0\u30FC\u30D3\u30FC"
            color: "#7ab882"
            font.pixelSize: 12
        }
    }

    // ── Frosted glass login card ──
    Rectangle {
        id: loginCard
        width: 380
        height: 440
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

    // ── Helper: look up user face icon from userModel ──
    function getUserIcon(username) {
        for (var i = 0; i < userModel.count; i++) {
            if (userModel.data(userModel.index(i, 0), Qt.UserRole + 1) === username) {
                var icon = userModel.data(userModel.index(i, 0), Qt.UserRole + 4);
                if (icon && icon.toString() !== "")
                    return icon;
            }
        }
        return "";
    }

    // ── Avatar ──
    Item {
        id: avatar
        width: 96
        height: 96
        anchors.horizontalCenter: loginCard.horizontalCenter
        anchors.top: loginCard.top
        anchors.topMargin: 30

        // Face image (hidden — used as ShaderEffect source)
        Image {
            id: faceImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: true
            cache: false
            visible: false

            // Fallback chain: userModel → sddm/faces → AccountsService
            property int attempt: 0
            property var sources: {
                var user = name.text;
                if (!user || user === "") return [];
                var list = [];
                var modelIcon = getUserIcon(user);
                if (modelIcon !== "") list.push(modelIcon);
                list.push("/usr/share/sddm/faces/" + user + ".face.icon");
                list.push("/var/lib/AccountsService/icons/" + user);
                return list;
            }

            source: attempt < sources.length ? sources[attempt] : ""

            onStatusChanged: {
                if (status === Image.Error && attempt < sources.length - 1)
                    attempt++;
            }
        }

        // Reset fallback chain when username changes
        Connections {
            target: name
            function onTextChanged() { faceImage.attempt = 0; }
        }

        // Circular clip via inline GLSL shader (Qt5 ShaderEffect).
        // Discards pixels outside a circle of radius 0.5 in UV space.
        ShaderEffect {
            anchors.fill: parent
            visible: faceImage.status === Image.Ready
            property variant src: faceImage

            fragmentShader: "
                varying highp vec2 qt_TexCoord0;
                uniform sampler2D src;
                uniform lowp float qt_Opacity;
                void main() {
                    highp vec2 uv = qt_TexCoord0 - vec2(0.5);
                    if (length(uv) > 0.5)
                        discard;
                    gl_FragColor = texture2D(src, qt_TexCoord0) * qt_Opacity;
                }
            "
        }

        // Circular border ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: "#40ffffff"
            border.width: 2
            visible: faceImage.status === Image.Ready
        }

        // Fallback: green circle with placeholder silhouette
        Rectangle {
            id: avatarFallback
            anchors.fill: parent
            radius: width / 2
            color: "#42a54b"
            visible: faceImage.status !== Image.Ready
            border.color: "#40ffffff"
            border.width: 2

            // Head
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 22
                width: 26
                height: 26
                radius: 13
                color: "transparent"
                border.color: "#ffffff"
                border.width: 2
            }
            // Shoulders
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                width: 42
                height: 20
                radius: 10
                color: "transparent"
                border.color: "#ffffff"
                border.width: 2
            }
        }
    }

    // Track whether we're editing the username
    property bool editingUsername: userModel.lastUser === ""

    // ── Username display (click to edit) ──
    Text {
        id: usernameLabel
        anchors.horizontalCenter: loginCard.horizontalCenter
        anchors.top: avatar.bottom
        anchors.topMargin: 14
        text: name.text !== "" ? name.text : "User"
        color: "#ffffff"
        font.pixelSize: 18
        font.bold: true
        visible: !editingUsername

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                editingUsername = true
                name.focus = true
            }
        }
    }

    // ── Username input (shown when editing) ──
    Column {
        id: nameColumn
        anchors.horizontalCenter: loginCard.horizontalCenter
        anchors.top: avatar.bottom
        anchors.topMargin: 8
        width: loginCard.width - 80
        spacing: 6
        visible: editingUsername

        Text {
            text: textConstants.userName
            color: "#80ffffff"
            font.pixelSize: 11
        }
        TextBox {
            id: name
            width: parent.width
            height: 44
            font.pixelSize: 15
            text: userModel.lastUser
            color: "#20ffffff"
            borderColor: "#30ffffff"
            focusColor: "#42a54b"
            hoverColor: "#25ffffff"
            textColor: "#ffffff"
            radius: 10
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (name.text !== "") {
                        editingUsername = false
                    }
                    password.focus = true
                    event.accepted = true
                }
            }
        }
    }

    // ── Login fields ──
    Column {
        id: fields
        anchors.top: editingUsername ? nameColumn.bottom : usernameLabel.bottom
        anchors.topMargin: 14
        anchors.horizontalCenter: loginCard.horizontalCenter
        width: loginCard.width - 80
        spacing: 14

        // Password input
        Column {
            width: parent.width
            spacing: 6

            Text {
                text: textConstants.password
                color: "#80ffffff"
                font.pixelSize: 11
            }
            PasswordBox {
                id: password
                width: parent.width
                height: 44
                font.pixelSize: 15
                color: "#20ffffff"
                borderColor: "#30ffffff"
                focusColor: "#42a54b"
                hoverColor: "#25ffffff"
                textColor: "#ffffff"
                radius: 10
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(name.text, password.text, session.index)
                        event.accepted = true
                    }
                }
            }
        }

        // Full-width Log In button
        Rectangle {
            width: parent.width
            height: 46
            radius: 10
            color: loginButtonArea.pressed ? "#2e8838" : loginButtonArea.containsMouse ? "#4db856" : "#42a54b"

            Text {
                anchors.centerIn: parent
                text: textConstants.login
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
            }

            MouseArea {
                id: loginButtonArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.login(name.text, password.text, session.index)
            }
        }

        // Session selector (click to cycle)
        Text {
            id: sessionLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var idx = session.index;
                var sName = (idx >= 0 && idx < sessionModel.count)
                    ? sessionModel.data(sessionModel.index(idx, 0), Qt.DisplayRole)
                    : "";
                return textConstants.session + ": " + (sName || "Default") + " \u25BE";
            }
            color: sessionMouseArea.containsMouse ? "#b0ffffff" : "#80ffffff"
            font.pixelSize: 12

            MouseArea {
                id: sessionMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    session.index = (session.index + 1) % sessionModel.count;
                }
            }
        }

        Text {
            id: errorMessage
            width: parent.width
            text: ""
            wrapMode: Text.WordWrap
            color: "#ffd6e8"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Hidden session selector for SDDM API
    ComboBox {
        id: session
        visible: false
        model: sessionModel
        index: sessionModel.lastIndex
    }

    // ── Clock display — bottom-right ──
    Column {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 32
        anchors.rightMargin: 40
        spacing: 4

        property var dateTime: new Date()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                parent.dateTime = new Date()
            }
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(parent.dateTime, "HH:mm")
            color: "#ffffff"
            font.pixelSize: 56
            font.weight: Font.Light
            opacity: 0.85
        }
        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(parent.dateTime, "dddd, MMMM d, yyyy")
            color: "#ffffff"
            font.pixelSize: 14
            opacity: 0.6
        }
    }

    // ── Power buttons — bottom-left ──
    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 36
        anchors.leftMargin: 40
        spacing: 16

        Text {
            text: "\u23FB"
            color: "#80ffffff"
            font.pixelSize: 18
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
        Text {
            text: "\u21BB"
            color: "#80ffffff"
            font.pixelSize: 18
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }
    }

    Component.onCompleted: {
        if (editingUsername) {
            name.focus = true
        } else {
            password.focus = true
        }
    }
}
