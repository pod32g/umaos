import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.15

Rectangle {
    id: navigationBar
    height: 62
    color: "#f2f6f0"
    border.color: "#d9e7d8"
    border.width: 1

    function displayLabel(rawLabel) {
        return rawLabel ? rawLabel.replace(/&/g, "") : "";
    }

    function actionButton(buttonText, enabled, isPrimary, clickedFn) {
        return null;
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 22
        spacing: 10

        Rectangle {
            visible: ViewManager.backAndNextVisible
            width: 84
            height: 32
            radius: 7
            color: backMouse.pressed ? "#edf3ed" : "#ffffff"
            border.width: 1
            border.color: ViewManager.backEnabled ? "#c7d8c7" : "#d9e7d8"
            opacity: ViewManager.backEnabled ? 1.0 : 0.52

            Text {
                anchors.centerIn: parent
                text: navigationBar.displayLabel(ViewManager.backLabel)
                color: "#6d8571"
                font.pixelSize: 12
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                enabled: ViewManager.backEnabled
                onClicked: ViewManager.back()
            }
        }

        Rectangle {
            visible: ViewManager.backAndNextVisible
            width: 95
            height: 32
            radius: 7
            color: nextMouse.pressed ? "#399341" : "#49ad4b"
            border.width: 1
            border.color: "#3d9842"
            opacity: ViewManager.nextEnabled ? 1.0 : 0.55

            Text {
                anchors.centerIn: parent
                text: navigationBar.displayLabel(ViewManager.nextLabel)
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                enabled: ViewManager.nextEnabled
                onClicked: ViewManager.next()
            }
        }

        Rectangle {
            visible: ViewManager.quitVisible
            width: 84
            height: 32
            radius: 7
            color: quitMouse.pressed ? "#edf3ed" : "#ffffff"
            border.width: 1
            border.color: ViewManager.quitEnabled ? "#c7d8c7" : "#d9e7d8"
            opacity: ViewManager.quitEnabled ? 1.0 : 0.52

            Text {
                anchors.centerIn: parent
                text: navigationBar.displayLabel(ViewManager.quitLabel)
                color: "#325039"
                font.pixelSize: 12
            }

            MouseArea {
                id: quitMouse
                anchors.fill: parent
                enabled: ViewManager.quitEnabled
                onClicked: ViewManager.quit()
            }
        }
    }
}
