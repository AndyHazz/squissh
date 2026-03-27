import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: helpPage

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18n("SquiSSH reads your standard SSH config file and displays hosts in the widget. You can manage hosts directly from the SSH Hosts tab, or edit your config file manually using the special comment directives below.")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Kirigami.Separator {}

        // Directives reference
        QQC2.Label {
            text: i18n("Config File Directives")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }

        QQC2.Label {
            text: i18n("These comments can be added to your SSH config file to organize hosts. They are ignored by SSH and only used by SquiSSH.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: "<b># GroupStart &lt;name&gt;</b>"
                textFormat: Text.RichText
            }
            QQC2.Label {
                text: i18n("Start a named group. Hosts below this line belong to this group.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                text: "<b># GroupEnd</b>"
                textFormat: Text.RichText
            }
            QQC2.Label {
                text: i18n("Close the current group. Hosts below return to ungrouped.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                text: "<b># Icon &lt;name or path&gt;</b>"
                textFormat: Text.RichText
            }
            QQC2.Label {
                text: i18n("Set the icon for the next Host entry. Use a KDE icon name (e.g. network-server-database) or an image path (e.g. ~/.local/share/icons/myicon.png).")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                text: "<b># MAC &lt;xx:xx:xx:xx:xx:xx&gt;</b>"
                textFormat: Text.RichText
            }
            QQC2.Label {
                text: i18n("Set the MAC address for the next Host entry. Enables Wake-on-LAN from the right-click menu when the host is offline. Requires the 'wakeonlan' package.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                text: "<b># Command &lt;command&gt;</b>"
                textFormat: Text.RichText
            }
            QQC2.Label {
                text: i18n("Add a custom command for the next Host entry. Can be repeated to add multiple commands. Commands appear in a submenu when right-clicking the host.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                text: "<b># NoSFTP</b>"
                textFormat: Text.RichText
            }
            QQC2.Label {
                text: i18n("Hide the file manager (SFTP) button for the next Host entry. Useful for hosts that don't support SFTP, such as routers or embedded devices.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        Kirigami.Separator {}

        // Example
        QQC2.Label {
            text: i18n("Example SSH Config")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: exampleText.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.alternateBackgroundColor
            border.width: 1
            border.color: Kirigami.Theme.separatorColor

            QQC2.Label {
                id: exampleText
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: "# Local terminal with custom commands\n# Icon squissh\n# Command htop\n# Command btop\n# Command journalctl -f\nHost local\n    HostName localhost\n\n# GroupStart Production Servers\n\n# Icon network-server-database\n# Command tail -f /var/log/syslog\n# Command systemctl status nginx\nHost prod-db\n    HostName 10.0.1.10\n    User admin\n\nHost prod-web\n    HostName 10.0.1.20\n    User deploy\n\n# GroupEnd\n\n# GroupStart Home Lab\n\n# Icon ~/.local/share/icons/squissh/pihole.png\n# MAC aa:bb:cc:dd:ee:ff\nHost pihole\n    HostName 192.168.1.50\n    User pi\n\n# NoSFTP\nHost router\n    HostName 192.168.1.1\n    User admin\n\nHost nas\n    HostName 192.168.1.100\n    User admin\n\n# GroupEnd\n\n# Hosts outside groups appear under \"Ungrouped\"\nHost personal-vps\n    HostName example.com\n    User me"
            }
        }

        Kirigami.Separator {}

        QQC2.Label {
            text: i18n("Icons")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }

        QQC2.Label {
            text: i18n("• Icon names follow the freedesktop icon naming spec. Browse available icons with the Cuttlefish app (kde-dev-utils).\n• Use 'squissh' for the built-in SquiSSH icon, or 'terminal' for the generic terminal icon.\n• Hosts without a custom icon show your configured terminal's icon.")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            text: i18n("Local Hosts")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }

        QQC2.Label {
            text: i18n("Hosts with HostName localhost, 127.0.0.1, or ::1 are treated as local — clicking opens a terminal directly without SSH, and custom commands run locally.")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            text: i18n("Other Notes")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }

        QQC2.Label {
            text: i18n("• Wildcard hosts (e.g. Host *) are automatically skipped.\n• The # Icon, # MAC, # Command, and # NoSFTP directives apply to the next Host entry only.\n• # Command can be repeated multiple times to add several commands to one host.\n• Hosts with a non-standard SSH port use a TCP connection check instead of ping for status detection.\n• Wake-on-LAN requires the 'wakeonlan' package to be installed.")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
