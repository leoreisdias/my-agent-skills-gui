import XCTest
@testable import myAgentSkills

final class myAgentSkillsTests: XCTestCase {
    func testAppVersionComparesSemantically() {
        XCTAssertTrue(AppVersion("v0.1.1") > AppVersion("0.1.0"))
        XCTAssertTrue(AppVersion("1.0.0") > AppVersion("0.9.9"))
        XCTAssertEqual(AppVersion("v0.1.0"), AppVersion("0.1.0"))
    }

    func testUpdateServicePicksPreferredDMGAsset() throws {
        let json = """
        {
          "tag_name": "v0.1.1",
          "html_url": "https://github.com/logbookfordevs/ai-skills-companion-menubar/releases/tag/v0.1.1",
          "body": "Release notes",
          "assets": [
            {
              "name": "checksums.txt",
              "browser_download_url": "https://example.com/checksums.txt"
            },
            {
              "name": "AI Skills Companion.dmg",
              "browser_download_url": "https://example.com/AI%20Skills%20Companion.dmg"
            }
          ]
        }
        """

        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        let info = AppUpdateInfo(
            currentVersion: AppVersion("0.1.0"),
            latestVersion: AppVersion(release.tagName),
            releaseURL: release.htmlURL,
            downloadURL: release.assets.first(where: { $0.name == "AI Skills Companion.dmg" })?.downloadURL,
            releaseNotes: release.body ?? ""
        )

        XCTAssertEqual(info.latestVersion, AppVersion("0.1.1"))
        XCTAssertEqual(info.downloadURL?.absoluteString, "https://example.com/AI%20Skills%20Companion.dmg")
    }

    func testParsesCustomSkillFrontmatter() {
        let contents = """
        ---
        name: dx-coding-playbook
        description: Improve maintainability and readability.
        ---

        # DX Coding Playbook

        Body paragraph.
        """

        let metadata = SkillFileParser.parse(contents: contents, fallbackName: "fallback")
        XCTAssertEqual(metadata.name, "dx-coding-playbook")
        XCTAssertEqual(metadata.description, "Improve maintainability and readability.")
    }

    func testSearchTokensRequireAllMatches() {
        let service = CustomSkillsCatalogService(rootURL: URL(fileURLWithPath: "/tmp/unused"))
        let skills = [
            CustomSkillRecord(
                name: "frontend-design",
                originalName: "frontend-design",
                description: "Create distinctive production-grade interfaces",
                folderName: "frontend-design",
                folderURL: URL(fileURLWithPath: "/tmp/frontend-design"),
                skillFileURL: URL(fileURLWithPath: "/tmp/frontend-design/SKILL.md"),
                isDisabled: false,
                storageLocation: .active,
                categoryScopeID: nil,
                categoryLabel: nil,
                categoryDescription: nil,
                tags: [],
                platforms: []
            ),
            CustomSkillRecord(
                name: "structured-debugging",
                originalName: "structured-debugging",
                description: "Investigate bugs and logs with root-cause clarity",
                folderName: "structured-debugging",
                folderURL: URL(fileURLWithPath: "/tmp/structured-debugging"),
                skillFileURL: URL(fileURLWithPath: "/tmp/structured-debugging/SKILL.md"),
                isDisabled: false,
                storageLocation: .active,
                categoryScopeID: nil,
                categoryLabel: nil,
                categoryDescription: nil,
                tags: [],
                platforms: []
            )
        ]

        let filtered = service.filter(skills: skills, query: "distinctive interfaces")
        XCTAssertEqual(filtered.map(\.name), ["frontend-design"])
    }

    func testOfficialParserReadsStructuredLines() {
        let output = """
        \u{001B}[38;5;145manthropics/skills@frontend-design\u{001B}[0m \u{001B}[36m129.2K installs\u{001B}[0m
        \u{001B}[38;5;102m└ https://skills.sh/anthropics/skills/frontend-design\u{001B}[0m
        """

        let results = OfficialSearchParser.parse(output)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "frontend-design")
        XCTAssertEqual(results.first?.source, "anthropics/skills")
        XCTAssertEqual(results.first?.installSource, "anthropics/skills@frontend-design")
    }

    func testNodeRuntimeResolverSelectsFirstExecutable() {
        let selected = NodeRuntimeResolver.selectExecutable(
            from: ["/missing/npx", "/present/npx", "/other/npx"],
            fileExists: { $0 == "/present/npx" }
        )

        XCTAssertEqual(selected, "/present/npx")
    }

    func testCodexRuntimeResolverSelectsFirstExecutable() {
        let selected = CodexRuntimeResolver.selectExecutable(
            from: ["/missing/codex", "/present/codex", "/other/codex"],
            fileExists: { $0 == "/present/codex" }
        )

        XCTAssertEqual(selected, "/present/codex")
    }

    func testAutoCategorizeBuildsExpectedCodexArguments() {
        let rootURL = URL(fileURLWithPath: "/tmp/skills-root")
        let service = CodexCategorizationService(rootURL: rootURL)
        let arguments = service.buildArguments(prompt: "Prompt body")

        XCTAssertEqual(arguments.prefix(2), ["exec", "--skip-git-repo-check"])
        XCTAssertTrue(arguments.contains("--sandbox"))
        XCTAssertTrue(arguments.contains("workspace-write"))
        XCTAssertTrue(arguments.contains("--full-auto"))
        XCTAssertTrue(arguments.contains("--ephemeral"))
        XCTAssertTrue(arguments.contains("--add-dir"))
        XCTAssertTrue(arguments.contains(rootURL.path))
        XCTAssertEqual(arguments.last, "Prompt body")
    }

    func testAutoCategorizePromptForMissingCatalogRequestsCreateFromScratch() {
        let service = CodexCategorizationService(rootURL: URL(fileURLWithPath: "/tmp/skills-root"))
        let snapshot = CustomSkillsCatalogSnapshot(
            skills: [
                makeCustomSkillRecord(folderName: "frontend-design", isDisabled: false),
                makeCustomSkillRecord(folderName: "structured-debugging", isDisabled: true)
            ],
            categorizationState: .missing
        )

        let prompt = service.buildPrompt(snapshot: snapshot)

        XCTAssertTrue(prompt.contains("skills.json is currently missing"))
        XCTAssertTrue(prompt.contains("create it from scratch"))
        XCTAssertTrue(prompt.contains("Active skill folders: frontend-design"))
        XCTAssertTrue(prompt.contains("Disabled skill folders: structured-debugging"))
        XCTAssertTrue(prompt.contains(SkillCatalogDefinition.templateJSON))
    }

    func testAutoCategorizePromptForLoadedCatalogPreservesExistingMappings() {
        let service = CodexCategorizationService(rootURL: URL(fileURLWithPath: "/tmp/skills-root"))
        let definition = SkillCatalogDefinition(
            version: 1,
            generatedAt: "2026-03-08",
            description: "Test catalog",
            scopes: [
                SkillCatalogScope(id: "frontend", label: "Frontend", description: "Frontend work")
            ],
            skills: [
                SkillCategorizationEntry(
                    folder: "frontend-design",
                    name: "frontend-design",
                    scope: "frontend",
                    platforms: ["generic"],
                    tags: ["ui"]
                )
            ]
        )
        let snapshot = CustomSkillsCatalogSnapshot(
            skills: [makeCustomSkillRecord(folderName: "frontend-design", isDisabled: false)],
            categorizationState: .loaded(definition)
        )

        let prompt = service.buildPrompt(
            snapshot: snapshot,
            additionalInstruction: "Put all of my ShadCN skills in a specific group."
        )

        XCTAssertTrue(prompt.contains("skills.json currently exists and is valid"))
        XCTAssertTrue(prompt.contains("Re-categorize the full library"))
        XCTAssertTrue(prompt.contains("reconsider existing mappings using the latest user guidance"))
        XCTAssertTrue(prompt.contains("You may revise existing skill-to-scope mappings"))
        XCTAssertTrue(prompt.contains("Existing scopes: Frontend"))
        XCTAssertTrue(prompt.contains("several Stitch-focused skills should live in a dedicated Stitch scope"))
        XCTAssertTrue(prompt.contains("a single shadcn-ui skill should usually remain inside Frontend"))
        XCTAssertTrue(prompt.contains("a browser automation skill usually belongs in Automation"))
        XCTAssertTrue(prompt.contains("Avoid broad catch-all scopes like Engineering"))
        XCTAssertTrue(prompt.contains("do not put a skill into Video only because it mentions Remotion"))
        XCTAssertTrue(prompt.contains("Brand-focused or project-focused skills should usually live in Project Context or Brand Context"))
        XCTAssertTrue(prompt.contains("Additional user guidance for this run"))
        XCTAssertTrue(prompt.contains("Put all of my ShadCN skills in a specific group."))
    }

    func testAutoCategorizePromptForAppendModeKeepsExistingMappings() {
        let service = CodexCategorizationService(rootURL: URL(fileURLWithPath: "/tmp/skills-root"))
        let definition = SkillCatalogDefinition(
            version: 1,
            generatedAt: "2026-03-08",
            description: "Test catalog",
            scopes: [
                SkillCatalogScope(id: "frontend", label: "Frontend", description: "Frontend work")
            ],
            skills: [
                SkillCategorizationEntry(
                    folder: "frontend-design",
                    name: "frontend-design",
                    scope: "frontend",
                    platforms: ["generic"],
                    tags: ["ui"]
                )
            ]
        )
        let snapshot = CustomSkillsCatalogSnapshot(
            skills: [
                makeCustomSkillRecord(folderName: "frontend-design", isDisabled: false, categoryScopeID: "frontend"),
                makeCustomSkillRecord(folderName: "structured-debugging", isDisabled: false, categoryScopeID: nil)
            ],
            categorizationState: .loaded(definition)
        )

        let prompt = service.buildPrompt(snapshot: snapshot)

        XCTAssertTrue(prompt.contains("skills.json currently exists and is valid"))
        XCTAssertTrue(prompt.contains("Keep all current mappings and only append missing skill entries"))
        XCTAssertTrue(prompt.contains("Preserve all existing skill mappings"))
        XCTAssertTrue(prompt.contains("Append only missing skills"))
        XCTAssertFalse(prompt.contains("Re-categorize the full library"))
    }

    func testAutoCategorizePromptForInvalidCatalogRequestsRepair() {
        let service = CodexCategorizationService(rootURL: URL(fileURLWithPath: "/tmp/skills-root"))
        let snapshot = CustomSkillsCatalogSnapshot(
            skills: [makeCustomSkillRecord(folderName: "remotion", isDisabled: false)],
            categorizationState: .invalid(message: "Unexpected end of file")
        )

        let prompt = service.buildPrompt(snapshot: snapshot)

        XCTAssertTrue(prompt.contains("skills.json currently exists but cannot be parsed"))
        XCTAssertTrue(prompt.contains("repair it"))
    }

    func testSkillCategorizationRunModeRecommendationMatchesCatalogState() {
        let loadedDefinition = SkillCatalogDefinition(
            version: 1,
            generatedAt: "2026-03-08",
            description: "Test catalog",
            scopes: [
                SkillCatalogScope(id: "frontend", label: "Frontend", description: "Frontend work")
            ],
            skills: []
        )

        XCTAssertEqual(
            SkillCategorizationRunMode.recommended(
                skills: [makeCustomSkillRecord(folderName: "frontend-design", isDisabled: false, categoryScopeID: nil)],
                categorizationState: .missing
            ),
            .appendMissing
        )
        XCTAssertEqual(
            SkillCategorizationRunMode.recommended(
                skills: [
                    makeCustomSkillRecord(folderName: "frontend-design", isDisabled: false, categoryScopeID: "frontend"),
                    makeCustomSkillRecord(folderName: "structured-debugging", isDisabled: false, categoryScopeID: nil)
                ],
                categorizationState: .loaded(loadedDefinition)
            ),
            .appendMissing
        )
        XCTAssertEqual(
            SkillCategorizationRunMode.recommended(
                skills: [makeCustomSkillRecord(folderName: "frontend-design", isDisabled: false, categoryScopeID: "frontend")],
                categorizationState: .loaded(loadedDefinition)
            ),
            .recategorizeAll
        )
    }

    func testReCategorizationModeUsesDistinctUserFacingCopy() {
        XCTAssertEqual(SkillCategorizationRunMode.appendMissing.actionButtonTitle, "Auto Categorize")
        XCTAssertEqual(SkillCategorizationRunMode.recategorizeAll.actionButtonTitle, "Re-categorize")
        XCTAssertTrue(SkillCategorizationRunMode.recategorizeAll.confirmationMessage.contains("reconsider existing category assignments"))
        XCTAssertTrue(SkillCategorizationRunMode.recategorizeAll.confirmationStatusMessage.contains("may revise existing category assignments"))
        XCTAssertTrue(SkillCategorizationRunMode.recategorizeAll.successStatusMessage.contains("Re-categorization updated"))
        XCTAssertTrue(SkillCategorizationRunMode.recategorizeAll.reviewStatusMessage.contains("finished re-categorizing"))
    }

    func testInstallWizardBuildsExpectedCommand() {
        var state = InstallWizardState()
        state.sourceKind = .github
        state.sourceInput = "vercel-labs/agent-skills"
        state.selectedSkill = "nextjs-app-router"
        state.scope = .global
        state.selectedAgentIDs = ["codex", "claude-code"]

        let arguments = state.buildInstallArguments()
        XCTAssertTrue(arguments.contains("skills"))
        XCTAssertTrue(arguments.contains("add"))
        XCTAssertTrue(arguments.contains("vercel-labs/agent-skills"))
        XCTAssertTrue(arguments.contains("-g"))
        XCTAssertTrue(arguments.contains("-s"))
        XCTAssertTrue(arguments.contains("nextjs-app-router"))
        XCTAssertEqual(arguments.filter { $0 == "-a" }.count, 2)
        XCTAssertEqual(arguments.last, "-y")
    }

    func testLoadsCategorizedCustomSkillsAndUncategorizedFallback() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)
        try makeSkill(named: "structured-debugging", description: "Debug work", in: rootURL)

        let catalogJSON = """
        {
          "version": 1,
          "generatedAt": "2026-03-08",
          "description": "Test catalog",
          "scopes": [
            {
              "id": "frontend",
              "label": "Frontend",
              "description": "Frontend skills"
            }
          ],
          "skills": [
            {
              "folder": "frontend-design",
              "name": "frontend-design",
              "scope": "frontend",
              "platforms": ["generic"],
              "tags": ["ui"]
            }
          ]
        }
        """
        try catalogJSON.write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let snapshot = service.loadSnapshot()
        let sections = service.buildSections(skills: snapshot.skills, categorizationState: snapshot.categorizationState)

        guard case .loaded = snapshot.categorizationState else {
            return XCTFail("Expected categorized state to load successfully.")
        }

        XCTAssertEqual(sections.map(\.title), ["Frontend", "Uncategorized"])
        XCTAssertEqual(sections.first?.skills.map(\.folderName), ["frontend-design"])
        XCTAssertEqual(sections.last?.skills.map(\.folderName), ["structured-debugging"])
    }

    func testLoadsDisplayAliasFromSkillsJSONWhilePreservingOriginalName() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "structured-debugging", description: "Debug work", in: rootURL)

        let catalogJSON = """
        {
          "version": 1,
          "generatedAt": "2026-03-08",
          "description": "Test catalog",
          "scopes": [],
          "skills": [
            {
              "folder": "structured-debugging",
              "name": "Root Cause Sherlock",
              "scope": "uncategorized"
            }
          ]
        }
        """
        try catalogJSON.write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        XCTAssertEqual(skill.name, "Root Cause Sherlock")
        XCTAssertEqual(skill.originalName, "structured-debugging")
        XCTAssertTrue(skill.hasAlias)
    }

    func testMissingSkillsJSONReportsMissingCategorization() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let snapshot = service.loadSnapshot()

        XCTAssertEqual(snapshot.skills.map(\.folderName), ["frontend-design"])
        XCTAssertEqual(snapshot.categorizationState, .missing)
    }

    func testMalformedSkillsJSONFallsBackSafely() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)
        try "{ invalid json".write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let snapshot = service.loadSnapshot()

        guard case .invalid(let message) = snapshot.categorizationState else {
            return XCTFail("Expected invalid categorization state.")
        }

        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(snapshot.skills.map(\.folderName), ["frontend-design"])
    }

    func testLoadsDisabledSkillsFromDisabledDirectory() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)

        let disabledURL = rootURL.appendingPathComponent(".disabled", isDirectory: true)
        try FileManager.default.createDirectory(at: disabledURL, withIntermediateDirectories: true)
        try makeSkill(named: "structured-debugging", description: "Debug work", in: disabledURL)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let snapshot = service.loadSnapshot()

        XCTAssertEqual(snapshot.skills.count, 2)
        XCTAssertEqual(snapshot.skills.first(where: { $0.folderName == "frontend-design" })?.isDisabled, false)
        XCTAssertEqual(snapshot.skills.first(where: { $0.folderName == "structured-debugging" })?.isDisabled, true)
        XCTAssertEqual(snapshot.skills.first(where: { $0.folderName == "structured-debugging" })?.storageLocation, .disabled)
    }

    func testDisablingSkillMovesItIntoDisabledDirectory() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        try service.setSkill(skill, enabled: false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("frontend-design").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(".disabled/frontend-design").path))
    }

    func testEnablingSkillMovesItBackToRootDirectory() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let disabledURL = rootURL.appendingPathComponent(".disabled", isDirectory: true)
        try FileManager.default.createDirectory(at: disabledURL, withIntermediateDirectories: true)
        try makeSkill(named: "structured-debugging", description: "Debug work", in: disabledURL)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first(where: { $0.folderName == "structured-debugging" }))

        try service.setSkill(skill, enabled: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("structured-debugging").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: disabledURL.appendingPathComponent("structured-debugging").path))
    }

    func testEnablingSkillFailsWhenDestinationAlreadyExists() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "structured-debugging", description: "Active copy", in: rootURL)

        let disabledURL = rootURL.appendingPathComponent(".disabled", isDirectory: true)
        try FileManager.default.createDirectory(at: disabledURL, withIntermediateDirectories: true)
        try makeSkill(named: "structured-debugging", description: "Disabled copy", in: disabledURL)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let disabledSkill = try XCTUnwrap(service.loadSnapshot().skills.first(where: { $0.isDisabled }))

        XCTAssertThrowsError(try service.setSkill(disabledSkill, enabled: true)) { error in
            XCTAssertEqual(
                error as? CustomSkillMutationError,
                .destinationAlreadyExists(
                    folderName: "structured-debugging",
                    destinationPath: rootURL.appendingPathComponent("structured-debugging").path
                )
            )
        }
    }

    func testTrashingSkillUsesTrashHandlerAndRemovesItFromSnapshot() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)

        var trashedPaths: [String] = []
        let service = CustomSkillsCatalogService(
            rootURL: rootURL,
            trashItemHandler: { url in
                trashedPaths.append(url.path)
                try FileManager.default.removeItem(at: url)
            }
        )

        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)
        try service.trashSkill(skill)

        XCTAssertEqual(trashedPaths, [rootURL.appendingPathComponent("frontend-design").path])
        XCTAssertTrue(service.loadSnapshot().skills.isEmpty)
    }

    func testRenameSkillUpdatesExistingSkillsJSONEntryNameOnly() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "structured-debugging", description: "Debug work", in: rootURL)

        let catalogJSON = """
        {
          "version": 1,
          "generatedAt": "2026-03-08",
          "description": "Test catalog",
          "scopes": [
            {
              "id": "review",
              "label": "Review",
              "description": "Review skills"
            }
          ],
          "skills": [
            {
              "folder": "structured-debugging",
              "name": "structured-debugging",
              "scope": "review",
              "platforms": ["generic"],
              "tags": ["debug"]
            }
          ]
        }
        """
        try catalogJSON.write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        try service.renameSkill(skill, displayName: "Debug Detective")

        let data = try Data(contentsOf: rootURL.appendingPathComponent("skills.json"))
        let updatedCatalog = try JSONDecoder().decode(SkillCatalogDefinition.self, from: data)
        let updatedSkill = try XCTUnwrap(updatedCatalog.skills.first)

        XCTAssertEqual(updatedSkill.folder, "structured-debugging")
        XCTAssertEqual(updatedSkill.name, "Debug Detective")
        XCTAssertEqual(updatedSkill.scope, "review")
        XCTAssertEqual(updatedSkill.platforms, ["generic"])
        XCTAssertEqual(updatedSkill.tags, ["debug"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("structured-debugging").path))
    }

    func testRenameSkillAppendsAliasEntryForUncategorizedSkill() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)

        let catalogJSON = """
        {
          "version": 1,
          "generatedAt": "2026-03-08",
          "description": "Test catalog",
          "scopes": [],
          "skills": []
        }
        """
        try catalogJSON.write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        try service.renameSkill(skill, displayName: "Frontend Hero")

        let data = try Data(contentsOf: rootURL.appendingPathComponent("skills.json"))
        let updatedCatalog = try JSONDecoder().decode(SkillCatalogDefinition.self, from: data)
        let appendedEntry = try XCTUnwrap(updatedCatalog.skills.first(where: { $0.folder == "frontend-design" }))

        XCTAssertEqual(appendedEntry.name, "Frontend Hero")
        XCTAssertEqual(appendedEntry.scope, "uncategorized")
    }

    func testRenameSkillFailsWhenSkillsJSONIsMissing() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        XCTAssertThrowsError(try service.renameSkill(skill, displayName: "Frontend Hero")) { error in
            XCTAssertEqual(
                error as? CustomSkillMutationError,
                .missingCategorizationFile(path: rootURL.appendingPathComponent("skills.json").path)
            )
        }
    }

    func testRenameSkillFailsWhenSkillsJSONIsInvalid() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)
        try "{ invalid json".write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        XCTAssertThrowsError(try service.renameSkill(skill, displayName: "Frontend Hero")) { error in
            guard case .invalidCategorizationFile(let path, _) = error as? CustomSkillMutationError else {
                return XCTFail("Expected invalid categorization file error.")
            }
            XCTAssertEqual(path, rootURL.appendingPathComponent("skills.json").path)
        }
    }

    func testRenameSkillFailsForEmptyDisplayName() throws {
        let rootURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try makeSkill(named: "frontend-design", description: "UI work", in: rootURL)
        try """
        {
          "version": 1,
          "generatedAt": "2026-03-08",
          "description": "Test catalog",
          "scopes": [],
          "skills": []
        }
        """.write(to: rootURL.appendingPathComponent("skills.json"), atomically: true, encoding: .utf8)

        let service = CustomSkillsCatalogService(rootURL: rootURL)
        let skill = try XCTUnwrap(service.loadSnapshot().skills.first)

        XCTAssertThrowsError(try service.renameSkill(skill, displayName: "   ")) { error in
            XCTAssertEqual(
                error as? CustomSkillMutationError,
                .invalidDisplayName(reason: "Enter a display name before saving.")
            )
        }
    }

    private func makeTemporaryDirectory() -> URL {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    private func makeSkill(named folderName: String, description: String, in rootURL: URL) throws {
        let folderURL = rootURL.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let contents = """
        ---
        name: \(folderName)
        description: \(description)
        ---

        # \(folderName)
        """
        try contents.write(to: folderURL.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }
}

private func makeCustomSkillRecord(
    folderName: String,
    isDisabled: Bool,
    categoryScopeID: String? = nil
) -> CustomSkillRecord {
    CustomSkillRecord(
        name: folderName,
        originalName: folderName,
        description: "Description for \(folderName)",
        folderName: folderName,
        folderURL: URL(fileURLWithPath: "/tmp/\(folderName)"),
        skillFileURL: URL(fileURLWithPath: "/tmp/\(folderName)/SKILL.md"),
        isDisabled: isDisabled,
        storageLocation: isDisabled ? .disabled : .active,
        categoryScopeID: categoryScopeID,
        categoryLabel: categoryScopeID == nil ? nil : "Category",
        categoryDescription: nil,
        tags: [],
        platforms: []
    )
}
