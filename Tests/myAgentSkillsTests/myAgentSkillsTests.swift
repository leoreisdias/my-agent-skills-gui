import XCTest
@testable import myAgentSkills

final class myAgentSkillsTests: XCTestCase {
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
                description: "Create distinctive production-grade interfaces",
                folderName: "frontend-design",
                folderURL: URL(fileURLWithPath: "/tmp/frontend-design"),
                skillFileURL: URL(fileURLWithPath: "/tmp/frontend-design/SKILL.md"),
                categoryScopeID: nil,
                categoryLabel: nil,
                categoryDescription: nil,
                tags: [],
                platforms: []
            ),
            CustomSkillRecord(
                name: "structured-debugging",
                description: "Investigate bugs and logs with root-cause clarity",
                folderName: "structured-debugging",
                folderURL: URL(fileURLWithPath: "/tmp/structured-debugging"),
                skillFileURL: URL(fileURLWithPath: "/tmp/structured-debugging/SKILL.md"),
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
