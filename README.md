# myAgentSkills

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="myAgentSkills icon">
</p>

<p align="center">
  <strong>Native macOS wrapper for the <code>skills.sh</code> CLI</strong><br>
  Search the official catalog, inspect installed skills, and keep a separate custom local skills browser in one menu bar companion.
</p>

## What It Does

- `Official` tab:
  - Search official skills through `npx skills find`
  - Open a guided native install flow for GitHub shorthands, URLs, local paths, or search results
- `Installed` tab:
  - Browse locally resolved official installs
  - Run `npx skills check`
  - Run `npx skills update`
- `Custom` tab:
  - Browse `~/.agents/skills`
  - Search by skill name and description
  - Copy the skill name or open the file/folder

## Why It Exists

The CLI is powerful, but discovering and installing skills is still faster when you can:

1. keep a live browser in your menu bar,
2. search without remembering command syntax,
3. inspect command output when something goes wrong,
4. keep your own custom local skills visible without mixing them into the official flow.

## Architecture

- `AppDelegate`:
  - status item
  - popover lifecycle
- `PopoverViewController`:
  - tab container
- `SkillsCLIService`:
  - runs `npx skills ...`
  - captures stdout/stderr
  - resolves `npx` for Finder-launched apps
- `InstalledSkillsCatalogService`:
  - resolves common skills directories for official installs
- `CustomSkillsCatalogService`:
  - reads `~/.agents/skills`
- `InstallWizardWindowController`:
  - source selection
  - optional source skill listing
  - scope + agent selection
  - final command preview and execution

## Build

```bash
swift build
swift test
./build-app.sh
```

The built app bundle will be:

```bash
myAgentSkills.app
```

## Notes

- The app treats `skills.sh` as the source of truth for official discovery and install/update behavior.
- The custom tab is intentionally read-only in v1.
- The repo currently depends on a working local Swift/Xcode toolchain; if your Command Line Tools and SDK versions are mismatched, `swift build` may fail until they are aligned.
