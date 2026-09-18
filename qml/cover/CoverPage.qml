import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../Storage.js" as Storage

CoverBackground {
    id: cover

    property var info: ({ today: 0, overdue: 0, next: "", nextDue: "" })

    function refresh() { info = Storage.summary() }

    Component.onCompleted: refresh()

    // Only worth keeping fresh while the app is not in front. A pair of
    // COUNTs once a minute is nothing.
    Timer {
        interval: 60000
        repeat: true
        running: Qt.application.state !== Qt.ApplicationActive
        onTriggered: cover.refresh()
    }

    Connections {
        target: Qt.application
        onStateChanged: cover.refresh()
    }

    Rectangle {
        anchors.fill: parent
        visible: !FiatAgendaTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatAgendaTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatAgendaTheme.backgroundLow }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: FiatAgendaTheme.coverWordmarkTop
        text: "fiat agenda"
        color: FiatAgendaTheme.secondaryText
        font.pixelSize: Theme.fontSizeTiny
        font.family: FiatAgendaTheme.serif
        font.italic: true
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: FiatAgendaTheme.coverSideMargin
        anchors.rightMargin: FiatAgendaTheme.coverSideMargin
        anchors.topMargin: cover.height * FiatAgendaTheme.coverFigureFraction
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: cover.info.today
            color: cover.info.overdue > 0 ? FiatAgendaTheme.overdue
                 : cover.info.today > 0   ? FiatAgendaTheme.accent
                                          : FiatAgendaTheme.markIdle
            font.pixelSize: FiatAgendaTheme.coverFigureSize
            font.family: FiatAgendaTheme.serif
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: cover.info.today === 0 ? qsTr("clear")
                : cover.info.overdue > 0 ? qsTr("due · %1 late").arg(cover.info.overdue)
                                         : qsTr("due today")
            color: FiatAgendaTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }

        Item {
            width: 1
            height: Theme.paddingSmall
            visible: cover.info.next !== ""
        }

        Label {
            width: parent.width
            visible: cover.info.next !== ""
            horizontalAlignment: Text.AlignHCenter
            text: cover.info.next
            color: FiatAgendaTheme.primaryText
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
