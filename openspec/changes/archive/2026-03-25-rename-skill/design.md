## Context

The `Global` tab already treats local skills as manageable filesystem-backed items. Users can open a skill, enable or disable it, and move it to Trash, but there is no supported rename flow. The original idea was to rename the underlying folder, but the real installation state is also tracked by the Vercel `skills` CLI in `~/.agents/.skill-lock.json`. That makes true folder renames risky because the app would be mutating identity that another tool depends on for updates.

The app already has an intermediate metadata layer in `~/.agents/skills/skills.json`. Each `skills[]` entry includes both:

- `folder`: the real local skill identity
- `name`: an app-managed display name field

Today the app matches by `folder`, but it does not use `name` for display. That creates a safer rename path: treat rename as a display alias stored in `skills.json`, while leaving the real folder and lock file untouched.

This change touches multiple layers:

- `CustomTabViewController` needs a new rename affordance and user input flow.
- `CustomSkillsCatalogService` needs a rename mutation that validates input and rewrites app metadata safely.
- `skills.json` handling must support display aliases without changing folder mappings.
- Skill loading must prefer the alias in `skills.json` over `SKILL.md` frontmatter or folder fallback.
- The card UI must continue to expose the original skill name separately from the alias so users can copy or reference the real identifier when talking to an agent.
- The feature must avoid mutating `~/.agents/.skill-lock.json` and local skill folders.

## Goals / Non-Goals

**Goals:**

- Let users rename any local skill shown in the `Global` tab.
- Support both active and disabled skills.
- Prevent destructive or confusing renames by validating empty names and invalid display aliases before mutating app metadata.
- Keep the post-rename UI consistent by updating the display alias in `skills.json` and using it as the preferred rendered title.
- Keep the original skill name visible in the card UI so the alias never hides the real skill identifier.
- Refresh the catalog cleanly after rename so search, category filters, and disabled state continue to work.
- Preserve compatibility with `npx skills update` by leaving real skill folder identity and `~/.agents/.skill-lock.json` unchanged.

**Non-Goals:**

- Renaming skills in external agent folders such as `~/.codex/skills` or `~/.claude/skills`.
- Bulk rename operations.
- Rewriting `SKILL.md` files or local skill folders.
- Rewriting `~/.agents/.skill-lock.json`.
- Introducing a new persistent database or identity layer for skills.

## Decisions

### Use `skills.json` aliasing instead of folder rename

The app should treat rename as a user-facing alias, not as a filesystem mutation. The `folder` field in `skills.json` remains the durable identity for matching the installed skill, while the `name` field becomes the app-managed display alias shown in the UI.

Alternative considered:

- Rename the underlying folder. Rejected because it risks desynchronizing `~/.agents/.skill-lock.json` and breaking the Vercel `skills` CLI update flow.

### Keep lock-file-managed identity read-only

The app should not rewrite `~/.agents/.skill-lock.json` as part of this feature. That file belongs to the `skills` CLI contract, and the safest DX is to avoid touching it entirely by keeping folder identity unchanged.

Alternative considered:

- Rewrite the lock entry to preserve folder renames. Rejected because the exact long-term CLI contract is outside the app’s control and the cost of getting it wrong is high.

### Prefer `skills.json` display name over `SKILL.md` frontmatter

The app should render the skill title using this precedence:

1. `skills.json` entry `name`
2. `SKILL.md` frontmatter `name`
3. folder name

This lets the app present a user-controlled alias without changing the underlying installed skill.

The app should also render the original skill identifier separately on the card, even when an alias exists. In practice that original identifier should come from the pre-alias display source, so users still see the name they would use outside the app.

Alternative considered:

- Keep using only `SKILL.md` frontmatter or folder fallback. Rejected because it misses the existing middleware layer already intended to hold app-managed metadata.

### Rewrite only the matching `skills.json` entry

Because categorization is matched by `folder`, the rename mutation should find the matching `skills.json` entry by `folder` and update only its `name`. The `folder`, `scope`, `tags`, and other metadata remain unchanged.

Alternative considered:

- Duplicate the entry or create parallel alias records. Rejected because it would complicate matching and make debugging harder.

### Keep the UX lightweight and local to the card action flow

The `Global` tab already uses small, direct actions per skill card. Rename should follow that pattern with a focused prompt or sheet initiated from each card, rather than a larger management screen.

Alternative considered:

- Dedicated skill editor UI. Rejected because it is more surface area than the current need justifies.

## Risks / Trade-offs

- `skills.json` may be missing or invalid -> Mitigation: block rename when the app-managed metadata file is unavailable for safe alias persistence, and explain why.
- Existing UI and search may assume `name` comes from `SKILL.md` or folder fallback -> Mitigation: centralize display-name precedence in catalog loading and test all search/filter paths.
- Aliases could confuse users about the real skill identifier -> Mitigation: always show the original name on the card and keep copy or reference actions tied to the real skill identity where appropriate.
- Some users may expect rename to change the real folder name -> Mitigation: message the feature clearly as an app label or display name, not as an on-disk rename.

## Migration Plan

No filesystem migration is required before release. Existing skills remain unchanged until a user explicitly renames one through the app, and that rename only updates `skills.json`.

Rollout can ship as a standard app update. If the rename action needs to be rolled back later, the UI affordance can be removed without changing existing skill data beyond the user-initiated aliases already performed.

## Open Questions

- Should the app offer a “reset to original name” action that clears the alias from `skills.json` and falls back to `SKILL.md` or folder name?
- If `skills.json` is missing, should the app eventually offer to create a minimal file automatically, or keep rename dependent on existing valid app metadata?
