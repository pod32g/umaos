import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: themeRoot

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            anchors.margins: 32
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.topMargin: 32
            spacing: 24

            Label {
                text: "Theme Manager"
                font.pixelSize: 24
                font.bold: true
                color: "#132B4F"
            }

            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 12
                color: "#FFFFFF"
                border.color: "#E0E8F0"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        spacing: 4
                        Label {
                            text: "Video Wallpaper"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#132B4F"
                        }
                        Label {
                            text: "Use animated video as desktop background"
                            font.pixelSize: 12
                            color: "#4A6A8A"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Switch {
                        id: videoToggle
                        checked: true
                        onCheckedChanged: {
                            if (checked) {
                                backend.runCommand("umao-apply-theme --video")
                            } else {
                                backend.runCommand("umao-apply-theme --no-video")
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 12
                color: "#FFFFFF"
                border.color: "#E0E8F0"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        spacing: 4
                        Label {
                            text: "UmaOS Sounds"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#132B4F"
                        }
                        Label {
                            text: "Custom notification and system sounds"
                            font.pixelSize: 12
                            color: "#4A6A8A"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Switch {
                        id: soundToggle
                        checked: false
                        enabled: false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 12
                color: "#FFFFFF"
                border.color: "#E0E8F0"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        spacing: 4
                        Label {
                            text: "Cursor Theme"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#132B4F"
                        }
                        Label {
                            text: "Change your mouse cursor style"
                            font.pixelSize: 12
                            color: "#4A6A8A"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Change"
                        onClicked: backend.runCommand("umao-cursor-switcher")
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
