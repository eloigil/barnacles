# Barnacles

Run several [Orca](https://github.com/stablyai/orca) instances side by side on macOS.

Orca allows only one running instance per profile (its data folder). Barnacles gives each
instance its own profile and starts Orca with `--user-data-dir`, so instances don't
block each other. Your normal Orca keeps running as usual.

## The app

Open **Barnacles**, click **New Barnacle**, give it a name and a color, and it opens as a
new Orca window. Pick a barnacle in the sidebar to open, show or quit it, copy your Orca
settings into it again, or delete it (its data goes to the Trash; your code is never touched).

For a quick extra window, right-click Barnacles in the Dock and choose **New Orca Window**
(or press ⇧⌘N). It creates "Window 2", "Window 3"… with your Orca settings and opens it
right away; rename it later from its page. The same Dock menu lists your barnacles to open.
Barnacles keeps running after you close its window so this menu stays available; choose
Options > Keep in Dock to keep it there.

Each barnacle also gets a launcher app with Orca's icon and a colored badge in
`~/Applications/Barnacles`, so you can open it from Spotlight ("Orca Work") or keep it
in the Dock.

Build it with the Xcode Command Line Tools (full Xcode isn't needed):

```bash
app/scripts/build-app.sh
```

This creates `app/build/Barnacles.app`; drag it into Applications. It's signed only for
your own Mac. Sharing it with others needs an Apple Developer ID signature and
notarization.

## Command line

The `barnacles` script does the same from Terminal and uses the same `~/.barnacles` folder.

### Install

```bash
ln -s "$PWD/barnacles" ~/.local/bin/barnacles
```

Any folder on your `PATH` works.

### Use

```bash
barnacles new work          # creates the instance and ~/Applications/Barnacles/Orca work.app,
                            # copying settings from your main Orca
barnacles open work         # starts it, or focuses it if it's already running
barnacles list              # shows instances and whether they're running
barnacles rm work           # deletes the launcher and the instance's data (asks first)
barnacles rm work --keep-data
barnacles app work          # recreates a launcher you deleted
barnacles sync work         # copies your main Orca's settings into "work" again (quit it first)
```

Each launcher app shows up in Spotlight ("Orca work") and can be dragged to the Dock.

## Settings

New instances copy their settings from your main Orca (in the app, "Use the same settings
as my Orca" is on by default): preferences, theme, fonts,
agents and model settings, plus Orca's onboarding (so it isn't shown again).
Projects, workspaces and terminal sessions are never copied; each instance has its own.

- `barnacles new work --from other` copies from another instance instead.
- `barnacles new work --blank` starts with Orca's defaults.
- `barnacles sync work [--from other]` copies settings again later. The previous file is
  saved as `orca-data.json.barnacles-bak`.

This is a copy, not live syncing. Each running Orca keeps its settings in memory and saves
them back, so two instances sharing one settings file would overwrite each other's changes.

GitHub (through the `gh` CLI) and agent sign-ins in `~/.claude` and `~/.codex` live
outside Orca's profile, so every instance shares them automatically.

## Good to know

- **Each instance has its own projects and sessions.** Settings are copied in when the
  instance is created (see above).
- **Some things are shared.** Folders in your home directory such as `~/.orca`
  (for example Linear tokens), `~/.claude` and `~/.codex` are shared by all instances.
  Orca's agent hooks there are built to handle more than one instance.
- **Every running instance has the Orca icon in the Dock.** The launcher app quits right
  after starting Orca, so you can't tell instances apart by their Dock icons.
- **Data lives in** `~/.barnacles/<folder>`, with names and colors from the app in
  `~/.barnacles/barnacles.json`. The path is kept short on purpose: Orca puts
  Unix sockets in that folder, and macOS caps socket paths at 103 characters. Barnacles
  refuses to create or open an instance whose path is too long.
- Set `BARNACLES_HOME`, `BARNACLES_APPS_DIR` or `BARNACLES_ORCA_APP` to change
  where data, launchers or Orca are found.
