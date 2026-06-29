import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.notification

import "../code/sshconfig.js" as SSHConfig
import "../code/discovery.js" as Discovery
import "../code/timeformat.js" as TimeFormat
import "../code/statemanager.js" as StateManager
import "../code/shellutil.js" as ShellUtil

PlasmoidItem {
    id: root

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}
    preloadFullRepresentation: true

    switchWidth: Kirigami.Units.gridUnit * 20
    switchHeight: Kirigami.Units.gridUnit * 14

    Plasmoid.icon: Qt.resolvedUrl("../icons/squissh.svg")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    toolTipMainText: i18n("SquiSSH")
    toolTipSubText: {
        var count = hostList.length
        return i18np("%1 host configured", "%1 hosts configured", count)
    }

    property var groupedHosts: {
        try {
            var cached = JSON.parse(plasmoid.configuration.cachedHosts || "[]")
            if (cached.length > 0) {
                var statuses = {}
                try { statuses = JSON.parse(plasmoid.configuration.cachedStatuses || "{}") } catch(e2) {}
                for (var i = 0; i < cached.length; i++)
                    for (var j = 0; j < cached[i].hosts.length; j++) {
                        var h = cached[i].hosts[j]
                        h.status = statuses[h.hostname] || "unknown"
                    }
                return cached
            }
        } catch(e) {}
        return []
    }
    property var hostList: {
        var groups = groupedHosts
        var flat = []
        for (var i = 0; i < groups.length; i++)
            for (var j = 0; j < groups[i].hosts.length; j++)
                flat.push(groups[i].hosts[j])
        return flat
    }
    property string searchText: ""
    property var favorites: {
        try {
            return JSON.parse(plasmoid.configuration.favorites || "[]")
        } catch(e) {
            return []
        }
    }
    property bool configLoaded: groupedHosts.length > 0
    property var previousStatuses: ({})
    property var discoveredHosts: []
    property double lastRefreshTime: 0
    readonly property int refreshCooldown: 30000 // 30 seconds
    readonly property var _localHostnames: ["localhost", "127.0.0.1", "::1"]
    property string terminalIcon: "utilities-terminal"
    property var _pendingSftp: null
    signal sftpPassphraseNeeded()

    function isLocalHost(hostname) {
        return _localHostnames.indexOf(hostname.toLowerCase()) >= 0
    }

    property bool _restoring: false
    readonly property string _prefsFile: "$HOME/.config/squissh-prefs.json"
    property var _cfgSnapshot: JSON.stringify(plasmoid.configuration)
    on_CfgSnapshotChanged: { if (!_restoring) prefsSaveTimer.restart() }

    function refreshIfStale() {
        var now = Date.now()
        if (now - lastRefreshTime < refreshCooldown) return
        lastRefreshTime = now
        loadConfig()
        checkAllStatus()
        discoverNetworkHosts()
    }

    property var collapsedGroups: {
        try {
            return JSON.parse(plasmoid.configuration.collapsedGroups || "[]")
        } catch(e) {
            return []
        }
    }

    property var connectionHistory: {
        try {
            return JSON.parse(plasmoid.configuration.connectionHistory || "{}")
        } catch(e) {
            return {}
        }
    }

    function recordConnection(hostAlias) {
        connectionHistory = StateManager.recordConnection(connectionHistory, hostAlias)
        plasmoid.configuration.connectionHistory = JSON.stringify(connectionHistory)
    }

    function formatTimeAgo(timestamp) {
        if (!timestamp || timestamp <= 0) return ""
        var diff = Date.now() - timestamp
        var seconds = Math.floor(diff / 1000)
        if (seconds < 60) return i18n("just now")
        var minutes = Math.floor(seconds / 60)
        if (minutes < 60) return i18np("%1 min ago", "%1 mins ago", minutes)
        var hours = Math.floor(minutes / 60)
        if (hours < 24) return i18np("%1 hour ago", "%1 hours ago", hours)
        var days = Math.floor(hours / 24)
        return i18np("%1 day ago", "%1 days ago", days)
    }

    Plasma5Support.DataSource {
        id: prefsIO
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (sourceName.indexOf("cat ") === 0 && data["exit code"] === 0 && data["stdout"]) {
                try {
                    var config = JSON.parse(data["stdout"])
                    _restoring = true
                    for (var key in config)
                        if (config.hasOwnProperty(key))
                            plasmoid.configuration[key] = config[key]
                } catch(e) {} finally { _restoring = false }
            }
        }
    }

    Timer {
        id: prefsSaveTimer
        interval: 1000
        onTriggered: root.savePrefs()
    }

    function savePrefs() {
        if (_restoring) return
        var cfg = plasmoid.configuration
        var keys = ["terminalCommand", "sshConfigPath", "showStatus", "pingTimeout",
                    "showBadge", "hideUnreachable", "enableGrouping", "sortOrder",
                    "enableSearch", "showIcons", "notifyOnStatusChange", "pollInterval",
                    "discoverHosts", "favorites", "collapsedGroups", "connectionHistory",
                    "cachedStatuses"]
        var config = {}
        for (var i = 0; i < keys.length; i++) config[keys[i]] = cfg[keys[i]]
        var encoded = Qt.btoa(JSON.stringify(config))
        prefsIO.connectSource("printf '%s' " + encoded + " | base64 -d > " + _prefsFile)
    }

    function loadPrefs() {
        prefsIO.connectSource("cat " + _prefsFile + " 2>/dev/null")
    }

    Plasma5Support.DataSource {
        id: configReader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (data["exit code"] === 0) {
                var result = SSHConfig.parseConfig(data["stdout"])
                var newCacheJson = JSON.stringify(result.groups)
                // Skip model rebuild if SSH config hasn't changed
                if (newCacheJson !== plasmoid.configuration.cachedHosts) {
                    root.groupedHosts = result.groups
                    var flat = []
                    for (var i = 0; i < result.groups.length; i++) {
                        for (var j = 0; j < result.groups[i].hosts.length; j++) {
                            flat.push(result.groups[i].hosts[j])
                        }
                    }
                    root.hostList = flat
                    plasmoid.configuration.cachedHosts = newCacheJson
                }
                root.configLoaded = true
                root.checkAllStatus()
                root.discoverNetworkHosts()
                root.lastRefreshTime = Date.now()
            }
        }
    }

    Plasma5Support.DataSource {
        id: pingRunner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            var status = data["exit code"] === 0 ? "online" : "offline"
            var match = sourceName.match(/ping\s+-c\s+1\s+-W\s+\d+\s+(.+)/)
            if (match) {
                updateHostStatus(match[1], status)
                return
            }
            var ncMatch = sourceName.match(/nc\s+-z\s+-w\s*\d+\s+(\S+)\s+\d+/)
            if (ncMatch) {
                updateHostStatus(ncMatch[1], status)
            }
        }
    }

    Plasma5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => { disconnectSource(sourceName) }
    }

    Plasma5Support.DataSource {
        id: clipboardSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => { disconnectSource(sourceName) }
    }

    Plasma5Support.DataSource {
        id: discoveryRunner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (data["exit code"] === 0) {
                root.parseDiscoveredHosts(data["stdout"])
            }
        }
    }

    Plasma5Support.DataSource {
        id: keyChecker
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            var exitCode = (data["stdout"] || "1").trim()
            if (exitCode !== "0") {
                root.sftpPassphraseNeeded()
            } else {
                root._doOpenSftp()
            }
        }
    }

    Plasma5Support.DataSource {
        id: sshAdder
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (data["exit code"] !== 0) {
                sshKeyNotification.text = i18n("Failed to unlock SSH key. Check your passphrase.")
                sshKeyNotification.sendEvent()
            }
            // xdg-open is launched inside the combined command; nothing more to do here
        }
    }

    Notification {
        id: sshKeyNotification
        componentName: "plasma_workspace"
        eventId: "notification"
        title: i18n("SquiSSH")
        iconName: "dialog-password"
    }

    function loadConfig() {
        var path = plasmoid.configuration.sshConfigPath || "~/.ssh/config"
        configReader.connectSource("cat \"" + path.replace("~", "$HOME") + "\"")
    }

    function discoverNetworkHosts() {
        if (!plasmoid.configuration.discoverHosts) return
        discoveryRunner.connectSource("avahi-browse -tpr _ssh._tcp")
    }

    function parseDiscoveredHosts(output) {
        var configuredHostnames = []
        for (var i = 0; i < hostList.length; i++) {
            configuredHostnames.push(hostList[i].hostname)
        }
        root.discoveredHosts = Discovery.parseDiscoveredHosts(output, configuredHostnames)
    }

    property var pingQueue: []

    Timer {
        id: pingStagger
        interval: 1 // yields to the event loop between each connection
        repeat: true
        onTriggered: {
            if (root.pingQueue.length === 0) {
                stop()
                return
            }
            pingRunner.connectSource(root.pingQueue.shift())
        }
    }

    function checkAllStatus() {
        if (!plasmoid.configuration.showStatus) return
        var timeout = plasmoid.configuration.pingTimeout || 2
        var queue = []
        for (var i = 0; i < hostList.length; i++) {
            var host = hostList[i]
            if (ShellUtil.isSafeHostname(host.hostname)) {
                if (host.port && host.port !== "22") {
                    queue.push("nc -z -w" + timeout + " " + host.hostname + " " + host.port)
                } else {
                    queue.push("ping -c 1 -W " + timeout + " " + host.hostname)
                }
            }
        }
        root.pingQueue = queue
        pingStagger.restart()
    }

    function updateHostStatus(hostname, status) {
        var changed = false
        var hostName = ""
        for (var i = 0; i < groupedHosts.length; i++) {
            for (var j = 0; j < groupedHosts[i].hosts.length; j++) {
                if (groupedHosts[i].hosts[j].hostname === hostname) {
                    groupedHosts[i].hosts[j].status = status
                    hostName = groupedHosts[i].hosts[j].host
                    changed = true
                }
            }
        }
        if (changed) {
            // Send notification on status change
            if (plasmoid.configuration.notifyOnStatusChange) {
                var prev = previousStatuses[hostname]
                if (prev && prev !== status) {
                    statusNotification.title = hostName
                    statusNotification.text = status === "online"
                        ? i18n("%1 is now online", hostName)
                        : i18n("%1 is now offline", hostName)
                    statusNotification.iconName = status === "online" ? "network-connect" : "network-disconnect"
                    statusNotification.sendEvent()
                }
            }
            previousStatuses[hostname] = status
            statusDebounce.restart()
        }
    }

    Timer {
        id: statusDebounce
        interval: 200
        onTriggered: {
            // Persist current statuses so next session starts with last known state
            var map = {}
            for (var i = 0; i < hostList.length; i++) {
                var s = hostList[i].status
                if (s === "online" || s === "offline")
                    map[hostList[i].hostname] = s
            }
            plasmoid.configuration.cachedStatuses = JSON.stringify(map)

            // Only rebuild the model when popup is visible; otherwise let changes accumulate
            if (root.expanded) {
                root.groupedHosts = root.groupedHosts.slice()
            }
        }
    }

    Notification {
        id: statusNotification
        componentName: "plasma_workspace"
        eventId: "notification"
    }

    Timer {
        id: pollTimer
        interval: (plasmoid.configuration.pollInterval || 5) * 60 * 1000
        repeat: true
        running: plasmoid.configuration.notifyOnStatusChange && hostList.length > 0
        onTriggered: root.checkAllStatus()
    }

    function connectToHost(hostAlias) {
        var host = findHost(hostAlias)
        var cmd = "setsid " + ((host && isLocalHost(host.hostname))
            ? plasmoid.configuration.terminalCommand.replace(/\s+(-e|--|--command)\s*$/, "")
            : plasmoid.configuration.terminalCommand + " ssh " + ShellUtil.shellQuote(hostAlias))
        launcher.disconnectSource(cmd)
        launcher.connectSource(cmd)
        recordConnection(hostAlias)
        root.expanded = false
    }

    function findHost(hostAlias) {
        for (var i = 0; i < hostList.length; i++)
            if (hostList[i].host === hostAlias) return hostList[i]
        return null
    }

    function editConfig(path) {
        launcher.connectSource("xdg-open " + path.replace("~", "$HOME"))
        root.expanded = false
    }

    function setupPasswordlessLogin(hostAlias) {
        var cmd = plasmoid.configuration.terminalCommand + " ssh-copy-id " + ShellUtil.shellQuote(hostAlias)
        launcher.connectSource(cmd)
        root.expanded = false
    }

    function copyToClipboard(text) {
        clipboardSource.connectSource("qdbus6 org.kde.klipper /klipper setClipboardContents " + Qt.btoa(text))
    }

    function toggleGroup(groupName) {
        collapsedGroups = StateManager.toggleGroup(collapsedGroups, groupName)
        plasmoid.configuration.collapsedGroups = JSON.stringify(collapsedGroups)
    }

    function isGroupCollapsed(groupName) {
        return StateManager.isGroupCollapsed(collapsedGroups, groupName)
    }

    function openSftp(host, user, hostname, port, identityFile) {
        _pendingSftp = { user: user, hostname: hostname, port: port, identityFile: identityFile || "" }
        if (identityFile) {
            var shellKey = identityFile.replace(/^~\//, "${HOME}/").replace(/^~$/, "${HOME}")
            keyChecker.connectSource('ssh-keygen -y -P "" -f "' + shellKey.replace(/"/g, '\\"') + '" >/dev/null 2>&1; echo $?')
        } else {
            _doOpenSftp()
        }
    }

    function _doOpenSftp() {
        if (!_pendingSftp) return
        var s = _pendingSftp
        _pendingSftp = null
        var url = "sftp://"
        if (s.user) url += s.user + "@"
        url += s.hostname
        if (s.port && s.port !== "22") url += ":" + s.port
        launcher.connectSource("xdg-open " + ShellUtil.shellQuote(url))
        root.expanded = false
    }

    function _addKeyToAgent(passphrase) {
        if (!_pendingSftp) return
        var s = _pendingSftp
        _pendingSftp = null

        var shellKey = s.identityFile.replace(/^~\//, "${HOME}/").replace(/^~$/, "${HOME}")
        var quotedPass = ShellUtil.shellQuote(passphrase)
        var quotedKey  = ShellUtil.shellQuote(shellKey)
        var quotedHost = ShellUtil.shellQuote(s.hostname)
        var quotedPort = ShellUtil.shellQuote((s.port && s.port !== "") ? s.port : "22")

        var url = "sftp://"
        if (s.user) url += s.user + "@"
        url += s.hostname
        if (s.port && s.port !== "22") url += ":" + s.port
        var quotedUrl = ShellUtil.shellQuote(url)

        // One shell context so AGENT_SOCK is shared across all steps.
        // The background subshell monitors the TCP connection to the host and
        // removes the key from the agent once the tab is closed.
        var cmd =
            "DIR=$(mktemp -d /tmp/.sq.XXXXXX) && " +
            "chmod 700 \"$DIR\" && " +
            "printf '%s' " + quotedPass + " > \"$DIR/p\" && " +
            "printf '#!/bin/sh\\n' > \"$DIR/a\" && " +
            "printf 'cat \"%s\"\\n' \"$DIR/p\" >> \"$DIR/a\" && " +
            "chmod 700 \"$DIR/a\" && " +
            "systemctl --user enable --now ssh-agent.socket 2>/dev/null; " +
            "AGENT_SOCK=\"${SSH_AUTH_SOCK:-${XDG_RUNTIME_DIR}/ssh-agent.socket}\"; " +
            "SSH_AUTH_SOCK=\"$AGENT_SOCK\" SSH_ASKPASS=\"$DIR/a\" SSH_ASKPASS_REQUIRE=force ssh-add \"" +
            shellKey.replace(/"/g, '\\"') + "\" 2>&1; " +
            "rm -rf \"$DIR\"; " +
            "HOST=" + quotedHost + "; " +
            "PORT=" + quotedPort + "; " +
            "KEY=$(eval echo " + quotedKey + "); " +
            "AGENT=\"$AGENT_SOCK\"; " +
            "( HOST_IP=$(getent hosts \"$HOST\" 2>/dev/null | awk 'NR==1{print $1}'); " +
            "MATCH=\"${HOST_IP:-$HOST}\"; " +
            "I=0; while [ $I -lt 15 ]; do sleep 1; " +
            "ss -tn state established 2>/dev/null | grep -qF \"$MATCH:$PORT\" && break; " +
            "I=$((I+1)); done; " +
            "while ss -tn state established 2>/dev/null | grep -qF \"$MATCH:$PORT\"; do sleep 2; done; " +
            "SSH_AUTH_SOCK=\"$AGENT\" ssh-add -d \"${KEY}.pub\" 2>/dev/null || " +
            "SSH_AUTH_SOCK=\"$AGENT\" ssh-add -d \"$KEY\" 2>/dev/null ) & " +
            "env SSH_AUTH_SOCK=\"$AGENT_SOCK\" setsid xdg-open " + quotedUrl + " &"

        sshAdder.connectSource(cmd)
        root.expanded = false
    }

    function isFavorite(host) {
        return StateManager.isFavorite(favorites, host)
    }

    function toggleFavorite(host) {
        favorites = StateManager.toggleFavorite(favorites, host)
        plasmoid.configuration.favorites = JSON.stringify(favorites)
    }

    function wakeHost(mac) {
        launcher.connectSource("wakeonlan " + mac)
    }

    function runHostCommand(hostAlias, command) {
        var host = findHost(hostAlias)
        var quoted = ShellUtil.shellQuote(command)
        var cmd
        if (host && isLocalHost(host.hostname)) {
            cmd = "setsid " + plasmoid.configuration.terminalCommand + " ${SHELL:-/bin/sh} -lic " + quoted
        } else {
            cmd = "setsid " + plasmoid.configuration.terminalCommand + " ssh -t " + ShellUtil.shellQuote(hostAlias) + " " + quoted
        }
        launcher.disconnectSource(cmd)
        launcher.connectSource(cmd)
        root.expanded = false
    }

    function connectFromSearch(text) {
        var cmd = "setsid " + plasmoid.configuration.terminalCommand + " ssh " + ShellUtil.shellQuote(text)
        launcher.connectSource(cmd)
        root.expanded = false
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            onTriggered: {
                root.lastRefreshTime = 0
                root.refreshIfStale()
            }
        },
        PlasmaCore.Action {
            text: i18n("Edit SSH Config")
            icon.name: "document-edit"
            onTriggered: {
                var path = plasmoid.configuration.sshConfigPath || "~/.ssh/config"
                root.editConfig(path)
            }
        }
    ]

    Plasma5Support.DataSource {
        id: termIconResolver
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (data["exit code"] === 0 && data["stdout"].trim())
                root.terminalIcon = data["stdout"].trim()
        }
    }

    function resolveTerminalIcon() {
        var bin = (plasmoid.configuration.terminalCommand || "").split(/\s/)[0].split("/").pop()
        if (bin) termIconResolver.connectSource(
            "grep -rl 'Exec.*" + bin + "' /usr/share/applications/ ~/.local/share/applications/ 2>/dev/null | head -1 | xargs grep '^Icon=' 2>/dev/null | head -1 | cut -d= -f2")
    }

    Component.onCompleted: {
        loadPrefs()
        loadConfig()
        resolveTerminalIcon()
    }

    // Write SSH config to disk when Apply is clicked in the Hosts config page
    Plasma5Support.DataSource {
        id: configWriter
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            root.loadConfig()
        }
    }

    Connections {
        target: plasmoid.configuration
        function onSshConfigPathChanged() { root.loadConfig() }
        function onSshConfigTextChanged() {
            var text = plasmoid.configuration.sshConfigText
            if (!text || text === "") return
            var path = plasmoid.configuration.sshConfigPath || "~/.ssh/config"
            path = path.replace("~", "$HOME")
            var encoded = Qt.btoa(text)
            var cmd = "cp -p \"" + path + "\" \"" + path + ".bak\" 2>/dev/null; " +
                      "printf '%s' " + encoded + " | base64 -d | tee \"" + path + "\" > /dev/null && " +
                      "chmod 600 \"" + path + "\""
            configWriter.connectSource(cmd)
        }
    }
}
