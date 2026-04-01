import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: wizardBar
    height: 64
    color: "#FFFFFF"

    property int currentPage: 0
    property int pageCount: 5
    signal next()
    signal back()

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: "#E0E0E0"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        Button {
            text: "Back"
            visible: wizardBar.currentPage > 0
            flat: true
            onClicked: wizardBar.back()
        }

        Item { Layout.fillWidth: true }

        Row {
            spacing: 8
            Repeater {
                model: wizardBar.pageCount
                delegate: Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: index <= wizardBar.currentPage ? "#2F74CC" : "#D0D0D0"
                }
            }
        }

        Item { Layout.fillWidth: true }

        Button {
            text: wizardBar.currentPage === wizardBar.pageCount - 1
                ? "Get Started!"
                : "Next"
            highlighted: true
            palette.button: "#2F74CC"
            palette.buttonText: "#FFFFFF"
            onClicked: wizardBar.next()
        }
    }
}
