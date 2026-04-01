import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    radius: 12
    color: selected ? "#EBF2FF" : "#FFFFFF"
    border.color: selected ? "#2F74CC" : "#E0E8F0"
    border.width: selected ? 2 : 1

    property string profileName: ""
    property string profileDesc: ""
    property string profileIcon: ""
    property bool selected: false
    signal toggled()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.toggled()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Label {
            text: card.profileIcon
            font.pixelSize: 28
        }

        Label {
            text: card.profileName
            font.pixelSize: 16
            font.bold: true
            color: "#132B4F"
        }

        Label {
            text: card.profileDesc
            font.pixelSize: 12
            color: "#4A6A8A"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: card.selected ? "#2F74CC" : "transparent"
            border.color: card.selected ? "#2F74CC" : "#C0C8D0"
            border.width: 2
            Layout.alignment: Qt.AlignRight

            Label {
                anchors.centerIn: parent
                text: "\u2713"
                color: "#FFFFFF"
                font.pixelSize: 14
                visible: card.selected
            }
        }
    }
}
