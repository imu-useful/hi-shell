# Implementation Plan: HyprShell AI

## Stage 1: Basic Quickshell Setup & Top Bar
- [x] Create `shell.qml` with a top bar (PanelWindow).
- [x] Implement Workspaces indicator (using Quickshell.Hyprland).
- [x] Add Clock and active window title.
- [x] Test that it runs: `qs -c hi-shell`

## Stage 2: App Launcher
- [ ] Create a floating Window for the App Launcher.
- [ ] Bind a keybind (e.g., Super+D) to toggle the launcher.
- [ ] Implement a search field that filters installed desktop applications (parse `/usr/share/applications`).
- [ ] Add Material 3 styling (rounded corners, blur background).

## Stage 3: Claude AI Command Palette (The Core Feature)
- [ ] Create a floating Window for the AI widget (triggered by Super+A).
- [ ] Add a text input and a "Send" button.
- [ ] Use Quickshell's Process module to run `claude --print "USER_PROMPT"` and capture the output.
- [ ] Display the output in a scrollable Material 3 card.
- [ ] Implement a loading state (spinner) while Claude is thinking.

## Stage 4: Control Center & System Stats
- [ ] Create a slide-out panel for the Control Center.
- [ ] Add volume slider (using `pactl` or Pipewire).
- [ ] Add Wi-Fi/Bluetooth toggles (using `nmcli` and `bluetoothctl`).
- [ ] Add CPU/RAM usage bars (using `psutil` or `/proc/stat`).

## Stage 5: Material 3 Theming (Matugen)
- [ ] Write a Python script (`theme_updater.py`) that runs `matugen` to generate a `Colors.qml` file from the wallpaper.
- [ ] Connect this script to Hyprland's wallpaper change event.
- [ ] Ensure all UI components use the dynamic colors.

## Stage 6: Build, Test, and README
- [ ] Ensure the shell starts correctly on boot (add to Hyprland config).
- [ ] Write a comprehensive `README.md` with installation instructions (dependencies: `quickshell`, `matugen`, `python`).
- [ ] Push final code to GitHub.
