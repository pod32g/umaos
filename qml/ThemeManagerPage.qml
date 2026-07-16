import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: themeRoot

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            // anchors.margins are no-ops without anchors; inset via x/width
            // so this page matches the other pages' 32 px padding.
            x: 32
            y: 32
            width: parent.width - 64
            spacing: 24

            Label {
                text: "Theme Manager"
                font.pixelSize: 24
                font.bold: true
                color: "#0e1f14"
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
                            color: "#0e1f14"
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
                        // Reflect the real system state instead of a
                        // hardcoded ON (set in onCompleted, and onToggled
                        // instead of onCheckedChanged, so no command fires
                        // during initialization).
                        Component.onCompleted: checked = backend.videoWallpaperEnabled()
                        onToggled: {
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
                            color: "#0e1f14"
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
                            color: "#0e1f14"
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
