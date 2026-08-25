/*
 * Picking a time of day. Optional, always -- a due date with no time is the
 * normal case, not an unfinished one.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Dates.js" as Dates

Dialog {
    id: dialog

    // In and out as 'HH:MM'. Empty means no time.
    property string chosen: ""

    allowedOrientations: defaultAllowedOrientations

    // The palette set once on the ApplicationWindow is inherited, but the
    // pickers draw their numbers straight from Theme.* and never consult it,
    // so under Fiat colours over a dark ambience the whole almanac came out
    // white on cream. Setting the palette ON the picker gives its own children
    // something nearer to read -- colorScheme included, which is the property
    // that actually decides light-on-dark or dark-on-light.
    function paint() {
        FiatAgendaTheme.applyPalette(dialog)
        FiatAgendaTheme.applyPalette(picker)
    }

    Component.onCompleted: {
        paint()
        if (dialog.chosen.length === 5) {
            picker.hour = parseInt(dialog.chosen.substring(0, 2), 10)
            picker.minute = parseInt(dialog.chosen.substring(3, 5), 10)
        }
    }

    onAccepted: dialog.chosen = Dates.formatTime(picker.hour, picker.minute)

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHead {
                title: qsTr("Time")
                acceptText: qsTr("Set")
                owner: dialog
            }

            TimePicker {
                id: picker
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(dialog.width, dialog.height) - Theme.horizontalPageMargin * 4
                height: width
                hour: 9
                minute: 0
            }
        }
    }
}
