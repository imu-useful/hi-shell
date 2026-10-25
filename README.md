# hi-shell

A Quickshell-based desktop shell for Hyprland with Material 3 design and a built-in Claude AI palette.

> Full installation instructions are coming in Stage 6.

## Google Calendar

Click the clock in the bar to open the calendar popup (month view + upcoming events).
hi-shell reads your calendars through the Google Calendar API (read-only). You need your own OAuth client once:

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project (e.g. `hi-shell`).
2. **APIs & Services → Library** → search **Google Calendar API** → **Enable**.
3. **Google Auth Platform → Branding**: set an app name and your email (user type **External**).
4. **Audience**: add your Google account under **Test users**.
5. **Clients → Create client** → application type **Desktop app** → create, then **Download JSON**.
6. Save the file as `~/.config/hi-shell/google-client.json`.
7. Click the clock → **Connect Google Calendar** (or run `python3 services/gcal.py auth`) and allow access in the browser.

The token is stored in `~/.local/state/hi-shell/google-token.json` (mode 600). Sign out with `python3 services/gcal.py logout`.

**Weekly re-sign-in:** while the app's publishing status is *Testing*, Google expires the sign-in after 7 days and the popup asks you to reconnect.
To avoid that, click **Publish app** under **Audience**. Google then shows an "unverified app" warning on sign-in
(it's your own app; choose *Advanced → Go to hi-shell*).

Try the UI without a Google account: `HI_SHELL_GCAL_DEMO=1 qs -c hi-shell`.
