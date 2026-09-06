import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Start/Stop button for whichever app is used for search (Pear or Spotify).
Rectangle {
    id: appBtn
    implicitWidth: appBtnRow.implicitWidth + Kirigami.Units.gridUnit * 1.5
    implicitHeight: Kirigami.Units.gridUnit * 1.9
    radius: height / 2
    color: appBtnMouse.containsMouse
           ? Qt.alpha(root.cActive, appBtnMouse.pressed ? 0.28 : 0.16)
           : "transparent"
    border.width: 1
    border.color: Qt.alpha(root.cActive, 0.4)

    RowLayout {
        id: appBtnRow
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: root.searchAppRunning ? "window-close" : "media-playback-start"
            color: root.cActive
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        PC3.Label {
            textFormat: Text.PlainText
            text: root.searchAppRunning ? i18n("Stop %1", root.searchAppName)
                                        : i18n("Start %1", root.searchAppName)
            font.family: root.cfgFont
            color: root.cActive
        }
    }
    MouseArea {
        id: appBtnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.searchApi) return;
            if (root.searchAppRunning) root.searchApi.closeApp();
            else root.searchApi.launchApp();
        }
    }
}
