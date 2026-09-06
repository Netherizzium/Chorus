import QtQuick
import QtQuick.Effects

Item {
    id: cover

    property url src
    property int px: 128
    property real radius: 0
    property Image front: imgA

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

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: cover.px
        sourceSize.height: cover.px
        visible: false
        onStatusChanged: if (status === Image.Ready && cover.front !== imgA && source == cover.src) cover.front = imgA
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
        onStatusChanged: if (status === Image.Ready && cover.front !== imgB && source == cover.src) cover.front = imgB
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
