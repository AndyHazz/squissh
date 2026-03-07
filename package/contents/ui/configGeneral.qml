import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: configPage

    property alias cfg_terminalCommand: terminalCommandField.text
    property string cfg_terminalCommandDefault
    property alias cfg_sshConfigPath: sshConfigPathField.text
    property string cfg_sshConfigPathDefault
    property alias cfg_showStatus: showStatusCheck.checked
    property bool cfg_showStatusDefault
    property alias cfg_pingTimeout: pingTimeoutSpin.value
    property int cfg_pingTimeoutDefault
    property alias cfg_showBadge: showBadgeCheck.checked
    property bool cfg_showBadgeDefault
    property alias cfg_hideUnreachable: hideUnreachableCheck.checked
    property bool cfg_hideUnreachableDefault
    property alias cfg_enableGrouping: enableGroupingCheck.checked
    property bool cfg_enableGroupingDefault
    property string cfg_sortOrder
    property string cfg_sortOrderDefault
    property alias cfg_enableSearch: enableSearchCheck.checked
    property bool cfg_enableSearchDefault
    property alias cfg_notifyOnStatusChange: notifyOnStatusChangeCheck.checked
    property bool cfg_notifyOnStatusChangeDefault
    property alias cfg_pollInterval: pollIntervalSpin.value
    property int cfg_pollIntervalDefault
    property alias cfg_discoverHosts: discoverHostsCheck.checked
    property bool cfg_discoverHostsDefault
    property alias cfg_showIcons: showIconsCheck.checked
    property bool cfg_showIconsDefault
    property alias cfg_showLastConnected: showLastConnectedCheck.checked
    property bool cfg_showLastConnectedDefault
    property alias cfg_showQuickCommands: showQuickCommandsCheck.checked
    property bool cfg_showQuickCommandsDefault

    // Programmatic config entries (not exposed in settings UI)
    property string cfg_favorites
    property string cfg_favoritesDefault
    property string cfg_collapsedGroups
    property string cfg_collapsedGroupsDefault
    property string cfg_connectionHistory
    property string cfg_connectionHistoryDefault
    property string cfg_cachedHosts
    property string cfg_cachedHostsDefault
    property string cfg_sshConfigText
    property string cfg_sshConfigTextDefault

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Connection")
        }

        QQC2.TextField {
            id: terminalCommandField
            Kirigami.FormData.label: i18n("Terminal command:")
            Layout.fillWidth: true
            placeholderText: "ghostty -e"
        }

        QQC2.Label {
            text: i18n("The widget runs: <terminal command> ssh <host alias>")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.TextField {
            id: sshConfigPathField
            Kirigami.FormData.label: i18n("SSH config file:")
            Layout.fillWidth: true
            placeholderText: "~/.ssh/config"
        }

        QQC2.CheckBox {
            id: discoverHostsCheck
            Kirigami.FormData.label: i18n("Discover network hosts:")
        }

        QQC2.Label {
            text: i18n("Uses Avahi/mDNS to find SSH servers on the local network")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }

        QQC2.CheckBox {
            id: enableSearchCheck
            Kirigami.FormData.label: i18n("Show search bar:")
        }

        QQC2.CheckBox {
            id: enableGroupingCheck
            Kirigami.FormData.label: i18n("Group hosts:")
        }

        QQC2.ComboBox {
            id: sortOrderCombo
            Kirigami.FormData.label: i18n("Sort order:")
            model: [i18n("SSH config order"), i18n("Recently accessed"), i18n("Alphabetical")]
            currentIndex: cfg_sortOrder === "recent" ? 1 : cfg_sortOrder === "alphabetical" ? 2 : 0
            onActivated: {
                var values = ["config", "recent", "alphabetical"]
                cfg_sortOrder = values[currentIndex]
            }
        }

        QQC2.CheckBox {
            id: showIconsCheck
            Kirigami.FormData.label: i18n("Show host icons:")
        }

        QQC2.CheckBox {
            id: showLastConnectedCheck
            Kirigami.FormData.label: i18n("Show last connected time:")
        }

        QQC2.CheckBox {
            id: showQuickCommandsCheck
            Kirigami.FormData.label: i18n("Show quick commands:")
        }

        QQC2.Label {
            text: i18n("Shows command buttons inline below each host")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.CheckBox {
            id: showBadgeCheck
            Kirigami.FormData.label: i18n("Show host count badge on icon:")
        }

        QQC2.Label {
            text: i18n("Shows the number of configured hosts on the panel icon")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Status Monitoring")
        }

        QQC2.CheckBox {
            id: showStatusCheck
            Kirigami.FormData.label: i18n("Show connection status:")
        }

        QQC2.SpinBox {
            id: pingTimeoutSpin
            Kirigami.FormData.label: i18n("Ping timeout (seconds):")
            from: 1
            to: 10
            enabled: showStatusCheck.checked
        }

        QQC2.SpinBox {
            id: pollIntervalSpin
            Kirigami.FormData.label: i18n("Poll interval (minutes):")
            from: 1
            to: 60
            enabled: showStatusCheck.checked
        }

        QQC2.Label {
            text: i18n("How often to re-check host reachability")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.CheckBox {
            id: hideUnreachableCheck
            Kirigami.FormData.label: i18n("Hide unreachable hosts:")
            enabled: showStatusCheck.checked
        }

        QQC2.CheckBox {
            id: notifyOnStatusChangeCheck
            Kirigami.FormData.label: i18n("Notify on status change:")
            enabled: showStatusCheck.checked
        }
    }
}
