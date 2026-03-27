.pragma library

/**
 * Parse SSH config file contents into grouped host list.
 *
 * Recognizes:
 *   #GroupStart <name>  — start a named group
 *   #GroupEnd           — close current group
 *   #Icon <name>        — set icon for next Host block
 *   #MAC xx:xx:xx:xx:xx:xx — set MAC address for next Host (Wake-on-LAN)
 *   #Command [Name] <cmd>  — add named command (name is optional)
 *   #NoSFTP             — disable SFTP file browser button for next Host
 *   Host <name>         — start host entry (skip wildcards)
 *   HostName <value>    — set hostname
 *   User <value>        — set user
 *   Port <value>        — set port
 *   IdentityFile <value> — set identity file
 *   <Key> <value>       — any other directive captured in options[]
 *
 * Preserves:
 *   Host * / Host web-? — wildcard blocks stored as raw text in rawBlocks[]
 *   Match blocks        — stored as raw text in rawBlocks[]
 *   Include directives  — stored as raw text in rawBlocks[]
 *
 * Returns: {
 *   groups: [{name: string, hosts: [{host, hostname, user, port, identityFile, icon, mac, noSftp, commands: [{name, cmd}], options}]}],
 *   rawBlocks: string[]  — unmanaged content (wildcards, Match, Include) preserved for round-trip
 * }
 */
function parseConfig(text) {
    var lines = text.split("\n")
    var groups = []
    var rawBlocks = []
    var currentGroupName = ""
    var currentGroup = { name: "", hosts: [] }
    var currentHost = null
    var pendingIcon = ""
    var pendingMac = ""
    var pendingNoSftp = false
    var pendingCommands = []

    // Track wildcard/unmanaged host blocks
    var inWildcardBlock = false
    var wildcardLines = []

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        var rawLine = lines[i]

        // If we're collecting a wildcard block, check if it ends
        if (inWildcardBlock) {
            // A new Host, Match, GroupStart, or top-level directive ends the wildcard block
            var endsBlock = line.match(/^Host\s+/i) ||
                            line.match(/^Match\s+/i) ||
                            line.match(/^#\s*GroupStart\s+/i) ||
                            line.match(/^#\s*GroupEnd/i)
            if (endsBlock) {
                rawBlocks.push(wildcardLines.join("\n"))
                wildcardLines = []
                inWildcardBlock = false
                // Fall through to process this line normally
            } else {
                // Continue collecting wildcard block lines
                wildcardLines.push(rawLine)
                continue
            }
        }

        // Group directives
        var groupStartMatch = line.match(/^#\s*GroupStart\s+(.+)/i)
        if (groupStartMatch) {
            if (currentHost) {
                currentGroup.hosts.push(currentHost)
                currentHost = null
            }
            if (currentGroup.hosts.length > 0) {
                groups.push(currentGroup)
            }
            currentGroupName = groupStartMatch[1].trim()
            currentGroup = { name: currentGroupName, hosts: [] }
            continue
        }

        if (line.match(/^#\s*GroupEnd/i)) {
            if (currentHost) {
                currentGroup.hosts.push(currentHost)
                currentHost = null
            }
            if (currentGroup.hosts.length > 0) {
                groups.push(currentGroup)
            }
            currentGroupName = ""
            currentGroup = { name: "", hosts: [] }
            continue
        }

        // Icon directive
        var iconMatch = line.match(/^#\s*Icon\s+(.+)/i)
        if (iconMatch) {
            pendingIcon = iconMatch[1].trim()
            continue
        }

        // MAC directive (for Wake-on-LAN)
        var macMatch = line.match(/^#\s*MAC\s+([0-9A-Fa-f:]{17})/i)
        if (macMatch) {
            pendingMac = macMatch[1].trim()
            continue
        }

        // NoSFTP directive
        if (line.match(/^#\s*NoSFTP\s*$/i)) {
            pendingNoSftp = true
            continue
        }

        // Command directive (repeatable — accumulates into array)
        var cmdMatch = line.match(/^#\s*Command\s+(.+)/i)
        if (cmdMatch) {
            var cmdText = cmdMatch[1].trim()
            // Requires text after closing bracket; bare '[Name]' falls through to unnamed
            var namedMatch = cmdText.match(/^\[([^\]]+)\]\s+(.+)/)
            if (namedMatch) {
                pendingCommands.push({ name: namedMatch[1].trim(), cmd: namedMatch[2].trim() })
            } else {
                pendingCommands.push({ name: "", cmd: cmdText })
            }
            continue
        }

        // Include directive — preserve as raw block
        if (line.match(/^Include\s+/i)) {
            rawBlocks.push(rawLine)
            continue
        }

        // Match block — preserve as raw block (collect until next Host/Match/end)
        if (line.match(/^Match\s+/i)) {
            inWildcardBlock = true
            wildcardLines = [rawLine]
            continue
        }

        // Skip other comments and blank lines
        if (line.startsWith("#") || line === "") {
            continue
        }

        // Host directive
        var hostMatch = line.match(/^Host\s+(.+)/i)
        if (hostMatch) {
            var hostNames = hostMatch[1].trim().split(/\s+/)

            // Check if ALL names are wildcards
            var allWildcard = true
            for (var w = 0; w < hostNames.length; w++) {
                if (hostNames[w].indexOf("*") === -1 && hostNames[w].indexOf("?") === -1) {
                    allWildcard = false
                    break
                }
            }

            if (allWildcard) {
                // Start collecting a wildcard block
                inWildcardBlock = true
                wildcardLines = [rawLine]
                // Reset pending directives since they were meant for this host
                pendingIcon = ""
                pendingMac = ""
                pendingNoSftp = false
                pendingCommands = []
                continue
            }

            // Save previous host
            if (currentHost) {
                currentGroup.hosts.push(currentHost)
            }

            currentHost = null

            // Process each host name (skip wildcards)
            for (var h = 0; h < hostNames.length; h++) {
                var name = hostNames[h]
                if (name.indexOf("*") !== -1 || name.indexOf("?") !== -1) {
                    continue
                }
                // For multi-host lines, create separate entries
                if (currentHost === null) {
                    currentHost = {
                        host: name,
                        hostname: name,
                        user: "",
                        port: "",
                        identityFile: "",
                        icon: pendingIcon || "",
                        status: "unknown",
                        mac: pendingMac,
                        noSftp: pendingNoSftp,
                        commands: pendingCommands.slice(),
                        options: []
                    }
                } else {
                    // Push previous and start new for multi-host
                    currentGroup.hosts.push(currentHost)
                    currentHost = {
                        host: name,
                        hostname: name,
                        user: "",
                        port: "",
                        identityFile: "",
                        icon: pendingIcon || "",
                        status: "unknown",
                        mac: pendingMac,
                        noSftp: pendingNoSftp,
                        commands: pendingCommands.slice(),
                        options: []
                    }
                }
            }
            pendingIcon = ""
            pendingMac = ""
            pendingNoSftp = false
            pendingCommands = []
            continue
        }

        // Host properties
        if (currentHost) {
            var hostnameMatch = line.match(/^HostName\s+(.+)/i)
            if (hostnameMatch) {
                currentHost.hostname = hostnameMatch[1].trim()
            } else {
                var userMatch = line.match(/^User\s+(.+)/i)
                if (userMatch) {
                    currentHost.user = userMatch[1].trim()
                } else {
                    var portMatch = line.match(/^Port\s+(.+)/i)
                    if (portMatch) {
                        currentHost.port = portMatch[1].trim()
                    } else {
                        var idMatch = line.match(/^IdentityFile\s+(.+)/i)
                        if (idMatch) {
                            currentHost.identityFile = idMatch[1].trim()
                        } else {
                            // Capture any other SSH directive as a key-value option
                            var optMatch = line.match(/^(\S+)\s+(.*)/i)
                            if (optMatch) {
                                currentHost.options.push({
                                    key: optMatch[1],
                                    value: optMatch[2].trim()
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    // Flush any remaining wildcard block
    if (inWildcardBlock && wildcardLines.length > 0) {
        rawBlocks.push(wildcardLines.join("\n"))
    }

    // Don't forget the last host/group
    if (currentHost) {
        currentGroup.hosts.push(currentHost)
    }
    if (currentGroup.hosts.length > 0) {
        groups.push(currentGroup)
    }

    return { groups: groups, rawBlocks: rawBlocks }
}

// Allow Node.js test runners to import this module
if (typeof module !== 'undefined') module.exports = { parseConfig }
