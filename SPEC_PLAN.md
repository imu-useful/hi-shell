# Development Plan: Focus Mode (Stage-by-Stage)

## Stage 1: Settings (Qt Window) and Profile Logic
- [ ] Create a separate native Qt window (`FocusSettingsWindow.qml`) for settings.
- [ ] Implement tabs: Timer, Wallpaper, Lists, Profiles, To-Do, and Exit Conditions.
- [ ] Create a JSON file (`~/.config/hi-shell/focus_profiles.json`) to store profiles (Study, Work, Custom) and settings.
- [ ] Implement profile selection logic (loading specific settings when a profile is selected).
- [ ] **Verification:** The window opens, and settings persist after a restart.

## Stage 2: UI Mode (Zen Mode) and Interface Locking
- [ ] Implement locking for the left panel and standard settings when a session begins.
- [ ] Hide all widgets on the top panel, except for Workspaces, System Icons, and the Clock/Timer.
- [ ] Disable desktop widgets; remove blur effects and animations.
- [ ] Implement wallpaper switching (and disable the "Now Playing" track cover art display).
- [ ] **Verification:** The interface becomes "minimalist" upon activation; the original state can only be restored after exiting the mode.

## Stage 3: Pomodoro Timer and Exit Conditions
- [ ] Implement Pomodoro logic (cycles of Focus -> Break).
- [ ] Implement three exit conditions: Manual (STOP button), Timer-based (timer only), and Task-based (tasks only).
- [ ] Hide the STOP button if the Timer or Tasks mode is selected.
- [ ] **Verification:** The timer functions correctly; the STOP button appears only in Manual mode. ## Stage 4: App Blocking and To-Do List
- [ ] Implement a To-Do list (adding, deleting, marking tasks as complete, and selecting tasks for a session).
- [ ] Implement app blocking (for apps on a blacklist) by monitoring processes or using Hyprland.
- [ ] Display a Material 3-style notification when an attempt is made to launch a blocked application.
- [ ] Link "task-based exit" to the To-Do list (i.e., exit the session once all selected tasks are completed).
- [ ] **Verification:** Blocked apps fail to launch, tasks can be marked as complete, and the session ends automatically upon task completion.

## Stage 5: Network Blocking and Interstitial Page
- [ ] Create a Python script to modify `/etc/hosts` (including a backup feature and execution via `pkexec`).
- [ ] Develop a local Python server that serves a Material 3-styled "Focus Mode" HTML page.
- [ ] Integrate the selected profile with the generation of a list of blocked websites.
- [ ] **Verification:** Accessing a blocked website (e.g., YouTube) redirects to a well-designed interstitial page featuring a timer.

## Stage 6: Tracker, Motivation, and Onboarding
- [ ] Implement a statistics tracker (tracking focus time and completed tasks) with data saved to an SQLite database or JSON file.
- [ ] Add an achievement system (displaying motivational messages upon reaching milestones, such as >3 hours of focus or >9 completed tasks).
- [ ] Implement an onboarding flow (a tutorial shown on the first launch, with a "Skip" option).
- [ ] **Verification:** Statistics update after each session, motivational messages appear when milestones are reached, and the tutorial is displayed only once.
