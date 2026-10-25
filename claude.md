# Project: hi-shell (Custom Hyprland Desktop Shell)

## Tech Stack
- **Shell UI:** Quickshell (QML, Wayland)
- **Backend / AI Bridge:** Python 3 (using `qml` Python bindings or subprocess for Claude CLI)
- **Design:** Material You (Material 3) via Quickshell's theming or QML Material components.
- **OS:** Arch Linux + Hyprland (Wayland)

## Core Features
1. **Top Bar:** Workspaces (Hyprland), active window title, clock, system tray (volume, battery, network), system stats (CPU/RAM).
2. **App Launcher:** Material 3 search bar to launch apps.
3. **Claude AI Widget:** A popup "Command Palette" (like Spotlight) where I can type a prompt. It sends the prompt to `claude` CLI in the background and shows the output in a Material 3 card.
4. **Control Center:** Quick toggles for Wi-Fi, Bluetooth, Dark/Light mode, and volume slider.
5. **Theming:** Use Matugen (or similar) to generate Material 3 colors from the current wallpaper.

## Rules
1. **Modular QML:** Do not write everything in one file. Separate Bar, Launcher, AIWidget, and ControlCenter into different QML files.
2. **Claude Integration:** Use `Quickshell.Io.Process` or `Quickshell.Io.Socket` to run the `claude` CLI. Ensure it doesn't block the UI thread.
3. **Hyprland IPC:** Use Quickshell's built-in Hyprland module for workspaces and window titles.
4. **Python Backend:** If Quickshell's QML cannot handle the Claude CLI streaming properly, create a Python daemon (`ai_bridge.py`) that runs `claude` and streams the output to QML via a Unix socket.
5. **Git Workflow:** Commit and push after every stage.

## Structure
- `shell.qml` (Main entry point for hi-shell)
- `modules/Bar.qml`
- `modules/Launcher.qml`
- `modules/AIWidget.qml`
- `modules/ControlCenter.qml`
- `services/` (Python scripts, theme generators)
- `README.md`
