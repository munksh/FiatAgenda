import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."
import "../components"
import "../Storage.js" as Storage
import "../Dates.js" as Dates

// The front page, in two modes. Tasks: yours, with dates, kept on the phone
// and synced with Nextcloud Tasks if you like. Lists: the things that come
// back, on the phone or shared with a household through Pantry on Nextcloud.

Page {
    id: page

    readonly property string mode: modeConfig.value === "lists" ? "lists" : "tasks"
    function setMode(m) { modeConfig.value = m }

    ConfigurationValue {
        id: modeConfig
        key: "/apps/harbour-fiatagenda/mode"
        defaultValue: "tasks"
    }
    ConfigurationValue {
        id: introConfig
        key: "/apps/harbour-fiatagenda/nextcloudIntroduced"
        defaultValue: false
    }
    readonly property bool introduced: introConfig.value === true || introConfig.value === "true"

    readonly property var app: FiatAgendaTheme.appWindow

    // Asked for from the pull-down, so the spinner shows for that sync and
    // not for the quiet ones that run on their own.
    property bool syncAsked: false
    function syncFromMenu() {
        syncAsked = true
        app.syncNow()
        if (!app.syncing) syncAsked = false
    }

    property string view: "today"          // today | upcoming | anytime | list

    readonly property bool manualOrder: view === "anytime"

    allowedOrientations: defaultAllowedOrientations

    // Read again on every reload, so a page left open overnight turns the page.
    property var now: new Date()

    function reload() {
        if (app !== null) app.syncSoon()
        now = new Date()
        Storage.loadTasks(taskModel, view, "")
        if (view === "today") Storage.loadDoneToday(doneModel)
        else doneModel.clear()
    }

    function show(v) {
        view = v
        reload()
    }

    onStatusChanged: if (status === PageStatus.Active) reload()

    Connections {
        target: page.app
        ignoreUnknownSignals: true
        onSynced: page.reload()
        onSyncingChanged: if (!page.app.syncing) page.syncAsked = false
    }

    function openNextcloud() {
        introConfig.value = true
        pageStack.animatorPush(Qt.resolvedUrl("NextcloudPage.qml"))
    }

    Component.onCompleted: paint()


    function paint() { FiatAgendaTheme.applyPalette(page) }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: page.paint()
    }


    ListModel { id: taskModel }
    ListModel { id: doneModel }

    function calendarBridge() {
        if (FiatAgendaTheme.appWindow === null) return null
        return FiatAgendaTheme.appWindow.calendarBridge()
    }

    FiatBackground { }

    SilicaListView {
        id: taskList

        anchors.fill: parent
        anchors.bottomMargin: capture.height
        model: taskModel
        clip: true
        visible: page.mode === "tasks"

        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent
            busy: page.syncAsked
            MenuItem {
                text: qsTr("About")
                color: FiatAgendaTheme.primaryText
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: FiatAgendaTheme.ambient ? qsTr("Fiat colours") : qsTr("Follow ambience")
                color: FiatAgendaTheme.primaryText
                onClicked: FiatAgendaTheme.setAmbient(!FiatAgendaTheme.ambient)
            }
            MenuItem {
                text: qsTr("Nextcloud")
                color: FiatAgendaTheme.primaryText
                onClicked: page.openNextcloud()
            }
            MenuItem {
                text: qsTr("Completed")
                color: FiatAgendaTheme.primaryText
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("CompletedPage.qml"))
            }
            MenuItem {
                visible: page.app !== null && page.app.tasksSync
                text: qsTr("Sync now")
                color: FiatAgendaTheme.primaryText
                onClicked: page.syncFromMenu()
            }
        }

        header: Component {
            Column {
                width: page.width
                spacing: Theme.paddingMedium

                ModeHead {
                    mode: page.mode
                    onChosen: page.setMode(mode)
                }

                SyncSpinner { running: page.syncAsked }

                // Once, after the update: what is new, and where it lives.
                Column {
                    x: Theme.horizontalPageMargin
                    width: page.width - Theme.horizontalPageMargin * 2
                    spacing: Theme.paddingSmall
                    visible: !page.introduced && !account.signedIn

                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: qsTr("New: Lists, for the things that come back. They work on this phone, and can be shared with your household through Pantry on Nextcloud. Tasks can sync with Nextcloud Tasks. Both are optional.")
                        color: FiatAgendaTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: FiatAgendaTheme.serif
                    }
                    Row {
                        spacing: Theme.paddingLarge
                        LinkText {
                            text: qsTr("Set it up")
                            onClicked: page.openNextcloud()
                        }
                        LinkText {
                            text: qsTr("Not now")
                            color: FiatAgendaTheme.secondaryText
                            onClicked: introConfig.value = true
                        }
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: page.width - Theme.horizontalPageMargin * 2
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    text: page.app === null ? ""
                          : page.app.nextcloudNotice !== "" ? page.app.nextcloudNotice
                          : page.app.tasksSync && page.app.syncError !== "" ? qsTr("Not synced: %1").arg(page.app.syncError)
                          : ""
                    color: FiatAgendaTheme.wrong
                    font.pixelSize: Theme.fontSizeExtraSmall
                }

                // The day, and how much of it is done. The ring only means
                // something on Today; the other views have no "of how many".
                FaceCard {
                    figure: String(page.now.getDate())
                    title: Dates.weekdayLong(page.now)
                    details: [Dates.monthLong(page.now), qsTr("week %1").arg(Dates.isoWeek(page.now))]
                    showRing: page.view === "today"
                    done: doneModel.count
                    total: doneModel.count + taskModel.count
                }

                Flow {
                    x: Theme.horizontalPageMargin
                    width: page.width - Theme.horizontalPageMargin * 2
                    spacing: Theme.paddingSmall

                    Pill {
                        text: qsTr("Today")
                        pixelSize: FiatAgendaTheme.navFontSize
                        selected: page.view === "today"
                        onClicked: page.show("today")
                    }
                    Pill {
                        text: qsTr("Upcoming")
                        pixelSize: FiatAgendaTheme.navFontSize
                        selected: page.view === "upcoming"
                        onClicked: page.show("upcoming")
                    }
                    Pill {
                        text: qsTr("Anytime")
                        pixelSize: FiatAgendaTheme.navFontSize
                        selected: page.view === "anytime"
                        onClicked: page.show("anytime")
                    }
                }

                Rectangle {
                    width: page.width
                    height: 1
                    color: FiatAgendaTheme.hairline
                }
            }
        }

        // What was finished today, struck through, with the time it was done.
        footer: Component {
            Item {
                width: page.width
                height: shown ? doneCol.height + Theme.paddingLarge : 0
                readonly property bool shown: page.view === "today" && doneModel.count > 0
                visible: shown

                Column {
                    id: doneCol
                    width: parent.width

                    Item { width: 1; height: Theme.paddingLarge }
                    Label {
                        x: Theme.horizontalPageMargin + FiatAgendaTheme.markSize + Theme.paddingMedium
                        text: qsTr("done today")
                        color: FiatAgendaTheme.secondaryText
                        font.family: FiatAgendaTheme.serif
                        font.italic: true
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Item { width: 1; height: Theme.paddingSmall }

                    Repeater {
                        model: doneModel
                        BackgroundItem {
                            width: doneCol.width
                            height: Theme.itemSizeSmall
                            highlightedColor: FiatAgendaTheme.highlightWash
                            onClicked: pageStack.animatorPush(Qt.resolvedUrl("TaskPage.qml"), { taskId: model.taskId })

                            Mark {
                                id: doneMark
                                x: Theme.horizontalPageMargin
                                anchors.verticalCenter: parent.verticalCenter
                                checked: true
                            }
                            Label {
                                anchors.left: doneMark.right
                                anchors.leftMargin: Theme.paddingMedium
                                anchors.right: doneTime.left
                                anchors.rightMargin: Theme.paddingMedium
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.title === undefined ? "" : model.title
                                truncationMode: TruncationMode.Fade
                                color: FiatAgendaTheme.secondaryText
                                font.strikeout: true
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            Label {
                                id: doneTime
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.horizontalPageMargin
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.doneAt ? Qt.formatTime(new Date(model.doneAt), "hh:mm") : ""
                                color: FiatAgendaTheme.secondaryText
                                font.family: FiatAgendaTheme.serif
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }

        delegate: TaskRow {
            width: taskList.width
            taskId: model.taskId === undefined ? -1 : model.taskId
            title: model.title === undefined ? "" : model.title
            listName: model.listName === undefined ? "" : model.listName
            dueDate: model.dueDate === undefined ? "" : model.dueDate
            dueTime: model.dueTime === undefined ? "" : model.dueTime
            repeatEvery: model.repeatEvery === undefined ? 0 : model.repeatEvery
            repeatUnit: model.repeatUnit === undefined ? "" : model.repeatUnit
            subTotal: model.subTotal === undefined ? 0 : model.subTotal
            subDone: model.subDone === undefined ? 0 : model.subDone

            // Which of the server's lists a task lives in is the server's
            // business; here every task is simply a task.
            showList: false
            showHandle: page.manualOrder
            itemIndex: index
            listView: taskList

            onOpened: pageStack.animatorPush(Qt.resolvedUrl("TaskPage.qml"),
                                             { taskId: model.taskId })

            onTaskCompleted: {
                Storage.setDone(model.taskId, true)
                page.reload()
            }

            onTaskRemoved: {
                // Ask for the event id BEFORE the row is gone.
                var eventId = Storage.calendarIdOf(model.taskId)
                Storage.deleteTask(model.taskId)
                taskModel.remove(index)
                // Only now, and only if there is actually an event, does the
                // calendar plugin get loaded at all.
                if (eventId !== "") {
                    try {
                        var bridge = page.calendarBridge()
                        if (bridge !== null) bridge.removeEvent(eventId)
                    } catch (e) { }
                }
            }

            // The model is already in the new order; the database just has to
            // agree with it. One write, on release.
            onReordered: Storage.saveOrder(taskModel)

            onDateShortcut: {
                if (kind === "today")         Storage.updateTask(model.taskId, { dueDate: Dates.todayISO() })
                else if (kind === "tomorrow") Storage.updateTask(model.taskId, { dueDate: Dates.tomorrowISO() })
                else if (kind === "notnow")   Storage.defer(model.taskId)
                else if (kind === "clear")    Storage.updateTask(model.taskId, { dueDate: "", dueTime: "" })
                page.reload()
            }
        }

        VerticalScrollDecorator { }
    }


    HouseholdView {
        id: households
        anchors.fill: parent
        visible: page.mode === "lists"
        active: page.mode === "lists" && page.status === PageStatus.Active
        onModeChosen: page.setMode(mode)
        onNextcloudWanted: page.openNextcloud()
    }

    EmptyNote {
        enabled: taskModel.count === 0 && page.mode === "tasks"
                 && !(page.view === "today" && doneModel.count > 0)
        text: page.view === "today"    ? qsTr("Nothing due today")
            : page.view === "upcoming" ? qsTr("Nothing ahead")
                                       : qsTr("No loose ends")
        hintText: qsTr("Type below to add one")
    }

    Item {
        id: capture

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: page.mode === "tasks" ? field.height : 0
        visible: page.mode === "tasks"

        Rectangle {
            anchors.fill: parent
            color: FiatAgendaTheme.ambient ? FiatAgendaTheme.card
                                           : FiatAgendaTheme.backgroundLow
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: FiatAgendaTheme.hairline
        }

        TextField {
            id: field
            anchors.left: parent.left
            anchors.right: addButton.left
            anchors.bottom: parent.bottom
            label: qsTr("New task")
            placeholderText: page.view === "today"    ? qsTr("Add to today")
                           : page.view === "upcoming" ? qsTr("Add for tomorrow")
                                                      : qsTr("Add a task")

            color: FiatAgendaTheme.primaryText
            inputMethodHints: Qt.ImhNoPredictiveText
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: page.commitCapture()
        }


        BackgroundItem {
            id: addButton
            anchors.right: parent.right
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: field.verticalCenter
            width: Theme.itemSizeExtraSmall
            height: Theme.itemSizeExtraSmall
            highlightedColor: FiatAgendaTheme.highlightWash
            // Quiet until there is something to commit.
            opacity: field.text.length > 0 ? 1.0 : 0.0
            enabled: field.text.length > 0
            Behavior on opacity { FadeAnimation { } }
            onClicked: page.commitCapture()

            Label {
                anchors.centerIn: parent
                text: "+"
                font.pixelSize: Theme.fontSizeLarge
                color: FiatAgendaTheme.accent
            }
        }
    }

    ActivityLine {
        running: (api.busy > 0 || dav.busy) && !page.syncAsked && !households.refreshAsked
    }

    function commitCapture() {
        var t = field.text.replace(/^\s+|\s+$/g, "")
        if (t === "") return

        Storage.addTask(t,
                        "",
                        view === "today"    ? Dates.todayISO()
                      : view === "upcoming" ? Dates.tomorrowISO()
                                            : "")
        field.text = ""
        reload()
        // Keep the keyboard up: capture comes in bursts, not one at a time.
        field.forceActiveFocus()
    }
}
