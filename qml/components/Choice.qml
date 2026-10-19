import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// One choice out of a few, as a row of the app's own pills.
// choices: [{ label: "Daily", value: ... }, ...]
Flow {
    id: root

    property var choices: []
    property var current
    signal chosen(var value)

    spacing: Theme.paddingSmall

    Repeater {
        model: root.choices
        Pill {
            text: modelData.label
            selected: modelData.value === root.current
            onClicked: root.chosen(modelData.value)
        }
    }
}
