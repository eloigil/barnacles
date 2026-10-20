# Contributing

Thanks for helping out! Barnacles is a small, temporary workaround: it will be
discontinued once Orca supports multiple windows itself. So the bar for new features
is "does this make running several Orcas easier today?" Bug fixes, polish and clearer
wording are always welcome.

For anything bigger than a small fix, please open an issue first so we can agree on
the approach.

## What's where

| Path | What it is |
|------|------------|
| `app/` | The Mac app, a SwiftUI package (macOS 14+) |
| `app/Sources/Barnacles/Orca.swift` | Finding, starting and inspecting Orca |
| `app/Sources/Barnacles/Store.swift` | Barnacles on disk (`~/.barnacles`), create, delete, copy settings |
| `app/Sources/Barnacles/Launcher.swift` | The "Orca \<name\>.app" launchers in `~/Applications/Barnacles` |
| `app/Sources/Barnacles/Views.swift` | The window |
| `app/Sources/Barnacles/BarnaclesApp.swift` | App entry point, menus, Dock menu |
| `app/scripts/` | `build-app.sh` builds the app, `make-dmg.sh` builds the DMG |
| `barnacles` | The command-line tool (bash 3.2, the version macOS ships) |
| `install.sh` | The one-line installer |
| `docs/` | The landing page, served by GitHub Pages |

## Building

You only need the Xcode Command Line Tools (`xcode-select --install`), not full Xcode.

```bash
app/scripts/build-app.sh
```

This creates `app/build/Barnacles.app`, a universal app (Apple silicon and Intel).
For a quicker build while you work, run `swift build` in `app/`.

## Trying your changes without touching your own barnacles

The app always uses the `.barnacles` folder in your home folder. To run your build
against a throwaway folder instead, point it at a fake home:

```bash
mkdir -p /tmp/bhome/.barnacles
open -n --env CFFIXED_USER_HOME=/tmp/bhome app/build/Barnacles.app
```

Keep that path short: Orca puts Unix sockets inside each barnacle's folder, and macOS
limits socket paths to 103 characters.

The command-line tool reads `BARNACLES_HOME`, `BARNACLES_APPS_DIR` and
`BARNACLES_ORCA_APP` instead:

```bash
BARNACLES_HOME=/tmp/bdata BARNACLES_APPS_DIR=/tmp/bapps ./barnacles new test
```

## Before you open a pull request

- The app builds with `app/scripts/build-app.sh`, with no new warnings.
- You tried the change by hand. There are no automated tests yet, so say in the pull
  request what you checked.
- For the command-line tool, `bash -n barnacles` passes and nothing needs bash 4.
- Code reads like the code around it. Keep comments short and only where the "why"
  isn't obvious.
- Text people see (buttons, alerts, the landing page) is plain and friendly, without
  jargon. Say "barnacle" for an instance, and name things the way macOS does.
- If the change affects how people use Barnacles, update `README.md` (and `docs/` if it
  shows up there).

To preview the landing page, serve `docs/` with any static server:

```bash
python3 -m http.server 4173 --directory docs
```

## Releases

Maintainers release by pushing a version tag, for example
`git tag v0.2-alpha && git push origin v0.2-alpha`. The Release workflow builds the
DMG and publishes it on GitHub. The download button and `install.sh` always fetch
the latest release.
