# Adderall

A tiny macOS menu bar app that toggles `sudo pmset -a disablesleep` with one click.

- **Click the icon**: toggle sleep disabled ⇄ allowed
- **Launch the `.app` again**: open the settings window (handled via app reopen)
- The icon reflects the state (💊 filled pill = staying awake / 💊 hollow pill = sleep allowed)
- Lives only in the menu bar; no Dock icon (it appears in the Dock only while settings are open)

## Settings

While Adderall is running in the menu bar, launching the `.app` again opens the settings window:

- **Launch at login** — register/unregister a login item via `SMAppService`
- **Also prevent display sleep** — while active, keeps the display awake with `caffeinate -d` (no root, fully reversible)
- **Passwordless execution status** — shown as ✓/✗; if not set up, the "Set up" button installs it via a single admin prompt
- **Quit Adderall** — quit button (there is no menu, so quit from here)

## Setup

### 1. Allow passwordless execution (first run only)

`disablesleep` requires root, so only that specific command is made password-free via sudoers.
Use the settings window's "Set up" button, or run it in a terminal:

```sh
./scripts/install-sudoers.sh
```

This installs `/etc/sudoers.d/adderall-disablesleep` with only these lines (no other pmset operations are allowed):

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
```

To remove it: `sudo rm /etc/sudoers.d/adderall-disablesleep`.

### 2. Build and run

```sh
./scripts/build-app.sh
open Adderall.app
```

> Launch with `open`, not by running the executable directly — a directly launched binary may not register in the menu bar.

## Releases / downloads

Publishing a GitHub Release triggers `.github/workflows/release.yml`, which builds `Adderall.app`
and attaches a DMG (`Adderall-<tag>.dmg`) containing an `/Applications` symlink for drag-to-install.
Open the DMG and drag Adderall into Applications.

Example release flow:

```sh
gh release create v0.1.0 --generate-notes
# after publishing, Actions builds the DMG and attaches it to the release
```

> On push / PR, `build.yml` only verifies the build and uploads `Adderall.zip` as a workflow artifact.

Builds are **ad-hoc signed** (not notarized), so Gatekeeper warns on first launch. To bypass:

- In Finder, right-click `Adderall.app` → "Open", or
- `xattr -dr com.apple.quarantine /Applications/Adderall.app`

## How it works

- State is read from the `SleepDisabled` line of `pmset -g` (no root)
- Toggling runs `sudo -n /usr/bin/pmset -a disablesleep {0,1}` (assumes passwordless setup; shows a prompt if missing)
- Passwordless availability is detected with `sudo -k -n …`, which ignores any cached sudo timestamp so it reflects only the sudoers rule
- Display sleep is controlled by starting/stopping a `caffeinate -d` process
- State is re-read every 5 seconds, so changes made elsewhere (e.g. a terminal) are picked up

## Development

```sh
swift build          # debug build
./scripts/build-app.sh && open Adderall.app
```
