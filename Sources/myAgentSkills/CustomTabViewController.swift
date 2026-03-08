import AppKit

@MainActor
final class CustomTabViewController: NSViewController, NSSearchFieldDelegate {
    private let catalogService: CustomSkillsCatalogService
    private let searchField = NSSearchField()
    private let bannerContainer = NSView()
    private let rowsStack = NSStackView()
    private let statusLabel = makeSecondaryLabel("")
    private var catalogSnapshot = CustomSkillsCatalogSnapshot(skills: [], categorizationState: .missing)
    private var allSkills: [CustomSkillRecord] = []
    private var filteredSkills: [CustomSkillRecord] = []

    init(catalogService: CustomSkillsCatalogService) {
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

        let descriptionLabel = makeBodyLabel("Browse every skill under `~/.agents/skills`, and search by name plus description so you can find the right skill faster.")
        descriptionLabel.textColor = .secondaryLabelColor

        searchField.placeholderString = "Search local skills by name or description"
        searchField.delegate = self

        let refreshButton = makeActionButton("Refresh", target: self, action: #selector(refresh))

        let controls = NSStackView(views: [searchField, refreshButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        bannerContainer.translatesAutoresizingMaskIntoConstraints = false

        let rowsColumn = makeScrollableColumn(minHeight: 420)
        let scrollView = rowsColumn.scrollView
        rowsStack.orientation = .vertical
        rowsStack.spacing = 20
        rowsStack.alignment = .width
        rowsColumn.contentView.addSubview(rowsStack)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: rowsColumn.contentView.leadingAnchor, constant: 12),
            rowsStack.trailingAnchor.constraint(equalTo: rowsColumn.contentView.trailingAnchor, constant: -12),
            rowsStack.topAnchor.constraint(equalTo: rowsColumn.contentView.topAnchor, constant: 12),
            rowsStack.bottomAnchor.constraint(equalTo: rowsColumn.contentView.bottomAnchor, constant: -12)
        ])

        let stack = NSStackView(views: [descriptionLabel, bannerContainer, controls, statusLabel, scrollView])
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
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        refresh()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    @objc private func refresh() {
        catalogSnapshot = catalogService.loadSnapshot()
        allSkills = catalogSnapshot.skills
        applyFilter()
    }

    @objc private func copySkillName(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        copyToPasteboard(filteredSkills[sender.tag].name)
    }

    @objc private func openSkillFile(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        NSWorkspace.shared.open(filteredSkills[sender.tag].skillFileURL)
    }

    @objc private func openSkillFolder(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < filteredSkills.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([filteredSkills[sender.tag].folderURL])
    }

    private func applyFilter() {
        filteredSkills = catalogService.filter(skills: allSkills, query: searchField.stringValue)
        renderBanner()
        updateStatusLabel()
        renderRows()
    }

    private func updateStatusLabel() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if filteredSkills.isEmpty {
            if query.isEmpty {
                statusLabel.stringValue = "No local skills found in ~/.agents/skills."
            } else {
                statusLabel.stringValue = "No local skills matched `\(query)`."
            }
            return
        }

        switch catalogSnapshot.categorizationState {
        case .loaded:
            let visibleSections = catalogService.buildSections(
                skills: filteredSkills,
                categorizationState: catalogSnapshot.categorizationState
            )
            statusLabel.stringValue = "Showing \(filteredSkills.count) local skill(s) in \(visibleSections.count) categor\(visibleSections.count == 1 ? "y" : "ies")."
        case .missing, .invalid:
            statusLabel.stringValue = "Loaded \(filteredSkills.count) local skill(s)."
        }
    }

    private func renderBanner() {
        bannerContainer.subviews.forEach { $0.removeFromSuperview() }

        let bannerView: NSView?
        switch catalogSnapshot.categorizationState {
        case .missing:
            bannerView = ActionBannerView(
                title: "Organize your skills by category",
                message: "Add `skills.json` to `~/.agents/skills` to group local skills into sections like Frontend, Docs, and Review.",
                buttonTitle: "Categorize",
                target: self,
                action: #selector(showCategorizationHelp)
            )
        case .invalid(let message):
            bannerView = ActionBannerView(
                title: "skills.json couldn’t be read",
                message: "Showing the flat list for now. \(message)",
                buttonTitle: "Categorize",
                target: self,
                action: #selector(showCategorizationHelp)
            )
        case .loaded:
            bannerView = nil
        }

        guard let bannerView else {
            bannerContainer.isHidden = true
            return
        }

        bannerContainer.isHidden = false
        bannerContainer.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            bannerView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor)
        ])
    }

    @objc private func showCategorizationHelp() {
        let alert = NSAlert()
        alert.messageText = "Categorize your skills"
        alert.informativeText = "Create `~/.agents/skills/skills.json` and the app will group the Skills tab using the categories you define there."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy JSON Template")
        alert.addButton(withTitle: "Close")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = SkillCatalogDefinition.templateJSON

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        alert.accessoryView = scrollView

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        copyToPasteboard(SkillCatalogDefinition.templateJSON)
        statusLabel.stringValue = "Copied skills.json template to the clipboard."
    }

    private func renderRows() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !filteredSkills.isEmpty else {
            addFullWidthArrangedSubview(
                EmptyStateView(
                    title: "Local skills",
                    message: "This tab is ready, but the app could not find any skills under `~/.agents/skills` yet."
                ),
                to: rowsStack
            )
            return
        }

        if case .loaded = catalogSnapshot.categorizationState {
            renderCategorizedRows()
            return
        }

        renderFlatRows(filteredSkills)
    }

    private func renderCategorizedRows() {
        let sections = catalogService.buildSections(
            skills: filteredSkills,
            categorizationState: catalogSnapshot.categorizationState
        )
        guard !sections.isEmpty else {
            renderFlatRows(filteredSkills)
            return
        }

        for sectionModel in sections {
            let section = makeCategorySectionContainer(
                title: sectionModel.title,
                subtitle: sectionModel.description,
                countText: "\(sectionModel.skills.count) skill\(sectionModel.skills.count == 1 ? "" : "s")"
            )
            addFullWidthArrangedSubview(section.container, to: rowsStack)
            let cards = sectionModel.skills.map { cardView(for: $0) }
            addCardGridRows(cards, to: section.contentStack)
        }
    }

    private func renderFlatRows(_ skills: [CustomSkillRecord]) {
        var cards: [NSView] = []

        for skill in skills {
            cards.append(cardView(for: skill))
        }

        addCardGridRows(cards, to: rowsStack)
    }

    private func cardView(for skill: CustomSkillRecord) -> NSView {
        let index = filteredSkills.firstIndex(of: skill) ?? 0
        let copyButton = makeActionButton("Copy Name", target: self, action: #selector(copySkillName(_:)))
        copyButton.tag = index
        let fileButton = makeActionButton("Open SKILL.md", target: self, action: #selector(openSkillFile(_:)))
        fileButton.tag = index
        let folderButton = makeActionButton("Open Folder", target: self, action: #selector(openSkillFolder(_:)))
        folderButton.tag = index

        return SkillRowBox(
            title: skill.name,
            subtitle: "",
            body: skill.description,
            actionButtons: [copyButton, fileButton, folderButton]
        )
    }
}
