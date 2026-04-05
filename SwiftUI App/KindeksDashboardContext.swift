import Foundation

/// Whose Kindeks dashboard is shown. Tiles stay the same; only the headline changes.
enum KindeksDashboardContext: Hashable {
    case own
    case peer(displayName: String, avatarData: Data?)
}

/// Push onto `NavigationStack` to open the same dashboard UI for a discovered peer.
struct PeerKindeksDestination: Hashable {
    let id: UUID
    let displayName: String
    let avatarData: Data?

    init(receiver: Receiver) {
        self.id = receiver.id
        self.displayName = receiver.name
        self.avatarData = receiver.avatarData
    }
}
