import AppKit
import Foundation

struct AppVersion: Comparable, Equatable {
    let rawValue: String
    private let numericComponents: [Int]

    init(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        rawValue = normalized
        numericComponents = normalized
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.numericComponents.count, rhs.numericComponents.count)
        for index in 0..<maxCount {
            let lhsComponent = index < lhs.numericComponents.count ? lhs.numericComponents[index] : 0
            let rhsComponent = index < rhs.numericComponents.count ? rhs.numericComponents[index] : 0
            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent
            }
        }
        return false
    }
}

struct ReleaseAsset: Decodable, Equatable {
    let name: String
    let downloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
    }
}

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let htmlURL: URL
    let body: String?
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case assets
    }
}

struct AppUpdateInfo: Equatable {
    let currentVersion: AppVersion
    let latestVersion: AppVersion
    let releaseURL: URL
    let downloadURL: URL?
    let releaseNotes: String
}

enum AppUpdateCheckResult: Equatable {
    case upToDate(currentVersion: AppVersion)
    case updateAvailable(AppUpdateInfo)
}

enum AppUpdateError: LocalizedError {
    case invalidResponse
    case missingDMGAsset
    case missingDownloadsDirectory
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Could not read the latest GitHub release information."
        case .missingDMGAsset:
            return "The latest release does not include a DMG asset yet."
        case .missingDownloadsDirectory:
            return "Could not locate the Downloads folder on this Mac."
        case .downloadFailed:
            return "The DMG download did not finish correctly."
        }
    }
}

@MainActor
final class AppUpdateService {
    static let repositoryOwner = "logbookfordevs"
    static let repositoryName = "ai-skills-companion-menubar"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func currentVersion() -> AppVersion {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return AppVersion(version)
    }

    func checkForUpdates(completion: @escaping @MainActor (Result<AppUpdateCheckResult, Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repositoryOwner)/\(Self.repositoryName)/releases/latest") else {
            completion(.failure(AppUpdateError.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AI Skills Companion", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard
                    let self,
                    let data,
                    let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    completion(.failure(AppUpdateError.invalidResponse))
                    return
                }

                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let currentVersion = self.currentVersion()
                    let latestVersion = AppVersion(release.tagName)
                    guard latestVersion > currentVersion else {
                        completion(.success(.upToDate(currentVersion: currentVersion)))
                        return
                    }

                    let info = AppUpdateInfo(
                        currentVersion: currentVersion,
                        latestVersion: latestVersion,
                        releaseURL: release.htmlURL,
                        downloadURL: Self.preferredDMGAsset(from: release.assets)?.downloadURL,
                        releaseNotes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    )
                    completion(.success(.updateAvailable(info)))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func downloadAndOpenDMG(_ info: AppUpdateInfo, completion: @escaping @MainActor (Result<URL, Error>) -> Void) {
        guard let downloadURL = info.downloadURL else {
            completion(.failure(AppUpdateError.missingDMGAsset))
            return
        }

        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        guard let destinationDirectory = downloadsDirectory else {
            completion(.failure(AppUpdateError.missingDownloadsDirectory))
            return
        }

        let destinationURL = destinationDirectory.appendingPathComponent("AI Skills Companion \(info.latestVersion.rawValue).dmg")

        session.downloadTask(with: downloadURL) { tempURL, _, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let tempURL else {
                    completion(.failure(AppUpdateError.downloadFailed))
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    NSWorkspace.shared.open(destinationURL)
                    completion(.success(destinationURL))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func openReleasePage(_ info: AppUpdateInfo) {
        NSWorkspace.shared.open(info.releaseURL)
    }

    private static func preferredDMGAsset(from assets: [ReleaseAsset]) -> ReleaseAsset? {
        assets.first {
            $0.name.localizedCaseInsensitiveContains("AI Skills Companion") &&
            $0.name.lowercased().hasSuffix(".dmg")
        } ?? assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}
