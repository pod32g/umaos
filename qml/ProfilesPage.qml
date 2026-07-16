import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: profilesRoot

    property var selectedProfiles: ({})
    property var profiles: []
    property bool applying: false
    property string resultMessage: ""
    // Set from the backend's structured status/failures fields rather than by
    // sniffing the message text for the word "success".
    property bool failed: false

    Component.onCompleted: {
        // A malformed payload here used to throw and leave the page blank
        // with no explanation.
        try {
            profiles = JSON.parse(backend.loadProfiles())
        } catch (e) {
            profiles = []
            profilesRoot.resultMessage = "Could not load setup profiles."
        }
    }

    Connections {
        target: backend
        function onApplyFinished(result) {
            // Guarded: a single non-JSON line would otherwise throw here and
            // leave `applying` true forever — spinner stuck, cards disabled,
            // and no way to retry.
            var parsed
            try {
                parsed = JSON.parse(result)
            } catch (e) {
                parsed = { message: "Profile application returned an unreadable result." }
            }
            profilesRoot.resultMessage = parsed.message || "Done"
            profilesRoot.failed = !!(parsed.failures && parsed.failures.length) ||
                                  parsed.status === "error"
            profilesRoot.applying = false
        }
        function onCommandFailed(msg) {
            profilesRoot.resultMessage = msg
            profilesRoot.failed = true
        }
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
            color: "#0e1f14"
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
                    enabled: !profilesRoot.applying
                    onToggled: {
                        var s = profilesRoot.selectedProfiles
                        if (s[modelData.name]) {
                            delete s[modelData.name]
                        } else {
                            s[modelData.name] = true
                        }
                        profilesRoot.selectedProfiles = s
                        profilesRoot.resultMessage = ""
                    }
                }
            }
        }

        Label {
            visible: profilesRoot.resultMessage !== ""
            text: profilesRoot.resultMessage
            font.pixelSize: 13
            color: profilesRoot.failed ? "#C62828" : "#2E7D32"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            BusyIndicator {
                visible: profilesRoot.applying
                running: profilesRoot.applying
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
            }

            Button {
                text: profilesRoot.applying ? "Applying..." : "Apply Selected Profiles"
                enabled: !profilesRoot.applying && Object.keys(profilesRoot.selectedProfiles).length > 0
                highlighted: true
                palette.button: "#42a54b"
                palette.buttonText: "#FFFFFF"
                onClicked: {
                    var names = Object.keys(profilesRoot.selectedProfiles)
                    profilesRoot.applying = true
                    profilesRoot.resultMessage = ""
                    profilesRoot.failed = false
                    // Async: result arrives via backend.applyFinished
                    backend.applyProfiles(JSON.stringify(names))
                }
            }
        }
    }
}
