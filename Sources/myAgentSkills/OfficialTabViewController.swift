import AppKit

@MainActor
final class OfficialTabViewController: NSViewController, NSSearchFieldDelegate {
    var onInstallComplete: (() -> Void)?

    private let cliService: SkillsCLIService
    private let searchField = NSSearchField()
    private let resultsStack = NSStackView()
    private let statusLabel = makeSecondaryLabel("")
    private let outputComponents = makeCommandOutputView()
    private var results: [OfficialSkillSearchResult] = []
    init(cliService: SkillsCLIService) {
        self.cliService = cliService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Official skills.sh")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .left

        let descriptionLabel = makeBodyLabel("Search the official skills catalog through the CLI. When you want to install something, this tab hands off to the real interactive CLI in Terminal so its own agent-selection flow stays intact.")
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .left

        searchField.placeholderString = "Search official skills"
        searchField.delegate = self

        let searchButton = makeActionButton("Search", target: self, action: #selector(runSearch))
        let addButton = makeActionButton("Install Source In CLI", target: self, action: #selector(promptForSourceInstall))

        let controls = NSStackView(views: [searchField, searchButton, addButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY
        controls.distribution = .fill

        let resultsColumn = makeScrollableColumn(minHeight: 320)
        let resultsScroll = resultsColumn.scrollView
        resultsStack.orientation = .vertical
        resultsStack.spacing = 12
        resultsStack.alignment = .width
        resultsColumn.contentView.addSubview(resultsStack)
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resultsStack.leadingAnchor.constraint(equalTo: resultsColumn.contentView.leadingAnchor, constant: 12),
            resultsStack.trailingAnchor.constraint(equalTo: resultsColumn.contentView.trailingAnchor, constant: -12),
            resultsStack.topAnchor.constraint(equalTo: resultsColumn.contentView.topAnchor, constant: 12),
            resultsStack.bottomAnchor.constraint(equalTo: resultsColumn.contentView.bottomAnchor, constant: -12)
        ])

        statusLabel.alignment = .left

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 12
        content.alignment = .width
        content.translatesAutoresizingMaskIntoConstraints = false

        addFullWidthArrangedSubview(titleLabel, to: content)
        addFullWidthArrangedSubview(descriptionLabel, to: content)
        addFullWidthArrangedSubview(controls, to: content)
        addFullWidthArrangedSubview(statusLabel, to: content)
        addFullWidthArrangedSubview(resultsScroll, to: content)
        addFullWidthArrangedSubview(makeSectionLabel("Command Output"), to: content)
        addFullWidthArrangedSubview(outputComponents.container, to: content)

        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        statusLabel.stringValue = resolverMessage()
        renderResults()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        runSearch()
    }

    @objc private func runSearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            statusLabel.stringValue = "Type a query to search the official directory."
            renderResults()
            return
        }

        statusLabel.stringValue = "Searching \(query)…"
        cliService.find(query: query) { [weak self] result, parsedResults in
            guard let self else { return }
            self.results = parsedResults
            self.outputComponents.textView.string = result.combinedOutput
            self.statusLabel.stringValue = parsedResults.isEmpty
                ? "No structured results were parsed. You can still use the guided installer."
                : "Found \(parsedResults.count) result(s)."
            self.renderResults()
        }
    }

    @objc private func promptForSourceInstall() {
        let alert = NSAlert()
        alert.messageText = "Install source with skills CLI"
        alert.informativeText = "Enter a GitHub shorthand, full URL, or local path. The real interactive CLI will open in Terminal."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open in Terminal")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "vercel-labs/agent-skills or https://skills.sh/..."
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let source = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }

        let result = cliService.openInteractiveInstall(source: source)
        outputComponents.textView.string = result.combinedOutput
        statusLabel.stringValue = result.succeeded ? "Opened interactive CLI install in Terminal." : "Could not open interactive install."
    }

    @objc private func installResultInTerminal(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < results.count else { return }
        let result = cliService.openInteractiveInstall(source: results[sender.tag].installSource)
        outputComponents.textView.string = result.combinedOutput
        statusLabel.stringValue = result.succeeded ? "Opened interactive CLI install in Terminal." : "Could not open interactive install."
    }

    @objc private func copyInstallSource(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < results.count else { return }
        copyToPasteboard(results[sender.tag].installSource)
    }

    private func renderResults() {
        resultsStack.arrangedSubviews.forEach {
            resultsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !results.isEmpty else {
            addFullWidthArrangedSubview(
                EmptyStateView(
                    title: "Search-first official browsing",
                    message: "Run a query to populate this tab. The CLI remains the source of truth, so the app does not preload the entire remote catalog."
                ),
                to: resultsStack
            )
            return
        }

        for (index, result) in results.enumerated() {
            let installButton = makeActionButton("Install In CLI", target: self, action: #selector(installResultInTerminal(_:)))
            installButton.tag = index
            let copyButton = makeActionButton("Copy Source", target: self, action: #selector(copyInstallSource(_:)))
            copyButton.tag = index

            let subtitle = result.source.map { "\($0) • Official result" } ?? "Official result"
            addFullWidthArrangedSubview(
                SkillRowBox(
                    title: result.title,
                    subtitle: subtitle,
                    body: result.description,
                    actionButtons: [installButton, copyButton]
                ),
                to: resultsStack
            )
        }
    }

    private func resolverMessage() -> String {
        let resolution = cliService.resolution()
        if resolution.isResolved {
            return "Using npx at \(resolution.executablePath ?? "unknown path")"
        }
        return "npx is unavailable. Official search and install will show setup errors until Node.js is available to GUI apps."
    }
}
