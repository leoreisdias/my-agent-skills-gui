// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "myAgentSkills",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "myAgentSkills",
            path: "Sources/myAgentSkills",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "myAgentSkillsTests",
            dependencies: ["myAgentSkills"],
            path: "Tests/myAgentSkillsTests"
        )
    ]
)
