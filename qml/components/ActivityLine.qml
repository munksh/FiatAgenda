import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// A short accent bar running along the top edge while the server is being
// asked something. Quiet enough to leave on for a refresh.
Item {
    id: root

    property bool running: api.busy > 0

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.max(2, Theme.paddingSmall / 2)
    clip: true
    opacity: running ? 1.0 : 0.0
    Behavior on opacity { FadeAnimation { duration: 400 } }

    Rectangle {
        id: runner
        width: root.width / 4
        height: root.height
        color: FiatAgendaTheme.accent

        NumberAnimation on x {
            running: root.running && Qt.application.state === Qt.ApplicationActive
            from: -runner.width
            to: root.width
            duration: 1100
            loops: Animation.Infinite
            easing.type: Easing.InOutQuad
        }
    }
}
