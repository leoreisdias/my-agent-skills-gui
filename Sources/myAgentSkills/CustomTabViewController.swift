import AppKit

@MainActor
final class CustomTabViewController: NSViewController, NSSearchFieldDelegate {
    private let catalogService: CustomSkillsCatalogService
    private let searchField = NSSearchField()
    private let rowsStack = NSStackView()
    private let statusLabel = makeSecondaryLabel("")
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

        let titleLabel = NSTextField(labelWithString: "Skills in ~/.agents/skills")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)

        let descriptionLabel = makeBodyLabel("Browse every skill under `~/.agents/skills`, and search by name plus description so you can find the right skill faster.")
        descriptionLabel.textColor = .secondaryLabelColor

        searchField.placeholderString = "Search local skills by name or description"
        searchField.delegate = self

        let refreshButton = makeActionButton("Refresh", target: self, action: #selector(refresh))

        let controls = NSStackView(views: [searchField, refreshButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        let rowsColumn = makeScrollableColumn(minHeight: 420)
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

        let stack = NSStackView(views: [titleLabel, descriptionLabel, controls, statusLabel, scrollView])
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
        allSkills = catalogService.loadSkills()
        applyFilter()
        if allSkills.isEmpty {
            statusLabel.stringValue = "No custom skills found in ~/.agents/skills."
        } else {
            statusLabel.stringValue = "Loaded \(filteredSkills.count) local skill(s)."
        }
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
        renderRows()
    }

    private func renderRows() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !filteredSkills.isEmpty else {
            addFullWidthArrangedSubview(
                EmptyStateView(
                    title: "Custom local source",
                    message: "This tab is ready, but the app could not find any skills under `~/.agents/skills` yet."
                ),
                to: rowsStack
            )
            return
        }

        for (index, skill) in filteredSkills.enumerated() {
            let copyButton = makeActionButton("Copy Name", target: self, action: #selector(copySkillName(_:)))
            copyButton.tag = index
            let fileButton = makeActionButton("Open SKILL.md", target: self, action: #selector(openSkillFile(_:)))
            fileButton.tag = index
            let folderButton = makeActionButton("Open Folder", target: self, action: #selector(openSkillFolder(_:)))
            folderButton.tag = index

            addFullWidthArrangedSubview(
                SkillRowBox(
                    title: skill.name,
                    subtitle: "Local Skill",
                    body: skill.description,
                    actionButtons: [copyButton, fileButton, folderButton]
                ),
                to: rowsStack
            )
        }
    }
}
