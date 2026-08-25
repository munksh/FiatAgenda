/*
 * Picking a day.
 *
 * Silica's own DatePickerDialog would do the job, but it brings a
 * DialogHeader that draws its text in Theme.highlightColor and a page that
 * paints no background -- which under Fiat colours means the ambience shows
 * through the middle of the app. Wrapping the picker costs a dozen lines and
 * keeps the app looking like itself.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Dates.js" as Dates

Dialog {
    id: dialog

    // In and out as 'YYYY-MM-DD'. Empty means no date.
    property string chosen: ""

    allowedOrientations: defaultAllowedOrientations

    // Silica has moved this around between versions -- some expose a settable
    // `date`, others only setDate(). Try the function first and fall back,
    // inside a try/catch: a throw in Component.onCompleted abandons the rest
    // of the handler, and the failure mode is a picker that silently opens on
    // today with no clue why.
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
        var d = Dates.fromISO(dialog.chosen)
        if (d === null) return
        try {
            if (typeof picker.setDate === "function") picker.setDate(d)
            else picker.date = d
        } catch (e) { }
    }

    onAccepted: dialog.chosen = Qt.formatDate(picker.date, "yyyy-MM-dd")

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHead {
                title: qsTr("Due date")
                acceptText: qsTr("Set")
                owner: dialog
            }

            DatePicker {
                id: picker
                width: parent.width
            }
        }
    }
}
