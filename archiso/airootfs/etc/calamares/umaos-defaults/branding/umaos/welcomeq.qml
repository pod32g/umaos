import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Page {
    id: welcomePage
    readonly property color pageBackground: "#f7f8f4"
    readonly property color copyColor: "#203c29"
    readonly property color mutedCopyColor: "#5d7363"
    readonly property color borderColor: "#d9e7d8"
    readonly property color accentColor: "#4aad4b"
    readonly property real bodyContentWidth: Math.min(width - 88, 710)

    Rectangle {
        anchors.fill: parent
        color: pageBackground
    }

    Column {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        Rectangle {
            width: parent.width
            height: 146

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#56c658" }
                GradientStop { position: 0.68; color: "#46b24a" }
                GradientStop { position: 1.0; color: "#69d06d" }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#03140a" }
                    GradientStop { position: 0.34; color: "#0f2d17" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
                opacity: 0.88
            }

            Rectangle {
                width: 248
                height: 248
                radius: 124
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -78
                anchors.bottomMargin: -108
                color: "#efcad7"
                opacity: 0.3
            }

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Welcome to UmaOS")
                    color: "#ffffff"
                    font.pixelSize: 31
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("ウマ娘 プリティーダービー")
                    color: "#e8f5ea"
                    opacity: 0.9
                    font.pixelSize: 15
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Easy install. Fast desktop. Racing-idol inspired style.")
                    color: "#ffffff"
                    opacity: 0.78
                    font.pixelSize: 12
                }
            }
        }

        Item {
            width: parent.width
            height: bodyContent.height + 36

            Column {
                id: bodyContent
                x: 44
                y: 36
                width: bodyContentWidth
                spacing: 24

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("This installer will guide you through installing UmaOS on your computer. Please make sure you have backed up any important data before proceeding.")
                    color: copyColor
                    font.pixelSize: 14
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 22
                }

                Row {
                    spacing: 16

                    Rectangle {
                        width: 214
                        height: 88
                        radius: 10
                        border.width: 1
                        border.color: borderColor
                        color: "#fbfcfa"
                        visible: config.releaseNotesUrl !== ""

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Qt.openUrlExternally(config.releaseNotesUrl)
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            Text {
                                text: qsTr("RELEASE NOTES")
                                color: accentColor
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 0.8
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: qsTr("View the latest changes and known issues")
                                color: mutedCopyColor
                                font.pixelSize: 12
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 18
                            }
                        }
                    }

                    Rectangle {
                        width: 214
                        height: 88
                        radius: 10
                        border.width: 1
                        border.color: borderColor
                        color: "#fbfcfa"
                        visible: config.supportUrl !== ""

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Qt.openUrlExternally(config.supportUrl)
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            Text {
                                text: qsTr("SUPPORT")
                                color: accentColor
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 0.8
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: qsTr("Get help from the UmaOS community")
                                color: mutedCopyColor
                                font.pixelSize: 12
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 18
                            }
                        }
                    }

                    Rectangle {
                        width: 214
                        height: 88
                        radius: 10
                        border.width: 1
                        border.color: borderColor
                        color: "#fbfcfa"
                        visible: config.donateUrl !== ""

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Qt.openUrlExternally(config.donateUrl)
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            Text {
                                text: qsTr("DONATE")
                                color: accentColor
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 0.8
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: qsTr("Support the UmaOS project")
                                color: mutedCopyColor
                                font.pixelSize: 12
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 18
                            }
                        }
                    }
                }

                Row {
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Language:")
                        color: copyColor
                        font.pixelSize: 13
                        font.bold: true
                    }

                    ComboBox {
                        id: languages
                        width: 214
                        height: 36
                        model: config.languagesModel
                        textRole: "label"
                        currentIndex: config.localeIndex
                        onActivated: config.localeIndex = currentIndex

                        background: Rectangle {
                            radius: 6
                            color: "#ffffff"
                            border.width: 1
                            border.color: borderColor
                        }

                        contentItem: Text {
                            leftPadding: 12
                            rightPadding: 28
                            text: languages.displayText
                            color: copyColor
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        indicator: Text {
                            x: languages.width - width - 11
                            y: (languages.height - height) / 2
                            text: "\u25be"
                            color: "#8faa8e"
                            font.pixelSize: 11
                        }

                        popup: Popup {
                            y: languages.height + 4
                            width: languages.width
                            padding: 4

                            background: Rectangle {
                                radius: 8
                                color: "#ffffff"
                                border.width: 1
                                border.color: borderColor
                            }

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: languages.popup.visible ? languages.delegateModel : null
                                currentIndex: languages.highlightedIndex
                            }
                        }

                        delegate: ItemDelegate {
                            width: languages.width
                            height: 34
                            padding: 0
                            highlighted: languages.highlightedIndex === index

                            background: Rectangle {
                                color: highlighted ? "#eef6ee" : "#ffffff"
                                radius: 6
                            }

                            contentItem: Text {
                                text: model[languages.textRole]
                                color: copyColor
                                font.pixelSize: 12
                                leftPadding: 12
                                rightPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
