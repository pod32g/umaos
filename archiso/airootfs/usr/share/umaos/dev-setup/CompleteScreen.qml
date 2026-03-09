import QtQuick
import QtQuick.Controls as QQC2

Item {
    id: root
    property string summary: ""
    property string warning: ""

    Column {
        anchors.centerIn: parent
        spacing: 20
        width: parent.width - 72

        // Green checkmark circle
        Item {
            width: 64
            height: 64
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent
                radius: 32
                color: Qt.rgba(0.26, 0.65, 0.29, 0.15)
            }

            Canvas {
                anchors.centerIn: parent
                width: 32
                height: 32
                onPaint: {
                    var ctx = getContext("2d")
                    // Circle outline
                    ctx.strokeStyle = Theme.primaryGreen
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    ctx.arc(16, 16, 14, 0, 2 * Math.PI)
                    ctx.stroke()
                    // Checkmark
                    ctx.lineWidth = 2.5
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(10, 16)
                    ctx.lineTo(14.5, 20.5)
                    ctx.lineTo(22, 12)
                    ctx.stroke()
                }
            }
        }

        // Title
        Text {
            text: "Umazing!"
            font.family: Theme.sansFont
            font.pixelSize: 24
            font.weight: Font.Bold
            font.letterSpacing: -0.3
            color: Theme.textPrimary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Summary
        Text {
            text: root.summary
            font.family: Theme.sansFont
            font.pixelSize: 14
            color: Theme.textMuted
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            lineHeight: 1.4
        }

        // AUR warning (if applicable)
        Text {
            visible: root.warning !== ""
            text: root.warning
            font.family: Theme.sansFont
            font.pixelSize: 12
            color: "#ffdc8c"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Close button
        Rectangle {
            width: closeText.width + 56
            height: 40
            radius: 8
            color: Theme.primaryGreen
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: closeText
                anchors.centerIn: parent
                text: "Close"
                font.family: Theme.sansFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.nearBlack
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.quit()
            }
        }
    }
}
