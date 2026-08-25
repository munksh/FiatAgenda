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

var SCHEMA = "2"       // bump, add a step to migrate(), never edit an old step

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

    return d
}

// Kept so the app can warm the database at startup instead of paying for the
// migration inside the first query. Calling it is optional.
function init() { db() }

// ---------------------------------------------------------------- reading --

var SELECT_ROW = "SELECT t.id, t.title, t.note, t.listName, t.parentId, t.done, t.doneAt, t.dueDate, t.dueTime, t.repeatEvery, t.repeatUnit, t.sortIndex, (SELECT COUNT(*) FROM tasks s WHERE s.parentId = t.id) AS subTotal, (SELECT COUNT(*) FROM tasks s WHERE s.parentId = t.id AND s.done = 1) AS subDone FROM tasks t "

// The model role is taskId, not id: `id` is loaded language in a QML
// delegate, and the one place a reader has to pause is the one place a bug
// hides.
function rowToObject(r) {
    return {
        taskId: r.id, title: r.title, note: r.note, listName: r.listName,
        parentId: r.parentId, done: r.done, doneAt: r.doneAt,
        dueDate: r.dueDate, dueTime: r.dueTime,
        repeatEvery: r.repeatEvery, repeatUnit: r.repeatUnit,
        sortIndex: r.sortIndex,
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

function getTask(id) {
    var out = null
    db().readTransaction(function (tx) {
        var rs = tx.executeSql(SELECT_ROW + "WHERE t.id = ?", [id])
        if (rs.rows.length > 0) out = rowToObject(rs.rows.item(0))
    })
    return out
}

// Every list name in use, alphabetically. There is no lists table: a list
// exists exactly as long as a task names it.
function lists() {
    var out = []
    db().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT DISTINCT listName FROM tasks WHERE IFNULL(listName,'') != '' AND done = 0 ORDER BY listName COLLATE NOCASE ASC", [])
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
        var rs = tx.executeSql("INSERT INTO tasks (title, note, listName, parentId, done, doneAt, dueDate, dueTime, repeatEvery, repeatUnit, sortIndex, createdAt) VALUES (?, '', ?, 0, 0, 0, ?, '', 0, '', ?, ?)", [title, listName || "", dueDate || "", idx, new Date().getTime()])
        id = parseInt(rs.insertId, 10)
    })
    return id
}

function addSubtask(parentId, title) {
    var id = -1
    db().transaction(function (tx) {
        var rs = tx.executeSql("SELECT COALESCE(MAX(sortIndex), -1) + 1 AS hi FROM tasks WHERE parentId = ?", [parentId])
        var idx = rs.rows.item(0).hi
        var ins = tx.executeSql("INSERT INTO tasks (title, note, listName, parentId, done, doneAt, dueDate, dueTime, repeatEvery, repeatUnit, sortIndex, createdAt) VALUES (?, '', '', ?, 0, 0, '', '', 0, '', ?, ?)", [title, parentId, idx, new Date().getTime()])
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
                "exportToCalendar", "calendarEventId", "remindAt", "alarmCookie"]

function updateTask(id, fields) {
    var sets = [], args = []
    for (var k in fields) {
        if (WRITABLE.indexOf(k) < 0) continue
        var v = fields[k]
        if (TEXT_COLUMNS.indexOf(k) >= 0 && (v === null || v === undefined)) v = ""
        sets.push(k + " = ?")
        args.push(v)
    }
    if (sets.length === 0) return
    args.push(id)
    db().transaction(function (tx) {
        tx.executeSql("UPDATE tasks SET " + sets.join(", ") + " WHERE id = ?", args)
    })
}

// Real delete. No soft-delete, no append-only history -- this is a task list,
// not Fiat Mos. The remorse timer on the swipe is the only safety net, and
// for a to-do it is enough. Subtasks go with the parent.
function deleteTask(id) {
    db().transaction(function (tx) {
        tx.executeSql("DELETE FROM tasks WHERE id = ? OR parentId = ?", [id, id])
    })
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
        db().transaction(function (tx) {
            tx.executeSql("UPDATE tasks SET dueDate = ?, done = 0, doneAt = ? WHERE id = ?", [next, new Date().getTime(), id])
            tx.executeSql("UPDATE tasks SET done = 0, doneAt = 0 WHERE parentId = ?", [id])
        })
        return next
    }

    db().transaction(function (tx) {
        tx.executeSql("UPDATE tasks SET done = ?, doneAt = ? WHERE id = ?", [done ? 1 : 0, done ? new Date().getTime() : 0, id])
    })
    return ""
}

function clearCompleted() {
    db().transaction(function (tx) {
        tx.executeSql("DELETE FROM tasks WHERE parentId IN (SELECT id FROM tasks WHERE done = 1 AND parentId = 0)", [])
        tx.executeSql("DELETE FROM tasks WHERE done = 1 AND parentId = 0", [])
    })
}

// ------------------------------------------------------------- reordering --

// Called once when the finger lifts, not on every swap: the model already
// shows the new order, the database just has to agree with it.
function saveOrder(model) {
    db().transaction(function (tx) {
        for (var i = 0; i < model.count; i++)
            tx.executeSql("UPDATE tasks SET sortIndex = ? WHERE id = ?", [i, model.get(i).taskId])
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
