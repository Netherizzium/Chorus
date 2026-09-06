import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3

// Play / pause button, hand-drawn to match SkipButton
PC3.ToolButton {
    id: btn

    property bool playing: false
    property real size: 24
    property color glyphColor: "white"

    Layout.preferredWidth: size
    Layout.preferredHeight: size

    contentItem: Item {
        implicitWidth: btn.size
        implicitHeight: btn.size
        opacity: btn.enabled ? 1.0 : 0.35

        Canvas {
            id: glyph
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = btn.glyphColor;
                var g = btn.size * 0.34;
                var cx = width / 2, cy = height / 2;
                if (btn.playing) {
                    var bw = Math.max(2, btn.size * 0.13);
                    var bh = g * 1.7;
                    var gap = btn.size * 0.09;
                    ctx.beginPath();
                    ctx.roundedRect(cx - gap - bw, cy - bh / 2, bw, bh, bw / 2, bw / 2);
                    ctx.roundedRect(cx + gap, cy - bh / 2, bw, bh, bw / 2, bw / 2);
                    ctx.fill();
                } else {
                    ctx.beginPath();
                    ctx.moveTo(cx - g * 0.6, cy - g * 0.85);
                    ctx.lineTo(cx - g * 0.6, cy + g * 0.85);
                    ctx.lineTo(cx + g * 0.8, cy);
                    ctx.closePath();
                    ctx.fill();
                }
            }
            Connections {
                target: btn
                function onPlayingChanged() { glyph.requestPaint(); }
                function onGlyphColorChanged() { glyph.requestPaint(); }
                function onSizeChanged() { glyph.requestPaint(); }
            }
        }
    }
}
