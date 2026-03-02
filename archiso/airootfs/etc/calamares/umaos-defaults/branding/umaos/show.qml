import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2f74cc" }
                GradientStop { position: 1.0; color: "#ff91c0" }
            }
        }
        Text {
            anchors.centerIn: parent
            text: "Welcome to UmaOS"
            color: "#ffffff"
            font.pixelSize: 40
            font.bold: true
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#f7fbff"
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Easy install, KDE desktop, and a racing-idol inspired style." 
            color: "#173764"
            font.pixelSize: 28
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#11192e"
        }
        Image {
            anchors.centerIn: parent
            source: "ura_logo.png"
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.min(parent.width * 0.42, 520)
            sourceSize.height: Math.min(parent.height * 0.42, 520)
            smooth: true
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#132b4f"
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Theme assets and customization tools are included in UmaOS."
            color: "#d9e8ff"
            font.pixelSize: 24
        }
    }

    function onActivate() {
        presentation.currentSlide = 0
    }
}
