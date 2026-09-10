import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page
    property bool ready: false

    property alias cfg_useCustomFont: customFontCheck.checked
    property alias cfg_fontPath: fontPathField.text
    property var cfg_fontFallbacks: []
    property double cfg_fontScale
    property double cfg_minFrac
    property double cfg_maxFrac
    property string cfg_activeColor
    property alias cfg_hideWhenIdle: hideIdleCheck.checked
    property alias cfg_showVolumeBar: volumeCheck.checked
    property int cfg_lyricsOffsetMs

    property var fontDialog: null
    property var colorButton: null

    readonly property int maxFallbacks: 5
    property var fontDialogField: null
    property int nextUid: 1

    ListModel { id: fallbackModel }

    function loadFallbacks() {
        fallbackModel.clear();
        var stored = page.cfg_fontFallbacks || [];
        for (var i = 0; i < stored.length && i < page.maxFallbacks; i++) {
            var p = String(stored[i] || "").trim();
            if (p !== "") fallbackModel.append({ path: p, uid: page.nextUid++ });
        }
    }
    onCfg_fontFallbacksChanged: if (!page.ready) page.loadFallbacks()

    function rowForUid(uid) {
        for (var i = 0; i < fallbackModel.count; i++)
            if (fallbackModel.get(i).uid === uid) return i;
        return -1;
    }
    function addFallback() {
        if (fallbackModel.count >= page.maxFallbacks) return;
        fallbackModel.append({ path: "", uid: page.nextUid++ });
    }
    function setFallbackPath(uid, path) {
        var i = page.rowForUid(uid);
        if (i < 0) return;
        fallbackModel.setProperty(i, "path", String(path));
        page.syncFallbacks();
    }
    function removeFallback(uid) {
        var i = page.rowForUid(uid);
        if (i < 0) return;
        fallbackModel.remove(i);
        page.syncFallbacks();
    }

    function syncFallbacks() {
        var out = [];
        for (var i = 0; i < fallbackModel.count; i++) {
            var p = String(fallbackModel.get(i).path || "").trim();
            if (p !== "") out.push(p);
        }
        page.cfg_fontFallbacks = out;
    }

    Component.onCompleted: {
        page.loadFallbacks();

        try {
            fontDialog = Qt.createQmlObject(
                'import QtQuick.Dialogs; FileDialog { }', page, "fontDialog");
            fontDialog.title = i18n("Choose a font file");
            fontDialog.nameFilters = [i18n("Font files (*.ttf *.otf *.ttc)"),
                                      i18n("All files (*)")];
            fontDialog.accepted.connect(function () {
                var f = fontDialog.selectedFile.toString();
                if (page.fontDialogField === null) {
                    fontPathField.text = f;
                } else {
                    page.fontDialogField.text = f;
                    page.setFallbackPath(page.fontDialogField.uid, f);
                }
            });
        } catch (e) { fontDialog = null; }

        try {
            colorButton = Qt.createQmlObject(
                'import org.kde.kquickcontrols as KQuickControls; KQuickControls.ColorButton { showAlphaChannel: true }',
                colorSlot, "colorButton");
            colorButton.color = page.cfg_activeColor || "#FFFFFF";
            colorButton.colorChanged.connect(function () {
                if (page.ready) {
                    page.cfg_activeColor = String(colorButton.color);
                    hexField.text = String(colorButton.color);
                }
            });
        } catch (e) { colorButton = null; }

        hexField.text = page.cfg_activeColor || "#FFFFFF";
        Qt.callLater(function () { page.ready = true; });
    }

    Kirigami.FormLayout {

        QQC2.CheckBox {
            id: customFontCheck
            Kirigami.FormData.label: i18n("Font:")
            text: i18n("Use custom font")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Font file:")
            visible: customFontCheck.checked
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                id: fontPathField
                Layout.fillWidth: true
            }
            QQC2.Button {
                visible: page.fontDialog !== null
                icon.name: "document-open"
                QQC2.ToolTip.text: i18n("Browse for a font file")
                QQC2.ToolTip.visible: hovered
                onClicked: { page.fontDialogField = null; page.fontDialog.open(); }
            }
            QQC2.Button {
                icon.name: "list-add"
                enabled: fallbackModel.count < page.maxFallbacks
                QQC2.ToolTip.text: i18n("Add a fallback font")
                QQC2.ToolTip.visible: hovered
                onClicked: page.addFallback()
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Fallback fonts:")
            visible: customFontCheck.checked && fallbackModel.count > 0
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: fallbackModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: i18n("%1.", index + 2)
                        opacity: 0.7
                    }
                    QQC2.TextField {
                        id: fallbackField
                        readonly property int uid: model.uid
                        Layout.fillWidth: true
                        Component.onCompleted: text = model.path
                        onTextEdited: page.setFallbackPath(fallbackField.uid, text)
                    }
                    QQC2.Button {
                        visible: page.fontDialog !== null
                        icon.name: "document-open"
                        QQC2.ToolTip.text: i18n("Browse for a font file")
                        QQC2.ToolTip.visible: hovered
                        onClicked: { page.fontDialogField = fallbackField; page.fontDialog.open(); }
                    }
                    QQC2.Button {
                        icon.name: "list-remove"
                        QQC2.ToolTip.text: i18n("Remove this fallback font")
                        QQC2.ToolTip.visible: hovered
                        onClicked: {
                            if (page.fontDialogField === fallbackField) page.fontDialogField = null;
                            page.removeFallback(fallbackField.uid);
                        }
                    }
                }
            }
        }

        QQC2.SpinBox {
            id: fontScaleSpin
            Kirigami.FormData.label: i18n("Font scale (%):")
            from: 50; to: 200; stepSize: 5
            value: 100
            Component.onCompleted: value = Math.round(page.cfg_fontScale ? page.cfg_fontScale * 100 : 100)
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: minFracSpin
            Kirigami.FormData.label: i18n("Min width (% of screen):")
            from: 0; to: 80; stepSize: 5
            value: 35
            Component.onCompleted: value = Math.round((page.cfg_minFrac || 0.35) * 100)
        }
        QQC2.SpinBox {
            id: maxFracSpin
            Kirigami.FormData.label: i18n("Max width (% of screen):")
            from: 10; to: 90; stepSize: 5
            value: 50
            Component.onCompleted: value = Math.round((page.cfg_maxFrac || 0.5) * 100)
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Color:")
            spacing: Kirigami.Units.smallSpacing
            Item {
                id: colorSlot
                visible: page.colorButton !== null
                Layout.preferredWidth: page.colorButton ? page.colorButton.implicitWidth : 0
                Layout.preferredHeight: page.colorButton ? page.colorButton.implicitHeight : 0
            }
            QQC2.TextField {
                id: hexField
                visible: page.colorButton === null
                placeholderText: "#FFFFFF"
                onTextEdited: if (page.ready
                        && /^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text))
                    page.cfg_activeColor = text
            }
        }

        QQC2.CheckBox {
            id: volumeCheck
            Kirigami.FormData.label: i18n("Volume:")
            text: i18n("Show volume slider in popup")
        }
        QQC2.Label {
            text: i18n("Tip: you can also scroll on the panel widget or the album cover in the popup to adjust the volume.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: hideIdleCheck
            Kirigami.FormData.label: i18n("When nothing is playing:")
            text: i18n("Collapse widget to zero width")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: lyricsOffsetSpin
            Kirigami.FormData.label: i18n("Lyrics timing offset (ms):")
            from: -3000; to: 3000; stepSize: 50
            value: 0
            editable: true
            Component.onCompleted: value = page.cfg_lyricsOffsetMs || 0
        }
        QQC2.Label {
            text: i18n("Positive values show lines earlier.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Connections {
        target: fontScaleSpin
        function onValueChanged() { if (page.ready) page.cfg_fontScale = fontScaleSpin.value / 100; }
    }
    Connections {
        target: minFracSpin
        function onValueChanged() { if (page.ready) page.cfg_minFrac = minFracSpin.value / 100; }
    }
    Connections {
        target: maxFracSpin
        function onValueChanged() { if (page.ready) page.cfg_maxFrac = maxFracSpin.value / 100; }
    }
    Connections {
        target: lyricsOffsetSpin
        function onValueChanged() { if (page.ready) page.cfg_lyricsOffsetMs = lyricsOffsetSpin.value; }
    }
}
