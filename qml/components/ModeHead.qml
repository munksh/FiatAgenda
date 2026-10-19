import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The wordmark, and the two sides of the app beside it: tasks, which are
// yours and have dates, and lists, which the household shares. Both sit on
// the status row; the cutout is in the middle, the corners are free.
Item {
    id: root

    property string mode: "tasks"
    signal chosen(string mode)

    width: parent ? parent.width : 0
    height: FiatAgendaTheme.statusRowCenter + word.height / 2 + Theme.paddingMedium

    Text {
        id: word
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, FiatAgendaTheme.statusRowCenter - height / 2)
        text: "fiat agenda"
        color: FiatAgendaTheme.primaryText
        font.pixelSize: Theme.fontSizeLarge
        font.family: FiatAgendaTheme.serif
        font.italic: true
    }

    // A Flow of fixed width, not a Row: a Pill sizes itself from its parent's
    // width, and a Row sizes itself from its children. Right to left, so the
    // first child sits in the corner.
    Flow {
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin - Theme.paddingMedium
        anchors.verticalCenter: word.verticalCenter
        width: root.width / 2
        layoutDirection: Qt.RightToLeft
        Pill {
            text: qsTr("Lists")
            pixelSize: FiatAgendaTheme.navFontSize
            selected: root.mode === "lists"
            onClicked: root.chosen("lists")
        }
        Pill {
            text: qsTr("Tasks")
            pixelSize: FiatAgendaTheme.navFontSize
            selected: root.mode === "tasks"
            onClicked: root.chosen("tasks")
        }
    }
}
