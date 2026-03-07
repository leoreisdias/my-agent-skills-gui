import Foundation

struct NodeRuntimeResolution {
    let executablePath: String?
    let attemptedPaths: [String]

    var isResolved: Bool {
        executablePath != nil
    }
}

final class NodeRuntimeResolver {
    private let fileManager: FileManager
    private let processInfo: ProcessInfo

    init(fileManager: FileManager = .default, processInfo: ProcessInfo = .processInfo) {
        self.fileManager = fileManager
        self.processInfo = processInfo
    }

    func resolveNPX() -> NodeRuntimeResolution {
        let homeDirectory = NSHomeDirectory()
        let environment = processInfo.environment
        let candidates = Self.candidatePaths(homeDirectory: homeDirectory, environment: environment, fileManager: fileManager)
        let selected = Self.selectExecutable(from: candidates) { [fileManager] path in
            fileManager.isExecutableFile(atPath: path)
        }

        return NodeRuntimeResolution(executablePath: selected, attemptedPaths: candidates)
    }

    static func candidatePaths(
        homeDirectory: String,
        environment: [String: String],
        fileManager: FileManager = .default
    ) -> [String] {
        var candidates: [String] = []

        if let path = environment["PATH"] {
            for segment in path.split(separator: ":") {
                candidates.append(URL(fileURLWithPath: String(segment)).appendingPathComponent("npx").path)
            }
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/npx",
            "/usr/local/bin/npx",
            "/usr/bin/npx",
            URL(fileURLWithPath: homeDirectory).appendingPathComponent(".local/bin/npx").path
        ])

        let nvmDirectory = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".nvm/versions/node")
        if let versions = try? fileManager.contentsOfDirectory(
            at: nvmDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            let nvmExecutables = versions
                .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
                .map { $0.appendingPathComponent("bin/npx").path }
            candidates.append(contentsOf: nvmExecutables)
        }

        return deduplicated(candidates)
    }

    static func selectExecutable(from candidates: [String], fileExists: (String) -> Bool) -> String? {
        candidates.first(where: fileExists)
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
