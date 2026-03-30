import AppKit

@MainActor
final class PopoverViewController: NSViewController {
    private let officialViewController: OfficialTabViewController
    private let installedViewController: InstalledTabViewController
    private let customViewController: CustomTabViewController
    private let updateService = AppUpdateService()
    private let segmentedControl = NSSegmentedControl(labels: ["Hub", "Per Agent", "Global"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentContainer = NSView()
    private let updateStatusLabel = makeSecondaryLabel("")
    private let updateBannerContainer = NSView()
    private let updateButton = NSButton(title: "Check for Updates", target: nil, action: nil)
    private var currentViewController: NSViewController?
    private var latestUpdateInfo: AppUpdateInfo?
    private var isCheckingForUpdates = false
    private var isDownloadingUpdate = false

    init(
        cliService: SkillsCLIService,
        installedCatalog: InstalledSkillsCatalogService,
        customCatalog: CustomSkillsCatalogService
    ) {
        officialViewController = OfficialTabViewController(cliService: cliService)
        installedViewController = InstalledTabViewController(cliService: cliService, catalogService: installedCatalog)
        customViewController = CustomTabViewController(catalogService: customCatalog)
        super.init(nibName: nil, bundle: nil)

        officialViewController.onInstallComplete = { [weak installedViewController] in
            installedViewController?.reloadContent()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 940, height: 720)

        view = NSView()

        let titleLabel = NSTextField(labelWithString: "AI Skills Companion")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)

        let subtitleLabel = makeBodyLabel("Switch between official CLI search, skills organized per agent, and the skills stored in `~/.agents/skills`.")
        subtitleLabel.textColor = .secondaryLabelColor

        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .small
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateStatusLabel.textColor = .secondaryLabelColor
        updateStatusLabel.alignment = .left
        updateBannerContainer.translatesAutoresizingMaskIntoConstraints = false
        updateBannerContainer.isHidden = true

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 12
        titleRow.alignment = .centerY
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.addArrangedSubview(titleLabel)

        let titleSpacer = NSView()
        titleSpacer.translatesAutoresizingMaskIntoConstraints = false
        titleSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleRow.addArrangedSubview(titleSpacer)
        titleRow.addArrangedSubview(updateButton)

        segmentedControl.segmentStyle = .capsule
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(tabChanged)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        addFullWidthArrangedSubview(titleRow, to: stack)
        addFullWidthArrangedSubview(subtitleLabel, to: stack)
        addFullWidthArrangedSubview(updateStatusLabel, to: stack)
        addFullWidthArrangedSubview(updateBannerContainer, to: stack)
        addFullWidthArrangedSubview(segmentedControl, to: stack)
        addFullWidthArrangedSubview(contentContainer, to: stack)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            contentContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 620)
        ])

        updateStatusLabel.stringValue = "Current version: v\(updateService.currentVersion().rawValue)"
        display(viewController: officialViewController)
    }

    @objc private func tabChanged() {
        switch segmentedControl.selectedSegment {
        case 1:
            display(viewController: installedViewController)
        case 2:
            display(viewController: customViewController)
        default:
            display(viewController: officialViewController)
        }
    }

    private func display(viewController: NSViewController) {
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        addChild(viewController)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(viewController.view)
        NSLayoutConstraint.activate([
            viewController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            viewController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        currentViewController = viewController
    }

    @objc private func checkForUpdates() {
        guard !isCheckingForUpdates, !isDownloadingUpdate else { return }
        isCheckingForUpdates = true
        updateButton.isEnabled = false
        updateStatusLabel.stringValue = "Checking GitHub Releases for updates…"
        latestUpdateInfo = nil
        renderUpdateBanner()

        updateService.checkForUpdates { [weak self] result in
            guard let self else { return }
            self.isCheckingForUpdates = false
            self.updateButton.isEnabled = true

            switch result {
            case .success(.upToDate(let currentVersion)):
                self.latestUpdateInfo = nil
                self.updateStatusLabel.stringValue = "You’re already on the latest version: v\(currentVersion.rawValue)."
            case .success(.updateAvailable(let info)):
                self.latestUpdateInfo = info
                self.updateStatusLabel.stringValue = "Update available: v\(info.currentVersion.rawValue) → v\(info.latestVersion.rawValue)."
            case .failure(let error):
                self.latestUpdateInfo = nil
                self.updateStatusLabel.stringValue = error.localizedDescription
            }

            self.renderUpdateBanner()
        }
    }

    @objc private func downloadLatestUpdate() {
        guard let latestUpdateInfo, !isDownloadingUpdate else { return }
        isDownloadingUpdate = true
        updateButton.isEnabled = false
        updateStatusLabel.stringValue = "Downloading AI Skills Companion v\(latestUpdateInfo.latestVersion.rawValue)… The DMG will open automatically."
        renderUpdateBanner()

        updateService.downloadAndOpenDMG(latestUpdateInfo) { [weak self] result in
            guard let self else { return }
            self.isDownloadingUpdate = false
            self.updateButton.isEnabled = true

            switch result {
            case .success(let downloadedURL):
                self.updateStatusLabel.stringValue = "Downloaded and opened \(downloadedURL.lastPathComponent). Drag the app into Applications to replace the current copy."
            case .failure(let error):
                self.updateStatusLabel.stringValue = error.localizedDescription
            }

            self.renderUpdateBanner()
        }
    }

    @objc private func openLatestReleasePage() {
        guard let latestUpdateInfo else { return }
        updateService.openReleasePage(latestUpdateInfo)
    }

    private func renderUpdateBanner() {
        updateBannerContainer.subviews.forEach { $0.removeFromSuperview() }

        guard let latestUpdateInfo else {
            updateBannerContainer.isHidden = true
            return
        }

        let message: String
        if isDownloadingUpdate {
            message = "The latest DMG is downloading now. It will open automatically when it finishes, and if the app already lives in Applications you can replace it there without losing your settings."
        } else {
            message = "GitHub has a newer release ready. Download the DMG to open it directly, or open the release page if you want to review the notes first."
        }

        let banner = ActionBannerView(
            title: "Update available: v\(latestUpdateInfo.latestVersion.rawValue)",
            message: message,
            buttonTitle: latestUpdateInfo.downloadURL == nil ? nil : "Download DMG",
            target: self,
            action: latestUpdateInfo.downloadURL == nil ? nil : #selector(downloadLatestUpdate),
            tone: .highlight,
            buttonEnabled: !isDownloadingUpdate,
            secondaryButtonTitle: "Open Release",
            secondaryTarget: self,
            secondaryAction: #selector(openLatestReleasePage),
            secondaryButtonEnabled: !isDownloadingUpdate
        )
        updateBannerContainer.addSubview(banner)
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: updateBannerContainer.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: updateBannerContainer.trailingAnchor),
            banner.topAnchor.constraint(equalTo: updateBannerContainer.topAnchor),
            banner.bottomAnchor.constraint(equalTo: updateBannerContainer.bottomAnchor)
        ])
        updateBannerContainer.isHidden = false
    }
}
