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

    // ── Slide 1: Welcome ──
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
            spacing: 14
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome to UmaOS"
                color: "#ffffff"
                font.pixelSize: 42
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u30A6\u30DE\u5A18 \u30D7\u30EA\u30C6\u30A3\u30FC\u30C0\u30FC\u30D3\u30FC"
                color: "#e8f5ea"
                font.pixelSize: 20
                opacity: 0.9
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Easy install. Fast desktop. Racing-idol inspired style."
                color: "#ffffff"
                font.pixelSize: 14
                opacity: 0.7
            }
        }
    }

    // ── Slide 2: Features ──
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#f0f9f2"
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.75
            spacing: 24
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "What's Inside"
                color: "#1a3d24"
                font.pixelSize: 30
                font.bold: true
            }
            Column {
                width: parent.width
                spacing: 14
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "\u2714  KDE Plasma 6 desktop with custom UmaOS theme"
                    color: "#2a5e34"
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "\u2714  Video wallpaper and Uma Musume artwork collection"
                    color: "#2a5e34"
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "\u2714  One-click game installer with Steam and Proton"
                    color: "#2a5e34"
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "\u2714  Auto GPU driver setup and audio diagnostics"
                    color: "#2a5e34"
                    font.pixelSize: 16
                }
            }
        }
    }

    // ── Slide 3: Logo ──
    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0e1f14" }
                GradientStop { position: 1.0; color: "#12301a" }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 20
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "ura_logo.png"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.min(parent.parent.width * 0.35, 400)
                sourceSize.height: Math.min(parent.parent.height * 0.35, 400)
                smooth: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "UmaOS"
                color: "#e8f5ea"
                font.pixelSize: 24
                font.bold: true
                opacity: 0.9
            }
        }
    }

    // ── Slide 4: Getting Started ──
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#12301a"
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.75
            spacing: 20
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Getting Started"
                color: "#e8f5ea"
                font.pixelSize: 28
                font.bold: true
            }
            Column {
                width: parent.width
                spacing: 12
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "After installation, your desktop will be fully customized with the UmaOS theme, wallpapers, and tools."
                    color: "#d9f0e0"
                    font.pixelSize: 15
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Run the 'Install Uma Musume' shortcut on your desktop to set up the game with Steam and Proton."
                    color: "#b0d8b8"
                    font.pixelSize: 14
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Use 'sudo uma-update' to sync the latest UmaOS scripts from GitHub at any time."
                    color: "#b0d8b8"
                    font.pixelSize: 14
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Umazing!"
                color: "#42a54b"
                font.pixelSize: 22
                font.bold: true
                opacity: 0.9
            }
        }
    }

    function onActivate() {
        presentation.currentSlide = 0
    }
}
