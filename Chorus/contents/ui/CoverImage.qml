import QtQuick
import QtQuick.Effects

Item {
    id: cover

    property url src
    property int px: 128
    property real radius: 0
    property Image front: imgA
    readonly property bool failed: _failedSrc != "" && _failedSrc == effSrc
    property url _failedSrc: ""
    property url _retriedSrc: ""
    property url _alt: ""
    readonly property url effSrc: _alt != "" ? _alt : src

    onSrcChanged: _alt = ""
    onEffSrcChanged: {
        if (effSrc == "") return;
        if (front.source == effSrc && front.status === Image.Ready) return;
        var back = front === imgA ? imgB : imgA;
        if (back.source == effSrc) {
            if (back.status === Image.Ready) { front = back; return; }
            if (back.status === Image.Loading) return;
            back.source = "";
        }
        back.source = effSrc;
    }

    function fallbackFor(u) {
        var m = String(u).match(/^https:\/\/i\.ytimg\.com\/vi(?:_webp)?\/([A-Za-z0-9_-]+)\/([A-Za-z0-9]+)\.(?:jpg|webp)/);
        if (!m) return "";
        var alt = "https://i.ytimg.com/vi/" + m[1] + "/hqdefault.jpg";
        return alt === String(u) ? "" : alt;
    }

    function settle(img) {
        if (img.source != effSrc) return;
        if (img.status === Image.Ready) {
            _failedSrc = "";
            if (front !== img) front = img;
        } else if (img.status === Image.Error) {
            if (_retriedSrc != effSrc) {
                _retriedSrc = effSrc;
                var s = img.source;
                img.source = "";
                img.source = s;
            } else {
                var alt = fallbackFor(effSrc);
                if (alt !== "" && String(_alt) !== alt) {
                    console.log("[chorus] cover art failed, falling back: " + effSrc + " -> " + alt);
                    _alt = alt;
                    return;
                }
                _failedSrc = effSrc;
                console.log("[chorus] cover art failed to load: " + effSrc);
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
