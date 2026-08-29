import QtQuick 2.0
import org.nemomobile.calendar 1.0

// Everything that touches the platform calendar, in one file, on purpose.
//
// Loaded through a Loader with an EMPTY source until something actually needs
// it -- see the note in MainPage. A missing or renamed plugin then leaves the
// item null and export quietly does nothing, instead of taking a page down.
//
// Written against what the plugin declares, read off plugins.qmltypes on the
// device rather than out of documentation.
//
// THE ID PROBLEM
// --------------
// createNewEvent() returns a CalendarEventModification: a description of a
// change, not a stored event. save() returns void and is fire-and-forget, and
// the modification never learns the uid the manager assigned. Measured, not
// assumed -- instanceId is empty before save, after save, and a second later:
//
//     instanceId before save '', after save ''
//     instanceId after settling ''
//
// So the id has to be looked UP. That matters because without it saveEvent
// has no previous event to remove, and every edit writes another copy beside
// the last one.
//
// It only has to happen ONCE per event. With an id stored on the task,
// removeAll() finds the old event wherever it is -- so changing the DAY needs
// no special handling at all.
//
// THE COLD MANAGER PROBLEM
// ------------------------
// Calendar.defaultNotebook is EMPTY on the first read. The manager loads its
// notebooks on a worker thread the first time anything touches the Calendar
// singleton, and the property fills in a moment later. Measured on device:
//
//     18:34:03  harbour-fiatagenda: started
//     18:34:13  no default notebook
//     18:34:14  dbus: Activating service 'org.nemomobile.calendardataservice'
//
// An empty notebook is therefore NOT a permissions failure. It is a "not
// yet". Treating it as fatal produced a bug with a strange shape: tasks WITH
// a time exported fine, tasks without one never appeared at all. A timed task
// makes two calls -- one when the day is picked, one when the time is -- and
// the second finds the manager warm. An all-day task makes one, and that one
// is always the cold one.
//
// So a save that arrives before the manager is ready is queued, not dropped.

Item {
    id: bridge

    visible: false

    // Carries the id back when the lookup finds it. saveEvent cannot return
    // it: the agenda query is asynchronous.
    // Carries the task too, so the id can be written without any page being
    // alive to hear the answer.
    signal eventSaved(int taskId, string instanceId)

    // Qt::LocalTime. The TimeSpec enum is not exposed on QML's Qt object, so
    // the integer is written out with its name next to it.
    readonly property int localTime: 0

    // CalendarAgendaModel::AgendaRoles::EventObjectRole, from the plugin's own
    // enum. get(index, role) takes the integer, so the QML role NAME never has
    // to be guessed at.
    readonly property int eventObjectRole: 256

    // FilterMode::FilterNone. Set explicitly -- a filter that hid all-day
    // events would hide exactly the ones this app creates most of.
    readonly property int filterNone: 0

    // An all-day task has no hour to remind at, so its reminders are measured
    // back from this time on the morning it is due.
    readonly property int allDayHour: 9

    // What the pending lookup is looking for.
    property int wantTask: -1
    property string wantTitle: ""
    property string wantDate: ""
    property var wantClaimed: []
    property int attempt: 0

    // True only from the moment the timer has pointed the model at our day.
    //
    // AgendaModel emits updated() on its own -- when it is built, and again
    // whenever the calendar changes underneath it, which includes the write we
    // just made. Those arrive before the model has been given any dates, so it
    // reports zero rows, and acting on them means answering a question nobody
    // asked. Worse, each one used to restart the retry timer: a burst of five
    // could postpone the real query indefinitely.
    property bool querying: false

    // Saves that arrived before the manager had a notebook to save into.
    // At most one per task: a later edit of the same task replaces the
    // earlier one rather than writing two events.
    property var queued: []

    // Touching the singleton is what starts the worker loading. Do it as
    // early as this item exists, so the wait below is as short as possible.
    Component.onCompleted: {
        var warm = Calendar.defaultNotebook
        if (!warm) notebookTimer.start()
    }

    function _dateAt(dueDate, hour, minute) {
        var p = dueDate.split("-")
        return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1,
                        parseInt(p[2], 10), hour, minute, 0)
    }

    /*
     * Write the event for a task. previousId, when set, is removed first:
     * one task, one event.
     *
     * Returns the instanceId if the plugin happens to expose it directly --
     * it does not today, but that costs nothing to check and would make the
     * whole lookup below unnecessary if a future version filled it in.
     * Otherwise returns "" and eventSaved() follows once the agenda answers.
     *
     * remindMinutes is how long BEFORE the task is due the reminder fires;
     * -1 means none. claimedIds are the event ids other tasks already own.
     */
    function saveEvent(taskId, previousId, title, note, dueDate, dueTime, remindMinutes, claimedIds) {
        if (!dueDate) return ""

        var req = {
            taskId: taskId,
            previousId: previousId ? previousId : "",
            title: title,
            note: note,
            dueDate: dueDate,
            dueTime: dueTime,
            remindMinutes: remindMinutes,
            claimedIds: claimedIds ? claimedIds : []
        }

        // Cold manager: hold the request rather than dropping it. The removal
        // of the previous event waits too -- removeAll() on a manager with no
        // notebooks has nothing to search.
        if (!Calendar.defaultNotebook) {
            _enqueue(req)
            notebookTimer.start()
            console.log("harbour-fiatagenda: calendar not ready yet, queued '"
                        + title + "'")
            return ""
        }

        return _write(req)
    }

    function _enqueue(req) {
        var q = []
        for (var i = 0; i < queued.length; i++)
            if (queued[i].taskId !== req.taskId) q.push(queued[i])
        q.push(req)
        queued = q
    }

    function _write(req) {
        if (req.previousId) removeEvent(req.previousId)

        // An event with no notebook is not stored -- mkcal answers
        // "addEvent(): NotebookUid empty" and drops it.
        var notebook = Calendar.defaultNotebook
        if (!notebook) return ""

        var ev = Calendar.createNewEvent()
        if (ev === null || ev === undefined) return ""

        ev.calendarUid = notebook
        ev.displayLabel = req.title
        ev.description = req.note ? req.note : ""

        var start, end, remindFrom
        if (req.dueTime && req.dueTime.length === 5) {
            var hh = parseInt(req.dueTime.substring(0, 2), 10)
            var mi = parseInt(req.dueTime.substring(3, 5), 10)
            start = _dateAt(req.dueDate, hh, mi)
            end = new Date(start.getTime() + 3600000)   // one hour
            remindFrom = start
            ev.allDay = false
        } else {
            start = _dateAt(req.dueDate, 0, 0)
            end = start
            remindFrom = _dateAt(req.dueDate, allDayHour, 0)
            ev.allDay = true
        }

        ev.setStartTime(start, localTime)
        ev.setEndTime(end, localTime)

        // The reminder rides on the event. The system fires it, so it works
        // whether or not this app is running -- no alarm to register, no
        // D-Bus service to wake, no notification to publish.
        //
        // A moment that has already passed never fires. Say so rather than
        // pretending a reminder was set.
        if (req.remindMinutes >= 0) {
            var at = new Date(remindFrom.getTime() - req.remindMinutes * 60000)
            if (at.getTime() > new Date().getTime()) {
                ev.reminderDateTime = at
            } else {
                console.log("harbour-fiatagenda: reminder time has already passed, "
                            + "not setting one")
            }
        }

        ev.save()

        if (ev.instanceId) return ev.instanceId

        wantTask = req.taskId
        wantTitle = req.title
        wantDate = req.dueDate
        wantClaimed = req.claimedIds
        attempt = 0
        querying = false
        settleTimer.restart()
        return ""
    }

    function removeEvent(instanceId) {
        if (!instanceId) return
        Calendar.removeAll(instanceId)
    }

    // ------------------------------------------------- waiting for the db --

    // Poll rather than listen: the singleton exposes defaultNotebook as a
    // plain property and there is no signal in plugins.qmltypes that promises
    // to fire when it fills in. Ten tries at 400 ms is four seconds, which is
    // far longer than the second the device actually took, and it stops the
    // moment the answer arrives.
    Timer {
        id: notebookTimer
        interval: 400
        repeat: true
        property int tries: 0

        onRunningChanged: if (running) tries = 0

        onTriggered: {
            if (Calendar.defaultNotebook) {
                stop()
                var q = bridge.queued
                bridge.queued = []
                for (var i = 0; i < q.length; i++) bridge._write(q[i])
                if (q.length > 0)
                    console.log("harbour-fiatagenda: calendar ready, wrote "
                                + q.length + " queued event(s)")
                return
            }
            if (++tries >= 10) {
                stop()
                if (bridge.queued.length > 0) {
                    console.log("harbour-fiatagenda: the calendar database never "
                                + "became readable -- dropping "
                                + bridge.queued.length + " event(s). Is the app "
                                + "running under sailjail with "
                                + "Permissions=Calendar;Privileged?")
                    bridge.queued = []
                }
            }
        }
    }

    // ---------------------------------------------------------- the lookup --

    // The plugin writes asynchronously, so the agenda is asked a beat after
    // save() rather than immediately, and asked again if the event has not
    // landed yet. Three tries is generous; if it is not there by then it is
    // not coming, and the log says so instead of failing in silence.
    Timer {
        id: settleTimer
        interval: 600
        onTriggered: {
            if (bridge.wantDate === "") return
            bridge.attempt++
            bridge.querying = true

            var d = bridge._dateAt(bridge.wantDate, 0, 0)
            // Nudge the range off and back, or setting the same dates twice
            // in a row emits no updated() and a retry waits forever.
            finder.startDate = new Date(1970, 0, 1)
            finder.endDate = new Date(1970, 0, 1)
            finder.startDate = d
            finder.endDate = d
        }
    }

    AgendaModel {
        id: finder
        filterMode: bridge.filterNone

        onUpdated: {
            if (bridge.wantDate === "" || !bridge.querying) return

            // Answer only for the day we actually asked about. This throws
            // away both the 1970 nudge and any update the model makes on its
            // own account.
            var want = bridge._dateAt(bridge.wantDate, 0, 0)
            if (startDate.getFullYear() !== want.getFullYear()
                || startDate.getMonth() !== want.getMonth()
                || startDate.getDate() !== want.getDate()) return

            var found = ""
            for (var i = 0; i < count; i++) {
                var ev = get(i, bridge.eventObjectRole)
                if (ev === null || ev === undefined) continue
                if (ev.displayLabel !== bridge.wantTitle) continue
                var id = ev.instanceId
                if (!id) continue
                if (bridge.wantClaimed.indexOf(id) >= 0) continue   // someone else's twin
                found = id
                break
            }

            // The date printed is the model's own, not the one we hoped for.
            console.log("harbour-fiatagenda: agenda for "
                        + startDate.getFullYear() + "-"
                        + (startDate.getMonth() + 1) + "-" + startDate.getDate()
                        + " has " + count + " row(s), attempt " + bridge.attempt
                        + ", matched '" + found + "'")

            if (found !== "") {
                var task = bridge.wantTask
                bridge.querying = false
                bridge.wantDate = ""
                bridge.wantTitle = ""
                bridge.wantTask = -1
                bridge.eventSaved(task, found)
            } else if (bridge.attempt < 3) {
                bridge.querying = false
                settleTimer.restart()
            } else {
                bridge.querying = false
                console.log("harbour-fiatagenda: gave up looking for '"
                            + bridge.wantTitle + "' on " + bridge.wantDate
                            + " -- the next edit will add a second event "
                            + "rather than replace this one")
                bridge.wantDate = ""
                bridge.wantTitle = ""
            }
        }
    }
}
