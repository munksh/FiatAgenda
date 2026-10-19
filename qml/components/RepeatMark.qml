import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The small circling arrow beside a repeat. Drawn, because "↻" is a different
// shape, or missing, from one font to the next.
Canvas {
    id: root

    property color color: FiatAgendaTheme.accent

    width: Theme.fontSizeExtraSmall * 0.85
    height: width
    antialiasing: true

    onColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var w = width, s = Math.max(1.5, w * 0.13)
        ctx.lineWidth = s
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = String(root.color)
        var r = w / 2 - s
        ctx.beginPath()
        ctx.arc(w / 2, w / 2, r, -Math.PI * 0.3, Math.PI * 1.55, false)
        ctx.stroke()
        // the arrowhead, at the open end of the arc
        var ex = w / 2 + r * Math.cos(-Math.PI * 0.3), ey = w / 2 + r * Math.sin(-Math.PI * 0.3)
        ctx.beginPath()
        ctx.moveTo(ex - w * 0.34, ey - w * 0.04)
        ctx.lineTo(ex, ey)
        ctx.lineTo(ex + w * 0.06, ey - w * 0.36)
        ctx.stroke()
    }
}
