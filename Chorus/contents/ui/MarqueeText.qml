import QtQuick

Item {
    id: root

    property string text: ""
    property alias font: label.font
    property alias color: label.color
    property real textOpacity: 1.0
    property bool scrolling: true

    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool overflows: label.implicitWidth > width + 1

    Text {
        textFormat: Text.PlainText
        id: label
        y: (root.height - height) / 2
        text: root.text
        opacity: root.textOpacity
        x: root.overflows ? 0 : (root.width - implicitWidth) / 2
    }

    SequentialAnimation {
        id: anim
        loops: Animation.Infinite
        PauseAnimation { duration: 2000 }
        NumberAnimation {
            target: label; property: "x"
            to: Math.min(0, root.width - label.implicitWidth)
            duration: Math.max(1000, (label.implicitWidth - root.width) * 35)
        }
        PauseAnimation { duration: 2000 }
        NumberAnimation { target: label; property: "x"; to: 0; duration: 600 }
    }

    function restart() {
        anim.stop();
        if (overflows && scrolling && visible) {
            label.x = 0;
            anim.start();
        } else {
            label.x = Qt.binding(function () {
                return root.overflows ? 0 : (root.width - label.implicitWidth) / 2;
            });
        }
    }

    onTextChanged: restart()
    onWidthChanged: restart()
    onOverflowsChanged: restart()
    onVisibleChanged: restart()
    onScrollingChanged: restart()
    Component.onCompleted: restart()
}
