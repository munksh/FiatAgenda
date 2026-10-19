import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// What went wrong with the last request, or that the phone is offline and the
// page shows the last copy it saw. A tap clears an error; it also goes by
// itself after a while.
Column {
    id: root

    x: Theme.horizontalPageMargin
    width: (parent ? parent.width : Screen.width) - 2 * Theme.horizontalPageMargin
    spacing: Theme.paddingSmall
    visible: api.error !== "" || api.offline

    Timer {
        interval: 8000
        running: api.error !== "" && Qt.application.state === Qt.ApplicationActive
        onTriggered: api.dismissError()
    }

    Label {
        width: parent.width
        visible: api.offline
        wrapMode: Text.WordWrap
        text: qsTr("Offline. This is what the phone saw last.")
        color: FiatAgendaTheme.secondaryText
        font.pixelSize: Theme.fontSizeExtraSmall
        font.italic: true
        font.family: FiatAgendaTheme.serif
    }

    MouseArea {
        width: parent.width
        height: errorLabel.height + Theme.paddingSmall
        visible: api.error !== ""
        onClicked: api.dismissError()
        Label {
            id: errorLabel
            width: parent.width
            wrapMode: Text.WordWrap
            text: api.error
            color: FiatAgendaTheme.wrong
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }
}
