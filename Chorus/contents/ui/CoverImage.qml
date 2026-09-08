import QtQuick
import QtQuick.Effects

Item {
    id: cover

    property url src
    property int px: 128
    property real radius: 0
    property Image front: imgA
    readonly property bool failed: _failedSrc != "" && _failedSrc == src
    property url _failedSrc: ""
    property url _retriedSrc: ""

    onSrcChanged: {
        if (src == "") return;
        if (front.source == src && front.status === Image.Ready) return;
        var back = front === imgA ? imgB : imgA;
        if (back.source == src) {
            if (back.status === Image.Ready) { front = back; return; }
            if (back.status === Image.Loading) return;
            back.source = "";
        }
        back.source = src;
    }

    function settle(img) {
        if (img.source != src) return;
        if (img.status === Image.Ready) {
            _failedSrc = "";
            if (front !== img) front = img;
        } else if (img.status === Image.Error) {
            if (_retriedSrc != src) {
                _retriedSrc = src;
                var s = img.source;
                img.source = "";
                img.source = s;
            } else {
                _failedSrc = src;
                console.log("[chorus] cover art failed to load: " + src);
            }
        }
    }

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: cover.px
        sourceSize.height: cover.px
        visible: false
        onStatusChanged: cover.settle(imgA)
    }
    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: cover.px
        sourceSize.height: cover.px
        visible: false
        onStatusChanged: cover.settle(imgB)
    }

    MultiEffect {
        anchors.fill: parent
        source: cover.front
        maskEnabled: true
        maskSource: mask
    }
    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: cover.radius }
    }
}
