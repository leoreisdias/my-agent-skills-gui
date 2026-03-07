import AppKit

@MainActor
final class InstallWizardWindowController: NSWindowController {
    var onInstallComplete: ((CLICommandResult) -> Void)?

    private let viewController: InstallWizardViewController

    init(cliService: SkillsCLIService, prefill: OfficialSkillSearchResult?) {
        viewController = InstallWizardViewController(cliService: cliService, prefill: prefill)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 760),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Guided Skill Install"
        window.contentViewController = viewController
        super.init(window: window)

        viewController.onInstallComplete = { [weak self] result in
            self?.onInstallComplete?(result)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class InstallWizardViewController: NSViewController {
    var onInstallComplete: ((CLICommandResult) -> Void)?

    private let cliService: SkillsCLIService
    private var state = InstallWizardState()
    private let sourceKindPopUp = NSPopUpButton()
    private let sourceField = NSTextField()
    private let loadSkillsButton = NSButton()
    private let skillSelectionPopUp = NSPopUpButton()
    private let projectScopeButton = NSButton(radioButtonWithTitle: "Project", target: nil, action: nil)
    private let globalScopeButton = NSButton(radioButtonWithTitle: "Global", target: nil, action: nil)
    private let extraAgentsField = NSTextField()
    private let previewTextField = makeBodyLabel("")
    private let outputComponents = makeCommandOutputView()
    private let statusLabel = makeSecondaryLabel("")
    private let agentsStack = NSStackView()
    private let availableSkillNamesPlaceholder = "Install every skill"
    private var agentButtons: [NSButton] = []

    init(cliService: SkillsCLIService, prefill: OfficialSkillSearchResult?) {
        self.cliService = cliService
        super.init(nibName: nil, bundle: nil)

        if let prefill {
            state.sourceKind = .searchResult
            state.sourceInput = prefill.installSource
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Native install wizard")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)

        let descriptionLabel = makeBodyLabel("Step 1: pick a source. Step 2: optionally load skills from that source. Step 3: choose project or global. Step 4: pick one or more agent targets. Step 5: review the generated command. Step 6: run it.")
        descriptionLabel.textColor = .secondaryLabelColor

        SkillSourceKind.allCases.forEach { sourceKindPopUp.addItem(withTitle: $0.displayName) }
        sourceKindPopUp.target = self
        sourceKindPopUp.action = #selector(sourceKindChanged)
        sourceKindPopUp.selectItem(at: SkillSourceKind.allCases.firstIndex(of: state.sourceKind) ?? 0)

        sourceField.placeholderString = "vercel-labs/agent-skills or https://… or /path/to/repo"
        sourceField.stringValue = state.sourceInput
        sourceField.target = self
        sourceField.action = #selector(sourceFieldChanged)

        loadSkillsButton.title = "Load Source Skills"
        loadSkillsButton.target = self
        loadSkillsButton.action = #selector(loadSourceSkills)
        loadSkillsButton.bezelStyle = .rounded

        skillSelectionPopUp.addItem(withTitle: availableSkillNamesPlaceholder)
        skillSelectionPopUp.target = self
        skillSelectionPopUp.action = #selector(skillSelectionChanged)

        projectScopeButton.target = self
        projectScopeButton.action = #selector(scopeChanged)
        globalScopeButton.target = self
        globalScopeButton.action = #selector(scopeChanged)
        projectScopeButton.state = .on

        extraAgentsField.placeholderString = "Extra agent ids, comma-separated"
        extraAgentsField.target = self
        extraAgentsField.action = #selector(extraAgentsChanged)

        agentsStack.orientation = .vertical
        agentsStack.spacing = 6
        agentsStack.alignment = .leading

        let agentsScroll = NSScrollView()
        agentsScroll.borderType = .bezelBorder
        agentsScroll.hasVerticalScroller = true
        let agentsContainer = NSView()
        agentsContainer.translatesAutoresizingMaskIntoConstraints = false
        agentsScroll.documentView = agentsContainer
        agentsScroll.translatesAutoresizingMaskIntoConstraints = false
        agentsContainer.addSubview(agentsStack)
        agentsStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            agentsStack.leadingAnchor.constraint(equalTo: agentsContainer.leadingAnchor, constant: 12),
            agentsStack.trailingAnchor.constraint(equalTo: agentsContainer.trailingAnchor, constant: -12),
            agentsStack.topAnchor.constraint(equalTo: agentsContainer.topAnchor, constant: 12),
            agentsStack.bottomAnchor.constraint(equalTo: agentsContainer.bottomAnchor, constant: -12),
            agentsStack.widthAnchor.constraint(equalTo: agentsContainer.widthAnchor, constant: -24),
            agentsScroll.heightAnchor.constraint(equalToConstant: 220)
        ])

        let copyButton = makeActionButton("Copy Command", target: self, action: #selector(copyCommand))
        let installButton = makeActionButton("Run Install", target: self, action: #selector(runInstall))

        let sourceControls = NSStackView(views: [sourceKindPopUp, sourceField, loadSkillsButton])
        sourceControls.orientation = .horizontal
        sourceControls.spacing = 8
        sourceControls.alignment = .centerY

        let scopeControls = NSStackView(views: [projectScopeButton, globalScopeButton])
        scopeControls.orientation = .horizontal
        scopeControls.spacing = 12
        scopeControls.alignment = .centerY

        let actionControls = NSStackView(views: [copyButton, installButton])
        actionControls.orientation = .horizontal
        actionControls.spacing = 8
        actionControls.alignment = .centerY

        let stack = NSStackView(views: [
            titleLabel,
            descriptionLabel,
            makeSectionLabel("1. Source"),
            sourceControls,
            makeSectionLabel("2. Optional skill selection"),
            skillSelectionPopUp,
            makeSectionLabel("3. Scope"),
            scopeControls,
            makeSectionLabel("4. Agent targets"),
            agentsScroll,
            extraAgentsField,
            makeSectionLabel("5. Generated command"),
            previewTextField,
            statusLabel,
            actionControls,
            makeSectionLabel("6. Command output"),
            outputComponents.container
        ])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            sourceKindPopUp.widthAnchor.constraint(equalToConstant: 150),
            skillSelectionPopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            sourceField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            previewTextField.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        configureAgentButtons()
        updatePreview()
    }

    private func configureAgentButtons() {
        agentButtons.forEach { button in
            agentsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        agentButtons = AgentTarget.all.map { agent in
            let button = NSButton(checkboxWithTitle: "\(agent.displayName) (\(agent.id))", target: self, action: #selector(agentToggled(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(agent.id)
            agentsStack.addArrangedSubview(button)
            return button
        }
    }

    @objc private func sourceKindChanged() {
        if let selected = SkillSourceKind.allCases[safe: sourceKindPopUp.indexOfSelectedItem] {
            state.sourceKind = selected
        }
        updatePreview()
    }

    @objc private func sourceFieldChanged() {
        state.sourceInput = sourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        updatePreview()
    }

    @objc private func loadSourceSkills() {
        sourceFieldChanged()
        guard !state.sourceInput.isEmpty else {
            statusLabel.stringValue = "Enter a source first."
            return
        }

        statusLabel.stringValue = "Loading available skills from source…"
        cliService.listSkills(source: state.sourceInput) { [weak self] result, skills in
            guard let self else { return }
            self.outputComponents.textView.string = result.combinedOutput
            self.skillSelectionPopUp.removeAllItems()
            self.skillSelectionPopUp.addItem(withTitle: self.availableSkillNamesPlaceholder)
            skills.forEach { self.skillSelectionPopUp.addItem(withTitle: $0) }
            self.statusLabel.stringValue = result.succeeded
                ? "Loaded \(skills.count) optional skill name(s) from the source."
                : "Could not load source skills. You can still install directly."
            self.state.selectedSkill = nil
            self.updatePreview()
        }
    }

    @objc private func skillSelectionChanged() {
        let selectedTitle = skillSelectionPopUp.titleOfSelectedItem ?? availableSkillNamesPlaceholder
        state.selectedSkill = selectedTitle == availableSkillNamesPlaceholder ? nil : selectedTitle
        updatePreview()
    }

    @objc private func scopeChanged(_ sender: NSButton) {
        state.scope = sender == globalScopeButton ? .global : .project
        projectScopeButton.state = state.scope == .project ? .on : .off
        globalScopeButton.state = state.scope == .global ? .on : .off
        updatePreview()
    }

    @objc private func agentToggled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        if sender.state == .on {
            state.selectedAgentIDs.insert(id)
        } else {
            state.selectedAgentIDs.remove(id)
        }
        updatePreview()
    }

    @objc private func extraAgentsChanged() {
        state.extraAgentIDs = extraAgentsField.stringValue
        updatePreview()
    }

    @objc private func copyCommand() {
        copyToPasteboard(state.commandPreview())
    }

    @objc private func runInstall() {
        sourceFieldChanged()
        extraAgentsChanged()
        guard !state.sourceInput.isEmpty else {
            statusLabel.stringValue = "The source is required."
            return
        }
        guard !state.allAgentIDs.isEmpty else {
            statusLabel.stringValue = "Pick at least one agent target."
            return
        }

        statusLabel.stringValue = "Running install…"
        cliService.add(state: state) { [weak self] result in
            guard let self else { return }
            self.outputComponents.textView.string = result.combinedOutput
            self.statusLabel.stringValue = result.succeeded ? "Install completed." : "Install failed."
            self.onInstallComplete?(result)
        }
    }

    private func updatePreview() {
        previewTextField.stringValue = state.commandPreview()
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
