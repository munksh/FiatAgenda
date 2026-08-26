/*
 * One task, as it appears in a list.
 *
 * Three gestures, each with exactly one meaning and no overlap:
 *   swipe right      complete, behind a remorse timer
 *   swipe left       delete, behind a remorse timer
 *   press and hold   the two date shortcuts
 *   drag the handle  reorder -- and the handle only exists in views that are
 *                    manually ordered, so a date-sorted view has no grip to
 *                    grab and no promise it cannot keep
 *
 * The remorse timer is the only safety net there is. Deletion here is a real
 * DELETE: no soft-delete, no append-only history. That is Fiat Mos's job, not
 * a task list's, and for a to-do the standard SFOS delay is enough.
 *
 * Press-and-hold is free for the context menu precisely because dragging
 * lives on the handle. Putting both on the row body is how you get a menu
 * every time someone tries to reorder.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../Dates.js" as Dates

ListItem {
    id: row

    property int taskId: -1
    property string title: ""
    property string listName: ""
    property string dueDate: ""
    property string dueTime: ""
    property int repeatEvery: 0
    property string repeatUnit: ""
    property int subTotal: 0
    property int subDone: 0

    property bool showList: true          // false inside a list's own view
    property bool showHandle: false       // true only where order is manual
    property int itemIndex: -1
    property var listView: null

    // Named away from `completed` and `activated`: Component.onCompleted is
    // one keystroke away from a handler that silently never fires.
    signal opened()
    signal taskCompleted()
    signal taskRemoved()
    signal reordered()
    signal dateShortcut(string kind)      // "today" | "tomorrow" | "notnow" | "clear"

    readonly property bool overdue: Dates.isOverdue(dueDate)
    readonly property bool dueToday: Dates.isToday(dueDate)

    // How far in from the left counts as the mark rather than the title.
    // Derived from the mark's real size so the two can never drift apart.
    readonly property real markZone: Theme.horizontalPageMargin
                                     + FiatAgendaTheme.markSize
                                     + Theme.paddingMedium
    property bool held: false

    contentHeight: Math.max(Theme.itemSizeSmall, texts.height + Theme.paddingLarge)
    highlighted: gesture.pressed && !gesture.swiping

    // Silica would wash a pressed row in the ambience highlight, which under
    // Fiat colours is a bright band across the paper. Every pressable thing in
    // this app uses the app's own accent instead.
    highlightedColor: FiatAgendaTheme.highlightWash

    // Menus read Theme.* directly and ignore the singleton, so every item says
    // its colour out loud. The palette on the ApplicationWindow gets most of
    // the way; this is the rest of it.
    menu: Component {
        ContextMenu {
            // Without this the menu is transparent and the list shows through
            // its own menu. A 15% accent wash rather than a solid fill: the
            // family rule is that backgroundColor on a menu paints the whole
            // panel, so keep it light enough that it tints instead of dimming.
            backgroundColor: FiatAgendaTheme.highlightWash
            highlightColor: FiatAgendaTheme.accent

            MenuItem {
                text: row.dueDate === "" ? qsTr("Due today") : qsTr("Not now")
                color: FiatAgendaTheme.primaryText
                onClicked: row.dateShortcut(row.dueDate === "" ? "today" : "notnow")
            }
            MenuItem {
                text: row.dueDate === "" ? qsTr("Due tomorrow") : qsTr("No date")
                color: FiatAgendaTheme.primaryText
                onClicked: row.dateShortcut(row.dueDate === "" ? "tomorrow" : "clear")
            }
        }
    }

    // ---- what the swipe is about to do, revealed underneath ----

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(FiatAgendaTheme.accent, 0.18)
        opacity: content.x > 0 ? Math.min(1, content.x / gesture.threshold) : 0
        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            text: row.repeatEvery > 0 ? qsTr("Next time") : qsTr("Done")
            color: FiatAgendaTheme.accent
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(FiatAgendaTheme.overdue, 0.18)
        opacity: content.x < 0 ? Math.min(1, -content.x / gesture.threshold) : 0
        Label {
            anchors.right: parent.right
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Delete")
            color: FiatAgendaTheme.overdue
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // ---- the row itself ----

    Item {
        id: content
        width: row.width
        height: row.contentHeight

        // No animation while the finger is down -- the row must track the
        // thumb exactly. The Behavior is only there for the snap back.
        Behavior on x {
            enabled: !gesture.swiping
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }

        // The mark. A drawn circle, not a glyph: a Rectangle with
        // radius = width / 2 is round in every font, and the bullet is not.
        Rectangle {
            id: mark
            anchors.left: parent.left
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            width: FiatAgendaTheme.markSize
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: row.overdue ? FiatAgendaTheme.overdue
                        : row.dueToday ? FiatAgendaTheme.accent
                        : FiatAgendaTheme.markIdle
        }

        Column {
            id: texts
            anchors.left: mark.right
            anchors.leftMargin: Theme.paddingMedium
            anchors.right: handle.visible ? handle.left : parent.right
            anchors.rightMargin: handle.visible ? Theme.paddingMedium : Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Label {
                width: parent.width
                text: row.title
                color: FiatAgendaTheme.primaryText
                font.pixelSize: Theme.fontSizeMedium
                truncationMode: TruncationMode.Fade
            }

            // The meta line only exists when it has something to say. An
            // invisible child does not collapse this Column -- the Column is
            // inside an Item with its own height, not the other way round --
            // but it does stop reserving a line, which is the point.
            Row {
                spacing: Theme.paddingSmall
                visible: dueLabel.visible || listLabel.visible || repeatLabel.visible || subLabel.visible

                Label {
                    id: dueLabel
                    visible: row.dueDate !== ""
                    text: Dates.formatDue(row.dueDate, row.dueTime)
                    color: row.overdue ? FiatAgendaTheme.overdue
                         : row.dueToday ? FiatAgendaTheme.accent
                         : FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
                Label {
                    id: listLabel
                    visible: row.showList && row.listName !== ""
                    text: (dueLabel.visible ? "· " : "") + row.listName
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
                Label {
                    id: repeatLabel
                    visible: row.repeatEvery > 0
                    text: "↻"
                    color: FiatAgendaTheme.accent
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
                Label {
                    id: subLabel
                    visible: row.subTotal > 0
                    text: row.subDone + "/" + row.subTotal
                    color: row.subTotal > 0 && row.subDone === row.subTotal
                           ? FiatAgendaTheme.accent : FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }

        // The grip: three hairlines, drawn rather than typed, and only in
        // views where dragging means something.
        Item {
            id: handle
            visible: row.showHandle
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: visible ? Theme.itemSizeSmall : 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.paddingSmall
                Repeater {
                    model: 3
                    Rectangle {
                        width: Theme.itemSizeExtraSmall * 0.42
                        height: 2
                        radius: 1
                        color: dragArea.pressed ? FiatAgendaTheme.accent : FiatAgendaTheme.markIdle
                    }
                }
            }

            /*
             * Reorder. preventStealing goes up the moment the finger lands,
             * or the list flicks away underneath the drag. The model is moved
             * as the finger crosses each neighbour, so the row genuinely
             * follows the thumb; the database is written once, on release.
             */
            MouseArea {
                id: dragArea
                anchors.fill: parent
                preventStealing: true

                onPressed: {
                    row.held = true
                    if (row.listView !== null) row.listView.interactive = false
                }
                onPositionChanged: {
                    if (!row.held || row.listView === null) return
                    var p = mapToItem(row.listView.contentItem, width / 2, mouse.y)
                    var target = row.listView.indexAt(row.listView.width / 2, p.y)
                    if (target >= 0 && target !== row.itemIndex)
                        row.listView.model.move(row.itemIndex, target, 1)
                }
                onReleased: finish()
                onCanceled: finish()

                function finish() {
                    if (!row.held) return
                    row.held = false
                    if (row.listView !== null) row.listView.interactive = true
                    row.reordered()
                }
            }
        }
    }

    // The held row lifts off the paper rather than changing colour.
    Rectangle {
        anchors.fill: parent
        visible: row.held
        color: FiatAgendaTheme.card
        opacity: 0.9
        z: -1
    }

    /*
     * The swipe. It covers the row but not the handle, so the two gestures
     * can never fight over the same pixels.
     *
     * preventStealing goes up only once the movement is unmistakably
     * horizontal -- before that the ListView must stay free to flick, or the
     * list feels stuck.
     */
    MouseArea {
        id: gesture
        anchors.fill: parent
        anchors.rightMargin: handle.visible ? handle.width : 0

        readonly property real threshold: row.width * 0.28
        property real pressX: 0
        property bool swiping: false

        // MouseArea delivers clicked() after released() whether or not the
        // finger travelled, and released() has already cleared `swiping` by
        // then. Without this latch every swipe would also open the task --
        // including the one that just started a delete.
        property bool swiped: false

        onPressed: { pressX = mouse.x; swiping = false; swiped = false }

        onPositionChanged: {
            var dx = mouse.x - pressX
            if (!swiping && Math.abs(dx) > Theme.paddingSmall) {
                swiping = true
                preventStealing = true
            }
            if (swiping) content.x = dx
        }

        onReleased: {
            var dx = content.x
            swiped = Math.abs(dx) > Theme.paddingSmall
            reset()
            if (dx > threshold) row.completeWithRemorse()
            else if (dx < -threshold) row.deleteWithRemorse()
        }

        onCanceled: reset()

        // The left edge is the mark, the rest is the task. Exactly the split a
        // subtask card uses, so one habit works in both places.
        //
        // Swiping right still completes, but it is now an accelerator rather
        // than the only way in: Silica's own pair is tap-to-enter and
        // hold-for-a-menu, and a row whose only route to "done" is a gesture
        // no other Sailfish app uses is a row most people never finish.
        onClicked: {
            if (!swiped) {
                if (mouse.x < row.markZone) row.completeWithRemorse()
                else row.opened()
            }
            swiped = false
        }
        onPressAndHold: if (!swiping) row.openMenu()

        // swiping goes down BEFORE x does, or the Behavior that animates the
        // snap back is still disabled at the moment the snap happens and the
        // row jumps home instead of travelling there.
        function reset() {
            swiping = false
            preventStealing = false
            content.x = 0
        }
    }

    function completeWithRemorse() {
        // A recurring task is not finished, it is moved -- so say so.
        remorseAction(repeatEvery > 0 ? qsTr("Rescheduling") : qsTr("Done"), function () { row.taskCompleted() })
    }

    function deleteWithRemorse() {
        remorseDelete(function () { row.taskRemoved() })
    }
}
