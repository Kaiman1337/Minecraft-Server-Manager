# SERVER-MANAGER

## Overview

The `SERVER-MANAGER` and `SERVER-HANDLER` scripts are tools designed to simplify the management and monitoring of Minecraft servers. These scripts automate tasks such as starting, stopping, and monitoring server states, ensuring smooth operation with minimal manual intervention.

---

## Features

### `server-manager.sh`
- **Server Management**:
  - Start, stop, and restart Minecraft servers.
  - Add new servers with custom configurations.
  - Manage multiple server types, including:
    - Vanilla servers
    - Plugin-based servers
    - Modded servers
    - Map servers
- **Java Version Switching**:
  - Easily switch between Java versions (e.g., Java 8, 17, 21) to match server requirements.
- **Session Management**:
  - Kill all active `tmux` sessions related to Minecraft servers.
- **Interactive Menu**:
  - User-friendly menu for managing servers and configurations.

### `server-handler.sh`
- **Server State Monitoring**:
  - Automatically detects server states (e.g., online, offline, crashed).
  - Restarts servers if they crash or become unresponsive.
- **WATCHDOG Integration**:
  - Monitors server activity and ensures the server remains operational.
- **Log Management**:
  - Generates detailed logs for server activity, including session states and server restarts.
- **Active Session Detection**:
  - Lists all active `tmux` sessions for better visibility.

---

## How It Works

### `server-manager.sh`
1. **Interactive Menu**:
   - Provides an easy-to-use interface for managing servers.
   - Allows users to start, stop, or add servers with minimal effort.

2. **Server Configuration**:
   - Automatically generates configuration files for new servers.
   - Supports custom server paths, Java versions, and server IDs.

3. **Session Management**:
   - Uses `tmux` to manage server sessions, ensuring servers run in the background.

### `server-handler.sh`
1. **State Detection**:
   - Continuously monitors server logs and `tmux` sessions to detect crashes or unresponsiveness.

2. **Automatic Recovery**:
   - Restarts servers if they crash or stop responding.
   - Ensures the `WATCHDOG` session is always running.

3. **Logging**:
   - Logs all server activities, including session states, restarts, and errors, for easy debugging.

---

## Usage

### Running `server-manager.sh`
1. Navigate to the script directory:
   ```bash
   cd /home/Minecraft/SERVER