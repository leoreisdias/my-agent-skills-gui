import AppKit

@MainActor
final class InstalledTabViewController: NSViewController, NSSearchFieldDelegate {
    private let cliService: SkillsCLIService
    private let catalogService: InstalledSkillsCatalogService
    private let searchField = NSSearchField()
    private let rowsStack = NSStackView()
    private let statusLabel = makeSecondaryLabel("")
    private let outputComponents = makeCommandOutputView()
    private var allRecords: [InstalledSkillRecord] = []
    private var filteredRecords: [InstalledSkillRecord] = []

    init(cliService: SkillsCLIService, catalogService: InstalledSkillsCatalogService) {
        self.cliService = cliService
        self.catalogService = catalogService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Installed official skills")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)

        let descriptionLabel = makeBodyLabel("Browse the global skill folders you care about most: `~/.agents/skills`, Codex, Claude, and Gemini / Antigravity.")
        descriptionLabel.textColor = .secondaryLabelColor

        searchField.placeholderString = "Filter installed skills"
        searchField.delegate = self

        let refreshButton = makeActionButton("Refresh", target: self, action: #selector(refresh))
        let checkButton = makeActionButton("Check Updates", target: self, action: #selector(checkUpdates))
        let updateButton = makeActionButton("Update All", target: self, action: #selector(updateAll))

        let controls = NSStackView(views: [searchField, refreshButton, checkButton, updateButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        let rowsColumn = makeScrollableColumn(minHeight: 320)
        let scrollView = rowsColumn.scrollView
        rowsStack.orientation = .vertical
        rowsStack.spacing = 12
        rowsStack.alignment = .width
        rowsColumn.contentView.addSubview(rowsStack)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: rowsColumn.contentView.leadingAnchor, constant: 12),
            rowsStack.trailingAnchor.constraint(equalTo: rowsColumn.contentView.trailingAnchor, constant: -12),
            rowsStack.topAnchor.constraint(equalTo: rowsColumn.contentView.topAnchor, constant: 12),
            rowsStack.bottomAnchor.constraint(equalTo: rowsColumn.contentView.bottomAnchor, constant: -12)
        ])

        let stack = NSStackView(views: [
            titleLabel,
            descriptionLabel,
            controls,
            statusLabel,
            scrollView,
            makeSectionLabel("Command Output"),
            outputComponents.container
        ])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        reloadContent()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func reloadContent() {
        allRecords = catalogService.loadSkills()
        applyFilter()
        if allRecords.isEmpty {
            statusLabel.stringValue = "No skills were found in the configured global folders."
        } else {
            statusLabel.stringValue = "Loaded \(filteredRecords.count) installed skill(s) across your global folders."
        }
    }

    @objc private func refresh() {
        reloadContent()
    }

    @objc private func checkUpdates() {
        statusLabel.stringValue = "Running skills check…"
        cliService.check { [weak self] result in
            guard let self else { return }
            self.outputComponents.textView.string = result.combinedOutput
            self.allRecords = InstalledCheckParser.parseStatuses(result.stdout + "\n" + result.stderr, records: self.allRecords)
            self.applyFilter()
            self.statusLabel.stringValue = result.succeeded ? "Update check completed." : "Update check failed."
        }
    }

    @objc private func updateAll() {
        statusLabel.stringValue = "Running skills update…"
        cliService.updateAll { [weak self] result in
            guard let self else { return }
            self.outputComponents.textView.string = result.combinedOutput
            self.statusLabel.stringValue = result.succeeded ? "Update completed." : "Update failed."
            self.reloadContent()
        }
    }

    @objc private func copySkillName(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredRecords.count else { return }
        copyToPasteboard(filteredRecords[sender.tag].name)
    }

    @objc private func openSkillFile(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredRecords.count else { return }
        if let url = filteredRecords[sender.tag].skillFileURL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSkillFolder(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredRecords.count else { return }
        if let url = filteredRecords[sender.tag].folderURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func applyFilter() {
        filteredRecords = catalogService.filter(skills: allRecords, query: searchField.stringValue)
        renderRows()
    }

    private func renderRows() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !filteredRecords.isEmpty else {
            addFullWidthArrangedSubview(
                EmptyStateView(
                    title: "No installed skills",
                    message: "Nothing was found in `~/.agents/skills`, `~/.codex/skills`, `~/.claude/skills`, or `~/.gemini/antigravity/skills`."
                ),
                to: rowsStack
            )
            return
        }

        let grouped = Dictionary(grouping: Array(filteredRecords.enumerated()), by: { $0.element.bucket })
        let orderedBuckets = grouped.keys.sorted {
            if $0.order != $1.order {
                return $0.order < $1.order
            }
            return $0.title < $1.title
        }

        for bucket in orderedBuckets {
            let section = makeSectionContainer(title: bucket.title, subtitle: bucket.locationLabel)
            addFullWidthArrangedSubview(section.container, to: rowsStack)

            for (index, record) in grouped[bucket, default: []] {
                let copyButton = makeActionButton("Copy Name", target: self, action: #selector(copySkillName(_:)))
                copyButton.tag = index
                let fileButton = makeActionButton("Open SKILL.md", target: self, action: #selector(openSkillFile(_:)))
                fileButton.tag = index
                fileButton.isEnabled = record.skillFileURL != nil
                let folderButton = makeActionButton("Open Folder", target: self, action: #selector(openSkillFolder(_:)))
                folderButton.tag = index
                folderButton.isEnabled = record.folderURL != nil

                addFullWidthArrangedSubview(
                    SkillRowBox(
                        title: record.name,
                        subtitle: "\(record.sourceLabel) • \(record.status.title)",
                        body: record.description,
                        actionButtons: [copyButton, fileButton, folderButton]
                    ),
                    to: section.contentStack
                )
            }

        }
    }
}
