import Foundation
import UIKit

enum ScreenEventType: String, Codable, CaseIterable {
    case added, updated, deleted

    var displayTitle: String {
        switch self {
        case .added: return "Added"
        case .updated: return "Updated"
        case .deleted: return "Deleted"
        }
    }

    var symbolName: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .updated: return "pencil.circle.fill"
        case .deleted: return "trash.circle.fill"
        }
    }

    var tintColor: UIColor {
        switch self {
        case .added: return .systemGreen
        case .updated: return .systemBlue
        case .deleted: return .systemRed
        }
    }
}

/// UI-facing model. Map the current server/WebSocket DTO to this type.
struct ScreenEvent: Identifiable, Hashable {
    let id: String
    let type: ScreenEventType
    let title: String
    let venue: String?
    let dateText: String?
    let previousDateText: String?

    init(id: String, type: ScreenEventType, title: String,
         venue: String? = nil, dateText: String? = nil, previousDateText: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.venue = venue
        self.dateText = dateText
        self.previousDateText = previousDateText
    }

    var detailText: String {
        [venue, dateText].compactMap { value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }
}

struct ScreenEventsSummary {
    let events: [ScreenEvent]
    var addedCount: Int { events.filter { $0.type == .added }.count }
    var updatedCount: Int { events.filter { $0.type == .updated }.count }
    var deletedCount: Int { events.filter { $0.type == .deleted }.count }
    var totalCount: Int { events.count }
    var countLine: String { "\(addedCount) added · \(updatedCount) updated · \(deletedCount) deleted" }

    var groupedEvents: [(type: ScreenEventType, events: [ScreenEvent])] {
        ScreenEventType.allCases.compactMap { type in
            let matching = events.filter { $0.type == type }
            return matching.isEmpty ? nil : (type, matching)
        }
    }
}
