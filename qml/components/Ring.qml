import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// How much of something is done, as a ring that closes, with the count in the
// middle. Drawn on a Canvas: QtQuick.Shapes is newer than the platform.
Item {
    id: root

    property int done: 0
    property int total: 0
    property color color: FiatAgendaTheme.accent

    readonly property real share: total > 0 ? Math.min(1, done / total) : 0
    readonly property real stroke: Math.max(3, Math.round(width * 0.075))

    width: Theme.itemSizeLarge
    height: width

    onShareChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = (width - root.stroke) / 2
            var cx = width / 2, cy = height / 2

            // Colours go in opaque and get their strength from globalAlpha: a
            // colour with alpha in it does not survive the trip into strokeStyle.
            ctx.lineWidth = root.stroke
            ctx.strokeStyle = String(FiatAgendaTheme.primaryText)
            ctx.globalAlpha = 0.12
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
            ctx.stroke()

            if (root.share <= 0) return
            ctx.globalAlpha = 1.0
            ctx.strokeStyle = String(root.color)
            ctx.lineCap = root.share < 1 ? "round" : "butt"
            ctx.beginPath()
            var start = -Math.PI / 2
            ctx.arc(cx, cy, r, start, start + Math.PI * 2 * root.share, false)
            ctx.stroke()
        }
    }

    Label {
        anchors.centerIn: parent
        text: root.done + "/" + root.total
        color: FiatAgendaTheme.primaryText
        font.family: FiatAgendaTheme.serif
        font.pixelSize: root.width * (text.length > 4 ? 0.2 : 0.24)
    }
}
