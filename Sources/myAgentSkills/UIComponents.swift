import AppKit

@MainActor
final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
func makeSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .secondaryLabelColor
    label.alignment = .left
    return label
}

@MainActor
func makeBodyLabel(_ text: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: 12)
    label.maximumNumberOfLines = 0
    label.lineBreakMode = .byWordWrapping
    label.alignment = .left
    return label
}

@MainActor
func makeSecondaryLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11)
    label.textColor = .secondaryLabelColor
    label.alignment = .left
    return label
}

@MainActor
func makeBadgeLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11, weight: .semibold)
    label.textColor = .secondaryLabelColor
    label.alignment = .center
    return label
}

@MainActor
func makeActionButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.bezelStyle = .rounded
    button.controlSize = .small
    return button
}

@MainActor
func makeLinkButton(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.isBordered = false
    button.bezelStyle = .inline
    button.controlSize = .small
    button.font = .systemFont(ofSize: 12, weight: .semibold)
    button.contentTintColor = .linkColor
    button.setButtonType(.momentaryPushIn)
    return button
}

@MainActor
func makeCommandOutputView() -> (container: NSScrollView, textView: NSTextView) {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    textView.backgroundColor = .textBackgroundColor

    let scrollView = NSScrollView()
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.documentView = textView
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        scrollView.heightAnchor.constraint(equalToConstant: 150)
    ])
    return (scrollView, textView)
}

@MainActor
final class CollapsibleSectionView: NSView {
    private let title: String
    private let toggleButton: NSButton
    private let contentContainer = NSView()
    private let contentView: NSView
    private(set) var isExpanded: Bool

    init(title: String, contentView: NSView, startsExpanded: Bool = false) {
        self.title = title
        self.contentView = contentView
        self.isExpanded = startsExpanded
        self.toggleButton = NSButton(title: "", target: nil, action: nil)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        toggleButton.target = self
        toggleButton.action = #selector(toggleExpanded)
        toggleButton.isBordered = false
        toggleButton.alignment = .left
        toggleButton.imagePosition = .imageLeading
        toggleButton.font = .systemFont(ofSize: 13, weight: .semibold)
        toggleButton.contentTintColor = .labelColor
        toggleButton.setButtonType(.momentaryPushIn)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [toggleButton, contentContainer])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        updateExpandedState()
    }

    @objc private func toggleExpanded() {
        isExpanded.toggle()
        updateExpandedState()
    }

    private func updateExpandedState() {
        contentContainer.isHidden = !isExpanded
        toggleButton.title = isExpanded ? "Hide \(title)" : "Show \(title)"
        toggleButton.image = NSImage(
            systemSymbolName: isExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: title
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

@MainActor
final class SkillRowBox: NSView {
    private let bodyLabel: NSTextField
    private let toggleButton: NSButton
    private let fullBody: String
    private let collapsedBody: String
    private let isExpandable: Bool
    private var isExpanded = false

    init(title: String, subtitle: String, body: String, actionButtons: [NSButton]) {
        self.fullBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.collapsedBody = SkillRowBox.truncatedBody(for: self.fullBody)
        self.isExpandable = self.collapsedBody != self.fullBody
        self.bodyLabel = makeBodyLabel(self.collapsedBody)
        self.toggleButton = makeLinkButton("View more", target: nil, action: nil)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.78).cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.alignment = .left

        let subtitleLabel = makeSecondaryLabel(subtitle)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.isHidden = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        subtitleLabel.alignment = .left
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.textColor = .labelColor
        bodyLabel.alignment = .left

        actionButtons.forEach {
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }

        let buttonRow = NSStackView(views: actionButtons)
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 6
        buttonRow.alignment = .centerY
        buttonRow.setContentCompressionResistancePriority(.required, for: .horizontal)
        buttonRow.setContentHuggingPriority(.required, for: .horizontal)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        toggleButton.target = self
        toggleButton.action = #selector(toggleDescription)
        toggleButton.isHidden = !isExpandable
        toggleButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggleButton.setContentHuggingPriority(.required, for: .horizontal)

        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .centerY
        if isExpandable {
            bottomRow.addArrangedSubview(toggleButton)
        }
        bottomRow.addArrangedSubview(spacer)
        bottomRow.addArrangedSubview(buttonRow)

        let stack = NSStackView(views: [titleLabel, subtitleLabel, bodyLabel, bottomRow])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])

        updateDescriptionState()
    }

    @objc private func toggleDescription() {
        guard isExpandable else { return }
        isExpanded.toggle()
        updateDescriptionState()
    }

    private func updateDescriptionState() {
        bodyLabel.stringValue = isExpanded ? fullBody : collapsedBody
        toggleButton.title = isExpanded ? "Show less" : "View more"
    }

    private static func truncatedBody(for value: String, limit: Int = 180) -> String {
        guard value.count > limit else { return value }
        let cutoffIndex = value.index(value.startIndex, offsetBy: limit)
        let prefix = String(value[..<cutoffIndex])
        let trimmed = prefix.replacingOccurrences(of: "\\s+\\S*$", with: "", options: .regularExpression)
        return trimmed.isEmpty ? prefix + "..." : trimmed + "..."
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
func addCardGridRows(_ cards: [NSView], to stackView: NSStackView, columns: Int = 2) {
    guard !cards.isEmpty else { return }

    for startIndex in stride(from: 0, to: cards.count, by: columns) {
        let endIndex = min(startIndex + columns, cards.count)
        let rowViews = Array(cards[startIndex..<endIndex])

        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .top
        rowStack.distribution = .fillEqually

        for card in rowViews {
            rowStack.addArrangedSubview(card)
        }

        while rowStack.arrangedSubviews.count < columns {
            let filler = NSView()
            filler.translatesAutoresizingMaskIntoConstraints = false
            rowStack.addArrangedSubview(filler)
        }

        addFullWidthArrangedSubview(rowStack, to: stackView)
    }
}

@MainActor
func makeScrollableColumn(minHeight: CGFloat) -> (scrollView: NSScrollView, contentView: FlippedContentView) {
    let contentView = FlippedContentView()
    contentView.translatesAutoresizingMaskIntoConstraints = false

    let scrollView = NSScrollView()
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.documentView = contentView
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight),
        contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
    ])

    return (scrollView, contentView)
}

@MainActor
func addFullWidthArrangedSubview(_ view: NSView, to stackView: NSStackView) {
    stackView.addArrangedSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
}

@MainActor
func makeSectionContainer(title: String, subtitle: String? = nil) -> (container: NSView, contentStack: NSStackView) {
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
    titleLabel.alignment = .left

    let headerViews: [NSView]
    if let subtitle, !subtitle.isEmpty {
        let subtitleLabel = makeSecondaryLabel(subtitle)
        headerViews = [titleLabel, subtitleLabel]
    } else {
        headerViews = [titleLabel]
    }

    let contentStack = NSStackView()
    contentStack.orientation = .vertical
    contentStack.spacing = 10
    contentStack.alignment = .width
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    let wrapper = NSStackView(views: headerViews + [contentStack])
    wrapper.orientation = .vertical
    wrapper.spacing = 10
    wrapper.alignment = .width
    wrapper.translatesAutoresizingMaskIntoConstraints = false

    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(wrapper)

    NSLayoutConstraint.activate([
        wrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        wrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        wrapper.topAnchor.constraint(equalTo: container.topAnchor),
        wrapper.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    return (container, contentStack)
}

@MainActor
func makeCategorySectionContainer(
    title: String,
    subtitle: String? = nil,
    countText: String? = nil
) -> (container: NSView, contentStack: NSStackView) {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.wantsLayer = true
    container.layer?.cornerRadius = 16
    container.layer?.borderWidth = 1
    container.layer?.borderColor = NSColor.separatorColor.cgColor
    container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45).cgColor

    let headerContainer = NSView()
    headerContainer.translatesAutoresizingMaskIntoConstraints = false
    headerContainer.wantsLayer = true
    headerContainer.layer?.cornerRadius = 12
    headerContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.82).cgColor

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
    titleLabel.alignment = .left

    let titleRow = NSStackView()
    titleRow.orientation = .horizontal
    titleRow.spacing = 10
    titleRow.alignment = .centerY
    titleRow.translatesAutoresizingMaskIntoConstraints = false
    titleRow.addArrangedSubview(titleLabel)

    if let countText, !countText.isEmpty {
        let badgeLabel = makeBadgeLabel(countText)
        let badgeContainer = NSView()
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 9
        badgeContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
        badgeContainer.addSubview(badgeLabel)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -10),
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4)
        ])
        titleRow.addArrangedSubview(badgeContainer)
    }

    titleRow.addArrangedSubview(NSView())

    let headerViews: [NSView]
    if let subtitle, !subtitle.isEmpty {
        let subtitleLabel = makeBodyLabel(subtitle)
        subtitleLabel.textColor = .secondaryLabelColor
        headerViews = [titleRow, subtitleLabel]
    } else {
        headerViews = [titleRow]
    }

    let headerStack = NSStackView(views: headerViews)
    headerStack.orientation = .vertical
    headerStack.spacing = 6
    headerStack.alignment = .width
    headerStack.translatesAutoresizingMaskIntoConstraints = false

    let contentStack = NSStackView()
    contentStack.orientation = .vertical
    contentStack.spacing = 14
    contentStack.alignment = .width
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    let separator = NSBox()
    separator.boxType = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false

    let wrapper = NSStackView(views: [headerContainer, separator, contentStack])
    wrapper.orientation = .vertical
    wrapper.spacing = 14
    wrapper.alignment = .width
    wrapper.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(wrapper)
    headerContainer.addSubview(headerStack)

    NSLayoutConstraint.activate([
        wrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        wrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        wrapper.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
        wrapper.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

        headerStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
        headerStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
        headerStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 14),
        headerStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -14)
    ])

    return (container, contentStack)
}

@MainActor
final class EmptyStateView: NSView {
    init(title: String, message: String) {
        super.init(frame: .zero)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .left

        let messageLabel = makeBodyLabel(message)
        messageLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, messageLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 112),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class ActionBannerView: NSView {
    init(title: String, message: String, buttonTitle: String? = nil, target: AnyObject? = nil, action: Selector? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.alignment = .left

        let messageLabel = makeBodyLabel(message)
        messageLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, messageLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .width
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .centerY
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.addArrangedSubview(textStack)

        if let buttonTitle, let action {
            let button = makeActionButton(buttonTitle, target: target, action: action)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            rowStack.addArrangedSubview(button)
        }

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
