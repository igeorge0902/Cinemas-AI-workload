import UIKit

@MainActor
final class ScreenEventsSummaryBannerView: UIControl {
    var onOpen: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    func configure(with summary: ScreenEventsSummary) {
        titleLabel.text = "Screen events"
        countLabel.text = summary.countLine
        accessibilityLabel = "Screen events. \(summary.countLine). Tap to view details."
        isHidden = summary.totalCount == 0
    }

    private func buildView() {
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.97)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 5)

        iconContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.22)
        iconContainer.layer.cornerRadius = 12
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "bell.badge.fill")
        iconView.tintColor = .label
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        countLabel.font = .preferredFont(forTextStyle: .caption1)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .secondaryLabel
        countLabel.numberOfLines = 2

        let labels = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        labels.axis = .vertical
        labels.spacing = 2
        labels.alignment = .leading

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.accessibilityLabel = "Dismiss screen events summary"
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [iconContainer, labels, closeButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
        addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        accessibilityTraits.insert(.button)
    }

    @objc private func openTapped() { onOpen?() }
    @objc private func dismissTapped() { onDismiss?() }
}
