/*
 * Dates.js -- every date decision Fiat Agenda makes.
 *
 * Dates are stored as plain 'YYYY-MM-DD' strings and times as 'HH:MM'.
 * An empty string means "no date" / "no time", which is a valid and common
 * state, not a missing value. Strings in this format sort and compare
 * correctly as text, which is why SQL can order and filter on them directly
 * with no date functions at all.
 *
 * .pragma library: no QML context here, so no Qt.formatDate. Everything is
 * plain JavaScript on purpose.
 */

.pragma library

var DAY_NAMES   = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function pad(n) { return (n < 10 ? "0" : "") + n }

// Date object -> 'YYYY-MM-DD', in local time.
function iso(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

// 'YYYY-MM-DD' -> Date at local midnight. Built field by field rather than
// parsed, because new Date("2026-08-24") is UTC and lands on the day before
// for anyone east of Greenwich.
function fromISO(s) {
    if (!s) return null
    var p = s.split("-")
    if (p.length !== 3) return null
    return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10))
}

function today() {
    var n = new Date()
    return new Date(n.getFullYear(), n.getMonth(), n.getDate())
}

function todayISO() { return iso(today()) }

function addDays(isoStr, n) {
    var d = fromISO(isoStr)
    if (d === null) return ""
    d.setDate(d.getDate() + n)
    return iso(d)
}

function tomorrowISO() { return addDays(todayISO(), 1) }

// Whole days between two ISO dates, b - a. Normalised to midday first so a
// daylight-saving change cannot turn 1 day into 0.96 of one.
function daysBetween(a, b) {
    var da = fromISO(a), db = fromISO(b)
    if (da === null || db === null) return 0
    da.setHours(12); db.setHours(12)
    return Math.round((db.getTime() - da.getTime()) / 86400000)
}

function isOverdue(dueISO) { return dueISO !== "" && dueISO < todayISO() }
function isToday(dueISO)   { return dueISO !== "" && dueISO === todayISO() }

// One step of a recurrence. Months clamp: the 31st in a 30-day month becomes
// the 30th rather than leaking into the next month, which is what setMonth
// does on its own.
function advance(isoStr, every, unit) {
    var d = fromISO(isoStr)
    if (d === null || every <= 0) return isoStr
    if (unit === "week") {
        d.setDate(d.getDate() + every * 7)
    } else if (unit === "month") {
        var day = d.getDate()
        d.setDate(1)
        d.setMonth(d.getMonth() + every)
        var last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        d.setDate(Math.min(day, last))
    } else {
        d.setDate(d.getDate() + every)
    }
    return iso(d)
}

// Next occurrence strictly after today. A daily task left alone for a week
// should come back tomorrow, not seven times in a row.
function nextOccurrence(isoStr, every, unit) {
    var next = advance(isoStr, every, unit)
    var guard = 0
    while (next <= todayISO() && guard < 500) {
        next = advance(next, every, unit)
        guard++
    }
    return next
}

// How a date reads on a row. Near dates get a word, this week gets a weekday,
// the rest gets a number, and another year gets the year.
function formatDue(dueISO, timeStr) {
    if (!dueISO) return ""
    var d = fromISO(dueISO)
    if (d === null) return ""
    var delta = daysBetween(todayISO(), dueISO)
    var label
    if (delta === 0)          label = "Today"
    else if (delta === 1)     label = "Tomorrow"
    else if (delta === -1)    label = "Yesterday"
    else if (delta > 1 && delta < 7)  label = DAY_NAMES[d.getDay()]
    else if (delta < -1 && delta > -7) label = "Last " + DAY_NAMES[d.getDay()]
    else if (d.getFullYear() === today().getFullYear())
        label = d.getDate() + " " + MONTH_NAMES[d.getMonth()]
    else
        label = d.getDate() + " " + MONTH_NAMES[d.getMonth()] + " " + d.getFullYear()

    return timeStr ? label + " " + timeStr : label
}

// The long form, for the task page.
function formatFull(dueISO) {
    if (!dueISO) return "No date"
    var d = fromISO(dueISO)
    if (d === null) return "No date"
    return DAY_NAMES[d.getDay()] + " " + d.getDate() + " " +
           MONTH_NAMES[d.getMonth()] + " " + d.getFullYear()
}

function formatTime(h, m) { return pad(h) + ":" + pad(m) }

function formatRepeat(every, unit) {
    if (!every || every <= 0) return "Never"
    if (every === 1 && unit === "day")   return "Daily"
    if (every === 1 && unit === "week")  return "Weekly"
    if (every === 1 && unit === "month") return "Monthly"
    return "Every " + every + " " + unit + "s"
}
