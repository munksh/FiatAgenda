import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The answer to a pull-down sync or refresh: a spinner that opens a row under
// the header and closes it again when the server has answered. It stays at
// least a moment, so a quick answer is seen rather than flickered.
Item {
    id: root

    property bool running: false
    readonly property bool shown: running || hold.running

    width: parent ? parent.width : 0
    height: shown ? Theme.itemSizeSmall : 0
    visible: height > 0
    clip: true

    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    onRunningChanged: if (running) hold.restart()

    Timer {
        id: hold
        interval: 800
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Medium
        running: root.shown
    }
}
