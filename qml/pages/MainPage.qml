import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Storage.js" as Storage
import "../Dates.js" as Dates

// The main page: one list, one row of pills, one field.
//
// The views are computed from dates, never curated:
//   Today     everything dated on or before today. Overdue tasks belong to
//             today -- giving them their own screen only means two lists to
//             look at before breakfast.
//   Upcoming  everything after today, nearest first.
//   Anytime   no date at all, in the order you dragged them. "No date" is a
//             normal state, not an unfinished one, so it gets a real home.
//   Lists     one named list, likewise in manual order.
//
// Capture inherits the meaning of the view you are standing in: type in Today
// and the task is due today, type in a list and it joins that list. The
// placeholder says so out loud, so it reads as a rule rather than magic.

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

    // Coming back from a task page, the completed page, anywhere.
    onStatusChanged: if (status === PageStatus.Active) reload()

    Component.onCompleted: paint()

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


    ListModel { id: taskModel }

    // Fiat colours paint their own paper. Under an ambience there is no
    // background at all -- the wallpaper is the background.
    FiatBackground { }

    SilicaListView {
        id: taskList

        anchors.fill: parent
        anchors.bottomMargin: capture.height
        model: taskModel
        clip: true

        // No backgroundColor here: it paints the whole panel and dims the
        // entire screen behind the menu. Colour the items instead -- they read
        // Theme.* directly and will otherwise stay ambience-coloured under
        // Fiat colours no matter what the palette says.
        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent

            MenuItem {
                // Named for where you are going, not where you are.
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

                // Lists sit on their own line so they read as a different kind
                // of thing from the three computed views. There is no tag
                // taxonomy on top of this and there is not going to be.
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

                // Positioners have no padding on this Qt, and the first row
                // must not sit flush against the pills.
                Item { width: 1; height: Theme.paddingMedium }
            }
        }

        delegate: TaskRow {
            width: taskList.width
            taskId: model.taskId
            title: model.title
            listName: model.listName
            dueDate: model.dueDate
            dueTime: model.dueTime
            repeatEvery: model.repeatEvery
            repeatUnit: model.repeatUnit
            subTotal: model.subTotal
            subDone: model.subDone

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
                Storage.deleteTask(model.taskId)
                taskModel.remove(index)
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

    // Outside the list view on purpose: a plain child of a ListView is
    // parented to its contentItem, which has no height when the model is
    // empty -- exactly when this needs to be visible.
    EmptyNote {
        enabled: taskModel.count === 0
        text: page.view === "today"    ? qsTr("Nothing due today")
            : page.view === "upcoming" ? qsTr("Nothing ahead")
            : page.view === "anytime"  ? qsTr("No loose ends")
                                       : qsTr("This list is empty")
        hintText: qsTr("Type below to add one")
    }

    // Fast capture, in the thumb zone.
    //
    // This is the one piece of permanent chrome on the main page, and it earns
    // the place: capture is the primary action, not a secondary one, and a
    // task manager you have to open a dialog to add to is a task manager you
    // stop adding to. Open, type, enter -- under two seconds, no forced fields.
    Item {
        id: capture

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: field.height

        Rectangle {
            anchors.fill: parent
            // Under Fiat colours this is the bottom of the gradient, so the
            // bar disappears into the paper and only the hairline shows.
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
            // Every field in the app names its own colour. The palette gets
            // the underline and the label; the text itself does not always
            // follow, and white text on cream paper is invisible.
            color: FiatAgendaTheme.primaryText
            inputMethodHints: Qt.ImhNoPredictiveText
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: page.commitCapture()
        }

        // A BackgroundItem with a drawn label rather than an IconButton --
        // same reason Fiat Mos's "+ Add set" is one. It is the idiom the
        // family already uses, and it needs nothing from Silica beyond what
        // is proven on this device.
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
