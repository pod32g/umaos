import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: sideBar
    anchors.fill: parent
    color: "#082012"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#02130a" }
            GradientStop { position: 1.0; color: "#08301a" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 118

            Column {
                anchors.centerIn: parent
                spacing: 10

                Image {
                    width: 72
                    height: 72
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "ura_logo_sidebar.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("UmaOS Installer")
                    color: "#eff7f0"
                    font.pixelSize: 15
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#42a54b"
            opacity: 0.22
        }

        Column {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            topPadding: 18

            Repeater {
                model: ViewManager

                Rectangle {
                    width: sideBar.width
                    height: 48
                    color: index === ViewManager.currentStepIndex ? "#49ad4b" : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        spacing: 11

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: index === ViewManager.currentStepIndex ? "#3e9841" : "transparent"
                            border.width: 1
                            border.color: index === ViewManager.currentStepIndex ? "#3e9841" : "#32553c"

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1).toString()
                                color: index === ViewManager.currentStepIndex ? "#112816" : "#a2c2a7"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: display
                            color: index === ViewManager.currentStepIndex ? "#112816" : "#d7e4d8"
                            font.pixelSize: 13
                            font.bold: index === ViewManager.currentStepIndex
                            opacity: index === ViewManager.currentStepIndex ? 1.0 : 0.92
                        }
                    }
                }
            }
        }
    }
}
