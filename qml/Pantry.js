// Small helpers for the household lists (Pantry). Not a .pragma library, so
// qsTr works and translates in the page that imports it.

// A household's role decides what you may do. A key the server does not send
// (an older Pantry) counts as allowed; the server still has the last word.
function can(house, key) {
    if (!house || !house.permissions)
        return true
    return house.permissions[key] !== false
}

function str(v) {
    return (v === undefined || v === null) ? "" : String(v)
}

function num(v) {
    var n = Number(v)
    return isNaN(n) ? 0 : n
}

// ---- repeats ----
// The editor writes FREQ and INTERVAL only. A rule written elsewhere with more
// in it (BYDAY, COUNT…) is shown and kept as it is unless it is changed here.

function parseRule(rrule) {
    var out = { freq: "", interval: 1, plain: true }
    var s = str(rrule).trim()
    if (s === "")
        return out
    if (s.indexOf("RRULE:") === 0)
        s = s.substring(6)
    var parts = s.split(";")
    for (var i = 0; i < parts.length; ++i) {
        var kv = parts[i].split("=")
        var k = kv[0].toUpperCase()
        var v = (kv[1] || "").toUpperCase()
        if (k === "FREQ") out.freq = v
        else if (k === "INTERVAL") out.interval = Math.max(1, parseInt(v, 10) || 1)
        else if (k !== "") out.plain = false
    }
    return out
}

function buildRule(freq, interval) {
    if (freq === "")
        return ""
    var n = Math.max(1, interval || 1)
    return "FREQ=" + freq + ";INTERVAL=" + n
}

function describeRule(rrule) {
    var r = parseRule(rrule)
    if (r.freq === "")
        return ""
    var n = r.interval
    var text
    switch (r.freq) {
    case "DAILY":
        text = n === 1 ? qsTr("every day") : qsTr("every %1 days").arg(n); break
    case "WEEKLY":
        text = n === 1 ? qsTr("every week") : qsTr("every %1 weeks").arg(n); break
    case "MONTHLY":
        text = n === 1 ? qsTr("every month") : qsTr("every %1 months").arg(n); break
    case "YEARLY":
        text = n === 1 ? qsTr("every year") : qsTr("every %1 years").arg(n); break
    default:
        text = qsTr("repeats")
    }
    return r.plain ? text : qsTr("repeats")
}

// ---- dates ----

function shortDate(seconds) {
    if (!seconds)
        return ""
    var d = new Date(seconds * 1000)
    var now = new Date()
    if (d.getFullYear() !== now.getFullYear())
        return Qt.formatDate(d, "d MMM yyyy")
    return Qt.formatDate(d, "d MMM")
}

// ---- lists of things from the server ----

function byId(array, id) {
    if (!array)
        return null
    for (var i = 0; i < array.length; ++i)
        if (array[i].id === id)
            return array[i]
    return null
}

function replaceById(array, item) {
    var out = []
    var found = false
    for (var i = 0; i < (array ? array.length : 0); ++i) {
        if (array[i].id === item.id) {
            out.push(item)
            found = true
        } else {
            out.push(array[i])
        }
    }
    if (!found)
        out.push(item)
    return out
}

function removeById(array, id) {
    var out = []
    for (var i = 0; i < (array ? array.length : 0); ++i)
        if (array[i].id !== id)
            out.push(array[i])
    return out
}

function asArray(v) {
    if (!v)
        return []
    if (v.length !== undefined)
        return v
    return []
}

// The colours Pantry offers. Its own web app shows the same.
var listColours = ["#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3", "#03a9f4", "#00bcd4",
                   "#009688", "#4caf50", "#8bc34a", "#cddc39", "#ffeb3b", "#ffc107", "#ff9800", "#ff5722"]
var categoryColours = ["#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6", "#0ea5e9", "#6366f1",
                       "#a855f7", "#ec4899", "#78716c"]
