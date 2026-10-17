import UIKit

@MainActor
final class ScreenEventToastView: UIControl {
    var onSelect: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    func configure(with event: ScreenEvent) {
        iconView.image = UIImage(systemName: event.type.symbolName)
        iconView.tintColor = event.type.tintColor
        switch event.type {
        case .added: titleLabel.text = "New screening added"
        case .updated: titleLabel.text = "Screening updated"
        case .deleted: titleLabel.text = "Screening removed"
        }
        detailLabel.text = [event.title, event.detailText].filter { !$0.isEmpty }.joined(separator: "\n")
        accessibilityLabel = "\(titleLabel.text ?? "Screening notification"). \(detailLabel.text ?? "")"
    }

    private func buildView() {
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.97)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.24
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 5)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 2

        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 3
        labels.alignment = .leading

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.accessibilityLabel = "Dismiss notification"
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [iconView, labels, closeButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        addTarget(self, action: #selector(selected), for: .touchUpInside)
        accessibilityTraits.insert(.button)
    }

    @objc private func selected() { onSelect?() }
    @objc private func dismissTapped() { onDismiss?() }
}
