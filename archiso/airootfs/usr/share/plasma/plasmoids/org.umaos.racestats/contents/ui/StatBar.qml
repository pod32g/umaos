import QtQuick
import QtQuick.Layouts

Item {
    id: statBar
    height: 40

    property string label: ""
    property real value: 0.0  // 0.0 to 1.0
    property string suffix: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: statBar.label
                color: "#4A6A8A"
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Text {
                text: statBar.suffix
                color: "#F8FBFF"
                font.pixelSize: 11
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: "#1F4F90"

            Rectangle {
                width: parent.width * Math.min(statBar.value, 1.0)
                height: parent.height
                radius: 4

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#2F74CC" }
                    GradientStop { position: 1.0; color: statBar.value > 0.8 ? "#FF91C0" : "#2F74CC" }
                }

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
