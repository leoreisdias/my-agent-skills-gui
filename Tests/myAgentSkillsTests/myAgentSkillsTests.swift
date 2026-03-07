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
                folderURL: URL(fileURLWithPath: "/tmp/frontend-design"),
                skillFileURL: URL(fileURLWithPath: "/tmp/frontend-design/SKILL.md")
            ),
            CustomSkillRecord(
                name: "structured-debugging",
                description: "Investigate bugs and logs with root-cause clarity",
                folderURL: URL(fileURLWithPath: "/tmp/structured-debugging"),
                skillFileURL: URL(fileURLWithPath: "/tmp/structured-debugging/SKILL.md")
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
}
