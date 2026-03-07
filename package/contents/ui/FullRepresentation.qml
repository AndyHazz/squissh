import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmaExtras.Representation {
    id: fullRoot

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    collapseMarginsHint: true

    property var hostModel: []

    function refreshModel(resetSelection) {
        var savedHost = ""
        if (!resetSelection && hostListView.currentIndex >= 0 && hostListView.currentIndex < hostModel.length) {
            var current = hostModel[hostListView.currentIndex]
            if (current && !current.isHeader) savedHost = current.host
        }

        hostModel = buildFilteredModel()

        if (resetSelection) {
            hostListView.currentIndex = -1
        } else if (savedHost) {
            for (var i = 0; i < hostModel.length; i++) {
                if (!hostModel[i].isHeader && hostModel[i].host === savedHost) {
                    hostListView.currentIndex = i
                    return
                }
            }
        }
    }

    header: PlasmaExtras.PlasmoidHeading {
        visible: plasmoid.configuration.enableSearch

        RowLayout {
            anchors.fill: parent

            Kirigami.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n("Search or connect to host...")
                onTextChanged: root.searchText = text
                Keys.onEscapePressed: {
                    if (text !== "") {
                        text = ""
                    } else {
                        root.expanded = false
                    }
                }
                Keys.onReturnPressed: {
                    if (text !== "" && hostListView.count === 0) {
                        root.connectFromSearch(text)
                    } else if (hostListView.count > 0) {
                        var idx = hostListView.nextHostIndex(0)
                        if (idx >= 0) {
                            var first = hostListView.model[idx]
                            root.connectToHost(first.discovered ? first.hostname : first.host)
                        }
                    }
                }
                Keys.onDownPressed: {
                    if (hostListView.count > 0) {
                        hostListView.keyboardNavigating = true
                        hostListView.currentIndex = hostListView.nextHostIndex(0)
                        hostListView.forceActiveFocus()
                    }
                }

            }
        }
    }

    Component.onCompleted: refreshModel(true)

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                fullRoot.refreshModel(false)
                searchField.text = ""
                hostListView.currentIndex = -1
                if (plasmoid.configuration.enableSearch) {
                    searchField.forceActiveFocus()
                } else {
                    hostListView.keyboardNavigating = true
                    hostListView.forceActiveFocus()
                }
                root.refreshIfStale()
            }
        }
        function onSearchTextChanged() { fullRoot.refreshModel(true) }
        function onGroupedHostsChanged() { fullRoot.refreshModel(false) }
        function onFavoritesChanged() { fullRoot.refreshModel(false) }
        function onCollapsedGroupsChanged() { fullRoot.refreshModel(false) }
        function onDiscoveredHostsChanged() { fullRoot.refreshModel(false) }
        function onConnectionHistoryChanged() { fullRoot.refreshModel(false) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: hostListView
                clip: true
                topMargin: Kirigami.Units.mediumSpacing
                bottomMargin: Kirigami.Units.mediumSpacing
                model: fullRoot.hostModel
                currentIndex: -1
                activeFocusOnTab: true
                keyNavigationEnabled: false
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 0
                property bool keyboardNavigating: false
                onActiveFocusChanged: {
                    if (activeFocus && currentIndex < 0 && keyboardNavigating) {
                        currentIndex = nextHostIndex(0)
                    }
                    if (!activeFocus) keyboardNavigating = false
                }

                function nextHostIndex(from) {
                    for (var i = from; i < count; i++) {
                        if (!model[i].isHeader) return i
                    }
                    return -1
                }

                function prevHostIndex(from) {
                    for (var i = from; i >= 0; i--) {
                        if (!model[i].isHeader) return i
                    }
                    return -1
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0 && currentIndex < count) {
                        var item = model[currentIndex]
                        if (item && !item.isHeader) {
                            root.connectToHost(item.discovered ? item.hostname : item.host)
                        }
                    }
                }

                Keys.onDownPressed: {
                    var next = nextHostIndex(currentIndex + 1)
                    if (next >= 0) currentIndex = next
                }

                Keys.onUpPressed: {
                    var prev = prevHostIndex(currentIndex - 1)
                    if (prev >= 0) {
                        currentIndex = prev
                    } else {
                        currentIndex = -1
                        if (plasmoid.configuration.enableSearch) {
                            searchField.forceActiveFocus()
                        }
                    }
                }

                Keys.onEscapePressed: {
                    currentIndex = -1
                    if (plasmoid.configuration.enableSearch) {
                        searchField.forceActiveFocus()
                    } else {
                        root.expanded = false
                    }
                }

                highlight: Rectangle {
                    color: Kirigami.Theme.highlightColor
                    opacity: hostListView.activeFocus ? 0.2 : 0
                    radius: Kirigami.Units.smallSpacing
                }

                delegate: Loader {
                    width: hostListView.width
                    sourceComponent: modelData.isHeader ? groupHeaderComponent : hostDelegateComponent
                    property var itemData: modelData
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: hostListView.count === 0 && root.configLoaded
                    text: root.searchText !== ""
                        ? i18n("No matching hosts — press Enter to connect to \"%1\"", root.searchText)
                        : i18n("No SSH hosts available")
                    iconName: root.searchText !== "" ? "go-next" : "network-disconnect"
                }
            }
        }

}

    function hostItem(h, discovered) {
        var lastConn = root.connectionHistory[h.host] || 0
        return {
            isHeader: false,
            host: h.host,
            hostname: h.hostname,
            user: h.user,
            icon: h.icon,
            status: h.status,
            discovered: discovered || false,
            lastConnected: lastConn,
            mac: h.mac || "",
            commands: h.commands || []
        }
    }

    function sortHostsList(hosts, order) {
        if (order === "alphabetical") {
            hosts.sort(function(a, b) {
                return a.host.toLowerCase().localeCompare(b.host.toLowerCase())
            })
        } else if (order === "recent") {
            hosts.sort(function(a, b) {
                var aTime = root.connectionHistory[a.host] || 0
                var bTime = root.connectionHistory[b.host] || 0
                if (aTime !== bTime) return bTime - aTime
                return 0
            })
        }
    }

    function buildFilteredModel() {
        var items = []
        var search = root.searchText.toLowerCase()
        var hideOffline = plasmoid.configuration.hideUnreachable && plasmoid.configuration.showStatus
        var grouping = plasmoid.configuration.enableGrouping
        var sortOrder = plasmoid.configuration.sortOrder || "config"
        var showRecentGroup = grouping && sortOrder !== "recent"
        var favSet = {}
        for (var f = 0; f < root.favorites.length; f++) {
            favSet[root.favorites[f]] = true
        }

        var favoriteHosts = []
        var recentHosts = []
        var now = Date.now()
        var oneDayMs = 24 * 60 * 60 * 1000

        for (var i = 0; i < root.groupedHosts.length; i++) {
            var group = root.groupedHosts[i]
            var filteredHosts = []

            for (var j = 0; j < group.hosts.length; j++) {
                var h = group.hosts[j]
                if (hideOffline && h.status === "offline") continue
                if (search !== "" &&
                    h.host.toLowerCase().indexOf(search) < 0 &&
                    h.hostname.toLowerCase().indexOf(search) < 0 &&
                    h.user.toLowerCase().indexOf(search) < 0) continue

                var lastConn = root.connectionHistory[h.host] || 0
                var isRecent = lastConn > 0 && (now - lastConn) < oneDayMs

                if (favSet[h.host]) {
                    favoriteHosts.push(h)
                } else if (showRecentGroup && isRecent) {
                    recentHosts.push(h)
                } else {
                    filteredHosts.push(h)
                }
            }

            if (filteredHosts.length > 0) {
                if (grouping) {
                    var groupName = group.name || i18n("Ungrouped")
                    var collapsed = root.isGroupCollapsed(groupName)

                    sortHostsList(filteredHosts, sortOrder)

                    items.push({
                        isHeader: true,
                        groupName: groupName,
                        hostCount: filteredHosts.length,
                        collapsed: collapsed
                    })

                    if (collapsed) continue
                }

                for (var k = 0; k < filteredHosts.length; k++) {
                    items.push(hostItem(filteredHosts[k], false))
                }
            }
        }

        // When ungrouped, sort the entire flat list
        if (!grouping) {
            if (sortOrder === "alphabetical") {
                items.sort(function(a, b) {
                    return a.host.toLowerCase().localeCompare(b.host.toLowerCase())
                })
            } else if (sortOrder === "recent") {
                items.sort(function(a, b) {
                    var aTime = a.lastConnected || 0
                    var bTime = b.lastConnected || 0
                    if (aTime !== bTime) return bTime - aTime
                    return 0
                })
            }
        }

        // Prepend Recent section (only when grouped and not sorting by recent)
        if (showRecentGroup && recentHosts.length > 0) {
            recentHosts.sort(function(a, b) {
                return (root.connectionHistory[b.host] || 0) - (root.connectionHistory[a.host] || 0)
            })

            var recentCollapsed = root.isGroupCollapsed(i18n("Recent"))
            items.unshift({
                isHeader: true,
                groupName: i18n("Recent"),
                hostCount: recentHosts.length,
                collapsed: recentCollapsed
            })
            if (!recentCollapsed) {
                for (var r = recentHosts.length - 1; r >= 0; r--) {
                    items.splice(1, 0, hostItem(recentHosts[r], false))
                }
            }
        }

        // Prepend favorites section
        if (favoriteHosts.length > 0) {
            sortHostsList(favoriteHosts, sortOrder)
            if (grouping) {
                items.unshift({
                    isHeader: true,
                    groupName: i18n("Favorites"),
                    hostCount: favoriteHosts.length,
                    collapsed: false
                })
            }
            for (var m = favoriteHosts.length - 1; m >= 0; m--) {
                items.splice(grouping ? 1 : 0, 0, hostItem(favoriteHosts[m], false))
            }
        }

        // Append discovered network hosts
        if (plasmoid.configuration.discoverHosts && root.discoveredHosts.length > 0) {
            var discoveredFiltered = []
            for (var d = 0; d < root.discoveredHosts.length; d++) {
                var dh = root.discoveredHosts[d]
                if (search !== "" &&
                    dh.host.toLowerCase().indexOf(search) < 0 &&
                    dh.hostname.toLowerCase().indexOf(search) < 0) continue
                discoveredFiltered.push(dh)
            }
            if (discoveredFiltered.length > 0) {
                var discoveredCollapsed = root.isGroupCollapsed(i18n("Discovered"))
                items.push({
                    isHeader: true,
                    groupName: i18n("Discovered"),
                    hostCount: discoveredFiltered.length,
                    collapsed: discoveredCollapsed
                })
                if (!discoveredCollapsed) {
                    for (var e = 0; e < discoveredFiltered.length; e++) {
                        items.push(hostItem(discoveredFiltered[e], true))
                    }
                }
            }
        }

        return items
    }

    Component {
        id: groupHeaderComponent
        GroupHeader {}
    }

    Component {
        id: hostDelegateComponent
        HostDelegate {}
    }
}
