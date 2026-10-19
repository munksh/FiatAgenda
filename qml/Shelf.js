// Where a call on the Lists side goes. The phone's own household is
// /houses/-1 and is answered here, from the phone; every other household is
// Pantry on the server, through `api`. Both answer in Pantry's shape and with
// api's callback, function (ok, data, status, message), so a page never needs
// to know which one it is talking to.
//
// The phone answers at once, before the call returns. Nothing on the Lists
// side depends on the answer coming later.

.import "Storage.js" as Storage

var LOCAL = -1
var PREFIX = "/houses/-1"

function isLocal(path) {
    return path === PREFIX || path.indexOf(PREFIX + "/") === 0
}

function localHouse(name, description) {
    return { id: LOCAL, name: name, description: description, local: true, role: "", isAdmin: true }
}

function parts(path) {
    return path.substring(PREFIX.length).split("/").filter(function (p) { return p !== "" })
}

function num(v) { return parseInt(v, 10) || 0 }

// What a GET on the phone's household answers, or undefined for a path it
// does not have.
function read(path) {
    var p = parts(path)
    if (p[0] === "lists" && p.length === 1) return Storage.shelfLists()
    if (p[0] === "lists" && p.length === 3 && p[2] === "items") return Storage.shelfItems(num(p[1]))
    if (p[0] === "items" && p.length === 1) return Storage.shelfItems(0)
    if (p[0] === "categories" && p.length === 1) return Storage.shelfCategories()
    if (p[0] === "members") return []
    return undefined
}

function write(method, path, body) {
    var p = parts(path)
    var b = body || {}
    if (p[0] === "lists") {
        if (p.length === 1 && method === "POST") return Storage.shelfAddList(b)
        var listId = num(p[1])
        if (p.length === 2 && method === "PATCH") return Storage.shelfUpdateList(listId, b)
        if (p.length === 2 && method === "DELETE") { Storage.shelfDeleteList(listId); return {} }
        if (p.length === 3 && p[2] === "items" && method === "POST") return Storage.shelfAddItem(listId, b)
        var itemId = num(p[3])
        if (p.length === 4 && method === "PATCH") return Storage.shelfUpdateItem(itemId, b)
        if (p.length === 4 && method === "DELETE") { Storage.shelfDeleteItems([itemId]); return {} }
        if (p.length === 5 && p[4] === "toggle") return Storage.shelfToggle(itemId)
    }
    if (p[0] === "items" && p[1] === "batch" && method === "POST") {
        var ids = b.itemIds || []
        if (p[2] === "uncheck") { Storage.shelfUncheck(ids); return {} }
        if (p[2] === "delete") { Storage.shelfDeleteItems(ids); return {} }
    }
    if (p[0] === "categories") {
        if (p.length === 1 && method === "POST") return Storage.shelfAddCategory(b)
        if (p.length === 2 && method === "PATCH") return Storage.shelfUpdateCategory(num(p[1]), b)
        if (p.length === 2 && method === "DELETE") { Storage.shelfDeleteCategory(num(p[1])); return {} }
    }
    return undefined
}

function answer(callback, data) {
    if (!callback) return
    if (data === undefined || data === null) callback(false, null, 404, "")
    else callback(true, data, 200, "")
}

// ---- the same four calls as api ----

function get(path, query, callback) {
    if (!isLocal(path)) return api.get(path, query, callback)
    answer(callback, read(path))
}

function cached(path, query) {
    if (!isLocal(path)) return api.cached(path, query)
    return read(path)
}

function send(method, path, body, callback) {
    if (!isLocal(path)) return api.send(method, path, body, callback)
    answer(callback, write(method, path, body))
}

// Pictures need the server; the phone's household has none.
function upload(path, fileUrl, fields, callback) {
    if (!isLocal(path)) return api.upload(path, fileUrl, fields, callback)
    if (callback) callback(false, null, 400, "")
}

function imageUrl(path, query) {
    if (!isLocal(path)) return api.imageUrl(path, query)
    return ""
}
