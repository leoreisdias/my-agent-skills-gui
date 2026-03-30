## 1. Categorization Run Modes

- [x] 1.1 Introduce a mode or intent model for Codex categorization runs so the app can distinguish append-only auto-categorization from full re-categorization.
- [x] 1.2 Update `CodexCategorizationService` prompt construction so re-categorization runs may revise existing mappings while still preserving valid `skills.json` structure and local-skill coverage.
- [x] 1.3 Keep append-only behavior unchanged for missing, invalid, or partially uncategorized libraries.

## 2. Global Tab UX

- [x] 2.1 Expose a visible re-categorization action in the `Global` tab when `skills.json` is valid and all discovered skills are already categorized.
- [x] 2.2 Reuse the existing confirmation flow with mode-aware copy that explains whether Codex will append missing entries or may revise current category assignments.
- [x] 2.3 Refresh banner text, status messaging, and completion states so successful reruns read as intentional re-categorization instead of only repair output.

## 3. Verification and Docs

- [x] 3.1 Add or update focused tests for mode selection, prompt wording, and rerun availability when categorization is already complete.
- [x] 3.2 Add or update UI-oriented tests for re-categorization success and review-needed outcomes after a rerun.
- [x] 3.3 Update `README.md` to explain when `Auto Categorize` versus re-categorization is available and how custom instructions influence a rerun.
