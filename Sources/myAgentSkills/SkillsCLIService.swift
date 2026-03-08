import AppKit
import Foundation

final class SkillsCLIService {
    private let runtimeResolver: NodeRuntimeResolver
    private let queue = DispatchQueue(label: "myAgentSkills.skills-cli", qos: .userInitiated)
    private let preferredTerminalDefaultsKey = "preferredInteractiveTerminal"

    init(runtimeResolver: NodeRuntimeResolver = NodeRuntimeResolver()) {
        self.runtimeResolver = runtimeResolver
    }

    func resolution() -> NodeRuntimeResolution {
        runtimeResolver.resolveNPX()
    }

    func find(query: String, completion: @escaping @MainActor (CLICommandResult, [OfficialSkillSearchResult]) -> Void) {
        run(arguments: ["--yes", "skills", "find", query]) { result in
            completion(result, OfficialSearchParser.parse(result.stdout + "\n" + result.stderr))
        }
    }

    func listSkills(source: String, completion: @escaping @MainActor (CLICommandResult, [String]) -> Void) {
        run(arguments: ["--yes", "skills", "add", source, "--list"]) { result in
            completion(result, SourceSkillListParser.parse(result.stdout + "\n" + result.stderr))
        }
    }

    func check(completion: @escaping @MainActor (CLICommandResult) -> Void) {
        run(arguments: ["--yes", "skills", "check"], completion: completion)
    }

    func updateAll(completion: @escaping @MainActor (CLICommandResult) -> Void) {
        run(arguments: ["--yes", "skills", "update"], completion: completion)
    }

    func add(state: InstallWizardState, completion: @escaping @MainActor (CLICommandResult) -> Void) {
        run(arguments: state.buildInstallArguments(), completion: completion)
    }

    func availableTerminalApps() -> [InteractiveTerminalApp] {
        InteractiveTerminalApp.allCases.filter { applicationURL(for: $0) != nil }
    }

    func preferredTerminalApp() -> InteractiveTerminalApp? {
        guard
            let rawValue = UserDefaults.standard.string(forKey: preferredTerminalDefaultsKey),
            let terminalApp = InteractiveTerminalApp(rawValue: rawValue),
            availableTerminalApps().contains(terminalApp)
        else {
            return nil
        }

        return terminalApp
    }

    func rememberPreferredTerminalApp(_ terminalApp: InteractiveTerminalApp) {
        UserDefaults.standard.set(terminalApp.rawValue, forKey: preferredTerminalDefaultsKey)
    }

    func clearPreferredTerminalApp() {
        UserDefaults.standard.removeObject(forKey: preferredTerminalDefaultsKey)
    }

    func openInteractiveInstall(source: String, terminalApp: InteractiveTerminalApp = .terminal) -> CLICommandResult {
        let resolution = runtimeResolver.resolveNPX()
        guard let executablePath = resolution.executablePath else {
            return CLICommandResult(
                executablePath: nil,
                arguments: ["--yes", "skills", "add", source],
                workingDirectory: FileManager.default.currentDirectoryPath,
                stdout: "",
                stderr: "Could not find npx. Install Node.js or make npx available to GUI apps.",
                exitCode: -1,
                attemptedPaths: resolution.attemptedPaths
            )
        }

        let workingDirectory = FileManager.default.currentDirectoryPath
        let installArguments = ["--yes", "skills", "add", source]
        let shellCommand = "cd \(shellQuoted(workingDirectory)) && \(shellQuoted(executablePath)) \(installArguments.map(shellQuoted).joined(separator: " "))"
        return openInteractiveCommand(
            shellCommand: shellCommand,
            executablePath: executablePath,
            arguments: installArguments,
            workingDirectory: workingDirectory,
            terminalApp: terminalApp,
            attemptedPaths: resolution.attemptedPaths
        )
    }

    func run(arguments: [String], completion: @escaping @MainActor (CLICommandResult) -> Void) {
        let resolution = runtimeResolver.resolveNPX()
        guard let executablePath = resolution.executablePath else {
            Task { @MainActor in
                completion(
                    CLICommandResult(
                        executablePath: nil,
                        arguments: arguments,
                        workingDirectory: FileManager.default.currentDirectoryPath,
                        stdout: "",
                        stderr: "Could not find npx. Install Node.js or make npx available to GUI apps.",
                        exitCode: -1,
                        attemptedPaths: resolution.attemptedPaths
                    )
                )
            }
            return
        }

        let environment = environment(forExecutablePath: executablePath)
        let currentDirectoryPath = FileManager.default.currentDirectoryPath
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath)

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.environment = environment

            do {
                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = CLICommandResult(
                    executablePath: executablePath,
                    arguments: arguments,
                    workingDirectory: process.currentDirectoryURL?.path,
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus,
                    attemptedPaths: resolution.attemptedPaths
                )

                Task { @MainActor in
                    completion(result)
                }
            } catch {
                let result = CLICommandResult(
                    executablePath: executablePath,
                    arguments: arguments,
                    workingDirectory: process.currentDirectoryURL?.path,
                    stdout: "",
                    stderr: error.localizedDescription,
                    exitCode: -1,
                    attemptedPaths: resolution.attemptedPaths
                )

                Task { @MainActor in
                    completion(result)
                }
            }
        }
    }

    private func environment(forExecutablePath executablePath: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        environment["FORCE_COLOR"] = "0"
        environment["CLICOLOR"] = "0"
        environment["CLICOLOR_FORCE"] = "0"
        environment["CI"] = "1"
        environment["npm_config_color"] = "false"

        let executableDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = ([executableDirectory, existingPath])
            .filter { !$0.isEmpty }
            .joined(separator: ":")

        return environment
    }

    private func openInteractiveCommand(
        shellCommand: String,
        executablePath: String,
        arguments: [String],
        workingDirectory: String,
        terminalApp: InteractiveTerminalApp,
        attemptedPaths: [String]
    ) -> CLICommandResult {
        guard let applicationURL = applicationURL(for: terminalApp) else {
            return CLICommandResult(
                executablePath: executablePath,
                arguments: arguments,
                workingDirectory: workingDirectory,
                stdout: "",
                stderr: "\(terminalApp.displayName) is not installed or could not be located.",
                exitCode: -1,
                attemptedPaths: attemptedPaths
            )
        }

        let launchResult: Result<String, Error>

        switch terminalApp {
        case .terminal:
            launchResult = runAppleScript(
                """
                on run argv
                    set commandText to item 1 of argv
                    tell application "Terminal"
                        activate
                        do script commandText
                    end tell
                end run
                """,
                arguments: [shellCommand]
            )
        case .iTerm2:
            launchResult = runAppleScript(
                """
                on run argv
                    set commandText to item 1 of argv
                    tell application "iTerm"
                        activate
                        if (count of windows) is 0 then
                            create window with default profile
                        end if
                        tell current window
                            create tab with default profile command commandText
                        end tell
                    end tell
                end run
                """,
                arguments: [shellCommand]
            )
        case .ghostty:
            launchResult = launchTerminalViaOpen(
                terminalApp: terminalApp,
                applicationURL: applicationURL,
                arguments: [
                    "--working-directory=\(workingDirectory)",
                    "-e",
                    executablePath
                ] + arguments
            )
        case .kitty:
            launchResult = launchTerminalExecutable(
                terminalApp: terminalApp,
                applicationURL: applicationURL,
                arguments: [
                    "--directory",
                    workingDirectory,
                    executablePath
                ] + arguments
            )
        }

        switch launchResult {
        case .success(let message):
            return CLICommandResult(
                executablePath: executablePath,
                arguments: arguments,
                workingDirectory: workingDirectory,
                stdout: message,
                stderr: "",
                exitCode: 0,
                attemptedPaths: attemptedPaths
            )
        case .failure(let error):
            return CLICommandResult(
                executablePath: executablePath,
                arguments: arguments,
                workingDirectory: workingDirectory,
                stdout: "",
                stderr: error.localizedDescription,
                exitCode: -1,
                attemptedPaths: attemptedPaths
            )
        }
    }

    private func applicationURL(for terminalApp: InteractiveTerminalApp) -> URL? {
        if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalApp.bundleIdentifier) {
            return applicationURL
        }

        let fallbackPaths: [String]
        switch terminalApp {
        case .terminal:
            fallbackPaths = ["/System/Applications/Utilities/Terminal.app", "/Applications/Utilities/Terminal.app"]
        case .iTerm2:
            fallbackPaths = ["/Applications/iTerm.app"]
        case .ghostty:
            fallbackPaths = ["/Applications/Ghostty.app"]
        case .kitty:
            fallbackPaths = ["/Applications/kitty.app", "/Applications/Kitty.app"]
        }

        return fallbackPaths
            .map(URL.init(fileURLWithPath:))
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func runAppleScript(_ source: String, arguments: [String]) -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source] + arguments

        do {
            try process.run()
            return .success("Opened interactive install in the selected terminal.")
        } catch {
            return .failure(error)
        }
    }

    private func launchTerminalExecutable(
        terminalApp: InteractiveTerminalApp,
        applicationURL: URL,
        arguments: [String]
    ) -> Result<String, Error> {
        guard let executableRelativePath = terminalApp.executableRelativePath else {
            return .failure(NSError(domain: "SkillsCLIService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No executable path is configured for \(terminalApp.displayName)."
            ]))
        }

        let executableURL = applicationURL.appendingPathComponent(executableRelativePath)
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        do {
            try process.run()
            return .success("Opened interactive install in \(terminalApp.displayName).")
        } catch {
            return .failure(error)
        }
    }

    private func launchTerminalViaOpen(
        terminalApp: InteractiveTerminalApp,
        applicationURL: URL,
        arguments: [String]
    ) -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", applicationURL.path, "--args"] + arguments

        do {
            try process.run()
            return .success("Opened interactive install in \(terminalApp.displayName).")
        } catch {
            return .failure(error)
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
