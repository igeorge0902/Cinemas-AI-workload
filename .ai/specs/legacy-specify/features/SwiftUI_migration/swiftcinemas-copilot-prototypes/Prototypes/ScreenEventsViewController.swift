import UIKit

@MainActor
final class ScreenEventsViewController: UITableViewController {
    private let summary: ScreenEventsSummary
    var onSelectEvent: ((ScreenEvent) -> Void)?

    init(summary: ScreenEventsSummary) {
        self.summary = summary
        super.init(style: .insetGrouped)
        title = "Screen events"
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(summary:) instead.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ScreenEventCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        tableView.backgroundColor = .systemBackground
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        summary.groupedEvents.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        summary.groupedEvents[section].events.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let group = summary.groupedEvents[section]
        return "\(group.type.displayTitle) (\(group.events.count))"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScreenEventCell", for: indexPath)
        let group = summary.groupedEvents[indexPath.section]
        let event = group.events[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = event.title
        content.secondaryText = event.detailText.isEmpty ? group.type.displayTitle : event.detailText
        content.image = UIImage(systemName: group.type.symbolName)
        content.imageProperties.tintColor = group.type.tintColor
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectEvent?(summary.groupedEvents[indexPath.section].events[indexPath.row])
    }
}
