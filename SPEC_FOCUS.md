# Focus Mode - Full Specification

## 1. General Description
Focus Mode is a shell operating mode designed to minimize distractions, block access to entertainment resources, and utilize the Pomodoro technique for time management.

## 2. Onboarding (First-time Setup)
- Upon the first launch of the mode, display a series of tooltips following the Material 3 design language.
- The tooltips explain the blocking mechanisms, the Pomodoro technique, and how to exit the mode.
- Includes a "Skip" button.

## 3. Focus Mode Settings Window (Qt Window)
- Focus Mode settings open as a **separate native window** (a distinct QML Window managed by Hyprland), rather than an embedded panel.
- The window features the following tabs:
- **Timer:** Configure Pomodoro session duration. 
- **Wallpaper:** Select a specific wallpaper for the mode. 
- **Lists:** Manage blacklists and whitelists. 
- **Profiles:** Access preset or custom profiles. 
- **To-Do List:** Manage tasks. 
- **Exit Condition:** Manual / Timer / Tasks.
- **Important:** This window is inaccessible during an active session and is hidden once the mode is initiated.

## 4. Exit Conditions & UI Lock
1. **Manual:** A **STOP** button is visible; all other UI elements are locked.
2. **Timer-based:** No **STOP** button is present; the mode can only be exited once the timer expires.
3. **Task-based:** No **STOP** button is present; the mode can only be exited once all tasks are completed.
- **UI Lock:** When any Focus Mode is active, access to standard settings and the left sidebar (Sidebar Left) is completely blocked. ## 5. Top Bar (Zen Mode Bar) and Wallpaper
- **Zen Bar:** Hides all widgets except for Desktops, System Icons, and the Clock/Timer.
- **Wallpaper:**
- Uses a dedicated wallpaper for Focus Mode. 
- **Disable Cover Art Mode:** If "track cover art" mode is active, it is automatically disabled when Focus Mode is engaged.

## 6. Visual Changes (Desktop Zen)
- Hides desktop widgets.
- Disables UI blur and animations.

## 7. Built-in Pomodoro Timer
- Configurable timing: focus sessions, short and long breaks, and the number of cycles.
- Automatic phase switching with notifications.
- Restrictions are lifted during break periods.

## 8. To-Do List
- Integrated task list.
- Option to select specific tasks for the current session.
- Tasks are saved in JSON format.

## 9. Focus Tracker & Motivation
- **Statistics:** Tracks time spent and the number of completed tasks.
- **Motivational Phrases (Achievements):** Displays a congratulatory notification upon reaching specific milestones.

## 10. Blocking & Interstitial Page
- **App Blocking:** Monitors processes and provides notifications.
- **Website Blocking:** Redirects traffic via `/etc/hosts` to `127.0.0.1`. A local Python server serves a "Focus Mode" interstitial page.
- **Security:** Includes `/etc/hosts` backup functionality and utilizes `pkexec` for privileged operations. ## 11. Technical Implementation
- QML: UI, animations, timer, onboarding, and a separate settings window (`FocusSettingsWindow.qml`).
- Python backend (`services/focus_manager.py`): Pomodoro logic, lists, hosts, a local server, a statistics tracker, and motivational phrases.