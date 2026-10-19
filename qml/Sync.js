/*
 * Sync.js -- tasks, both ways, with a CalDAV server (Nextcloud Tasks).
 *
 * The phone keeps every task; a list switched on in the Nextcloud page also
 * lives on the server, one VTODO per task. A sync run:
 *
 *   1. moves out of the server what was moved here into a list that is not
 *      synced, and deletes there what was deleted here (the tombstones)
 *   2. reads each synced list whole and compares, task by task:
 *        same on both sides and changed here    -> send it
 *        changed there, not here                -> take it
 *        changed on both                        -> the newer change wins
 *        on the server only                     -> take it, or match it to a
 *                                                  task here with the same
 *                                                  title rather than doubling it
 *        here only                              -> send it
 *        gone from the server, not changed here -> gone here too
 *
 * Every write to the server carries the copy it was based on (If-Match), so
 * nothing written elsewhere in the meantime is overwritten blind. Properties
 * this app does not know are kept: a task is rewritten from the server's own
 * copy, and only the fields that differ are touched.
 *
 * Reminders are not synced. They ride on this phone's calendar and fire here.
 */

.pragma library
.import "Storage.js" as Storage
.import "Dates.js" as Dates

var running = false

// ------------------------------------------------------------------ ics --

function unfold(text) {
    return String(text).replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n[ \t]/g, "").split("\n")
}

function splitProp(line) {
    // name;params:value -- the first colon outside double quotes
    var inQuote = false
    for (var i = 0; i < line.length; i++) {
        var ch = line.charAt(i)
        if (ch === '"') inQuote = !inQuote
        else if (ch === ":" && !inQuote) {
            var head = line.substring(0, i)
            var semi = head.indexOf(";")
            return {
                name: (semi < 0 ? head : head.substring(0, semi)).toUpperCase(),
                params: semi < 0 ? "" : head.substring(semi + 1),
                value: line.substring(i + 1)
            }
        }
    }
    return null
}

function parse(text) {
    var root = { name: "", props: [], children: [] }
    var stack = [root]
    var lines = unfold(text)
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (line === "") continue
        var p = splitProp(line)
        if (p === null) continue
        var top = stack[stack.length - 1]
        if (p.name === "BEGIN") {
            var c = { name: p.value.toUpperCase(), props: [], children: [] }
            top.children.push(c)
            stack.push(c)
        } else if (p.name === "END") {
            if (stack.length > 1) stack.pop()
        } else {
            top.props.push(p)
        }
    }
    return root
}

function fold(line) {
    var out = []
    while (line.length > 74) {
        out.push(line.substring(0, 74))
        line = " " + line.substring(74)
    }
    out.push(line)
    return out.join("\r\n")
}

function serialize(comp) {
    var out = []
    var walk = function (c) {
        out.push("BEGIN:" + c.name)
        for (var i = 0; i < c.props.length; i++) {
            var p = c.props[i]
            out.push(fold(p.name + (p.params !== "" ? ";" + p.params : "") + ":" + p.value))
        }
        for (var j = 0; j < c.children.length; j++) walk(c.children[j])
        out.push("END:" + c.name)
    }
    for (var k = 0; k < comp.children.length; k++) walk(comp.children[k])
    return out.join("\r\n") + "\r\n"
}

function findComp(c, name) {
    if (c.name === name) return c
    for (var i = 0; i < c.children.length; i++) {
        var f = findComp(c.children[i], name)
        if (f !== null) return f
    }
    return null
}

function getProp(c, name) {
    for (var i = 0; i < c.props.length; i++)
        if (c.props[i].name === name) return c.props[i]
    return null
}

function removeProp(c, name, keep) {
    var out = []
    for (var i = 0; i < c.props.length; i++)
        if (c.props[i].name !== name || (keep && keep(c.props[i]))) out.push(c.props[i])
    c.props = out
}

function setProp(c, name, value, params) {
    var p = getProp(c, name)
    if (p === null) {
        c.props.push({ name: name, params: params || "", value: value })
    } else {
        p.value = value
        p.params = params || ""
    }
}

function param(p, key) {
    if (p === null || p.params === "") return ""
    var parts = p.params.split(";")
    for (var i = 0; i < parts.length; i++) {
        var kv = parts[i].split("=")
        if (kv[0].toUpperCase() === key) return (kv[1] || "").replace(/"/g, "").toUpperCase()
    }
    return ""
}

function escapeText(s) {
    return String(s).replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n")
}

function unescapeText(s) {
    return String(s).replace(/\\([\\;,nN])/g, function (m, c) { return (c === "n" || c === "N") ? "\n" : c })
}

// ---------------------------------------------------------------- dates --

function pad(n) { return (n < 10 ? "0" : "") + n }

function utcStamp(ms) {
    var d = new Date(ms)
    return d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) + "T"
         + pad(d.getUTCHours()) + pad(d.getUTCMinutes()) + pad(d.getUTCSeconds()) + "Z"
}

// An iCalendar date or date-time, as milliseconds. Floating and TZID times
// are taken as this phone's own wall clock.
function icalMs(v) {
    var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?$/.exec(String(v).trim())
    if (!m) return 0
    var y = +m[1], mo = +m[2] - 1, d = +m[3]
    if (m[4] === undefined) return new Date(y, mo, d).getTime()
    if (m[7] === "Z") return Date.UTC(y, mo, d, +m[4], +m[5], +m[6])
    return new Date(y, mo, d, +m[4], +m[5], +m[6]).getTime()
}

function readDue(p) {
    if (p === null) return { date: "", time: "" }
    var v = String(p.value).trim()
    var dateOnly = param(p, "VALUE") === "DATE" || /^\d{8}$/.test(v)
    var ms = icalMs(v)
    if (!ms) return { date: "", time: "" }
    var d = new Date(ms)
    if (dateOnly) return { date: Dates.iso(d), time: "" }
    return { date: Dates.iso(d), time: pad(d.getHours()) + ":" + pad(d.getMinutes()) }
}

function compactDate(iso) { return iso.replace(/-/g, "") }

// --------------------------------------------------------------- tasks --

// The fields this app keeps, read out of one VTODO.
function readTodo(ics) {
    var root = parse(ics)
    var t = findComp(root, "VTODO")
    if (t === null) return null
    var get = function (n) { var p = getProp(t, n); return p === null ? "" : p.value }

    var out = {
        uid: get("UID"),
        title: unescapeText(get("SUMMARY")),
        note: unescapeText(get("DESCRIPTION")),
        due: readDue(getProp(t, "DUE")),
        done: get("STATUS").toUpperCase() === "COMPLETED" || get("COMPLETED") !== "",
        doneAt: icalMs(get("COMPLETED")),
        repeatEvery: 0,
        repeatUnit: "",
        parentUid: "",
        sortIndex: get("X-APPLE-SORT-ORDER") !== "" ? parseInt(get("X-APPLE-SORT-ORDER"), 10) || 0 : null,
        modifiedAt: icalMs(get("LAST-MODIFIED")) || icalMs(get("DTSTAMP"))
    }

    var rrule = get("RRULE").toUpperCase()
    if (rrule !== "") {
        var freq = (/FREQ=([A-Z]+)/.exec(rrule) || [])[1] || ""
        var n = parseInt((/INTERVAL=(\d+)/.exec(rrule) || [])[1] || "1", 10)
        if (freq === "DAILY") { out.repeatEvery = n; out.repeatUnit = "day" }
        else if (freq === "WEEKLY") { out.repeatEvery = n; out.repeatUnit = "week" }
        else if (freq === "MONTHLY") { out.repeatEvery = n; out.repeatUnit = "month" }
        else if (freq === "YEARLY") { out.repeatEvery = n * 12; out.repeatUnit = "month" }
    }

    for (var i = 0; i < t.props.length; i++) {
        var p = t.props[i]
        if (p.name !== "RELATED-TO") continue
        var rel = param(p, "RELTYPE")
        if (rel === "" || rel === "PARENT") out.parentUid = p.value.trim()
    }
    return out
}

function sameRepeat(a, b) {
    var na = a.repeatEvery > 0 ? a.repeatEvery : 0
    var nb = b.repeatEvery > 0 ? b.repeatEvery : 0
    if (na === 0 && nb === 0) return true
    return na === nb && a.repeatUnit === b.repeatUnit
}

function freshIcs(uid) {
    var now = utcStamp(new Date().getTime())
    return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Munkstolen//fiat agenda//EN\r\n"
         + "BEGIN:VTODO\r\nUID:" + uid + "\r\nCREATED:" + now + "\r\nDTSTAMP:" + now + "\r\n"
         + "END:VTODO\r\nEND:VCALENDAR\r\n"
}

// The server's copy with this task's fields written into it. Only what
// differs from that copy is touched, so a date written with a time zone, a
// priority or a category set elsewhere all stay as they were.
function writeTodo(task, baseIcs, uid, parentUid) {
    var base = baseIcs !== "" ? baseIcs : freshIcs(uid)
    var root = parse(base)
    var t = findComp(root, "VTODO")
    if (t === null) {
        root = parse(freshIcs(uid))
        t = findComp(root, "VTODO")
    }
    var old = readTodo(serialize(root)) || {}
    var now = utcStamp(new Date().getTime())

    if (getProp(t, "UID") === null) setProp(t, "UID", uid)
    setProp(t, "DTSTAMP", now)
    setProp(t, "LAST-MODIFIED", now)

    if (old.title !== task.title) setProp(t, "SUMMARY", escapeText(task.title))

    if (old.note !== task.note) {
        if (task.note !== "") setProp(t, "DESCRIPTION", escapeText(task.note))
        else removeProp(t, "DESCRIPTION")
    }

    if (!old.due || old.due.date !== task.dueDate || old.due.time !== task.dueTime) {
        removeProp(t, "DUE")
        if (task.dueDate !== "") {
            if (task.dueTime !== "")
                setProp(t, "DUE", compactDate(task.dueDate) + "T" + task.dueTime.replace(":", "") + "00")
            else
                setProp(t, "DUE", compactDate(task.dueDate), "VALUE=DATE")
            var start = getProp(t, "DTSTART")
            if (start !== null && icalMs(start.value) > icalMs(getProp(t, "DUE").value))
                removeProp(t, "DTSTART")
        }
    }

    var done = task.done === 1
    if (old.done !== done) {
        if (done) {
            setProp(t, "STATUS", "COMPLETED")
            setProp(t, "COMPLETED", utcStamp(task.doneAt > 0 ? task.doneAt : new Date().getTime()))
            setProp(t, "PERCENT-COMPLETE", "100")
        } else {
            setProp(t, "STATUS", "NEEDS-ACTION")
            removeProp(t, "COMPLETED")
            removeProp(t, "PERCENT-COMPLETE")
        }
    }

    if (!sameRepeat(old, task)) {
        removeProp(t, "RRULE")
        if (task.repeatEvery > 0) {
            var freq = task.repeatUnit === "week" ? "WEEKLY" : task.repeatUnit === "month" ? "MONTHLY" : "DAILY"
            setProp(t, "RRULE", "FREQ=" + freq + ";INTERVAL=" + task.repeatEvery)
        }
    }

    if ((old.parentUid || "") !== parentUid) {
        removeProp(t, "RELATED-TO", function (p) { var r = param(p, "RELTYPE"); return r !== "" && r !== "PARENT" })
        if (parentUid !== "") t.props.push({ name: "RELATED-TO", params: "RELTYPE=PARENT", value: parentUid })
    }

    if (old.sortIndex !== task.sortIndex) setProp(t, "X-APPLE-SORT-ORDER", String(task.sortIndex))

    return serialize(root)
}

// ---------------------------------------------------------------- runs --

function series(steps, done) {
    var i = 0
    var next = function () {
        if (i >= steps.length) { done(); return }
        var step = steps[i++]
        try {
            step(next)
        } catch (e) {
            console.log("harbour-fiatagenda: sync step failed -- " + e)
            next()
        }
    }
    next()
}

function normalise(s) { return String(s).replace(/^\s+|\s+$/g, "").toLowerCase() }

// Where a task belongs on the server, from the lists switched on: its own
// list's, its parent's for a subtask, or nowhere.
function targetOf(task, byId, byName, defaultHref) {
    if (task.parentId > 0) {
        var p = byId[task.parentId]
        return p ? targetOf(p, byId, byName, defaultHref) : ""
    }
    if (task.listName === "") return defaultHref
    return byName[task.listName] || ""
}

function mapping() {
    var lists = Storage.remoteLists()
    var out = { lists: [], byName: {}, defaultHref: "" }
    for (var i = 0; i < lists.length; i++) {
        var l = lists[i]
        if (!l.enabled) continue
        out.lists.push(l)
        if (l.isDefault) out.defaultHref = l.href
        else out.byName[l.listName] = l.href
    }
    return out
}

function indexTasks(all) {
    var byId = {}
    for (var i = 0; i < all.length; i++) byId[all[i].id] = all[i]
    return byId
}

/*
 * One run. done(ok, report) -- report.changed lists the tasks the server
 * changed here and report.removedEvents the calendar entries of tasks it
 * deleted, so the calendar can follow.
 */
// Before a run: what lists the server has, everything here paired with one
// of them, and the lists the server is missing made there.
function prepare(dav, report, then) {
    dav.discover(function (ok, found, message) {
        if (!ok) { report.errors.push(message); then(false); return }
        Storage.updateRemoteLists(found)
        var missing = Storage.syncEverything()
        if (missing.length === 0) { then(true); return }
        var steps = missing.map(function (name) {
            return function (next) {
                dav.makeList(name, "#B04642", function (ok2, href, msg) {
                    if (!ok2) report.errors.push(msg)
                    next()
                })
            }
        })
        series(steps, function () {
            dav.discover(function (ok3, again) {
                if (ok3) {
                    Storage.updateRemoteLists(again)
                    Storage.syncEverything()
                }
                then(report.errors.length === 0)
            })
        })
    })
}

function run(dav, done) {
    if (running) { done(false, { busy: true, errors: [], changed: [], removedEvents: [], pushed: 0, pulled: 0 }); return }
    running = true
    var report = { errors: [], changed: [], removedEvents: [], pushed: 0, pulled: 0, removed: 0 }
    var finish = function () {
        running = false
        done(report.errors.length === 0, report)
    }
    prepare(dav, report, function (ready) {
        if (!ready) { finish(); return }
        runLists(dav, report, finish)
    })
}

function runLists(dav, report, finish) {
    var map = mapping()
    var steps = []

    // 1a. moved here into a list that is not synced, or into another one
    var all = Storage.syncTasks()
    var byId = indexTasks(all)
    all.forEach(function (t) {
        if (t.remoteHref === "" || t.remoteList === "") return
        if (targetOf(t, byId, map.byName, map.defaultHref) === t.remoteList) return
        steps.push(function (next) {
            dav.remove(t.remoteHref, t.remoteEtag, function (ok, status, message) {
                if (ok || status === 412) {
                    Storage.detachTask(t.id)
                    report.removed++
                } else {
                    report.errors.push(message)
                }
                next()
            })
        })
    })

    // 1b. deleted here
    Storage.tombstones().forEach(function (tomb) {
        steps.push(function (next) {
            dav.remove(tomb.href, tomb.etag, function (ok, status, message) {
                // 412: changed there since. It stays on the server, and the
                // next read brings it back here, newer than the deletion.
                if (ok || status === 412) {
                    Storage.dropTombstone(tomb.href)
                    if (ok) report.removed++
                } else {
                    report.errors.push(message)
                }
                next()
            })
        })
    })

    // 2. each list
    map.lists.forEach(function (list) {
        steps.push(function (next) {
            dav.fetch(list.href, function (ok, items, status, message) {
                if (!ok) {
                    if (status === 404) {
                        Storage.unsyncList(list.href)
                        report.errors.push("“" + list.name + "” is no longer on the server.")
                    } else {
                        report.errors.push(message)
                    }
                    next()
                    return
                }
                reconcile(dav, list, items || [], report, next)
            })
        })
    })

    series(steps, finish)
}

function fieldsFrom(s, list, parentId) {
    var top = parentId === 0
    var f = {
        title: s.t.title !== "" ? s.t.title : "…",
        note: s.t.note,
        listName: top ? list.listName : "",
        parentId: parentId,
        done: s.t.done ? 1 : 0,
        doneAt: s.t.done ? (s.t.doneAt || new Date().getTime()) : 0,
        dueDate: s.t.due.date,
        dueTime: s.t.due.time,
        repeatEvery: s.t.repeatEvery,
        repeatUnit: s.t.repeatUnit,
        remoteUid: s.t.uid,
        remoteHref: s.href,
        remoteEtag: s.etag,
        remoteList: list.href,
        remoteIcs: s.ics,
        dirty: 0,
        modifiedAt: s.t.modifiedAt || new Date().getTime()
    }
    if (s.t.sortIndex !== null) f.sortIndex = s.t.sortIndex
    return f
}

function reconcile(dav, list, items, report, next) {
    var map = mapping()
    var server = []
    var byHref = {}
    for (var i = 0; i < items.length; i++) {
        var t = readTodo(items[i].ics)
        if (t === null) continue
        var s = { href: items[i].href, etag: items[i].etag, ics: items[i].ics, t: t, seen: false }
        server.push(s)
        byHref[s.href] = s
    }

    var all = Storage.syncTasks()
    var byId = indexTasks(all)
    var byUid = {}
    all.forEach(function (x) { if (x.remoteUid !== "") byUid[x.remoteUid] = x })
    var target = function (x) { return targetOf(x, byId, map.byName, map.defaultHref) }
    var parentIdFor = function (s) {
        var p = s.t.parentUid !== "" ? byUid[s.t.parentUid] : null
        return p ? p.id : 0
    }
    var take = function (localId, s) {
        Storage.applyRemote(localId, fieldsFrom(s, list, parentIdFor(s)))
        report.changed.push(localId)
        report.pulled++
    }

    var pushes = []
    var push = function (x, etag, baseIcs) {
        pushes.push(function (go) {
            var fresh = Storage.syncTasks()
            var now = indexTasks(fresh)
            var cur = now[x.id]
            if (!cur) { go(); return }
            var uid = cur.remoteUid !== "" ? cur.remoteUid : dav.newUid()
            var href = cur.remoteHref !== "" ? cur.remoteHref : list.href + uid + ".ics"
            var parent = cur.parentId > 0 ? now[cur.parentId] : null
            var parentUid = parent ? parent.remoteUid : ""
            if (cur.parentId > 0 && parentUid === "") { go(); return }
            if (cur.remoteUid === "")
                Storage.applyRemote(cur.id, { remoteUid: uid })
            var ics = writeTodo(cur, baseIcs !== undefined ? baseIcs : cur.remoteIcs, uid, parentUid)
            dav.put(href, ics, etag, function (ok, status, newEtag, message) {
                if (ok) {
                    Storage.markSent(cur.id, cur.modifiedAt, {
                        remoteHref: href, remoteEtag: newEtag, remoteList: list.href, remoteIcs: ics })
                    report.pushed++
                } else if (status === 412) {
                    // Changed there meanwhile: the next run compares again.
                    Storage.applyRemote(cur.id, { remoteEtag: "" })
                } else {
                    report.errors.push(message)
                }
                go()
            })
        })
    }

    // a. tasks this list already shares with the server
    all.forEach(function (x) {
        if (x.remoteList !== list.href || x.remoteHref === "") return
        var s = byHref[x.remoteHref]
        if (!s) {
            if (x.dirty === 1) {
                Storage.detachTask(x.id)
            } else {
                if (x.calendarEventId !== "") report.removedEvents.push(x.calendarEventId)
                Storage.deleteLocal(x.id)
                report.pulled++
            }
            return
        }
        s.seen = true
        if (s.etag === x.remoteEtag && s.etag !== "") {
            if (x.dirty === 1 && target(x) === list.href) push(x, s.etag, s.ics)
        } else if (x.dirty !== 1 || s.t.modifiedAt > x.modifiedAt) {
            take(x.id, s)
        } else {
            push(x, s.etag, s.ics)
        }
    })

    // b. on the server only
    all = Storage.syncTasks()
    byId = indexTasks(all)
    var unsynced = all.filter(function (x) { return x.remoteHref === "" && target(x) === list.href })
    var fresh = server.filter(function (s) {
        if (s.seen) return false
        for (var k = 0; k < all.length; k++) if (all[k].remoteHref === s.href) return false
        return true
    })
    fresh.sort(function (a, b) { return (a.t.parentUid === "" ? 0 : 1) - (b.t.parentUid === "" ? 0 : 1) })
    fresh.forEach(function (s) {
        // The same task on both sides before the list was synced: one task.
        // Same title and the same state, never an open one with a finished
        // one; of several, the one due the same day. Each is taken once.
        var match = null
        var due = s.t.due && s.t.due.date ? s.t.due.date : ""
        for (var k = 0; k < unsynced.length; k++) {
            var u = unsynced[k]
            if (normalise(u.title) !== normalise(s.t.title)) continue
            if ((u.parentId === 0) !== (s.t.parentUid === "")) continue
            if ((u.done === 1) !== (s.t.done === true)) continue
            if (u.dueDate === due) { match = u; break }
            if (match === null) match = u
        }
        if (match !== null) {
            unsynced.splice(unsynced.indexOf(match), 1)
            take(match.id, s)
            byUid[s.t.uid] = { id: match.id }
            return
        }
        var id = Storage.insertRemote(fieldsFrom(s, list, parentIdFor(s)))
        byUid[s.t.uid] = { id: id }
        report.changed.push(id)
        report.pulled++
    })

    // c. here only: parents first, so a subtask can name its parent
    unsynced.sort(function (a, b) { return (a.parentId === 0 ? 0 : 1) - (b.parentId === 0 ? 0 : 1) })
    unsynced.forEach(function (x) { push(x, "", "") })

    series(pushes, next)
}
