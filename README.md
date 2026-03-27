<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/squissh-icon-light.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/squissh-icon-dark.png">
    <img src="docs/squissh-icon-dark.png" alt="SquiSSH" width="128">
  </picture>
</p>

<h1 align="center">SquiSSH</h1>

<p align="center">
  A KDE Plasma 6 system tray widget for Super QUIck SSH connections from your <code>~/.ssh/config</code>.
</p>

<p align="center">
  <img src="docs/Screenshot_1.png" alt="SquiSSH screenshot" width="400">
</p>

## Features

- Parses `~/.ssh/config` automatically — no duplicate configuration
- **Built-in SSH config editor** with host add/edit/delete and reordering
- One-click SSH connections in your preferred terminal
- Host grouping with `#GroupStart` / `#GroupEnd` comments
- Custom icons per host with `#Icon` directive
- **Local host support** — hosts with `localhost` / `127.0.0.1` / `::1` open a terminal directly
- **Connection history** with "Recent" group showing last 24 hours
- **Wake-on-LAN** via `#MAC` directive (right-click offline hosts)
- **Per-host custom commands** via `#Command` directive (with optional display names)
- Pin favorite hosts to the top
- Live online/offline status via ping (TCP port check for non-standard SSH ports)
- Search/filter hosts, or connect to arbitrary hostnames
- One-click SFTP file manager access
- mDNS/Avahi network host discovery
- Status change notifications
- Auto-detects your terminal emulator's icon for host entries

## Installation

### From KDE Store

<p>Search for "SquiSSH" in **Get New Widgets** on your Plasma panel.</p>
<p>Also to be found on the KDE store: https://store.kde.org/p/2349907/</p>

### From Source

```bash
git clone https://github.com/AndyHazz/squissh.git
cd squissh
kpackagetool6 -t Plasma/Applet -i package
```

Then right-click your system tray → **Configure System Tray** → enable **SquiSSH**.

To upgrade an existing installation:

```bash
kpackagetool6 -t Plasma/Applet -u package
```

## SSH Config Format

SquiSSH reads your standard `~/.ssh/config` and adds optional directives via comments:

```ssh-config
# GroupStart Production
# Icon network-server-database
# Command [View Logs] tail -f /var/log/syslog
# Command systemctl status nginx
Host prod-db
    HostName 10.0.1.10
    User admin

Host prod-web
    HostName 10.0.1.20
    User deploy
# GroupEnd

# GroupStart Home Lab
# Icon computer
# MAC aa:bb:cc:dd:ee:ff
Host pihole
    HostName 192.168.1.50
    User pi

# NoSFTP
Host router
    HostName 192.168.1.1
    User admin

Host nas
    HostName 192.168.1.100
    User admin
# GroupEnd

# Hosts without a group appear under "Ungrouped"
Host personal-vps
    HostName example.com
    User me
```

### Directives

| Directive | Description |
|-----------|-------------|
| `# GroupStart <name>` | Start a named group |
| `# GroupEnd` | Close the current group |
| `# Icon <name or path>` | Set a KDE icon or image path for the next host |
| `# MAC <xx:xx:xx:xx:xx:xx>` | Set MAC address for Wake-on-LAN on the next host |
| `# Command [Name] <command>` | Add a custom command with optional display name (repeatable) |
| `# NoSFTP` | Hide the SFTP file browser button for the next host |

These are standard SSH comments and won't affect your SSH connections.

You can also manage all of these from the **SSH Hosts** tab in the widget settings.

## Configuration

Right-click the widget icon → **Configure SquiSSH...**

| Option | Default | Description |
|--------|---------|-------------|
| Terminal command | `ghostty -e` | Command prefix to launch SSH (e.g., `konsole -e`, `alacritty -e`) |
| SSH config file | `~/.ssh/config` | Path to your SSH config |
| Show search bar | `true` | Show search/filter in the popup |
| Group hosts | `true` | Group hosts by `#GroupStart` directives |
| Sort order | Config order | Sort by SSH config order, recently accessed, or alphabetical |
| Show host icons | `true` | Show icons next to host entries |
| Show host count badge | `false` | Show host count on tray icon |
| Show connection status | `true` | Ping hosts to show online/offline dots |
| Ping timeout | `2` seconds | Timeout for status pings |
| Poll interval | `5` minutes | How often to re-check host reachability |
| Hide unreachable hosts | `false` | Hide hosts that fail ping |
| Notify on status change | `false` | Desktop notifications when hosts go online/offline |
| Discover network hosts | `false` | Find SSH servers on LAN via Avahi/mDNS |

## Requirements

- KDE Plasma 6
- `kpackagetool6` (included with Plasma 6)
- `wakeonlan` (optional, for Wake-on-LAN feature)

## License

GPL-3.0
