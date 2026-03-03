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
                GradientStop { position: 0.0; color: "#12301a" }
                GradientStop { position: 0.5; color: "#42a54b" }
                GradientStop { position: 1.0; color: "#ff91c0" }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 12
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
                color: "#e8f5ea"
                font.pixelSize: 22
                opacity: 0.85
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#f0f9f2"
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Easy install, KDE desktop, and a racing-idol inspired style."
            color: "#16302a"
            font.pixelSize: 28
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0e1f14"
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
            color: "#12301a"
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Theme assets and customization tools are included in UmaOS."
            color: "#d9f0e0"
            font.pixelSize: 24
        }
    }

    function onActivate() {
        presentation.currentSlide = 0
    }
}
