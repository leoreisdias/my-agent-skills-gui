## Context

`AI Skills Companion` already wraps a Codex-powered categorization flow in the `Global` tab. Today that flow is surfaced only when `skills.json` is missing, invalid, or still leaves some skills uncategorized. The underlying service also biases the prompt toward preserving existing mappings and appending only missing skills, which is correct for bootstrap and repair runs but not for users who want to revise an already complete classification.

This change needs to span both the UI and the prompt builder. The UI must expose a safe, understandable rerun action even when categorization is healthy. The Codex prompt must reflect the user’s intent so a re-categorization run can reconsider current assignments instead of treating them as fixed.

## Goals / Non-Goals

**Goals:**
- Let users start a re-categorization run from the `Global` tab even when `skills.json` is valid and no skills are uncategorized.
- Preserve the existing guided confirmation flow, streamed output, and optional custom instruction field.
- Teach the prompt builder to support a distinct re-categorization mode that allows revising existing mappings while still preserving JSON validity and schema shape.
- Keep the behavior legible in the UI so users can tell whether Codex is filling gaps or reworking categories.

**Non-Goals:**
- Replacing Codex with a local categorization engine.
- Editing category mappings manually inside the app.
- Expanding categorization beyond the `Global` tab.
- Redesigning the entire categorization UI beyond what is needed to expose reruns clearly.

## Decisions

### Introduce explicit categorization run modes

The categorization flow should distinguish between:
- `appendMissing`: current behavior for missing, invalid, or partially uncategorized libraries
- `recategorizeAll`: new behavior for intentional reruns on a fully categorized library

This keeps the branching logic readable in both the controller and the prompt builder. It also avoids encoding product intent indirectly through snapshot state alone.

Alternative considered: infer rerun intent only from UI state and custom text.
Why not: that would make the service harder to reason about and harder to test because the same public API would silently change behavior based on loosely coupled conditions.

### Keep one shared confirmation surface with mode-aware copy

The existing overlay already explains the Codex run, accepts one-off instructions, and anchors the streamed output area. Reusing it preserves continuity and avoids adding another modal path. The copy should become mode-aware so users understand whether Codex will only append missing entries or may revise current assignments.

Alternative considered: add a separate “Re-categorize” dialog.
Why not: it adds more UI surface area without adding much clarity, and it increases maintenance for a workflow that shares the same execution plumbing.

### Allow `recategorizeAll` to revise existing mappings while preserving structure

For re-categorization runs, the prompt should still require:
- valid `skills.json`
- the same schema keys
- inclusion of active and disabled skills
- no edits to `SKILL.md`

But it should no longer instruct Codex to append only missing skills or preserve every current skill mapping. Instead, it should tell Codex to reconsider existing assignments in light of the latest user guidance while preserving useful scope definitions when they still fit.

Alternative considered: always preserve current mappings and ask the user to manually edit JSON afterward.
Why not: that defeats the purpose of rerunning Codex as a corrective categorization tool.

### Expose rerun entry points only when they are meaningful

When categorization is missing, invalid, or incomplete, the primary action remains `Auto Categorize`. When categorization is already healthy, the UI should expose a rerun-oriented action such as `Re-categorize` or equivalent banner/toolbar copy so the feature feels intentional instead of hidden. The exact label can be finalized during implementation, but the state transition should remain discoverable from the `Global` tab.

Alternative considered: always show only `Auto Categorize`.
Why not: the current label reads like a setup/repair action and does not communicate that a complete, user-directed reclassification is available.

## Risks / Trade-offs

- Re-categorization may move many skills at once and surprise users. → Use mode-aware confirmation copy that explicitly says existing mappings may change.
- A broad custom instruction could degrade an otherwise good taxonomy. → Keep the optional instruction field scoped as one-off guidance and preserve streamed output for review.
- Adding mode branching could make the controller harder to follow. → Centralize run mode selection and reuse the same execution path after the mode is chosen.
- Reusing existing scopes during re-categorization might conflict with user intent to reorganize aggressively. → Prompt Codex to preserve useful scopes when they still fit, but allow reassignments and new scopes when guidance makes them more appropriate.
