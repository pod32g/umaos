import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: profilesRoot

    property var selectedProfiles: ({})
    property var profiles: []

    Component.onCompleted: {
        var data = backend.loadProfiles()
        profiles = JSON.parse(data)
    }

    property var iconMap: ({
        "Gaming": "\u{1F3AE}",
        "Creator": "\u{1F3AC}",
        "Laptop": "\u{1F4BB}",
        "Developer": "\u{1F6E0}"
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Label {
            text: "Choose Your Setup"
            font.pixelSize: 24
            font.bold: true
            color: "#132B4F"
        }

        Label {
            text: "Select one or more profiles. You can always change this later."
            font.pixelSize: 14
            color: "#4A6A8A"
        }

        GridLayout {
            columns: 2
            rowSpacing: 16
            columnSpacing: 16
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: profilesRoot.profiles
                delegate: ProfileCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    profileName: modelData.name || ""
                    profileDesc: modelData.description || ""
                    profileIcon: profilesRoot.iconMap[modelData.name] || "\u{1F4E6}"
                    selected: !!profilesRoot.selectedProfiles[modelData.name]
                    onToggled: {
                        var s = profilesRoot.selectedProfiles
                        if (s[modelData.name]) {
                            delete s[modelData.name]
                        } else {
                            s[modelData.name] = true
                        }
                        profilesRoot.selectedProfiles = s
                    }
                }
            }
        }
    }
}
