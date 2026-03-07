import Foundation

enum OfficialSearchParser {
    static func parse(_ output: String) -> [OfficialSkillSearchResult] {
        let lines = output
            .strippingANSI()
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { shouldKeep(line: $0) }

        let results = parsePairedCLIResults(lines: lines)

        if !results.isEmpty {
            return deduplicated(results)
        }

        return lines.prefix(12).map {
            OfficialSkillSearchResult(
                title: $0,
                source: nil,
                description: "Raw CLI result",
                rawValue: $0,
                installSource: $0
            )
        }
    }

    private static func shouldKeep(line: String) -> Bool {
        guard !line.isEmpty else { return false }
        let lowercased = line.lowercased()
        if lowercased.contains("████") || lowercased.contains("skills add <owner/repo@skill>") {
            return false
        }

        let ignoredPrefixes = [
            "searching",
            "found ",
            "using ",
            "tip:",
            "run ",
            "command:",
            "stdout",
            "stderr",
            "install with"
        ]
        return !ignoredPrefixes.contains(where: lowercased.hasPrefix)
    }

    private static func parsePairedCLIResults(lines: [String]) -> [OfficialSkillSearchResult] {
        var results: [OfficialSkillSearchResult] = []
        var currentIdentifier: String?
        var currentInstallCount: String?

        for line in lines {
            if line.hasPrefix("http://") || line.hasPrefix("https://") || line.hasPrefix("└ http") {
                guard let identifier = currentIdentifier else { continue }
                let cleanURL = line.replacingOccurrences(of: "└", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let (source, title) = splitIdentifier(identifier)
                let descriptionParts = [currentInstallCount, cleanURL].compactMap { $0 }
                results.append(
                    OfficialSkillSearchResult(
                        title: title,
                        source: source,
                        description: descriptionParts.joined(separator: "\n"),
                        rawValue: "\(identifier) \(descriptionParts.joined(separator: " "))",
                        installSource: identifier
                    )
                )
                currentIdentifier = nil
                currentInstallCount = nil
                continue
            }

            if let parsed = parseIdentifierLine(line) {
                currentIdentifier = parsed.identifier
                currentInstallCount = parsed.installCount
                continue
            }

            if let result = parseStructured(line: line) {
                results.append(result)
            }
        }

        return results
    }

    private static func parseIdentifierLine(_ line: String) -> (identifier: String, installCount: String?)? {
        let cleaned = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
        guard cleaned.contains("@"), cleaned.contains("/") else { return nil }

        let pattern = #"^(.*?)\s+([0-9][0-9\.,]*[KMB]? installs)$"#
        if let match = cleaned.range(of: pattern, options: .regularExpression) {
            let matchedString = String(cleaned[match])
            let installsMatch = matchedString.replacingOccurrences(of: pattern, with: "$2", options: .regularExpression)
            let identifier = matchedString.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
            return (identifier.trimmingCharacters(in: .whitespacesAndNewlines), installsMatch)
        }

        return (cleaned.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    private static func splitIdentifier(_ identifier: String) -> (source: String?, title: String) {
        let parts = identifier.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return (identifier.contains("/") ? identifier : nil, identifier)
        }

        return (parts[0], parts[1])
    }

    private static func parseStructured(line: String) -> OfficialSkillSearchResult? {
        let cleaned = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
        let separators = [" — ", " – ", " - "]

        for separator in separators {
            let parts = cleaned.components(separatedBy: separator)
            guard parts.count >= 2 else { continue }

            let titleCandidate = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptionCandidate = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !titleCandidate.isEmpty else { continue }

            let (source, title) = splitIdentifier(titleCandidate)
            return OfficialSkillSearchResult(
                title: title,
                source: source ?? titleCandidate,
                description: descriptionCandidate,
                rawValue: cleaned,
                installSource: titleCandidate
            )
        }

        return nil
    }

    private static func deduplicated(_ results: [OfficialSkillSearchResult]) -> [OfficialSkillSearchResult] {
        var seen = Set<String>()
        return results.filter { seen.insert($0.rawValue).inserted }
    }
}

enum SourceSkillListParser {
    static func parse(_ output: String) -> [String] {
        let lines = output
            .strippingANSI()
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidates = lines.compactMap { line -> String? in
            let cleaned = line.replacingOccurrences(of: #"^[\-\*\d\.\)]\s*"#, with: "", options: .regularExpression)
            guard !cleaned.lowercased().hasPrefix("available") else { return nil }
            guard !cleaned.contains("http://"), !cleaned.contains("https://") else { return nil }
            guard !cleaned.contains("Command:"), !cleaned.contains("Exit Code:") else { return nil }
            return cleaned
        }

        return Array(Set(candidates)).sorted()
    }
}

enum InstalledCheckParser {
    static func parseStatuses(_ output: String, records: [InstalledSkillRecord]) -> [InstalledSkillRecord] {
        let lines = output
            .strippingANSI()
            .components(separatedBy: .newlines)
            .map { $0.lowercased() }

        return records.map { record in
            guard let line = lines.first(where: {
                $0.contains(record.name.lowercased()) && (record.agentID == nil || $0.contains(record.agentID!.lowercased()))
            }) else {
                return record
            }

            var updated = record
            if line.contains("up to date") || line.contains("up-to-date") {
                updated.status = .upToDate
            } else if line.contains("update available") || line.contains("outdated") {
                updated.status = .updateAvailable(details: "Update available")
            } else if line.contains("error") || line.contains("failed") {
                updated.status = .error(details: "Check failed")
            } else {
                updated.status = .info(details: "Reported by CLI")
            }
            return updated
        }
    }
}
