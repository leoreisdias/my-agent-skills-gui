import Foundation

enum SkillFileParser {
    static func parse(contents: String, fallbackName: String) -> FrontmatterMetadata {
        let lines = contents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return FrontmatterMetadata(
                name: nil,
                description: firstBodyParagraph(from: contents)
            )
        }

        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        var isInsideFrontmatter = true

        for line in lines.dropFirst() {
            if isInsideFrontmatter, line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                isInsideFrontmatter = false
                continue
            }

            if isInsideFrontmatter {
                frontmatterLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }

        let values = Dictionary(uniqueKeysWithValues: frontmatterLines.compactMap { line -> (String, String)? in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return (key, value)
        })

        let description = values["description"].flatMap { $0.isEmpty ? nil : $0 }
            ?? firstBodyParagraph(from: bodyLines.joined(separator: "\n"))

        return FrontmatterMetadata(
            name: values["name"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName,
            description: description
        )
    }

    private static func firstBodyParagraph(from contents: String) -> String? {
        contents
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

final class CustomSkillsCatalogService {
    private let rootURL: URL
    private let fileManager: FileManager
    private let categorizationFileName = "skills.json"

    init(rootURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".agents/skills"), fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func loadSnapshot() -> CustomSkillsCatalogSnapshot {
        let categorizationState = loadCategorizationState()
        let skills = loadSkills(categorizationState: categorizationState)
        return CustomSkillsCatalogSnapshot(skills: skills, categorizationState: categorizationState)
    }

    func loadSkills() -> [CustomSkillRecord] {
        loadSnapshot().skills
    }

    func buildSections(skills: [CustomSkillRecord], categorizationState: SkillCategorizationState) -> [CustomSkillSection] {
        guard case .loaded(let catalogDefinition) = categorizationState else {
            return []
        }

        let orderedSections = catalogDefinition.scopes.compactMap { scope -> CustomSkillSection? in
            let scopedSkills = skills.filter { $0.categoryScopeID == scope.id }
            guard !scopedSkills.isEmpty else { return nil }

            return CustomSkillSection(
                id: scope.id,
                title: scope.label,
                description: scope.description,
                skills: scopedSkills
            )
        }

        let uncategorizedSkills = skills.filter { $0.categoryScopeID == nil }
        guard !uncategorizedSkills.isEmpty else {
            return orderedSections
        }

        return orderedSections + [
            CustomSkillSection(
                id: "uncategorized",
                title: "Uncategorized",
                description: "Skills found in `~/.agents/skills` but not assigned in `skills.json`.",
                skills: uncategorizedSkills
            )
        ]
    }

    private func loadSkills(categorizationState: SkillCategorizationState) -> [CustomSkillRecord] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let categorizationByFolder: [String: SkillCategorizationEntry]
        let scopesByID: [String: SkillCatalogScope]
        if case .loaded(let definition) = categorizationState {
            categorizationByFolder = Dictionary(
                definition.skills.map { ($0.folder, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            scopesByID = Dictionary(
                definition.scopes.map { ($0.id, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
        } else {
            categorizationByFolder = [:]
            scopesByID = [:]
        }

        return contents.compactMap { folderURL in
            let skillFileURL = folderURL.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFileURL.path) else { return nil }

            let contents = (try? String(contentsOf: skillFileURL)) ?? ""
            let metadata = SkillFileParser.parse(contents: contents, fallbackName: folderURL.lastPathComponent)
            let description = metadata.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderName = folderURL.lastPathComponent
            let categorizationEntry = categorizationByFolder[folderName]
            let scope = categorizationEntry.flatMap { scopesByID[$0.scope] }
            return CustomSkillRecord(
                name: metadata.name ?? folderURL.lastPathComponent,
                description: description?.isEmpty == false ? description! : "Custom Local",
                folderName: folderName,
                folderURL: folderURL,
                skillFileURL: skillFileURL,
                categoryScopeID: scope?.id,
                categoryLabel: scope?.label,
                categoryDescription: scope?.description,
                tags: categorizationEntry?.tags ?? [],
                platforms: categorizationEntry?.platforms ?? []
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadCategorizationState() -> SkillCategorizationState {
        let categorizationFileURL = rootURL.appendingPathComponent(categorizationFileName)
        guard fileManager.fileExists(atPath: categorizationFileURL.path) else {
            return .missing
        }

        do {
            let data = try Data(contentsOf: categorizationFileURL)
            let decoder = JSONDecoder()
            let definition = try decoder.decode(SkillCatalogDefinition.self, from: data)
            return .loaded(definition)
        } catch {
            return .invalid(message: error.localizedDescription)
        }
    }

    func filter(skills: [CustomSkillRecord], query: String) -> [CustomSkillRecord] {
        let tokens = query.normalizedSearchTokens()
        guard !tokens.isEmpty else { return skills }
        return skills.filter { record in
            let searchable = record.searchableText
            return tokens.allSatisfy(searchable.contains)
        }
    }
}

final class InstalledSkillsCatalogService {
    private let fileManager: FileManager
    private let homeDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) {
        self.fileManager = fileManager
        self.homeDirectoryURL = homeDirectoryURL
    }

    func loadSkills() -> [InstalledSkillRecord] {
        var results: [InstalledSkillRecord] = []
        let roots: [(bucket: InstalledSkillBucket, url: URL, agentID: String?)] = [
            (
                InstalledSkillBucket(
                    title: "Global Library",
                    order: 0,
                    locationLabel: "~/.agents/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".agents/skills"),
                nil
            ),
            (
                InstalledSkillBucket(
                    title: "Codex",
                    order: 1,
                    locationLabel: "~/.codex/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".codex/skills"),
                "codex"
            ),
            (
                InstalledSkillBucket(
                    title: "Claude",
                    order: 2,
                    locationLabel: "~/.claude/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".claude/skills"),
                "claude-code"
            ),
            (
                InstalledSkillBucket(
                    title: "Gemini / Antigravity",
                    order: 3,
                    locationLabel: "~/.gemini/antigravity/skills"
                ),
                homeDirectoryURL.appendingPathComponent(".gemini/antigravity/skills"),
                "gemini-antigravity"
            )
        ]

        for root in roots {
            results.append(contentsOf: loadSkills(in: root.url, bucket: root.bucket, agentID: root.agentID))
        }

        return results.sorted {
            if $0.bucket.order != $1.bucket.order {
                return $0.bucket.order < $1.bucket.order
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func filter(skills: [InstalledSkillRecord], query: String) -> [InstalledSkillRecord] {
        let tokens = query.normalizedSearchTokens()
        guard !tokens.isEmpty else { return skills }
        return skills.filter { record in
            let searchable = record.searchableText
            return tokens.allSatisfy(searchable.contains)
        }
    }

    private func loadSkills(in rootURL: URL, agent: AgentTarget, scope: InstallScope) -> [InstalledSkillRecord] {
        []
    }

    private func loadSkills(in rootURL: URL, bucket: InstalledSkillBucket, agentID: String?) -> [InstalledSkillRecord] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { folderURL in
            let skillFileURL = folderURL.appendingPathComponent("SKILL.md")
            let contents = (try? String(contentsOf: skillFileURL)) ?? ""
            let metadata = SkillFileParser.parse(contents: contents, fallbackName: folderURL.lastPathComponent)
            let description = metadata.description?.trimmingCharacters(in: .whitespacesAndNewlines)

            return InstalledSkillRecord(
                name: metadata.name ?? folderURL.lastPathComponent,
                description: description?.isEmpty == false ? description! : "Installed skill",
                sourceLabel: bucket.locationLabel,
                bucket: bucket,
                agentID: agentID,
                folderURL: folderURL,
                skillFileURL: fileManager.fileExists(atPath: skillFileURL.path) ? skillFileURL : nil,
                status: .unknown
            )
        }
    }
}
