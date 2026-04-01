import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: navRoot
    color: "#12301a"

    property int currentIndex: 0
    signal pageSelected(int index)

    property var items: [
        { label: "Welcome", icon: "\u{1F3E0}" },
        { label: "Profiles", icon: "\u{26A1}" },
        { label: "Theme", icon: "\u{1F3A8}" },
        { label: "System", icon: "\u{1F4BB}" },
        { label: "About", icon: "\u{2139}" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 20
        spacing: 4

        Label {
            text: "UmaOS"
            color: "#f0f9f2"
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 16
        }

        Repeater {
            model: navRoot.items
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                radius: 8
                color: navRoot.currentIndex === index
                    ? "#42a54b"
                    : mouseArea.containsMouse ? "#1a3a20" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 10

                    Label {
                        text: modelData.icon
                        font.pixelSize: 16
                    }
                    Label {
                        text: modelData.label
                        color: "#f0f9f2"
                        font.pixelSize: 14
                        font.bold: navRoot.currentIndex === index
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: navRoot.pageSelected(index)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
