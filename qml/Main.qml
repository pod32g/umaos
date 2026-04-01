import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: root
    visible: true
    width: 860
    height: 580
    minimumWidth: 700
    minimumHeight: 480
    title: "UmaOS Welcome"
    color: "#f0f9f2"

    property bool wizardMode: backend.firstRun
    property int currentPage: 0
    property var pageNames: ["welcome", "profiles", "theme", "systeminfo", "about"]
    property int wizardPageCount: 3

    RowLayout {
        anchors.fill: parent
        spacing: 0

        NavBar {
            id: navBar
            visible: !root.wizardMode
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            currentIndex: root.currentPage
            onPageSelected: function(index) {
                root.currentPage = index
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage

                WelcomePage {}
                ProfilesPage {}
                ThemeManagerPage {}
                SystemInfoPage {}
                AboutPage {}
            }

            WizardBar {
                visible: root.wizardMode
                Layout.fillWidth: true
                currentPage: root.currentPage
                pageCount: root.wizardPageCount
                onNext: {
                    if (root.currentPage < root.wizardPageCount - 1) {
                        root.currentPage++
                    } else {
                        backend.markFirstRunDone()
                        root.wizardMode = false
                        root.currentPage = 0
                    }
                }
                onBack: {
                    if (root.currentPage > 0)
                        root.currentPage--
                }
            }
        }
    }
}
