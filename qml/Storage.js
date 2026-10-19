/*
 * Storage.js -- the whole data layer.
 *
 * One tasks table. Lists are a name on the task, not a table; subtasks are a
 * parentId on the task, not a table. That is deliberate: the feature set is
 * one level of subtasks and flat lists, and any more normalisation than that
 * would be paying for a project manager Fiat Agenda is not.
 *
 * Two rules that are easy to forget and expensive to rediscover:
 *   1. SQL passed to tx.executeSql() must be on ONE line. Multi-line strings
 *      do not work there.
 *   2. This file must be in DISTFILES or it will not deploy.
 */

.pragma library
.import QtQuick.LocalStorage 2.0 as LS
.import "Dates.js" as Dates

var SCHEMA = "5"       // bump, add a step to migrate(), never edit an old step

var ready = false

/*
 * Every entry point goes through db(), and db() migrates on first use. That
 * is deliberate: the alternative is calling init() from the ApplicationWindow
 * and hoping it runs before the first page does -- which it does not, because
 * a window's Component.onCompleted fires after its children have already
 * built themselves and asked for rows.
 */
function db() {
    var d = open_()
    if (!ready) {
        ready = true          // set before migrating: migrate() calls db() itself
        d = migrate(d)
    }
    return d
}

function open_() {
    return LS.LocalStorage.openDatabaseSync("FiatAgenda", "", "Fiat Agenda", 1000000)
}

/*
 * Schema versioning, the same way the other Fiat apps do it: the database
 * carries its own version and migrate() walks it forward one step at a time.
 * Every step is a one-way door -- write a new step, never edit a shipped one,
 * or a phone that already migrated will never receive the fix.
 *
 * The handle is re-opened after each step so its version property is the one
 * on disk rather than the one it was opened with.
 */
function migrate(d) {
    if (d.version === "") {
        d.changeVersion("", "1", function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, note TEXT DEFAULT '', listName TEXT DEFAULT '', parentId INTEGER DEFAULT 0, done INTEGER DEFAULT 0, doneAt INTEGER DEFAULT 0, dueDate TEXT DEFAULT '', dueTime TEXT DEFAULT '', repeatEvery INTEGER DEFAULT 0, repeatUnit TEXT DEFAULT '', sortIndex INTEGER DEFAULT 0, createdAt INTEGER DEFAULT 0)")
        })
        d = open_()
    }

    // v2 adds the two native integration flags. They are independent of each
    // other and both optional. Nothing reads them yet; the columns exist so
    // calendar export and scheduled reminders can land without a migration
    // that has to touch live rows.
    if (d.version === "1") {
        d.changeVersion("1", "2", function (tx) {
            tx.executeSql("ALTER TABLE tasks ADD COLUMN exportToCalendar INTEGER DEFAULT 0")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN calendarEventId TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remindAt TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN alarmCookie INTEGER DEFAULT 0")
        })
        d = open_()
    }

    // v3: how long before a task is due its reminder should fire, in minutes.
    // -1 is off. Minutes rather than a timestamp on purpose: a recurring task
    // moves, and a stored absolute time would go stale the first time it did.
    // The absolute moment is computed when the calendar event is written.
    if (d.version === "2") {
        d.changeVersion("2", "3", function (tx) {
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remindMinutes INTEGER DEFAULT -1")
        })
        d = open_()
    }

    // v4: sync with a CalDAV server (Nextcloud Tasks).
    //   remote*      where the task lives on the server, and the copy last
    //                seen there -- kept whole, so properties other clients set
    //                survive a write from here
    //   dirty        changed here since it was last sent; 1 for every row
    //                that exists today, so a list switched on later sends all
    //   modifiedAt   when it changed here, for "the newest change wins"
    //   tombstones   tasks deleted here that the server still has
    //   remote_lists the server's task lists and which list here each one is
    if (d.version === "3") {
        d.changeVersion("3", "4", function (tx) {
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remoteUid TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remoteHref TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remoteEtag TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remoteList TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN remoteIcs TEXT DEFAULT ''")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN dirty INTEGER DEFAULT 1")
            tx.executeSql("ALTER TABLE tasks ADD COLUMN modifiedAt INTEGER DEFAULT 0")
            tx.executeSql("CREATE TABLE IF NOT EXISTS tombstones (href TEXT PRIMARY KEY, etag TEXT DEFAULT '')")
            tx.executeSql("CREATE TABLE IF NOT EXISTS remote_lists (href TEXT PRIMARY KEY, name TEXT DEFAULT '', color TEXT DEFAULT '', listName TEXT DEFAULT '', enabled INTEGER DEFAULT 0, isDefault INTEGER DEFAULT 0)")
        })
        d = open_()
    }

    // v5: the Lists side without a server. The phone's own household, kept in
    // the same shape Pantry uses, so the same pages show it. Times are in
    // seconds, as Pantry's are.
    if (d.version === "4") {
        d.changeVersion("4", "5", function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS shelf_lists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT DEFAULT '', color TEXT DEFAULT '', sortOrder INTEGER DEFAULT 0, createdAt INTEGER DEFAULT 0, updatedAt INTEGER DEFAULT 0)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS shelf_items (id INTEGER PRIMARY KEY AUTOINCREMENT, listId INTEGER NOT NULL, name TEXT NOT NULL, description TEXT DEFAULT '', quantity TEXT DEFAULT '', categoryId INTEGER DEFAULT 0, done INTEGER DEFAULT 0, doneAt INTEGER DEFAULT 0, rrule TEXT DEFAULT '', repeatFromCompletion INTEGER DEFAULT 0, deleteOnDone INTEGER DEFAULT 0, nextDueAt INTEGER DEFAULT 0, sortOrder INTEGER DEFAULT 0, createdAt INTEGER DEFAULT 0, updatedAt INTEGER DEFAULT 0)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS shelf_categories (id INTEGER PRIMARY KEY AUTOINCREMENT, listId INTEGER DEFAULT 0, name TEXT NOT NULL, color TEXT DEFAULT '', icon TEXT DEFAULT '', sortOrder INTEGER DEFAULT 0, createdAt INTEGER DEFAULT 0)")
        })
        d = open_()
    }

    return d
}

// Kept so the app can warm the database at startup instead of paying for the
// migration inside the first query. Calling it is optional.
function init() { db() }

// ---------------------------------------------------------------- reading --

var SELECT_ROW = "SELECT t.id, t.title, t.note, t.listName, t.parentId, t.done, t.doneAt, t.dueDate, t.dueTime, t.repeatEvery, t.repeatUnit, t.sortIndex, t.exportToCalendar, IFNULL(t.calendarEventId,'') AS calendarEventId, IFNULL(t.remindMinutes,-1) AS remindMinutes, (SELECT COUNT(*) FROM tasks s WHERE s.parentId = t.id) AS subTotal, (SELECT COUNT(*) FROM tasks s WHERE s.parentId = t.id AND s.done = 1) AS subDone FROM tasks t "

// The model role is taskId, not id: `id` is loaded language in a QML
// delegate, and the one place a reader has to pause is the one place a bug
// hides.
// LocalStorage stores a bound "" as NULL, so text is read back through text().
function text(v) { return (v === null || v === undefined) ? "" : v }

function rowToObject(r) {
    return {
        taskId: r.id, title: text(r.title), note: text(r.note), listName: text(r.listName),
        parentId: r.parentId, done: r.done, doneAt: r.doneAt,
        dueDate: text(r.dueDate), dueTime: text(r.dueTime),
        repeatEvery: r.repeatEvery, repeatUnit: text(r.repeatUnit),
        sortIndex: r.sortIndex,
        exportToCalendar: (r.exportToCalendar === undefined ? 0 : r.exportToCalendar),
        calendarEventId: (r.calendarEventId === undefined ? "" : r.calendarEventId),
        remindMinutes: (r.remindMinutes === undefined ? -1 : r.remindMinutes),
        subTotal: (r.subTotal === undefined ? 0 : r.subTotal),
        subDone: (r.subDone === undefined ? 0 : r.subDone)
    }
}

/*
 * Fill a ListModel with one view's worth of tasks.
 *
 *   today     everything dated on or before today and not done -- overdue
 *             tasks belong to today, they do not get their own screen
 *   upcoming  dated after today
 *   anytime   no date at all, in the order the user dragged them into
 *   list      one named list, likewise in manual order
 *
 * Only top-level tasks. Subtasks live on the task's own page.
 */
function loadTasks(model, view, listName) {
    model.clear()
    var where, args = []
    var order = " ORDER BY t.dueDate ASC, CASE WHEN t.dueTime = '' THEN 1 ELSE 0 END ASC, t.dueTime ASC, t.sortIndex ASC"

    if (view === "today") {
        where = "WHERE t.parentId = 0 AND t.done = 0 AND IFNULL(t.dueDate,'') != '' AND t.dueDate <= ?"
        args = [Dates.todayISO()]
    } else if (view === "upcoming") {
        where = "WHERE t.parentId = 0 AND t.done = 0 AND IFNULL(t.dueDate,'') > ?"
        args = [Dates.todayISO()]
    } else if (view === "anytime") {
        where = "WHERE t.parentId = 0 AND t.done = 0 AND IFNULL(t.dueDate,'') = ''"
        order = " ORDER BY t.sortIndex ASC, t.id ASC"
    } else {
        where = "WHERE t.parentId = 0 AND t.done = 0 AND IFNULL(t.listName,'') = ?"
        args = [listName]
        order = " ORDER BY t.sortIndex ASC, t.id ASC"
    }

    db().readTransaction(function (tx) {
        var rs = tx.executeSql(SELECT_ROW + where + order, args)
        for (var i = 0; i < rs.rows.length; i++) model.append(rowToObject(rs.rows.item(i)))
    })
}

function loadSubtasks(model, parentId) {
    model.clear()
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT id, title, done, sortIndex FROM tasks WHERE parentId = ? ORDER BY sortIndex ASC, id ASC", [parentId])
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            model.append({ taskId: r.id, title: r.title, done: r.done, sortIndex: r.sortIndex })
        }
    })
}

function loadCompleted(model) {
    model.clear()
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT id, title, listName, dueDate, dueTime, doneAt FROM tasks WHERE done = 1 AND parentId = 0 ORDER BY doneAt DESC, id DESC", [])
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            model.append({ taskId: r.id, title: r.title, listName: r.listName,
                           dueDate: r.dueDate, dueTime: r.dueTime, doneAt: r.doneAt })
        }
    })
}

// What was finished today, for the foot of the Today view and its ring. A
// recurring task that was done today has moved on to its next date and is
// not done, but its doneAt says today, so it counts as well.
function loadDoneToday(model) {
    model.clear()
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT id, title, IFNULL(listName,'') AS listName, done, doneAt, repeatEvery FROM tasks WHERE parentId = 0 AND doneAt >= ? ORDER BY doneAt ASC, id ASC", [Dates.startOfTodayMs()])
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            model.append({ taskId: r.id, title: text(r.title), listName: text(r.listName),
                           done: r.done, doneAt: r.doneAt, repeatEvery: r.repeatEvery })
        }
    })
}

function getTask(id) {
    var out = null
    db().readTransaction(function (tx) {
        var rs = tx.executeSql(SELECT_ROW + "WHERE t.id = ?", [id])
        if (rs.rows.length > 0) out = rowToObject(rs.rows.item(0))
    })
    return out
}

// Every list name in use, alphabetically. There is no lists table: a list
// exists exactly as long as a task names it -- or, for a list synced with the
// server, as long as it is synced, so an emptied shared list stays in view.
function lists() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT listName FROM tasks WHERE IFNULL(listName,'') != '' AND done = 0 UNION SELECT listName FROM remote_lists WHERE enabled = 1 AND isDefault = 0 AND IFNULL(listName,'') != '' ORDER BY 1 COLLATE NOCASE ASC", [])
        for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i).listName)
    })
    return out
}

// What the cover needs, in one pass.
function summary() {
    var out = { today: 0, overdue: 0, next: "", nextDue: "" }
    var t = Dates.todayISO()
    db().readTransaction(function (tx) {
        var a = tx.executeSql("SELECT COUNT(*) AS n FROM tasks WHERE parentId = 0 AND done = 0 AND IFNULL(dueDate,'') != '' AND dueDate <= ?", [t])
        out.today = a.rows.item(0).n
        var b = tx.executeSql("SELECT COUNT(*) AS n FROM tasks WHERE parentId = 0 AND done = 0 AND IFNULL(dueDate,'') != '' AND dueDate < ?", [t])
        out.overdue = b.rows.item(0).n
        var c = tx.executeSql("SELECT title, dueDate FROM tasks WHERE parentId = 0 AND done = 0 AND IFNULL(dueDate,'') != '' ORDER BY dueDate ASC, CASE WHEN dueTime = '' THEN 1 ELSE 0 END ASC, dueTime ASC, sortIndex ASC LIMIT 1", [])
        if (c.rows.length > 0) { out.next = c.rows.item(0).title; out.nextDue = c.rows.item(0).dueDate }
    })
    return out
}

// ---------------------------------------------------------------- writing --

// New tasks go to the top of a manually ordered view, not the bottom: what
// you just typed is what you are thinking about.
function nextSortIndex(parentId) {
    var v = 0
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT MIN(sortIndex) AS lo FROM tasks WHERE parentId = ?", [parentId])
        var lo = rs.rows.item(0).lo
        v = (lo === null || lo === undefined) ? 0 : lo - 1
    })
    return v
}

/*
 * Fast capture. Everything except the title is optional, and the caller
 * passes the view's own meaning as the default: a task captured in Today is
 * due today, a task captured inside a list joins that list. No extra taps,
 * and no dialog between the thought and the row.
 */
function addTask(title, listName, dueDate) {
    var id = -1
    var idx = nextSortIndex(0)
    db().transaction(function (tx) {
        var now = new Date().getTime()
        var rs = tx.executeSql("INSERT INTO tasks (title, note, listName, parentId, done, doneAt, dueDate, dueTime, repeatEvery, repeatUnit, sortIndex, createdAt, dirty, modifiedAt) VALUES (?, '', ?, 0, 0, 0, ?, '', 0, '', ?, ?, 1, ?)", [title, listName || "", dueDate || "", idx, now, now])
        id = parseInt(rs.insertId, 10)
    })
    return id
}

function addSubtask(parentId, title) {
    var id = -1
    db().transaction(function (tx) {
        var rs = tx.executeSql("SELECT COALESCE(MAX(sortIndex), -1) + 1 AS hi FROM tasks WHERE parentId = ?", [parentId])
        var idx = rs.rows.item(0).hi
        var now = new Date().getTime()
        var ins = tx.executeSql("INSERT INTO tasks (title, note, listName, parentId, done, doneAt, dueDate, dueTime, repeatEvery, repeatUnit, sortIndex, createdAt, dirty, modifiedAt) VALUES (?, '', '', ?, 0, 0, '', '', 0, '', ?, ?, 1, ?)", [title, parentId, idx, now, now])
        id = parseInt(ins.insertId, 10)
    })
    return id
}

// fields is a plain object of column -> value. Unknown columns are dropped
// rather than trusted, so a typo cannot become SQL.
// Columns that may be written, and the ones that must never hold NULL.
// An empty string means "no date" / "no list" and is a real, common state --
// but NULL is not the same thing. `dueDate = ''` is false for NULL and so is
// `dueDate != ''`, so one stray NULL drops a task out of Today, Upcoming AND
// Anytime at once: it does not move, it vanishes. Belt and braces here, and
// IFNULL in every query above.
var TEXT_COLUMNS = ["title", "note", "listName", "dueDate", "dueTime",
                    "repeatUnit", "calendarEventId", "remindAt"]

var WRITABLE = ["title", "note", "listName", "dueDate", "dueTime",
                "repeatEvery", "repeatUnit", "done", "doneAt", "sortIndex",
                "exportToCalendar", "calendarEventId", "remindMinutes",
                "remindAt", "alarmCookie"]

// The columns a synced copy carries. A change to any other (the calendar
// event's id, say) is this phone's business and is not sent anywhere.
var SYNCED = ["title", "note", "listName", "dueDate", "dueTime", "repeatEvery",
              "repeatUnit", "done", "doneAt", "sortIndex"]

function updateTask(id, fields) {
    var sets = [], args = []
    var synced = false
    for (var k in fields) {
        if (WRITABLE.indexOf(k) < 0) continue
        var v = fields[k]
        if (TEXT_COLUMNS.indexOf(k) >= 0 && (v === null || v === undefined)) v = ""
        sets.push(k + " = ?")
        args.push(v)
        if (SYNCED.indexOf(k) >= 0) synced = true
    }
    if (sets.length === 0) return
    if (synced) {
        sets.push("dirty = 1", "modifiedAt = ?")
        args.push(new Date().getTime())
    }
    args.push(id)
    db().transaction(function (tx) {
        tx.executeSql("UPDATE tasks SET " + sets.join(", ") + " WHERE id = ?", args)
    })
}

// Real delete. No soft-delete, no append-only history -- this is a task list,
// not Fiat Mos. The remorse timer on the swipe is the only safety net, and
// for a to-do it is enough. Subtasks go with the parent.
// A task the server has is remembered as a tombstone, so the next sync can
// delete it there too.
function deleteTask(id) {
    db().transaction(function (tx) {
        tx.executeSql("INSERT OR REPLACE INTO tombstones (href, etag) SELECT remoteHref, IFNULL(remoteEtag,'') FROM tasks WHERE (id = ? OR parentId = ?) AND IFNULL(remoteHref,'') != ''", [id, id])
        tx.executeSql("DELETE FROM tasks WHERE id = ? OR parentId = ?", [id, id])
    })
}

// Every calendar event id already spoken for by some task.
//
// Used to tell twins apart. Two tasks called the same thing on the same day
// produce two events with the same label, and the agenda cannot say which is
// which -- but one of them is already claimed, and the other is the one we
// just wrote.
function claimedCalendarIds() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT calendarEventId FROM tasks WHERE IFNULL(calendarEventId,'') != ''", [])
        for (var i = 0; i < rs.rows.length; i++) out.push(rs.rows.item(i).calendarEventId)
    })
    return out
}

// The calendar event id of a task, read before deleting it. The row is gone by
// the time the caller can clean up after it, so ask first.
function calendarIdOf(id) {
    var out = ""
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT IFNULL(calendarEventId,'') AS c FROM tasks WHERE id = ?", [id])
        if (rs.rows.length > 0) out = rs.rows.item(0).c
    })
    return out
}

/*
 * Completing a task.
 *
 * A recurring task is never finished, only moved: it keeps its identity, its
 * subtasks are unticked, and the due date jumps to the next occurrence after
 * today. Returns the new due date so the UI can say where it went, or "" if
 * the task simply closed.
 */
function setDone(id, done) {
    var t = getTask(id)
    if (t === null) return ""

    if (done && t.repeatEvery > 0 && t.dueDate !== "") {
        var next = Dates.nextOccurrence(t.dueDate, t.repeatEvery, t.repeatUnit)
        var stamp = new Date().getTime()
        db().transaction(function (tx) {
            tx.executeSql("UPDATE tasks SET dueDate = ?, done = 0, doneAt = ?, dirty = 1, modifiedAt = ? WHERE id = ?", [next, stamp, stamp, id])
            tx.executeSql("UPDATE tasks SET done = 0, doneAt = 0, dirty = 1, modifiedAt = ? WHERE parentId = ? AND done = 1", [stamp, id])
        })
        return next
    }

    var now = new Date().getTime()
    db().transaction(function (tx) {
        tx.executeSql("UPDATE tasks SET done = ?, doneAt = ?, dirty = 1, modifiedAt = ? WHERE id = ?", [done ? 1 : 0, done ? now : 0, now, id])
    })
    return ""
}

function clearCompleted() {
    db().transaction(function (tx) {
        tx.executeSql("INSERT OR REPLACE INTO tombstones (href, etag) SELECT remoteHref, IFNULL(remoteEtag,'') FROM tasks WHERE (parentId IN (SELECT id FROM tasks WHERE done = 1 AND parentId = 0) OR (done = 1 AND parentId = 0)) AND IFNULL(remoteHref,'') != ''", [])
        tx.executeSql("DELETE FROM tasks WHERE parentId IN (SELECT id FROM tasks WHERE done = 1 AND parentId = 0)", [])
        tx.executeSql("DELETE FROM tasks WHERE done = 1 AND parentId = 0", [])
    })
}

// ------------------------------------------------------------- reordering --

// Called once when the finger lifts, not on every swap: the model already
// shows the new order, the database just has to agree with it.
function saveOrder(model) {
    var now = new Date().getTime()
    db().transaction(function (tx) {
        for (var i = 0; i < model.count; i++)
            tx.executeSql("UPDATE tasks SET sortIndex = ?, dirty = 1, modifiedAt = ? WHERE id = ? AND sortIndex != ?", [i, now, model.get(i).taskId, i])
    })
}

// ------------------------------------------------------------- shortcuts --

// "Not now" -- push a dated task one day further out, from today at the
// earliest, so deferring something three weeks overdue lands on tomorrow
// rather than three weeks ago plus one.
function defer(id) {
    var t = getTask(id)
    if (t === null || t.dueDate === "") return ""
    var base = t.dueDate < Dates.todayISO() ? Dates.todayISO() : t.dueDate
    var next = Dates.addDays(base, 1)
    updateTask(id, { dueDate: next })
    return next
}

// ------------------------------------------------------------------ sync --
//
// Everything below is for Sync.js. A synced list is a server task list
// (remote_lists) tied to a list name here; "tasks without a list" can be tied
// to one more. Settings never delete anything on the server: switching a list
// off only lets go of it here.

function remoteLists() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT href, name, IFNULL(color,'') AS color, IFNULL(listName,'') AS listName, enabled, isDefault FROM remote_lists ORDER BY name COLLATE NOCASE ASC", [])
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            out.push({ href: r.href, name: r.name, color: r.color, listName: r.listName,
                       enabled: r.enabled === 1, isDefault: r.isDefault === 1 })
        }
    })
    return out
}

function detachTasks(tx, where, args) {
    tx.executeSql("UPDATE tasks SET remoteUid = '', remoteHref = '', remoteEtag = '', remoteList = '', remoteIcs = '', dirty = 1 WHERE " + where, args)
}

// What the server says it has. New lists arrive switched off; a synced list
// renamed on the server takes its list here along; one that is gone lets go.
function updateRemoteLists(found) {
    var known = remoteLists()
    db().transaction(function (tx) {
        var seen = {}
        for (var i = 0; i < found.length; i++) {
            var f = found[i]
            seen[f.href] = true
            var old = null
            for (var j = 0; j < known.length; j++)
                if (known[j].href === f.href) old = known[j]
            if (old === null) {
                tx.executeSql("INSERT INTO remote_lists (href, name, color, listName, enabled, isDefault) VALUES (?, ?, ?, '', 0, 0)", [f.href, f.name, f.color || ""])
                continue
            }
            tx.executeSql("UPDATE remote_lists SET name = ?, color = ? WHERE href = ?", [f.name, f.color || "", f.href])
            if (old.enabled && !old.isDefault && old.listName !== "" && old.name !== f.name) {
                tx.executeSql("UPDATE tasks SET listName = ? WHERE listName = ?", [f.name, old.listName])
                tx.executeSql("UPDATE remote_lists SET listName = ? WHERE href = ?", [f.name, f.href])
            }
        }
        for (var k = 0; k < known.length; k++) {
            if (seen[known[k].href]) continue
            detachTasks(tx, "remoteList = ?", [known[k].href])
            tx.executeSql("DELETE FROM remote_lists WHERE href = ?", [known[k].href])
        }
    })
}

// Tie a server list to a list here: by its own name, or as the home of the
// tasks that have no list.
function syncList(href, asDefault) {
    var all = remoteLists()
    var me = null
    for (var i = 0; i < all.length; i++)
        if (all[i].href === href) me = all[i]
    if (me === null) return
    db().transaction(function (tx) {
        if (asDefault) {
            for (var j = 0; j < all.length; j++) {
                if (all[j].isDefault && all[j].href !== href) {
                    detachTasks(tx, "remoteList = ?", [all[j].href])
                    tx.executeSql("UPDATE remote_lists SET enabled = 0, isDefault = 0 WHERE href = ?", [all[j].href])
                }
            }
            if (me.enabled && !me.isDefault)
                detachTasks(tx, "remoteList = ?", [href])
            tx.executeSql("UPDATE remote_lists SET enabled = 1, isDefault = 1, listName = '' WHERE href = ?", [href])
            return
        }
        var name = me.name
        var taken = function (n) {
            for (var k = 0; k < all.length; k++)
                if (all[k].href !== href && all[k].enabled && !all[k].isDefault && all[k].listName === n) return true
            return false
        }
        var n = 2
        while (taken(name)) name = me.name + " " + (n++)
        if (me.isDefault)
            detachTasks(tx, "remoteList = ?", [href])
        tx.executeSql("UPDATE remote_lists SET enabled = 1, isDefault = 0, listName = ? WHERE href = ?", [name, href])
    })
}

// Where the tasks without a list live on the server. A list that was synced
// as a list of its own becomes the home: its tasks here lose the list name and
// keep their place on the server, so nothing is sent twice. The old home
// becomes a list like any other; the tasks without a list still point at it,
// so the next run moves them across instead of copying them.
function setHome(href) {
    var all = remoteLists()
    var home = null
    for (var i = 0; i < all.length; i++) if (all[i].href === href) home = all[i]
    if (home === null) return
    db().transaction(function (tx) {
        if (home.enabled && !home.isDefault && home.listName !== "")
            tx.executeSql("UPDATE tasks SET listName = '' WHERE listName = ?", [home.listName])
        for (var o = 0; o < all.length; o++)
            if (all[o].isDefault && all[o].href !== href)
                tx.executeSql("UPDATE remote_lists SET isDefault = 0, enabled = 1, listName = ? WHERE href = ?", [all[o].name, all[o].href])
        tx.executeSql("UPDATE remote_lists SET enabled = 1, isDefault = 1, listName = '' WHERE href = ?", [href])
    })
}

// With sync on, everything on the phone is synced: the tasks without a list
// with one list on the server, and every list here with the server's list of
// the same name. Lists only the server has come here too. Returns the names
// of lists the server still needs; the caller makes them and calls again.
function syncEverything() {
    var all = remoteLists()
    var here = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT DISTINCT listName FROM tasks WHERE IFNULL(listName,'') != ''", [])
        for (var i = 0; i < rs.rows.length; i++) here.push(rs.rows.item(i).listName)
    })
    var lower = function (v) { return String(v).toLowerCase() }
    var isHere = function (name) {
        for (var i = 0; i < here.length; i++) if (lower(here[i]) === lower(name)) return true
        return false
    }

    // The home for tasks without a list: the one already chosen, else the
    // server's own "Tasks" or "Personal", else any list that is not one of
    // the phone's. Never a list the phone has by name, or that list would
    // swallow the tasks that have none.
    var home = null
    for (var d = 0; d < all.length; d++) if (all[d].enabled && all[d].isDefault) home = all[d]
    var prefer = ["tasks", "personal"]
    for (var p = 0; home === null && p < prefer.length; p++)
        for (var q = 0; q < all.length; q++)
            if (lower(all[q].name) === prefer[p] && !isHere(all[q].name)) { home = all[q]; break }
    for (var r = 0; home === null && r < all.length; r++)
        if (!isHere(all[r].name)) home = all[r]

    var missing = []
    if (home === null) missing.push("Tasks")
    else if (!home.isDefault || !home.enabled) setHome(home.href)

    all = remoteLists()
    for (var k = 0; k < all.length; k++)
        if (!all[k].enabled && (home === null || all[k].href !== home.href)) syncList(all[k].href, false)

    all = remoteLists()
    for (var m = 0; m < here.length; m++) {
        var found = false
        for (var n = 0; n < all.length; n++)
            if (all[n].enabled && !all[n].isDefault && lower(all[n].listName) === lower(here[m])) found = true
        if (!found) missing.push(here[m])
    }
    return missing
}

function unsyncList(href) {
    db().transaction(function (tx) {
        detachTasks(tx, "remoteList = ?", [href])
        tx.executeSql("UPDATE remote_lists SET enabled = 0, isDefault = 0 WHERE href = ?", [href])
    })
}

// Signing out lets go of everything; the tasks stay on the phone.
function forgetServer() {
    db().transaction(function (tx) {
        detachTasks(tx, "IFNULL(remoteList,'') != ''", [])
        tx.executeSql("DELETE FROM remote_lists", [])
        tx.executeSql("DELETE FROM tombstones", [])
    })
}

function syncTasks() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT id, title, IFNULL(note,'') AS note, IFNULL(listName,'') AS listName, parentId, done, doneAt, IFNULL(dueDate,'') AS dueDate, IFNULL(dueTime,'') AS dueTime, repeatEvery, IFNULL(repeatUnit,'') AS repeatUnit, sortIndex, exportToCalendar, IFNULL(calendarEventId,'') AS calendarEventId, IFNULL(remoteUid,'') AS remoteUid, IFNULL(remoteHref,'') AS remoteHref, IFNULL(remoteEtag,'') AS remoteEtag, IFNULL(remoteList,'') AS remoteList, IFNULL(remoteIcs,'') AS remoteIcs, IFNULL(dirty,1) AS dirty, IFNULL(modifiedAt,0) AS modifiedAt FROM tasks ORDER BY parentId ASC, id ASC", [])
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i)
            out.push({ id: r.id, title: r.title, note: r.note, listName: r.listName, parentId: r.parentId,
                       done: r.done, doneAt: r.doneAt, dueDate: r.dueDate, dueTime: r.dueTime,
                       repeatEvery: r.repeatEvery, repeatUnit: r.repeatUnit, sortIndex: r.sortIndex,
                       exportToCalendar: r.exportToCalendar, calendarEventId: r.calendarEventId,
                       remoteUid: r.remoteUid, remoteHref: r.remoteHref, remoteEtag: r.remoteEtag,
                       remoteList: r.remoteList, remoteIcs: r.remoteIcs, dirty: r.dirty, modifiedAt: r.modifiedAt })
        }
    })
    return out
}

var REMOTE_WRITABLE = ["title", "note", "listName", "parentId", "done", "doneAt", "dueDate", "dueTime",
                       "repeatEvery", "repeatUnit", "sortIndex", "remoteUid", "remoteHref", "remoteEtag",
                       "remoteList", "remoteIcs", "dirty", "modifiedAt"]

// A write that came from the server: it does not mark the task as changed.
function applyRemote(id, fields) {
    var sets = [], args = []
    for (var k in fields) {
        if (REMOTE_WRITABLE.indexOf(k) < 0) continue
        var v = fields[k]
        if (v === null || v === undefined) v = (k === "parentId" || k === "done" || k === "doneAt" || k === "repeatEvery" || k === "sortIndex" || k === "dirty" || k === "modifiedAt") ? 0 : ""
        sets.push(k + " = ?")
        args.push(v)
    }
    if (sets.length === 0) return
    args.push(id)
    db().transaction(function (tx) {
        tx.executeSql("UPDATE tasks SET " + sets.join(", ") + " WHERE id = ?", args)
    })
}

function insertRemote(fields) {
    var id = -1
    var now = new Date().getTime()
    db().transaction(function (tx) {
        var rs = tx.executeSql("INSERT INTO tasks (title, note, listName, parentId, done, doneAt, dueDate, dueTime, repeatEvery, repeatUnit, sortIndex, createdAt, remoteUid, remoteHref, remoteEtag, remoteList, remoteIcs, dirty, modifiedAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)",
            [fields.title || "", fields.note || "", fields.listName || "", fields.parentId || 0,
             fields.done || 0, fields.doneAt || 0, fields.dueDate || "", fields.dueTime || "",
             fields.repeatEvery || 0, fields.repeatUnit || "", fields.sortIndex || 0, now,
             fields.remoteUid || "", fields.remoteHref || "", fields.remoteEtag || "",
             fields.remoteList || "", fields.remoteIcs || "", fields.modifiedAt || now])
        id = parseInt(rs.insertId, 10)
    })
    return id
}

// Sent: the server copy is recorded, and the task is clean again unless it
// was changed once more while the request was on its way.
function markSent(id, sentAt, fields) {
    applyRemote(id, fields)
    db().transaction(function (tx) {
        tx.executeSql("UPDATE tasks SET dirty = 0 WHERE id = ? AND IFNULL(modifiedAt,0) = ?", [id, sentAt])
    })
}

// Gone from the server and not changed here: gone here too. No tombstone,
// the server already has nothing to delete.
function deleteLocal(id) {
    db().transaction(function (tx) {
        tx.executeSql("DELETE FROM tasks WHERE id = ? OR parentId = ?", [id, id])
    })
}

function detachTask(id) {
    db().transaction(function (tx) {
        detachTasks(tx, "id = ?", [id])
    })
}

function tombstones() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT href, IFNULL(etag,'') AS etag FROM tombstones", [])
        for (var i = 0; i < rs.rows.length; i++) out.push({ href: rs.rows.item(i).href, etag: rs.rows.item(i).etag })
    })
    return out
}

function dropTombstone(href) {
    db().transaction(function (tx) {
        tx.executeSql("DELETE FROM tombstones WHERE href = ?", [href])
    })
}

// How much is waiting to be sent: deletions, and changed tasks that live (or
// will live) in a synced list.
function pendingCount() {
    var n = 0
    db().readTransaction(function (tx) {
        var a = tx.executeSql("SELECT COUNT(*) AS n FROM tombstones", [])
        n += a.rows.item(0).n
        var b = tx.executeSql("SELECT COUNT(*) AS n FROM tasks t LEFT JOIN tasks p ON t.parentId = p.id WHERE IFNULL(t.dirty,1) = 1 AND (IFNULL(t.remoteHref,'') != '' OR (t.parentId = 0 AND IFNULL(t.listName,'') IN (SELECT IFNULL(listName,'') FROM remote_lists WHERE enabled = 1)) OR (t.parentId != 0 AND IFNULL(p.listName,'') IN (SELECT IFNULL(listName,'') FROM remote_lists WHERE enabled = 1)))", [])
        n += b.rows.item(0).n
    })
    return n
}

// ---------------------------------------------------- lists on the phone --
//
// The phone's own household. Everything comes back in the shape Pantry sends,
// so the Lists pages cannot tell the two apart. Shelf.js does the routing.

function nowSeconds() { return Math.floor(new Date().getTime() / 1000) }

function shelfList(r) {
    return { id: r.id, houseId: -1, name: text(r.name), description: text(r.description),
             color: text(r.color), icon: "", sortOrder: r.sortOrder, canEdit: true,
             createdAt: r.createdAt, updatedAt: r.updatedAt }
}

function shelfItem(r) {
    return { id: r.id, listId: r.listId, name: text(r.name), description: text(r.description),
             quantity: text(r.quantity), categoryId: r.categoryId > 0 ? r.categoryId : null,
             done: r.done === 1, doneAt: r.doneAt > 0 ? r.doneAt : null, rrule: text(r.rrule),
             repeatFromCompletion: r.repeatFromCompletion === 1, deleteOnDone: r.deleteOnDone === 1,
             nextDueAt: r.nextDueAt > 0 ? r.nextDueAt : null, imageFileId: null, addedBy: "",
             sortOrder: r.sortOrder, createdAt: r.createdAt, updatedAt: r.updatedAt }
}

function shelfCategory(r) {
    return { id: r.id, houseId: -1, listId: r.listId > 0 ? r.listId : null, name: text(r.name),
             color: text(r.color), icon: text(r.icon), sortOrder: r.sortOrder, createdAt: r.createdAt }
}

var ITEM_COLUMNS = "id, listId, name, IFNULL(description,'') AS description, IFNULL(quantity,'') AS quantity, categoryId, done, doneAt, IFNULL(rrule,'') AS rrule, repeatFromCompletion, deleteOnDone, nextDueAt, sortOrder, createdAt, updatedAt"

function shelfRow(table, id, wrap) {
    var out = null
    db().readTransaction(function (tx) {
        var cols = table === "shelf_items" ? ITEM_COLUMNS : "*"
        var rs = tx.executeSql("SELECT " + cols + " FROM " + table + " WHERE id = ?", [id])
        if (rs.rows.length > 0) out = wrap(rs.rows.item(0))
    })
    return out
}

// ---- lists ----

function shelfLists() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT * FROM shelf_lists ORDER BY sortOrder ASC, id ASC", [])
        for (var i = 0; i < rs.rows.length; i++) out.push(shelfList(rs.rows.item(i)))
    })
    return out
}

function shelfAddList(f) {
    var now = nowSeconds(), id = 0
    db().transaction(function (tx) {
        var rs = tx.executeSql("SELECT IFNULL(MAX(sortOrder), -1) + 1 AS n FROM shelf_lists", [])
        var ins = tx.executeSql("INSERT INTO shelf_lists (name, description, color, sortOrder, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?)",
                                [f.name || "", f.description || "", f.color || "", rs.rows.item(0).n, now, now])
        id = parseInt(ins.insertId, 10)
    })
    return shelfRow("shelf_lists", id, shelfList)
}

function shelfUpdateList(id, f) {
    var sets = [], args = []
    var keys = ["name", "description", "color"]
    for (var i = 0; i < keys.length; i++)
        if (f[keys[i]] !== undefined) { sets.push(keys[i] + " = ?"); args.push(f[keys[i]] === null ? "" : String(f[keys[i]])) }
    if (sets.length > 0) {
        sets.push("updatedAt = ?"); args.push(nowSeconds()); args.push(id)
        db().transaction(function (tx) { tx.executeSql("UPDATE shelf_lists SET " + sets.join(", ") + " WHERE id = ?", args) })
    }
    return shelfRow("shelf_lists", id, shelfList)
}

function shelfDeleteList(id) {
    db().transaction(function (tx) {
        tx.executeSql("DELETE FROM shelf_items WHERE listId = ?", [id])
        tx.executeSql("DELETE FROM shelf_categories WHERE listId = ?", [id])
        tx.executeSql("DELETE FROM shelf_lists WHERE id = ?", [id])
    })
}

// ---- items ----

// A repeating item that was ticked off comes back on the day it is due again.
function shelfRevive() {
    var now = nowSeconds()
    db().transaction(function (tx) {
        tx.executeSql("UPDATE shelf_items SET done = 0, doneAt = 0, nextDueAt = 0, updatedAt = ? WHERE done = 1 AND nextDueAt > 0 AND nextDueAt <= ?", [now, now])
    })
}

// listId 0 is every list.
function shelfItems(listId) {
    shelfRevive()
    var out = []
    db().readTransaction(function (tx) {
        var rs = listId > 0
            ? tx.executeSql("SELECT " + ITEM_COLUMNS + " FROM shelf_items WHERE listId = ? ORDER BY sortOrder ASC, id ASC", [listId])
            : tx.executeSql("SELECT " + ITEM_COLUMNS + " FROM shelf_items ORDER BY listId ASC, sortOrder ASC, id ASC", [])
        for (var i = 0; i < rs.rows.length; i++) out.push(shelfItem(rs.rows.item(i)))
    })
    return out
}

var ITEM_TEXT = ["name", "description", "quantity", "rrule"]
var ITEM_FLAGS = ["repeatFromCompletion", "deleteOnDone"]

function shelfAddItem(listId, f) {
    var now = nowSeconds(), id = 0
    db().transaction(function (tx) {
        var rs = tx.executeSql("SELECT IFNULL(MAX(sortOrder), -1) + 1 AS n FROM shelf_items WHERE listId = ?", [listId])
        var ins = tx.executeSql("INSERT INTO shelf_items (listId, name, description, quantity, categoryId, rrule, repeatFromCompletion, deleteOnDone, sortOrder, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                                [listId, f.name || "", f.description || "", f.quantity || "", f.categoryId > 0 ? f.categoryId : 0,
                                 f.rrule || "", f.repeatFromCompletion ? 1 : 0, f.deleteOnDone ? 1 : 0, rs.rows.item(0).n, now, now])
        id = parseInt(ins.insertId, 10)
    })
    return shelfRow("shelf_items", id, shelfItem)
}

// "" clears a text, categoryId 0 clears the category: the same rules as Pantry.
function shelfUpdateItem(id, f) {
    var sets = [], args = []
    for (var i = 0; i < ITEM_TEXT.length; i++)
        if (f[ITEM_TEXT[i]] !== undefined) { sets.push(ITEM_TEXT[i] + " = ?"); args.push(f[ITEM_TEXT[i]] === null ? "" : String(f[ITEM_TEXT[i]])) }
    for (var j = 0; j < ITEM_FLAGS.length; j++)
        if (f[ITEM_FLAGS[j]] !== undefined) { sets.push(ITEM_FLAGS[j] + " = ?"); args.push(f[ITEM_FLAGS[j]] ? 1 : 0) }
    if (f.categoryId !== undefined) { sets.push("categoryId = ?"); args.push(f.categoryId > 0 ? f.categoryId : 0) }
    // A changed rule starts counting again from now.
    if (f.rrule !== undefined) sets.push("nextDueAt = CASE WHEN done = 1 THEN nextDueAt ELSE 0 END")
    if (sets.length > 0) {
        sets.push("updatedAt = ?"); args.push(nowSeconds()); args.push(id)
        db().transaction(function (tx) { tx.executeSql("UPDATE shelf_items SET " + sets.join(", ") + " WHERE id = ?", args) })
    }
    return shelfRow("shelf_items", id, shelfItem)
}

function shelfDeleteItems(ids) {
    db().transaction(function (tx) {
        for (var i = 0; i < ids.length; i++) tx.executeSql("DELETE FROM shelf_items WHERE id = ?", [ids[i]])
    })
}

// The next time a repeating item is wanted: the rule's step from now, at the
// start of that day.
function shelfNextDue(rrule, fromSeconds) {
    var freq = "", interval = 1
    var parts = text(rrule).replace(/^RRULE:/, "").split(";")
    for (var i = 0; i < parts.length; i++) {
        var kv = parts[i].split("=")
        var k = (kv[0] || "").toUpperCase(), v = (kv[1] || "").toUpperCase()
        if (k === "FREQ") freq = v
        else if (k === "INTERVAL") interval = Math.max(1, parseInt(v, 10) || 1)
    }
    if (freq === "") return 0
    var d = new Date(fromSeconds * 1000)
    d.setHours(0, 0, 0, 0)
    var iso = Dates.iso(d)
    if (freq === "DAILY") iso = Dates.advance(iso, interval, "day")
    else if (freq === "WEEKLY") iso = Dates.advance(iso, interval, "week")
    else if (freq === "MONTHLY") iso = Dates.advance(iso, interval, "month")
    else if (freq === "YEARLY") iso = Dates.advance(iso, interval * 12, "month")
    else return 0
    return Math.floor(Dates.fromISO(iso).getTime() / 1000)
}

// Answers like Pantry's toggle: the item as it is now, or, for one that goes
// away when done, its id with deletedAt.
function shelfToggle(id) {
    var it = shelfRow("shelf_items", id, shelfItem)
    if (it === null) return null
    var now = nowSeconds()
    if (!it.done && it.deleteOnDone && it.rrule === "") {
        shelfDeleteItems([id])
        return { id: id, deletedAt: now }
    }
    db().transaction(function (tx) {
        if (it.done)
            tx.executeSql("UPDATE shelf_items SET done = 0, doneAt = 0, nextDueAt = 0, updatedAt = ? WHERE id = ?", [now, id])
        else
            tx.executeSql("UPDATE shelf_items SET done = 1, doneAt = ?, nextDueAt = ?, updatedAt = ? WHERE id = ?", [now, shelfNextDue(it.rrule, now), now, id])
    })
    return shelfRow("shelf_items", id, shelfItem)
}

function shelfUncheck(ids) {
    var now = nowSeconds()
    db().transaction(function (tx) {
        for (var i = 0; i < ids.length; i++)
            tx.executeSql("UPDATE shelf_items SET done = 0, doneAt = 0, nextDueAt = 0, updatedAt = ? WHERE id = ?", [now, ids[i]])
    })
}

// ---- categories ----

function shelfCategories() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT * FROM shelf_categories ORDER BY sortOrder ASC, id ASC", [])
        for (var i = 0; i < rs.rows.length; i++) out.push(shelfCategory(rs.rows.item(i)))
    })
    return out
}

function shelfAddCategory(f) {
    var now = nowSeconds(), id = 0
    db().transaction(function (tx) {
        var rs = tx.executeSql("SELECT IFNULL(MAX(sortOrder), -1) + 1 AS n FROM shelf_categories", [])
        var ins = tx.executeSql("INSERT INTO shelf_categories (listId, name, color, icon, sortOrder, createdAt) VALUES (?, ?, ?, ?, ?, ?)",
                                [f.listId > 0 ? f.listId : 0, f.name || "", f.color || "", f.icon || "", rs.rows.item(0).n, now])
        id = parseInt(ins.insertId, 10)
    })
    return shelfRow("shelf_categories", id, shelfCategory)
}

function shelfUpdateCategory(id, f) {
    var sets = [], args = []
    var keys = ["name", "color", "icon"]
    for (var i = 0; i < keys.length; i++)
        if (f[keys[i]] !== undefined) { sets.push(keys[i] + " = ?"); args.push(f[keys[i]] === null ? "" : String(f[keys[i]])) }
    if (sets.length > 0) {
        args.push(id)
        db().transaction(function (tx) { tx.executeSql("UPDATE shelf_categories SET " + sets.join(", ") + " WHERE id = ?", args) })
    }
    return shelfRow("shelf_categories", id, shelfCategory)
}

function shelfDeleteCategory(id) {
    db().transaction(function (tx) {
        tx.executeSql("UPDATE shelf_items SET categoryId = 0 WHERE categoryId = ?", [id])
        tx.executeSql("DELETE FROM shelf_categories WHERE id = ?", [id])
    })
}
