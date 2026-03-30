## 1. Display Alias Foundation

- [x] 1.1 Update catalog loading so local skill display names prefer `skills.json` entry `name`, then `SKILL.md` frontmatter `name`, then folder name.
- [x] 1.2 Extend the loaded skill model so the UI can render both the aliased display name and the original skill name.
- [x] 1.3 Add a `CustomSkillsCatalogService` rename mutation that validates the requested alias and rewrites only the matching `skills.json` entry `name`.
- [x] 1.4 Extend local skill mutation errors to cover rename-specific validation and missing or invalid `skills.json` states with user-readable messages.

## 2. Metadata Safety

- [x] 2.1 Keep `skills.json` folder mappings, scopes, tags, and unrelated entries unchanged when applying a rename alias.
- [x] 2.2 Ensure rename never mutates local skill folders or `~/.agents/.skill-lock.json`, and document that contract in the implementation.

## 3. Global Tab UX

- [x] 3.1 Add a rename action to each local skill card in the `Global` tab for both active and disabled skills.
- [x] 3.2 Implement the rename prompt or sheet, including the current displayed name, input trimming, and inline validation feedback.
- [x] 3.3 Update the card UI so renamed skills show both the alias and the original skill name, with copy or reference actions using the original identifier.
- [x] 3.4 Refresh the local skill listing, filters, and transient status messaging after rename success or failure.

## 4. Verification

- [x] 4.1 Add or update focused tests for alias precedence, original-name rendering, copy behavior, `skills.json` rewrite behavior, and blocking behavior when `skills.json` is missing or invalid.
- [x] 4.2 Manually verify renaming active and disabled skills, preserving CLI update behavior, and failure cases in the app UI.
