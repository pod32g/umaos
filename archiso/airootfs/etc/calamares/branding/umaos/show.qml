import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#13301b" }
                GradientStop { position: 0.58; color: "#42a54b" }
                GradientStop { position: 1.0; color: "#77d370" }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#07110a"
            opacity: 0.18
        }

        Rectangle {
            width: Math.max(parent.width * 0.72, 420)
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -width * 0.18
            anchors.bottomMargin: -height * 0.15
            color: "#f0bfd7"
            opacity: 0.42
        }

        Rectangle {
            width: Math.max(parent.width * 0.58, 360)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: -width * 0.34
            anchors.topMargin: -height * 0.26
            color: "#092113"
            opacity: 0.32
        }

        Column {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome to UmaOS"
                color: "#ffffff"
                font.pixelSize: 40
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ウマ娘 プリティーダービー"
                color: "#edf8ee"
                opacity: 0.9
                font.pixelSize: 22
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Repeater {
                    model: 4
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#ffffff"
                        opacity: index === 0 ? 0.95 : 0.42
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Easy install. Fast desktop. Racing-idol inspired style."
                color: "#ffffff"
                opacity: 0.72
                font.pixelSize: 14
            }
        }
    }

    function onActivate() {
        presentation.currentSlide = 0
    }
}
