import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_appMode
    property string cfg_searchMode
    property alias cfg_playerMatch: matchField.text
    property alias cfg_preferSongs: preferSongsCheck.checked
    property alias cfg_apiUrl: apiUrlField.text
    property alias cfg_extraQueue: extraQueueSpin.value
    property alias cfg_launchCmd: launchField.text
    property alias cfg_closeCmd: closeField.text
    property bool cfg_pearHideAppButton: false
    property alias cfg_spotifyClientId: spotifyIdField.text
    property alias cfg_spotifyClientSecret: spotifySecretField.text
    property alias cfg_spotifyLaunchCmd: spotifyLaunchField.text
    property alias cfg_spotifyCloseCmd: spotifyCloseField.text
    property bool cfg_spotifyHideAppButton: false
    property string legacyAppMode: ""

    readonly property var appModes: ["universal", "custom"]
    readonly property var searchModes: ["none", "auto", "pear", "spotify"]
    readonly property bool autoSearch: searchCombo.currentIndex === 1
    readonly property bool pearSearch: searchCombo.currentIndex === 2
    readonly property bool spotifySearch: searchCombo.currentIndex === 3
    readonly property bool showPear: pearSearch || autoSearch
    readonly property bool showSpotify: spotifySearch || autoSearch
    readonly property bool hideCommands: autoSearch
        ? cfg_pearHideAppButton && cfg_spotifyHideAppButton
        : (pearSearch ? cfg_pearHideAppButton
                      : spotifySearch && cfg_spotifyHideAppButton)
    readonly property int fieldWidth: Kirigami.Units.gridUnit * 22

    Kirigami.FormLayout {

        QQC2.ComboBox {
            id: appModeCombo
            Kirigami.FormData.label: i18n("Music app:")
            model: [
                i18n("All media players"),
                i18n("Only specific apps")
            ]
            onActivated: page.cfg_appMode = page.appModes[currentIndex]
            Component.onCompleted: {
                page.legacyAppMode = page.cfg_appMode;
                var i = page.appModes.indexOf(page.cfg_appMode);
                if (i < 0) { i = 0; page.cfg_appMode = page.appModes[0]; }
                currentIndex = i;
            }
        }
        QQC2.TextField {
            id: matchField
            Kirigami.FormData.label: i18n("App name or class:")
            visible: appModeCombo.currentIndex === 1
            placeholderText: i18n("e.g. spotify, org.kde.elisa. Separate several with commas")
            Layout.maximumWidth: page.fieldWidth
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: searchCombo
            Kirigami.FormData.label: i18n("Search bar:")
            model: [
                i18n("None"),
                i18n("Automatic (follow what's playing)"),
                i18n("Pear Desktop (YouTube Music)"),
                i18n("Spotify (requires Premium)")
            ]
            onActivated: page.cfg_searchMode = page.searchModes[currentIndex]
            Component.onCompleted: {
                var m = page.cfg_searchMode;
                if (page.searchModes.indexOf(m) < 0) {
                    m = (page.legacyAppMode === "pear" || page.legacyAppMode === "spotify")
                        ? page.legacyAppMode : "none";
                    page.cfg_searchMode = m;
                }
                currentIndex = Math.max(0, page.searchModes.indexOf(m));
            }
        }
        QQC2.Label {
            visible: page.autoSearch
            text: i18n("Uses Spotify or YouTube Music search while that app is playing; players without a search API (Elisa, VLC...) get no search bar.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: page.fieldWidth
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Spotify")
            visible: page.showSpotify
        }
        QQC2.TextField {
            id: spotifyIdField
            visible: page.showSpotify
            Kirigami.FormData.label: i18n("Client ID:")
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.TextField {
            id: spotifySecretField
            visible: page.showSpotify
            Kirigami.FormData.label: i18n("Client secret:")
            echoMode: TextInput.Password
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.Label {
            visible: page.showSpotify
            text: spotifyIdField.text.trim() !== "" && spotifySecretField.text.trim() !== ""
                  ? i18n("Results show in the widget and play in the Spotify app.")
                  : i18n("Required for search: create an app at developer.spotify.com and paste its client ID and secret here (Spotify requires Premium for Web API access).")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.CheckBox {
            id: spotifyHideBtnCheck
            visible: page.spotifySearch
            Kirigami.FormData.label: i18n("Start/Stop button:")
            text: i18n("Hidden in popup")
            checked: page.cfg_spotifyHideAppButton
            onToggled: page.cfg_spotifyHideAppButton = checked
        }
        QQC2.TextField {
            id: spotifyLaunchField
            visible: page.showSpotify && !page.hideCommands
            Kirigami.FormData.label: i18n("Start command:")
            placeholderText: "gtk-launch spotify || gtk-launch com.spotify.Client || spotify"
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.TextField {
            id: spotifyCloseField
            visible: page.showSpotify && !page.hideCommands
            Kirigami.FormData.label: i18n("Close command:")
            placeholderText: "pkill -x spotify"
            Layout.maximumWidth: page.fieldWidth
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Pear Desktop")
            visible: page.showPear
        }
        QQC2.CheckBox {
            id: preferSongsCheck
            visible: page.showPear
            Kirigami.FormData.label: i18n("Results:")
            text: i18n("Prefer songs over videos")
        }
        QQC2.TextField {
            id: apiUrlField
            visible: page.showPear
            Kirigami.FormData.label: i18n("API server URL:")
            placeholderText: "http://127.0.0.1:26538"
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.Label {
            visible: page.showPear
            text: i18n("Requires the API Server plugin enabled inside Pear Desktop.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.SpinBox {
            id: extraQueueSpin
            visible: page.showPear
            Kirigami.FormData.label: i18n("Extra songs queued on cold start:")
            from: 0; to: 15
            value: 5
        }
        QQC2.CheckBox {
            id: pearHideBtnCheck
            visible: page.pearSearch
            Kirigami.FormData.label: i18n("Start/Stop button:")
            text: i18n("Hidden in popup")
            checked: page.cfg_pearHideAppButton
            onToggled: page.cfg_pearHideAppButton = checked
        }
        QQC2.TextField {
            id: launchField
            visible: page.showPear && !page.hideCommands
            Kirigami.FormData.label: i18n("Start command:")
            placeholderText: "gtk-launch com.github.th_ch.youtube_music || youtube-music"
            Layout.maximumWidth: page.fieldWidth
        }
        QQC2.TextField {
            id: closeField
            visible: page.showPear && !page.hideCommands
            Kirigami.FormData.label: i18n("Force-close command:")
            placeholderText: "pkill -9 -f youtube-music"
            Layout.maximumWidth: page.fieldWidth
        }

        Item { Kirigami.FormData.isSection: true; visible: page.autoSearch }
        QQC2.CheckBox {
            id: autoHideBtnCheck
            visible: page.autoSearch
            Kirigami.FormData.label: i18n("Start/Stop button:")
            text: i18n("Hidden in popup")
            checked: page.cfg_pearHideAppButton && page.cfg_spotifyHideAppButton
            onToggled: {
                page.cfg_pearHideAppButton = checked;
                page.cfg_spotifyHideAppButton = checked;
            }
        }
    }
}
