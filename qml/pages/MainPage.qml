import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Storage.js" as Storage
import "../Dates.js" as Dates

// The main page:


Page {
    id: page

    property string view: "today"          // today | upcoming | anytime | list
    property string listName: ""
    property var listNames: []

    readonly property bool manualOrder: view === "anytime" || view === "list"

    allowedOrientations: defaultAllowedOrientations

    function reload() {
        Storage.loadTasks(taskModel, view, listName)
        listNames = Storage.lists()
        // A list stops existing when its last task does. Fall back rather than
        // sit on an empty view with a pill that is no longer there.
        if (view === "list" && listNames.indexOf(listName) < 0) {
            view = "today"
            listName = ""
            Storage.loadTasks(taskModel, view, listName)
        }
    }

    function show(v, name) {
        view = v
        listName = name || ""
        reload()
    }

    onStatusChanged: if (status === PageStatus.Active) reload()

    Component.onCompleted: paint()


    function paint() { FiatAgendaTheme.applyPalette(page) }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: page.paint()
    }


    ListModel { id: taskModel }

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

        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent
            MenuItem {
                text: qsTr("About")
                color: FiatAgendaTheme.primaryText
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: FiatAgendaTheme.ambient ? qsTr("fiat colours") : qsTr("Follow ambience")
                color: FiatAgendaTheme.primaryText
                onClicked: FiatAgendaTheme.setAmbient(!FiatAgendaTheme.ambient)
            }
            MenuItem {
                text: qsTr("Completed")
                color: FiatAgendaTheme.primaryText
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("CompletedPage.qml"))
            }
        }

        header: Component {
            Column {
                width: page.width
                spacing: Theme.paddingMedium

                Wordmark { }

                Flow {
                    x: Theme.horizontalPageMargin
                    width: page.width - Theme.horizontalPageMargin * 2
                    spacing: Theme.paddingSmall

                    Pill {
                        text: qsTr("Today")
                        selected: page.view === "today"
                        onClicked: page.show("today")
                    }
                    Pill {
                        text: qsTr("Upcoming")
                        selected: page.view === "upcoming"
                        onClicked: page.show("upcoming")
                    }
                    Pill {
                        text: qsTr("Anytime")
                        selected: page.view === "anytime"
                        onClicked: page.show("anytime")
                    }
                }

                Flow {
                    x: Theme.horizontalPageMargin
                    width: page.width - Theme.horizontalPageMargin * 2
                    spacing: Theme.paddingSmall
                    visible: page.listNames.length > 0

                    Repeater {
                        model: page.listNames
                        Pill {
                            text: modelData
                            selected: page.view === "list" && page.listName === modelData
                            onClicked: page.show("list", modelData)
                        }
                    }
                }


                Item { width: 1; height: Theme.paddingMedium }
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

            showList: page.view !== "list"
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


    EmptyNote {
        enabled: taskModel.count === 0
        text: page.view === "today"    ? qsTr("Nothing due today")
            : page.view === "upcoming" ? qsTr("Nothing ahead")
            : page.view === "anytime"  ? qsTr("No loose ends")
                                       : qsTr("This list is empty")
        hintText: qsTr("Type below to add one")
    }

    Item {
        id: capture

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: field.height

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
                           : page.view === "anytime"  ? qsTr("Add a task")
                                                      : qsTr("Add to %1").arg(page.listName)

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

    function commitCapture() {
        var t = field.text.replace(/^\s+|\s+$/g, "")
        if (t === "") return

        Storage.addTask(t,
                        view === "list" ? listName : "",
                        view === "today"    ? Dates.todayISO()
                      : view === "upcoming" ? Dates.tomorrowISO()
                                            : "")
        field.text = ""
        reload()
        // Keep the keyboard up: capture comes in bursts, not one at a time.
        field.forceActiveFocus()
    }
}
