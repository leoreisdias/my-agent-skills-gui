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
    return label
}

@MainActor
func makeBodyLabel(_ text: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: 12)
    label.maximumNumberOfLines = 0
    label.lineBreakMode = .byWordWrapping
    return label
}

@MainActor
func makeSecondaryLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11)
    label.textColor = .secondaryLabelColor
    return label
}

@MainActor
func makeActionButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.bezelStyle = .rounded
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
func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

@MainActor
final class SkillRowBox: NSView {
    init(title: String, subtitle: String, body: String, actionButtons: [NSButton]) {
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
        titleLabel.lineBreakMode = .byTruncatingTail

        let subtitleLabel = makeSecondaryLabel(subtitle)
        let bodyLabel = makeBodyLabel(body)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let buttonRow = NSStackView(views: actionButtons)
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .leading

        let stack = NSStackView(views: [titleLabel, subtitleLabel, bodyLabel, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
final class EmptyStateView: NSView {
    init(title: String, message: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let messageLabel = makeBodyLabel(message)
        messageLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, messageLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
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
