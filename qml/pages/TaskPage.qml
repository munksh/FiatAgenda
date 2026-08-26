import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Storage.js" as Storage
import "../Dates.js" as Dates

// One task, opened.
//
// Changes save as they are made -- there is no Save button and no Cancel,
// because on Sailfish going back is how you finish. The page is a stack of
// pills rather than a form: nothing here is required, and nothing here is
// asked for before it is wanted.
//
// A subtask is a CARD, borrowed straight from Fiat Mos's sets. It reads as a
// card, swipes left to delete, and the delete waits three seconds with a way
// out. Tapping it turns it into a field; tapping its mark ticks it. That order
// matters: a row that is a live text field cannot also be a swipe target,
// because every horizontal drag would land on a cursor instead.
//
// One level of subtasks, and there is no control on this page that could
// produce a second. That is the feature, not a limitation waiting to be
// lifted.

Page {
    id: page

    property int taskId: -1
    property var task: null
    property var listNames: []

    // Revealed by "Every ...", so the custom controls can be open before the
    // value has actually changed.
    property bool customRepeat: false
    property bool newListOpen: false

    // Which subtask is open as a field, and which is counting down to
    // deletion. Ids, not indices -- an index stops meaning anything the
    // moment a row leaves the model.
    property int editingSub: -1
    property int pendingSub: -1

    allowedOrientations: defaultAllowedOrientations

    ListModel { id: subModel }

    function load() {
        task = Storage.getTask(taskId)
        if (task === null) { pageStack.pop(); return }

        listNames = Storage.lists()
        titleField.text = task.title
        noteField.text = task.note
        customRepeat = task.repeatEvery > 1
        intervalSlider.value = task.repeatEvery > 0 ? task.repeatEvery : 1
    }

    function save(fields) {
        Storage.updateTask(taskId, fields)
        task = Storage.getTask(taskId)
    }

    // Free text is written back when the field is left, and again when the
    // page is, so a task edited and immediately swiped away is not lost.
    function saveTexts() {
        if (task === null) return
        var t = titleField.text.replace(/^\s+|\s+$/g, "")
        var fields = {}
        if (t !== "" && t !== task.title) fields.title = t
        if (noteField.text !== task.note) fields.note = noteField.text
        if (fields.title !== undefined || fields.note !== undefined) save(fields)
    }

    function setRepeat(every, unit) {
        customRepeat = false
        save({ repeatEvery: every, repeatUnit: unit })
    }

    // The subtask model is loaded once and then edited in place -- never
    // reloaded. Reloading clears the model, which destroys every delegate,
    // which takes a running remorse countdown with it.
    Component.onCompleted: {
        paint()
        load()
        Storage.loadSubtasks(subModel, taskId)
    }

    // Silica's own chrome -- the virtual keyboard, the menus, field labels and
    // underlines -- uses the palette it inherited when the page was BUILT.
    // Setting it on the ApplicationWindow alone is not enough: a page pushed
    // AFTER the switch was thrown carries the old one, which is why the main
    // page came out right and this one did not.
    //
    // So every page paints itself, on creation and on every later switch.
    function paint() { FiatAgendaTheme.applyPalette(page) }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: page.paint()
    }


    onStatusChanged: {
        if (status === PageStatus.Activating) load()
        else if (status === PageStatus.Deactivating) saveTexts()
    }

    // Fiat colours paint their own paper. Under an ambience there is no
    // background at all -- the wallpaper is the background.
    FiatBackground { }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent

            MenuItem {
                text: qsTr("Delete task")
                color: FiatAgendaTheme.wrong
                onClicked: remorse.execute(qsTr("Deleting"), function () {
                    Storage.deleteTask(page.taskId)
                    pageStack.pop()
                })
            }
        }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead {
                title: qsTr("task")
                subtitle: "fiat agenda"
            }

            TextField {
                id: titleField
                width: parent.width
                label: qsTr("Task")
                placeholderText: qsTr("Task")
                color: FiatAgendaTheme.primaryText
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
                onActiveFocusChanged: if (!activeFocus) page.saveTexts()
            }

            // -- Due -----------------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Due")
            }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingSmall

                Pill {
                    text: qsTr("No date")
                    selected: page.task !== null && page.task.dueDate === ""
                    // Clearing the date clears the time and the recurrence with
                    // it: a time with no day is not a due date, it is a riddle.
                    onClicked: page.save({ dueDate: "", dueTime: "", repeatEvery: 0, repeatUnit: "" })
                }
                Pill {
                    text: qsTr("Today")
                    selected: page.task !== null && Dates.isToday(page.task.dueDate)
                    onClicked: page.save({ dueDate: Dates.todayISO() })
                }
                Pill {
                    text: qsTr("Tomorrow")
                    selected: page.task !== null && page.task.dueDate === Dates.tomorrowISO()
                    onClicked: page.save({ dueDate: Dates.tomorrowISO() })
                }
                Pill {
                    property bool isOther: page.task !== null && page.task.dueDate !== ""
                                           && !Dates.isToday(page.task.dueDate)
                                           && page.task.dueDate !== Dates.tomorrowISO()
                    text: isOther ? Dates.formatFull(page.task.dueDate) : qsTr("Pick a day")
                    selected: isOther
                    onClicked: {
                        if (page.task === null) return
                        // push, not animatorPush: this one needs the page
                        // instance back straight away to hear its accepted().
                        var dlg = pageStack.push(Qt.resolvedUrl("DateDialog.qml"),
                                                 { chosen: page.task.dueDate })
                        dlg.accepted.connect(function () { page.save({ dueDate: dlg.chosen }) })
                    }
                }
            }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingSmall
                visible: page.task !== null && page.task.dueDate !== ""

                Pill {
                    text: qsTr("No time")
                    selected: page.task !== null && page.task.dueTime === ""
                    onClicked: page.save({ dueTime: "" })
                }
                Pill {
                    text: (page.task !== null && page.task.dueTime !== "")
                          ? page.task.dueTime : qsTr("Pick a time")
                    selected: page.task !== null && page.task.dueTime !== ""
                    onClicked: {
                        if (page.task === null) return
                        var dlg = pageStack.push(Qt.resolvedUrl("TimeDialog.qml"),
                                                 { chosen: page.task.dueTime })
                        dlg.accepted.connect(function () { page.save({ dueTime: dlg.chosen }) })
                    }
                }
            }

            // -- Repeat --------------------------------------------------------
            //
            // Recurrence needs a day to recur from, so the whole section only
            // exists once there is one. Hiding it beats showing a control that
            // would quietly do nothing.

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Repeat")
                visible: page.task !== null && page.task.dueDate !== ""
            }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingSmall
                visible: page.task !== null && page.task.dueDate !== ""

                Pill {
                    text: qsTr("Never")
                    selected: page.task !== null && page.task.repeatEvery === 0
                    onClicked: page.setRepeat(0, "")
                }
                Pill {
                    text: qsTr("Daily")
                    selected: page.task !== null && page.task.repeatEvery === 1 && page.task.repeatUnit === "day"
                    onClicked: page.setRepeat(1, "day")
                }
                Pill {
                    text: qsTr("Weekly")
                    selected: page.task !== null && page.task.repeatEvery === 1 && page.task.repeatUnit === "week"
                    onClicked: page.setRepeat(1, "week")
                }
                Pill {
                    text: qsTr("Monthly")
                    selected: page.task !== null && page.task.repeatEvery === 1 && page.task.repeatUnit === "month"
                    onClicked: page.setRepeat(1, "month")
                }
                Pill {
                    text: page.task !== null && page.task.repeatEvery > 1
                          ? Dates.formatRepeat(page.task.repeatEvery, page.task.repeatUnit)
                          : qsTr("Every ...")
                    selected: page.customRepeat || (page.task !== null && page.task.repeatEvery > 1)
                    onClicked: page.customRepeat = true
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: page.customRepeat && page.task !== null && page.task.dueDate !== ""

                Slider {
                    id: intervalSlider
                    width: parent.width
                    minimumValue: 1
                    maximumValue: 30
                    stepSize: 1
                    label: qsTr("Every")
                    valueText: Math.round(value) + " " +
                               (page.task !== null && page.task.repeatUnit !== ""
                                ? page.task.repeatUnit : "day") +
                               (Math.round(value) > 1 ? "s" : "")
                    onValueChanged: {
                        if (page.task === null || !page.customRepeat) return
                        var n = Math.round(value)
                        var unit = page.task.repeatUnit !== "" ? page.task.repeatUnit : "day"
                        if (n !== page.task.repeatEvery || unit !== page.task.repeatUnit)
                            page.save({ repeatEvery: n, repeatUnit: unit })
                    }
                }

                Flow {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    spacing: Theme.paddingSmall

                    Repeater {
                        model: ["day", "week", "month"]
                        Pill {
                            text: modelData + "s"
                            selected: page.task !== null && page.task.repeatUnit === modelData
                            onClicked: page.save({ repeatEvery: Math.round(intervalSlider.value),
                                                   repeatUnit: modelData })
                        }
                    }
                }
            }

            // -- List ----------------------------------------------------------
            //
            // Lists are a name on the task, nothing more. A list exists for
            // exactly as long as something is in it, which is why there is no
            // screen for managing lists and no tag taxonomy on top.

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("List")
            }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingSmall

                Pill {
                    text: qsTr("None")
                    selected: page.task !== null && page.task.listName === ""
                    onClicked: { page.newListOpen = false; page.save({ listName: "" }) }
                }
                Repeater {
                    model: page.listNames
                    Pill {
                        text: modelData
                        selected: page.task !== null && page.task.listName === modelData
                        onClicked: { page.newListOpen = false; page.save({ listName: modelData }) }
                    }
                }
                Pill {
                    text: qsTr("New ...")
                    selected: page.newListOpen
                    onClicked: { page.newListOpen = true; newListField.forceActiveFocus() }
                }
            }

            TextField {
                id: newListField
                width: parent.width
                visible: page.newListOpen
                label: qsTr("List name")
                placeholderText: qsTr("List name")
                color: FiatAgendaTheme.primaryText
                inputMethodHints: Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    var n = text.replace(/^\s+|\s+$/g, "")
                    if (n !== "") {
                        page.save({ listName: n })
                        page.listNames = Storage.lists()
                    }
                    text = ""
                    page.newListOpen = false
                    focus = false
                }
            }

            // -- Note ----------------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Note")
            }

            TextArea {
                id: noteField
                width: parent.width
                label: qsTr("Note")
                placeholderText: qsTr("Anything worth remembering")
                color: FiatAgendaTheme.primaryText
                onActiveFocusChanged: if (!activeFocus) page.saveTexts()
            }

            // -- Subtasks ------------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Subtasks")
            }

            Repeater {
                model: subModel

                Item {
                    id: subWrap

                    property int subId: model.taskId
                    property int subIndex: index
                    property bool editingThis: page.editingSub === subId
                    property bool pendingThis: page.pendingSub === subId
                    // A quarter of the row width. Low enough not to fight you.
                    property real threshold: width * 0.25
                    // How far in from the card's left edge counts as the mark
                    // rather than the text. A tap there ticks; anywhere else
                    // opens the field.
                    property real markZone: Theme.paddingLarge + FiatAgendaTheme.markSize * 0.8 + Theme.paddingMedium

                    x: Theme.horizontalPageMargin
                    width: content.width - Theme.horizontalPageMargin * 2
                    height: card.height
                    // So the card is cut off at the row edge instead of sliding
                    // out over the page margin.
                    clip: true

                    // 1 when the countdown starts, 0 when it runs out. Drives
                    // the shade below, so the time left is a shape and not just
                    // a number nobody is counting.
                    property real countdown: 1

                    function startRemorse() {
                        page.pendingSub = subId
                        card.x = -width
                        subWrap.countdown = 1
                        countdownAnim.restart()
                        remorseTimer.restart()
                    }

                    function stopRemorse() {
                        countdownAnim.stop()
                        remorseTimer.stop()
                        subWrap.countdown = 1
                    }

                    Timer {
                        id: remorseTimer
                        interval: 3000
                        onTriggered: {
                            if (page.pendingSub !== subWrap.subId) return
                            page.pendingSub = -1
                            Storage.deleteTask(subWrap.subId)
                            // Remove this one row rather than reloading the
                            // model. Reloading rebuilds every delegate, and
                            // that is what made the row below jump up under
                            // the "Add subtask" field.
                            subModel.remove(subWrap.subIndex)
                        }
                    }

                    NumberAnimation {
                        id: countdownAnim
                        target: subWrap
                        property: "countdown"
                        from: 1
                        to: 0
                        duration: 3000
                    }

                    // Behind the card. While you drag it is just a red field;
                    // once you let go past the threshold the card leaves
                    // entirely and this becomes the countdown. No bin to aim
                    // at, no second tap -- that is the Sailfish way round.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingLarge
                        color: FiatAgendaTheme.wrong
                        visible: card.x < -1 || subWrap.pendingThis
                        clip: true

                        // The time left, as a shape. A darker band that shrinks
                        // away to the left over the three seconds -- so you can
                        // see how long you still have without reading anything.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * subWrap.countdown
                            visible: subWrap.pendingThis
                            color: Qt.darker(FiatAgendaTheme.wrong, 1.45)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.paddingLarge
                            anchors.rightMargin: Theme.paddingLarge
                            visible: subWrap.pendingThis

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - cancelBtn.width
                                text: qsTr("Deleting subtask…")
                                truncationMode: TruncationMode.Fade
                                font.pixelSize: Theme.fontSizeSmall
                                color: FiatAgendaTheme.markOn(FiatAgendaTheme.wrong)
                            }

                            BackgroundItem {
                                id: cancelBtn
                                anchors.verticalCenter: parent.verticalCenter
                                width: cancelLabel.width + Theme.paddingLarge
                                height: Theme.itemSizeExtraSmall
                                onClicked: {
                                    subWrap.stopRemorse()
                                    page.pendingSub = -1
                                    card.x = 0
                                }
                                Label {
                                    id: cancelLabel
                                    anchors.centerIn: parent
                                    text: qsTr("Cancel")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: FiatAgendaTheme.markOn(FiatAgendaTheme.wrong)
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: card
                        width: parent.width
                        height: cardColumn.height + Theme.paddingMedium * 2
                        radius: Theme.paddingLarge
                        color: FiatAgendaTheme.card
                        border.color: FiatAgendaTheme.cardBorder
                        border.width: 1

                        Behavior on x {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        Column {
                            id: cardColumn
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.paddingLarge
                            width: parent.width - Theme.paddingLarge * 2
                            spacing: Theme.paddingSmall

                            // -- reading the subtask ------------------------
                            Row {
                                width: parent.width
                                spacing: Theme.paddingMedium
                                // NOT hidden while the remorse runs. A Column
                                // ignores invisible children when it measures
                                // itself, so hiding this row would take
                                // cardColumn's height to zero, then card's,
                                // then subWrap's -- and the red field behind,
                                // anchored to subWrap, would collapse into a
                                // strip. The card has already slid off screen
                                // by then; there is nothing to hide.
                                visible: !subWrap.editingThis

                                Rectangle {
                                    id: markDot
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: FiatAgendaTheme.markSize * 0.8
                                    height: width
                                    radius: width / 2
                                    color: model.done ? FiatAgendaTheme.accent : "transparent"
                                    border.width: 2
                                    border.color: model.done ? FiatAgendaTheme.accent
                                                             : FiatAgendaTheme.markIdle
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - markDot.width - Theme.paddingMedium
                                    text: model.title
                                    truncationMode: TruncationMode.Fade
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: model.done ? FiatAgendaTheme.secondaryText
                                                      : FiatAgendaTheme.primaryText
                                }
                            }

                            // -- editing the subtask ------------------------
                            TextField {
                                id: subField
                                width: parent.width
                                visible: subWrap.editingThis
                                label: qsTr("Subtask")
                                placeholderText: qsTr("Subtask")
                                color: FiatAgendaTheme.primaryText
                                Component.onCompleted: text = model.title
                                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                                EnterKey.onClicked: focus = false
                            }

                            BackgroundItem {
                                width: doneLabel.width + Theme.paddingLarge
                                height: Theme.itemSizeExtraSmall
                                visible: subWrap.editingThis
                                highlightedColor: FiatAgendaTheme.highlightWash
                                onClicked: {
                                    var t = subField.text.replace(/^\s+|\s+$/g, "")
                                    if (t !== "" && t !== model.title) {
                                        Storage.updateTask(subWrap.subId, { title: t })
                                        subModel.setProperty(subWrap.subIndex, "title", t)
                                    }
                                    page.editingSub = -1
                                }
                                Label {
                                    id: doneLabel
                                    anchors.centerIn: parent
                                    text: qsTr("Done")
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: FiatAgendaTheme.accent
                                }
                            }
                        }
                    }

                    // The gesture. Only alive while the card is a card -- once
                    // it is a field, the field owns the touches.
                    MouseArea {
                        anchors.fill: parent
                        enabled: !subWrap.editingThis && !subWrap.pendingThis

                        property real pressX: 0
                        property real baseX: 0
                        property bool moved: false

                        onPressed: {
                            pressX = mouse.x
                            baseX = card.x
                            moved = false
                        }
                        onPositionChanged: {
                            var dx = mouse.x - pressX
                            if (Math.abs(dx) > Theme.paddingSmall) moved = true
                            card.x = Math.min(0, baseX + dx)
                        }
                        onReleased: {
                            if (!moved) {
                                // The left edge is the mark, the rest is the
                                // text. One card, two meanings, no second
                                // control to draw.
                                if (mouse.x < subWrap.markZone) {
                                    var next = model.done ? 0 : 1
                                    Storage.setDone(subWrap.subId, next === 1)
                                    subModel.setProperty(subWrap.subIndex, "done", next)
                                } else {
                                    page.editingSub = subWrap.subId
                                }
                                return
                            }
                            // Past the threshold, letting go deletes. Short of
                            // it, the card springs back.
                            if (card.x < -subWrap.threshold) subWrap.startRemorse()
                            else card.x = 0
                        }
                        onCanceled: card.x = 0
                    }
                }
            }

            TextField {
                id: subAddField
                width: parent.width
                label: qsTr("Add subtask")
                placeholderText: qsTr("Add subtask")
                color: FiatAgendaTheme.primaryText
                inputMethodHints: Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    var t = text.replace(/^\s+|\s+$/g, "")
                    if (t === "") return
                    var id = Storage.addSubtask(page.taskId, t)
                    subModel.append({ taskId: id, title: t, done: 0, sortIndex: subModel.count })
                    text = ""
                    forceActiveFocus()
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                visible: subModel.count > 0
                text: qsTr("Tap a subtask to edit it, tap its mark to tick it, swipe it left to delete — you get a few seconds to change your mind.")
            }
        }

        VerticalScrollDecorator { }
    }
}
