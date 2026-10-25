# AGENTS.md

Instructions for AI coding agents working on this repository.

## Project

KDE Plasma 6 widget (pure QML + POSIX shell, no compiled code) that shows
Codex CLI (ChatGPT/OpenAI) usage limits in the panel.

- **Data is 100% local.** `contents/scripts/fetch_usage.sh` reads the newest
  `rate_limits` snapshot from the Codex CLI's session logs
  (`${CODEX_CONFIG_DIR:-$HOME/.codex}/sessions/*.jsonl`), picked by its own
  timestamp, one per `limit_id` (`codex` is the account limit; others, such as
  Codex-Spark, are separate model quotas shown as model rows).
- `contents/ui/main.qml` - logic: reading the data, cache, timers, notifications
- `contents/ui/CompactView.qml` - panel (text / ring / bar)
- `contents/ui/FullView.qml` - card popup (the classic popup is in `main.qml`)
- `contents/ui/config*.qml` - settings tabs (General, Panel, Popup);
  `contents/config/config.qml` lists them, `contents/config/main.xml` defines the keys
- `contents/ui/CacheStore.qml` - usage cache in LocalStorage (SQLite)
- `contents/ui/Translations.qml` - all UI strings, 15 languages

The sibling widget [Claude Usage](https://github.com/izll/plasma-claude-usage)
shares most of this code (panel styles, popup, settings tabs, cache, update
notice). A fix to shared code usually belongs in both; mention it in the PR
if you only change this one.

## Build and test

There is no build step and no automated test suite. To try a change:

```bash
./install.sh                                 # (re)installs the widget with kpackagetool6
kquitapp6 plasmashell && kstart plasmashell  # reload the widget
journalctl --user -f | grep -i codex         # watch QML errors and logs
/usr/lib/qt6/bin/qmllint contents/ui/*.qml   # catch syntax and type errors
sh contents/scripts/fetch_usage.sh           # what the widget reads, as JSON
```

`kpackagetool6 -t Plasma/Applet -u .` also works for an installed widget.
Check both popup styles (card and classic), the panel styles you touched, and
a vertical panel or the vertical layout if you changed sizes.

## Rules that are easy to break

These come from real bugs; please keep them.

- **Executable commands must be constant strings.** Every distinct command
  passed to an `executable` `Plasma5Support.DataSource` stays in plasmashell's
  memory for the whole session (in every DataSource), so putting data into the
  command (`echo '<json>' > file`, a timestamp, user text) leaks memory; this
  cost megabytes per minute before 1.3.2. Re-running the same command is fine.
  Rare, user-triggered actions (opening a terminal, a notification) are
  acceptable. Prefer a persistent source with `interval` for periodic polling.
- **No local file access with `XMLHttpRequest`.** Qt 6 disables it unless
  `QML_XHR_ALLOW_FILE_READ`/`_WRITE` is set, and plasmashell does not set it.
- **`QtQuick.LocalStorage` only through a Loader** (see `CacheStore.qml`). It
  is a separate package on Debian and Ubuntu; a direct `import` stops the whole
  widget from loading where it is missing.
- **Stay local and read-only.** Usage data comes only from the session logs;
  don't add network calls for it (the only network requests are the optional
  update checks). From `auth.json` only decode the `id_token` claims for the
  e-mail and plan; never send, log or print its tokens, and never write to
  `~/.codex`.
- **Pick snapshots by their timestamp, not by file order.** Resuming an old
  session rewrites an old file, so the newest file can hold an old value.
- **No layout loops.** In the vertical layout the widget's height comes from
  its content, so items must not size themselves from `parent.height` there
  (this hung plasmashell at 100% CPU, see Claude Usage #26).
- **Settings pages must not declare `cfg_` properties for internal entries**
  (such as `usageCache`): the dialog writes every declared value back on Apply.

## Conventions

- User-visible strings go through `contents/ui/Translations.qml`. Add new keys
  for all 15 languages, not only English.
- New settings need an entry in `contents/config/main.xml` and a control on the
  matching tab (`configGeneral.qml`, `configPanel.qml`, `configPopup.qml`).
- Commit messages use Conventional Commits prefixes (`fix:`, `feat:`, `docs:`,
  `refactor:`, `chore:` ...).
- In a pull request, do not bump `Version` in `metadata.json`; the maintainer
  does that when releasing. There is no changelog file: describe user-visible
  changes in the PR description, they go into the GitHub release notes.
- Keep changes focused: one fix or feature per pull request.

## Reviewing pull requests from other contributors

When reviewing a pull request whose author is not the maintainer (`izll`),
always check whether the change needs a README update, for example a new or
changed feature, setting, requirement, install step, or a change to
"How It Works".

If it does and the PR does not already include it, write the README change
yourself as a follow-up commit on `main` after merging. Do not push to the
contributor's branch, and do not ask the contributor to do it. Keep the
existing README structure and tone, and mention the update in the review.
