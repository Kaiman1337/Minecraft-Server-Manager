# SERVER-MANAGER

## Overview

`SERVER-MANAGER` is a Linux-based Minecraft server administration toolkit designed to automate server lifecycle management, crash monitoring, logging, and web panel integration.

The project is built around a central management script, a crash-monitoring script, supporting configuration modules, and a structured runtime environment for logs, state files, and web-side integration.

It is intended for self-hosted Minecraft infrastructure where servers are managed through shell scripts, `tmux`, `cron`, and `firewalld`.

---

## Features

### `.SERVER-MANAGER.sh`
- Interactive server management menu
- Start, stop, archive, configure, and delete server instances
- Java version switching support
- Server state handling through environment configuration
- Centralized logging of management actions
- Integration with helper scripts stored in `.conf/`

### `.CRASH-MONITOR.sh`
- Automatic crash detection
- Checks whether the server `tmux` session still exists
- Compares recent server CLI output snapshots to detect freezes
- Can be triggered automatically every minute using `cron`
- Includes a ready-to-use cron command inside the script comments

### `.SYSTEM_MANAGER.sh`
- First-run system initialization script
- Installs required packages and dependencies
- Configures `cron` and `firewalld`
- Installs `zsh`, `tmux`, and supporting tools
- Intended to work on first boot in Bash and remain usable later from a Zsh-based environment

---

## Project Structure

Current directory structure:

```bash
.
├── .SYSTEM_MANAGER.sh
├── SERVER
│   ├── .CRASH-MONITOR.sh
│   ├── .SERVER-MANAGER.sh
│   ├── .conf
│   │   ├── add_server.sh
│   │   ├── archive_server.sh
│   │   ├── change_server_state.sh
│   │   ├── config.sh
│   │   ├── configure_server.sh
│   │   ├── delete_server.sh
│   │   ├── help.sh
│   │   ├── java_version_switch.sh
│   │   ├── kill_all_server_sessions.sh
│   │   ├── load_env.sh
│   │   └── log.sh
│   ├── db
│   │   └── database.sql
│   ├── env
│   │   └── server-properties.env
│   ├── logs
│   │   ├── 2026-04-14.log
│   │   └── latest.log
│   ├── new_web_commands_reciver.sh
│   ├── output
│   │   ├── .actual-cli-output.txt
│   │   └── .latest-cli-output.txt
│   ├── server-manager-daemon.sh
│   └── www-server-manager-req.txt
└── SERVERS
```

---

## Directory and File Roles

### Root
- `.SYSTEM_MANAGER.sh` — system initialization and package installation script for first-run setup

### `SERVER/`
- `.SERVER-MANAGER.sh` — main interactive Minecraft server manager
- `.CRASH-MONITOR.sh` — watchdog-style crash monitor designed for cron execution
- `server-manager-daemon.sh` — background service or daemon logic related to server management
- `new_web_commands_reciver.sh` — script used to receive commands from the web management layer
- `www-server-manager-req.txt` — supporting requirements or notes for the web-side server manager logic

### `SERVER/.conf/`
Contains internal helper modules used by `.SERVER-MANAGER.sh`:

- `add_server.sh` — adds a new server definition
- `archive_server.sh` — archives existing servers
- `change_server_state.sh` — changes the active server state
- `config.sh` — shared configuration logic
- `configure_server.sh` — server-specific setup logic
- `delete_server.sh` — removes server definitions or files
- `help.sh` — help and usage output
- `java_version_switch.sh` — switches Java runtime versions
- `kill_all_server_sessions.sh` — stops all active Minecraft-related `tmux` sessions
- `load_env.sh` — loads `.env` or server property values
- `log.sh` — shared logging logic

### `SERVER/db/`
- `database.sql` — SQL file updated with the current server list for the web UI and web-based server management page

### `SERVER/env/`
- `server-properties.env` — stores the currently active server configuration and state

### `SERVER/logs/`
- `latest.log` — current active log file
- `YYYY-MM-DD.log` — archived daily logs
- Log files are written per day
- When a full month passes, older daily logs are packed into ZIP archives named after the corresponding month and year

### `SERVER/output/`
- `.actual-cli-output.txt` — latest captured CLI snapshot from the running Minecraft server
- `.latest-cli-output.txt` — previous CLI snapshot used for comparison
- These files are used to detect whether the server is frozen, crashed, or still actively responding
- They can also be used to avoid shutdown actions when player activity is still detected

### `SERVERS/`
- contains the actual Minecraft server instances, worlds, jars, and runtime server directories

---

## Logging

`.SERVER-MANAGER.sh` logs all significant server-management changes. Log files are stored daily, with `latest.log` representing the current active log and date-based files used as archives for previous days.

At the end of a full month, older daily logs are compressed into ZIP packages named using the corresponding month and year, which helps keep long-term log storage organized and manageable.

---

## Crash Monitor and Cron

`.CRASH-MONITOR.sh` is intended to run automatically once per minute through `cron`. The script includes a ready-to-copy cron command in its own comment header for convenience.

Usage comment inside the script:

```bash
# Usage: Paste: ( crontab -l 2>/dev/null; echo '* * * * * /home/Minecraft/SERVER/.CRASH-MONITOR.sh' ) | crontab -
```

This command appends the crash-monitor job to the current user crontab so it runs every minute.

You can also verify installed cron entries with:

```bash
crontab -l
```

---

## Database Integration

The `SERVER/db/database.sql` file is updated with the list of currently available servers. Its purpose is to provide data for the web UI and web-based server management page.

This allows the shell-side management logic and the web interface to stay synchronized around the known server inventory.

---

## Environment File

Active server data is stored in:

```env
# Server Configuration
SERVER_STATUS=ONLINE
SERVER_TYPE=FORGE
SERVER_NAME=Forge-Server
SERVER_PATH=/home/Minecraft/SERVERS/FORGE/Forge-Server
SERVER_VERSION=1.21.1
SERVER_ID=1
```

This file describes the currently selected server and its runtime state.

### Field meaning
- `SERVER_STATUS` — current server state, such as `ONLINE`, `OFFLINE`, `START`, or `STOP`
- `SERVER_TYPE` — server category, for example `FORGE`, `VANILLA`, or other supported types
- `SERVER_NAME` — display or internal name of the active server
- `SERVER_PATH` — full filesystem path to the server instance
- `SERVER_VERSION` — Minecraft or server software version
- `SERVER_ID` — unique internal identifier used by management logic or web integration

---

## Output Snapshot Logic

The `output/` directory is used by the crash monitor to compare current and previous server console output.

This mechanism helps determine whether:
- the server has crashed
- the server is frozen
- the console is no longer updating
- players may still be online before shutdown or restart logic is triggered

The monitor typically sends a command such as `/list`, captures fresh server log output, and compares it with the previous snapshot. If the output does not change, the script may assume the server is unresponsive and restart it.

---

## First-Run Setup

Use `.SYSTEM_MANAGER.sh` on a fresh machine to install and configure the required system packages and services.

Expected responsibilities:
- install `cron`
- install and configure `firewalld`
- install `zsh`
- install `tmux`
- install helper packages such as `git`, `curl`, and `jq`

This script is designed to run correctly in Bash on first run, while remaining usable later from a terminal environment where Zsh becomes the default shell.

---

## Typical Workflow

1. Run `.SYSTEM_MANAGER.sh` on a fresh system
2. Configure required system packages and firewall rules
3. Manage Minecraft servers through `.SERVER-MANAGER.sh`
4. Add `.CRASH-MONITOR.sh` to `cron`
5. Keep the web UI synchronized through `database.sql`
6. Use logs and output snapshots for diagnostics and recovery

---

## Notes

- The project depends heavily on `tmux` for background server session management
- `cron` is required for automatic crash monitoring
- `firewalld` is used for firewall handling
- The project is structured for Linux-based Minecraft hosting environments
- `new_web_commands_reciver.sh` keeps its current filename for project consistency, even though `receiver` would be the standard spelling
