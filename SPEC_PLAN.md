# Development Plan: Focus Mode (Stage-by-Stage)

## Stage 1: Settings (Qt Window) and Profile Logic
- [x] Create a separate native Qt window (`FocusSettingsWindow.qml`) for settings.
- [x] Implement tabs: Timer, Wallpaper, Lists, Profiles, To-Do, and Exit Conditions.
- [x] Create a JSON file (`~/.config/hi-shell/focus_profiles.json`) to store profiles (Study, Work, Custom) and settings.
- [x] Implement profile selection logic (loading specific settings when a profile is selected).
- [x] **Verification:** The window opens, and settings persist after a restart.

## Stage 2: UI Mode (Zen Mode) and Interface Locking
- [x] Implement locking for the left panel and standard settings when a session begins.
- [x] Hide all widgets on the top panel, except for Workspaces, System Icons, and the Clock/Timer.
- [x] Disable desktop widgets; remove blur effects and animations.
- [x] Implement wallpaper switching (and disable the "Now Playing" track cover art display).
- [x] **Verification:** The interface becomes "minimalist" upon activation; the original state can only be restored after exiting the mode.

## Stage 3: Pomodoro Timer and Exit Conditions
- [x] Implement Pomodoro logic (cycles of Focus -> Break).
- [x] Implement three exit conditions: Manual (STOP button), Timer-based (timer only), and Task-based (tasks only).
- [x] Hide the STOP button if the Timer or Tasks mode is selected.
- [x] **Verification:** The timer functions correctly; the STOP button appears only in Manual mode. ## Stage 4: App Blocking and To-Do List
- [x] Implement a To-Do list (adding, deleting, marking tasks as complete, and selecting tasks for a session).
- [x] Implement app blocking (for apps on a blacklist) by monitoring processes or using Hyprland.
- [x] Display a Material 3-style notification when an attempt is made to launch a blocked application.
- [x] Link "task-based exit" to the To-Do list (i.e., exit the session once all selected tasks are completed).
- [x] **Verification:** Blocked apps fail to launch, tasks can be marked as complete, and the session ends automatically upon task completion.

## Stage 5: Network Blocking and Interstitial Page
- [x] Create a Python script to modify `/etc/hosts` (including a backup feature and execution via `pkexec`).
- [x] Develop a local Python server that serves a Material 3-styled "Focus Mode" HTML page.
- [x] Integrate the selected profile with the generation of a list of blocked websites.
- [x] **Verification:** Accessing a blocked website (e.g., YouTube) redirects to a well-designed interstitial page featuring a timer.

## Stage 6: Tracker, Motivation, and Onboarding
- [x] Implement a statistics tracker (tracking focus time and completed tasks) with data saved to an SQLite database or JSON file.
- [x] Add an achievement system (displaying motivational messages upon reaching milestones, such as >3 hours of focus or >9 completed tasks).
- [x] Implement an onboarding flow (a tutorial shown on the first launch, with a "Skip" option).
- [x] **Verification:** Statistics update after each session, motivational messages appear when milestones are reached, and the tutorial is displayed only once.
