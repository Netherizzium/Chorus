import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/lrc.js" as Lrc

// Popup search UI shared by both providers used by whichever one is active
ColumnLayout {
    id: box
    spacing: Kirigami.Units.smallSpacing * 2

    property var api: null
    property string placeholder: ""

    // reset search state whenever the popup closes or a result is picked
    Connections {
        target: root
        function onExpandedChanged() {
            if (!root.expanded) {
                searchField.clear();
                if (box.api) box.api.clearSearch();
            }
        }
    }
    Connections {
        target: box.api
        enabled: box.api !== null
        function onSearchAccepted() {
            searchField.clear();
            searchField.focus = false;
            if (box.api) box.api.clearSearch();
        }
    }

    function go() {
        if (!box.api || searchField.text.trim() === "") return;
        if (!box.api.configured) {
            box.api.reportUnconfigured();
            return;
        }
        box.api.doSearch(searchField.text);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PC3.TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: box.placeholder
            color: root.cActive
            placeholderTextColor: root.cInactive
            font.family: root.cfgFont
            onAccepted: box.go()
            onTextEdited: if (text === "" && box.api) box.api.clearSearch()
            Keys.onEscapePressed: {
                searchField.clear();
                if (box.api) box.api.clearSearch();
            }
        }
        PC3.ToolButton {
            icon.name: "search"
            icon.color: root.cActive
            enabled: searchField.text.trim() !== ""
            onClicked: box.go()
        }
    }
    // hand-drawn spinner: the themed BusyIndicator ignores the configured color
    Canvas {
        id: spinner
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        visible: box.api !== null && box.api.searching
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = root.cActive;
            ctx.lineWidth = Math.max(2, width * 0.11);
            ctx.lineCap = "round";
            var r = (Math.min(width, height) - ctx.lineWidth) / 2;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r, 0, Math.PI * 1.5);
            ctx.stroke();
        }
        Connections {
            target: root
            function onCActiveChanged() { spinner.requestPaint(); }
        }
        RotationAnimator on rotation {
            from: 0; to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.visible
        }
    }
    PC3.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        visible: box.api !== null && box.api.searchError !== ""
        text: box.api !== null ? Lrc.normalize(box.api.searchError) : ""
        color: root.cActive
        opacity: 0.6
        wrapMode: Text.WordWrap
        font.family: root.cfgFont
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        horizontalAlignment: Text.AlignHCenter
    }
    ListView {
        id: resultsList
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(count, 5) * (Kirigami.Units.gridUnit * 2.4)
        visible: count > 0 && box.api !== null && !box.api.searching
        clip: true
        model: box.api !== null ? box.api.searchResults : []
        delegate: PC3.ItemDelegate {
            width: resultsList.width
            height: Kirigami.Units.gridUnit * 2.4
            contentItem: ColumnLayout {
                spacing: 0
                PC3.Label {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: Lrc.normalize(modelData.title)
                    color: root.cActive
                    font.family: root.cfgFont
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                PC3.Label {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: Lrc.normalize(modelData.subtitle)
                    visible: text !== ""
                    color: root.cActive
                    opacity: 0.6
                    font.family: root.cfgFont
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
            onClicked: if (box.api) box.api.playSearchResult(modelData)
        }
    }
}
