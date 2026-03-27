## Why

The app already uses Codex to create or repair `skills.json`, but it only exposes that flow when categorization is missing, invalid, or incomplete. Users who dislike an otherwise valid classification currently have no app-level way to ask Codex to re-categorize the full library with new guidance.

## What Changes

- Add an explicit re-categorization entry point in the `Global` tab when `skills.json` is already valid and all skills are categorized.
- Allow the user to rerun Codex against the full skill catalog with a custom instruction aimed at changing existing groupings, not only appending missing entries.
- Distinguish between append-only auto-categorization and full re-categorization so the prompt, messaging, and success states match the user’s intent.
- Update documentation and tests to cover the new re-categorization flow.

## Capabilities

### New Capabilities
- `skill-recategorization`: Let users rerun Codex on an already categorized library to revise existing category assignments based on custom guidance.

### Modified Capabilities

## Impact

- Affected UI in `Sources/myAgentSkills/CustomTabViewController.swift`
- Affected Codex prompt construction in `Sources/myAgentSkills/CodexCategorizationService.swift`
- Affected categorization behavior and coverage in `Tests/myAgentSkillsTests/myAgentSkillsTests.swift`
- Affected user documentation in `README.md`
