## ADDED Requirements

### Requirement: User can rename a local skill label from the Global tab
The system SHALL let the user start a rename flow for any skill shown in the `Global` tab, including active and disabled skills.

#### Scenario: Rename action is available for an active skill
- **WHEN** the user views an active local skill in the `Global` tab
- **THEN** the app provides a rename action for that skill

#### Scenario: Rename action is available for a disabled skill
- **WHEN** the user views a disabled local skill in the `Global` tab
- **THEN** the app provides a rename action for that skill

### Requirement: Rename input is validated before mutation
The system SHALL validate the requested display name before changing app-managed metadata.

#### Scenario: Empty rename is rejected
- **WHEN** the user submits a rename value that is empty after trimming whitespace
- **THEN** the app rejects the rename and explains that a non-empty name is required

#### Scenario: Invalid display name is rejected
- **WHEN** the user submits a rename value that cannot be stored safely as a display alias
- **THEN** the app rejects the rename and explains that the name is invalid

### Requirement: Rename is stored as an app-managed alias
The system SHALL treat rename as an app-level display alias stored in `skills.json`, without changing the underlying local skill identity.

#### Scenario: Matching skill entry alias is updated
- **WHEN** the user confirms a valid rename request
- **THEN** the app updates the matching `skills.json` entry `name` for that skill's `folder`

#### Scenario: Visible skill name prefers app alias
- **WHEN** a skill has a `skills.json` entry with a non-empty `name`
- **THEN** the app shows that alias as the skill title in the UI

#### Scenario: Display falls back when no alias exists
- **WHEN** a skill does not have a `skills.json` alias `name`
- **THEN** the app falls back to `SKILL.md` frontmatter `name`, and then to folder name if needed

### Requirement: Original skill identity remains visible in the UI
The system SHALL continue to expose the original skill name in the card UI even when an alias is present, so users can reference the real skill outside the app.

#### Scenario: Renamed skill still shows its original name
- **WHEN** a skill has an alias from `skills.json`
- **THEN** the card shows both the aliased display name and the original skill name

#### Scenario: Copy or reference actions use the original skill name
- **WHEN** the user copies or references a renamed skill for use with an agent
- **THEN** the app provides the original skill name rather than the aliased label

### Requirement: Rename preserves installed skill identity
The system SHALL preserve the real installed skill identity so external `skills` CLI operations continue to work.

#### Scenario: Folder identity remains unchanged
- **WHEN** the user renames a skill in the app
- **THEN** the app does not rename the underlying skill folder

#### Scenario: Skills CLI lock file remains unchanged
- **WHEN** the user renames a skill in the app
- **THEN** the app does not modify `~/.agents/.skill-lock.json`

### Requirement: Rename depends on valid app metadata
The system SHALL persist renames only through valid app-managed metadata.

#### Scenario: Missing skills.json blocks rename
- **WHEN** the user attempts to rename a skill and `skills.json` does not exist
- **THEN** the app blocks the rename and explains that app metadata is required

#### Scenario: Invalid skills.json blocks rename
- **WHEN** the user attempts to rename a skill and `skills.json` cannot be parsed
- **THEN** the app blocks the rename and explains that the metadata file must be repaired first

### Requirement: Rename reports a clear outcome
The system SHALL refresh the local skill listing and show a user-readable outcome after each rename attempt.

#### Scenario: Successful rename refreshes the list
- **WHEN** the app completes a rename successfully
- **THEN** the `Global` tab reloads and shows the renamed skill in the updated list

#### Scenario: Rename failure leaves the original skill intact
- **WHEN** the rename operation fails before completion
- **THEN** the app keeps the original skill available and shows an error message describing the failure
