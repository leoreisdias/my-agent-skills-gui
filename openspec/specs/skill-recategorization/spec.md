## ADDED Requirements

### Requirement: User can rerun categorization for an already categorized library
The system SHALL let the user start a Codex categorization run even when `skills.json` is valid and every discovered skill already has a category.

#### Scenario: Re-categorization action is available after successful categorization
- **WHEN** the `Global` tab loads a valid `skills.json` and no local skills remain under `Uncategorized`
- **THEN** the app provides a visible action that lets the user rerun categorization intentionally

### Requirement: Re-categorization keeps custom guidance in the flow
The system SHALL let the user provide one-off guidance when rerunning categorization so the next Codex pass can reflect the user’s preferred grouping.

#### Scenario: User supplies custom instruction for re-categorization
- **WHEN** the user starts a re-categorization run
- **THEN** the confirmation flow includes a custom-instruction input that will be passed to Codex for that run

### Requirement: Re-categorization may revise existing mappings
The system SHALL treat an intentional rerun as a full re-categorization pass that can update existing skill-to-scope mappings instead of only appending missing entries.

#### Scenario: Prompt allows reassignment during rerun
- **WHEN** the user confirms a re-categorization run for a valid, fully categorized `skills.json`
- **THEN** the Codex prompt instructs the model to reconsider existing category assignments using the latest user guidance while preserving valid JSON output

### Requirement: Re-categorization communicates that existing categories may change
The system SHALL explain the effect of a rerun before execution so users understand that the new pass may reorganize current categories.

#### Scenario: Confirmation copy sets expectations
- **WHEN** the user opens the re-categorization confirmation flow
- **THEN** the app explains that Codex may revise existing category assignments in `skills.json`

### Requirement: Re-categorization refreshes the catalog after completion
The system SHALL reload local categorization state after a rerun and report whether the new classification is ready for browsing.

#### Scenario: Successful rerun refreshes categorized results
- **WHEN** Codex finishes a re-categorization run successfully and writes a valid `skills.json`
- **THEN** the `Global` tab reloads the skill catalog and shows a success message for the completed re-categorization

#### Scenario: Incomplete rerun requests review
- **WHEN** Codex finishes a re-categorization run but the resulting categorization still cannot be treated as fully ready
- **THEN** the app keeps the refreshed data available and shows a message that the categorization still needs review
