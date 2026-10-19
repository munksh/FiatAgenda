/*
 * Fiat Agenda -- your tasks, and the household's lists.
 *
 * Part of the Munkstolen Fiat family. The Fiat colours standard lives in
 * FiatAgendaTheme. Besides handing Silica's chrome the palette, this file
 * owns what must outlive any page: the calendar bridge, and the sync with
 * Nextcloud Tasks.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "."          // qmldir lives here: this is what resolves FiatAgendaTheme
import "pages"
import "Storage.js" as Storage
import "Sync.js" as Sync

ApplicationWindow {
    id: app

    initialPage: Component { MainPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    /*
     * Fiat colours reach only what the app draws itself. Menus, pull-down
     * drawers, TextField labels and underlines, sliders and selection all
     * read Theme.* directly, and most of them expose no colour property to
     * set. `palette` is the way in: assigned once here, every Silica control
     * on every page below inherits it.
     *
     * Re-applied rather than reverted when the switch is thrown -- under an
     * ambience applyPalette feeds Silica back its own Theme.* values, so the
     * toggle round-trips cleanly with nothing to remember.
     */
    Component.onCompleted: {
        Storage.init()
        // Same line Fiat Mos prints. If this never appears in
        //     journalctl -f | grep -i agenda
        // then the root QML itself never loaded, and the problem is the
        // package, not the pages.
        console.log("harbour-fiatagenda: started")
        // The theme re-applies the palette itself when the switch is thrown;
        // it needs to know what to apply it to.
        FiatAgendaTheme.appWindow = app
        // Once, here: palette is inherited, so every Silica control in every
        // page below picks it up.
        FiatAgendaTheme.applyPalette(app)
        if (account.signedIn) {
            account.checkPantry()
            syncNow()
        }
    }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: FiatAgendaTheme.applyPalette(app)
    }

    /*
     * The calendar bridge lives HERE, not on a page.
     *
     * Writing an event is asynchronous: the plugin hands the work to a worker
     * thread with a queued connection, so the event's id has to be looked up
     * afterwards, which takes about a second. A bridge owned by TaskPage dies
     * with TaskPage -- and changing a date and going straight back is exactly
     * the case where the page is torn down mid-lookup. The id then never lands
     * on the task, the next edit has nothing to remove, and you get a second
     * event beside the first. That was the duplicate on date change.
     *
     * Up here it outlives any page, and the id is written straight to the
     * database by whoever it belongs to -- no page has to still be alive.
     *
     * Still an empty source until something asks: a user who never exports
     * never loads the plugin.
     */
    Loader { id: calendarLoader }

    function calendarBridge() {
        if (calendarLoader.source == "")
            calendarLoader.source = Qt.resolvedUrl("components/CalendarBridge.qml")
        return calendarLoader.item
    }

    Connections {
        target: calendarLoader.item
        ignoreUnknownSignals: true
        onEventSaved: {
            if (taskId > 0 && instanceId !== "")
                Storage.updateTask(taskId, { calendarEventId: instanceId })
        }
    }

    // ---- Nextcloud ----
    //
    // Tasks sync with Nextcloud Tasks when it is switched on: at start, when
    // the app comes back to the front, a few seconds after a change, and
    // every five minutes while it is open. A run that failed is not retried
    // for a minute, so a phone without a connection is not kept busy.

    ConfigurationValue {
        id: tasksSyncConfig
        key: "/apps/harbour-fiatagenda/tasksSync"
        defaultValue: false
    }
    ConfigurationValue {
        id: lastSyncConfig
        key: "/apps/harbour-fiatagenda/lastSync"
        defaultValue: 0
    }

    readonly property bool tasksSync: account.signedIn
                                      && (tasksSyncConfig.value === true || tasksSyncConfig.value === "true")
    property bool syncing: false
    property string syncError: ""
    readonly property double lastSync: Number(lastSyncConfig.value) || 0
    property double lastFailure: 0
    property string nextcloudNotice: ""

    // After a run that changed something here, so the pages read again.
    signal synced()

    function setTasksSync(on) {
        tasksSyncConfig.value = on
        if (on) syncNow()
    }

    function syncNow() {
        if (!tasksSync || syncing) return
        syncing = true
        Sync.run(dav, function (ok, report) {
            app.syncing = false
            if (report.busy) return
            if (ok) {
                app.syncError = ""
                lastSyncConfig.value = new Date().getTime()
            } else {
                app.syncError = report.errors.length > 0 ? report.errors[0] : ""
                app.lastFailure = new Date().getTime()
            }
            app.followCalendar(report)
            if (report.pulled > 0 || report.removed > 0) app.synced()
        })
    }

    function syncSoon() {
        if (!tasksSync || syncing) return
        if (new Date().getTime() - lastFailure < 60000) return
        if (Storage.pendingCount() > 0) soonTimer.restart()
    }

    Timer {
        id: soonTimer
        interval: 4000
        onTriggered: app.syncNow()
    }
    Timer {
        interval: 300000
        repeat: true
        running: app.tasksSync && Qt.application.state === Qt.ApplicationActive
        onTriggered: app.syncNow()
    }
    Connections {
        target: Qt.application
        onStateChanged: {
            if (!app.tasksSync) return
            var now = new Date().getTime()
            if (Qt.application.state === Qt.ApplicationActive) {
                if (now - app.lastSync > 60000 && now - app.lastFailure > 60000) app.syncNow()
            } else if (Storage.pendingCount() > 0) {
                app.syncNow()
            }
        }
    }

    // A task the server changed keeps its calendar entry in step, the same
    // way an edit on the task page does.
    function followCalendar(report) {
        var ids = report.changed || []
        var gone = report.removedEvents || []
        if (ids.length === 0 && gone.length === 0) return
        var bridge = null
        try {
            for (var i = 0; i < ids.length; i++) {
                var t = Storage.getTask(ids[i])
                if (t === null || (t.exportToCalendar !== 1 && t.calendarEventId === "")) continue
                if (bridge === null) bridge = calendarBridge()
                if (bridge === null) return
                if (t.exportToCalendar !== 1 || t.dueDate === "") {
                    if (t.calendarEventId !== "") bridge.removeEvent(t.calendarEventId)
                    Storage.updateTask(t.taskId, { calendarEventId: "" })
                    continue
                }
                var id = bridge.saveEvent(t.taskId, t.calendarEventId, t.title, t.note, t.dueDate,
                                          t.dueTime, t.remindMinutes, Storage.claimedCalendarIds())
                if (id !== "") Storage.updateTask(t.taskId, { calendarEventId: id })
            }
            for (var j = 0; j < gone.length; j++) {
                if (bridge === null) bridge = calendarBridge()
                if (bridge !== null) bridge.removeEvent(gone[j])
            }
        } catch (e) {
            console.log("harbour-fiatagenda: calendar unavailable -- " + e)
        }
    }

    // Signing out lets go of the server; every task stays on the phone.
    function signOut() {
        Storage.forgetServer()
        account.signOut()
    }

    // A revoked app password answers 401 to everything.
    function lostSignIn() {
        if (!account.signedIn) return
        nextcloudNotice = qsTr("The server no longer accepts this phone's sign-in. Connect again to go on syncing.")
        signOut()
    }
    Connections { target: api; onUnauthorized: app.lostSignIn() }
    Connections { target: dav; onUnauthorized: app.lostSignIn() }
    Connections {
        target: account
        onSignedInNow: {
            app.nextcloudNotice = ""
            account.checkPantry()
        }
        onPantryChanged: if (account.pantryState === "unauthorized") app.lostSignIn()
    }
}
