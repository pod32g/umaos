import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

Item {
    id: root

    // Active tab
    property string activeTab: "languages"

    // Track selection state; bump version to trigger binding re-eval
    property var selectedTags: ({})
    property int selectionVersion: 0

    function isSelected(tag) {
        void selectionVersion  // force dependency
        return selectedTags[tag] === true
    }

    function toggleTag(tag) {
        if (selectedTags[tag])
            delete selectedTags[tag]
        else
            selectedTags[tag] = true
        selectionVersion++
    }

    function selectedCount() {
        void selectionVersion
        var n = 0
        for (var k in selectedTags) if (selectedTags[k]) n++
        return n
    }

    function totalPackages() {
        void selectionVersion
        var pkgs = {}
        var stacks = backend.stacks
        for (var i = 0; i < stacks.length; i++) {
            if (selectedTags[stacks[i].tag]) {
                var list = stacks[i].packages
                for (var j = 0; j < list.length; j++)
                    pkgs[list[j]] = true
            }
        }
        var n = 0
        for (var p in pkgs) n++
        return n
    }

    function getSelectedTagList() {
        var tags = []
        for (var k in selectedTags)
            if (selectedTags[k]) tags.push(k)
        return tags
    }

    function tabLabel(cat) {
        if (cat === "languages") return "Languages"
        if (cat === "editors") return "Editors"
        if (cat === "ai") return "AI"
        if (cat === "devops") return "DevOps"
        if (cat === "data") return "Data"
        return cat
    }

    // ── Header ──
    Column {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 36
        spacing: 6

        Text {
            text: "UMAOS"
            font.family: Theme.sansFont
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: 0.8
            color: Theme.primaryGreen
        }
        Text {
            text: "Dev Setup"
            font.family: Theme.sansFont
            font.pixelSize: 28
            font.weight: Font.Bold
            font.letterSpacing: -0.3
            color: Theme.textPrimary
        }
        Text {
            text: "Select development stacks to install on your system."
            font.family: Theme.sansFont
            font.pixelSize: 14
            color: Theme.textMuted
        }
    }

    // ── Tab bar ──
    Column {
        id: tabBar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20
        spacing: 0

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 36
            spacing: 0

            Repeater {
                model: backend.categories
                delegate: Item {
                    width: tabText.width + 32
                    height: tabText.height + 18

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: root.tabLabel(modelData)
                        font.family: Theme.sansFont
                        font.pixelSize: 13
                        font.weight: modelData === root.activeTab ? Font.DemiBold : Font.Medium
                        color: modelData === root.activeTab ? Theme.primaryGreen : Theme.textMuted
                    }

                    // Active underline
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tabText.width + 8
                        height: 2
                        radius: 1
                        color: Theme.primaryGreen
                        visible: modelData === root.activeTab
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = modelData
                    }
                }
            }
        }

        // Divider
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.divider
        }
    }

    // ── Stack list ──
    ListView {
        id: stackList
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.topMargin: 12
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 8
        clip: true
        spacing: 6
        model: backend.stacks

        delegate: Rectangle {
            id: rowDelegate
            width: stackList.width
            height: modelData.category === root.activeTab ? 64 : 0
            visible: modelData.category === root.activeTab
            radius: 10
            color: root.isSelected(modelData.tag) ? Theme.cardBg : "transparent"
            clip: true

            property bool checked: root.isSelected(modelData.tag)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 14

                // Checkbox
                Item {
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: rowDelegate.checked ? Theme.primaryGreen : "transparent"
                        border.width: rowDelegate.checked ? 0 : 1.5
                        border.color: Theme.borderGreen

                        // Checkmark
                        Canvas {
                            anchors.centerIn: parent
                            width: 12
                            height: 10
                            visible: rowDelegate.checked
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.strokeStyle = Theme.nearBlack
                                ctx.lineWidth = 2
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                ctx.moveTo(1, 5)
                                ctx.lineTo(4.5, 8.5)
                                ctx.lineTo(11, 1.5)
                                ctx.stroke()
                            }
                        }
                    }
                }

                // Text content
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    width: parent.width - 50

                    Row {
                        spacing: 8
                        Text {
                            text: modelData.displayName
                            font.family: Theme.sansFont
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: rowDelegate.checked ? Theme.textPrimary : Theme.textSecondary
                        }
                        // Installed badge
                        Rectangle {
                            visible: modelData.installed
                            width: installedLabel.width + 16
                            height: installedLabel.height + 4
                            radius: 4
                            color: Qt.rgba(1.0, 0.569, 0.753, 0.12)
                            anchors.verticalCenter: parent.children[0].verticalCenter

                            Text {
                                id: installedLabel
                                anchors.centerIn: parent
                                text: "Installed"
                                font.family: Theme.sansFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.pinkAccent
                            }
                        }
                    }

                    Text {
                        text: modelData.packages.join("  ")
                        font.family: Theme.monoFont
                        font.pixelSize: 12
                        color: rowDelegate.checked ? Theme.textDim : Theme.faintGreen
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTag(modelData.tag)
            }
        }
    }

    // ── Footer ──
    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 72
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.divider
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 36
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.selectedCount() > 0
                    ? root.selectedCount() + " stacks selected  \u00b7  " + root.totalPackages() + " packages"
                    : "No stacks selected"
                font.family: Theme.sansFont
                font.pixelSize: 13
                color: Theme.dimGreen
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 36
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Cancel button
            Rectangle {
                width: cancelText.width + 40
                height: 40
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: Theme.borderGreen

                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.family: Theme.sansFont
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.textMuted
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }

            // Install button
            Rectangle {
                width: installText.width + 48
                height: 40
                radius: 8
                color: root.selectedCount() > 0 ? Theme.primaryGreen : Theme.borderGreen
                opacity: root.selectedCount() > 0 ? 1.0 : 0.5

                Text {
                    id: installText
                    anchors.centerIn: parent
                    text: "Install"
                    font.family: Theme.sansFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.nearBlack
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.selectedCount() > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.selectedCount() > 0) {
                            var tags = root.getSelectedTagList()
                            stackView.push(installingScreen, {"selectedTags": tags})
                        }
                    }
                }
            }
        }
    }
}
