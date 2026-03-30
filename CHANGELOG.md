# Changelog

All notable changes to this project will be documented in this file.

## [0.1.1] - 2026-03-29

### Added
- Global `Check for Updates` flow in the popover header.
- GitHub Releases integration to detect newer versions of AI Skills Companion.
- Inline update banner with `Download DMG` and `Open Release` actions.
- Automatic DMG download to the user's Downloads folder, followed by automatic opening of the downloaded file.
- Project-local packaging metadata via `version.env`.
- New local developer scripts for `launch` and `compile-and-run` workflows.
- Post-build bundle validation during packaging, including executable and code-signature inspection.
- Local skill label aliases in `Global`, stored in `skills.json`, so skills can have app-friendly names without changing their real installed identifiers.
- Codex-powered re-categorization flow for `Global`, so an already categorized library can be reorganized with new guidance.
- Live OpenSpec coverage for local skill renaming and re-categorization capabilities.

### Changed
- App version metadata is now aligned with the public GitHub release versioning scheme.
- README now documents the update flow and the recommended `/Applications` replacement path for upgrades.
- The SwiftPM packaging flow is now more defensive about build output paths and emits bundle metadata directly into the packaged app.
- DMG packaging now reuses the improved app bundle flow and verifies the generated artifact path before finishing.
- Renamed local skill cards now keep the original skill name visible and use that original identifier for copy or reference actions.
- Healthy categorized libraries now surface `Re-categorize` as a lightweight action instead of a persistent banner.

### Fixed
- `Global` category chips now wrap instead of getting clipped horizontally when many categories are present.
- The top tab selector now keeps equal segment widths so the selected state stays visually aligned.
- Opening the `Auto Categorize` confirmation no longer expands extra content early, which reduces popover layout drift in the `Global` tab.
- Local skill action buttons now wrap inside cards instead of compressing the card content when the layout gets narrow.
- The rename label flow now uses a dedicated modal window instead of a broken alert accessory layout.
- Running categorization no longer reintroduces a large banner layout jump in `Global`.
- `Per Agent` sections now keep their full width instead of collapsing into a shrinked layout.

## [0.1.0] - 2026-03-09

### Added
- First public release of **AI Skills Companion**, a native macOS menu bar app for browsing and managing AI skills.
- `Hub` tab for official `skills.sh` discovery and install-command preparation.
- `Per Agent` tab for inspecting skills installed across common agent folders.
- `Global` tab for browsing the local `~/.agents/skills` library.
- Local skill management actions in `Global`, including disable, re-enable, and move-to-Trash.
- Optional `skills.json` categorization support for grouping local skills into custom sections.
- `Auto Categorize` flow powered by Codex CLI, with in-app confirmation and live output.
- DMG packaging flow for GitHub Releases.

### Changed
- The product naming was finalized around the current app language:
  - `AI Skills Companion`
  - `Hub`
  - `Per Agent`
  - `Global`
- Official installs now use a copy-first CLI flow instead of opening a terminal automatically.
- Search behavior in `Per Agent` and `Global` was moved to explicit search (`Search` button or `Enter`) for better scalability.

### Fixed
- Multiple layout and alignment fixes across `Hub`, `Per Agent`, and `Global`.
- Improved empty states, category visibility, and card consistency in the `Global` tab.
- Cleaner command output behavior by hiding low-value path debugging details on successful runs.
