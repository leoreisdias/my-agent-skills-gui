## Why

AI Skills Companion lets users browse, disable, restore, and trash local skills, but it does not let them rename how a skill appears in the app when the visible label no longer fits. A true on-disk folder rename is risky because the Vercel `skills` CLI tracks installed skills in `~/.agents/.skill-lock.json`, and changing real folder identity could break `npx skills update`.

## What Changes

- Add a rename action for local skills shown in the `Global` tab.
- Let users rename both active and disabled local skills without leaving the app.
- Treat rename as an app-level display alias stored in `~/.agents/skills/skills.json`, not as a filesystem folder rename.
- Update the app to prefer the `skills.json` entry `name` field as the displayed skill title, with existing metadata or folder-name fallbacks when no alias exists.
- Always keep the original skill name visible somewhere on the card so users can still reference the real skill when asking an agent to use it.
- Preserve the real installed skill identity, including skill folders and `~/.agents/.skill-lock.json`, so the `skills` CLI update flow keeps working.
- Show clear success and error messaging for rename outcomes, including invalid input and missing or unreadable app metadata.

## Capabilities

### New Capabilities
- `skill-rename`: Rename a local skill in the app by assigning a display alias in `skills.json` while keeping the real installed skill identity unchanged.

### Modified Capabilities
- None.

## Impact

- Affected code: local custom skill catalog loading and mutation logic, the `Global` tab UI, and app-managed skill metadata handling.
- Affected files are likely under `Sources/myAgentSkills/CustomTabViewController.swift`, `Sources/myAgentSkills/CatalogServices.swift`, and model or utility types related to skill records and mutation errors.
- Affected data: `~/.agents/skills/skills.json` and read-only awareness of `~/.agents/.skill-lock.json`.
