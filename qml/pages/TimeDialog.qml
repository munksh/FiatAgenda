import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Dates.js" as Dates

// Picking a time of day. Optional, always -- a due date with no time is the
// normal case, not an unfinished one.
//
// Silica's TimePicker draws NO DIGITS. Read the file: a ShaderEffect for the
// ring, two TimePickerGlassItems for the beads, a MouseArea, and nothing else
// -- there is not one Text element in it. The dial is only the dial, and every
// app that uses one draws the time itself. So the missing numbers were never a
// colour problem and no palette would ever have fixed them.
//
// It also sets its own size (itemSizeMedium * 4, height = width) and lays the
// touch bands out from that, so it is centred and left alone here.
//
// The ring reads timePicker.palette.primaryColor, so the palette does have to
// reach the picker itself, not just the dialog around it.

Dialog {
    id: dialog

    // In and out as 'HH:MM'. Empty means no time.
    property string chosen: ""

    allowedOrientations: defaultAllowedOrientations

    function paint() {
        FiatAgendaTheme.applyPalette(dialog)
        FiatAgendaTheme.applyPalette(picker)
    }

    Component.onCompleted: {
        paint()
        if (dialog.chosen.length === 5) {
            picker.hour = parseInt(dialog.chosen.substring(0, 2), 10)
            picker.minute = parseInt(dialog.chosen.substring(3, 5), 10)
        } else {
            picker.hour = 9
            picker.minute = 0
        }
    }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: dialog.paint()
    }

    // Built here rather than read from picker.timeText, which formats through
    // Silica's own locale machinery. The app stores and shows 24-hour HH:MM
    // everywhere else; the dialog should not be the one screen that disagrees.
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

            // The digits Silica leaves to us. Serif, because every large
            // figure in the family is serif -- a grotesque numeral under a
            // serif wordmark reads as two unrelated typefaces.
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Dates.formatTime(picker.hour, picker.minute)
                font.pixelSize: Theme.fontSizeHuge
                font.family: FiatAgendaTheme.serif
                color: FiatAgendaTheme.primaryText
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("inner ring hours · outer ring minutes")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
            }

            TimePicker {
                id: picker
                anchors.horizontalCenter: parent.horizontalCenter
                // No width or height. It sizes itself, and its touch bands are
                // computed from that size -- forcing it would move the bands
                // out from under the ring you can see.
            }
        }
    }
}
