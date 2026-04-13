import Foundation

struct DonationGoal: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var imageData: Data?
}

enum DonationCarouselItem: Identifiable, Hashable {
    case goal(DonationGoal)
    case addOwn
    case partnerStub(Int)

    var id: String {
        switch self {
        case .goal(let g): return "g-\(g.id.uuidString)"
        case .addOwn: return "add"
        case .partnerStub(let i): return "p-\(i)"
        }
    }
}

enum DonationGoalsLocalStore {
    static let maxGoalsPerAccount = 10
    private static let ownKey = "donation_goals_own_v1"

    private static func peerKey(_ peerId: UUID) -> String {
        "donation_goals_peer_\(peerId.uuidString)"
    }

    static func loadOwn() -> [DonationGoal] {
        guard let data = UserDefaults.standard.data(forKey: ownKey),
              let decoded = try? JSONDecoder().decode([DonationGoal].self, from: data) else {
            return []
        }
        return Array(decoded.prefix(maxGoalsPerAccount))
    }

    static func saveOwn(_ goals: [DonationGoal]) {
        let trimmed = Array(goals.prefix(maxGoalsPerAccount))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: ownKey)
        }
    }

    /// First open for this peer id: seed demo goals and persist (local simulation until sync exists).
    static func loadOrSeedPeerGoals(peerId: UUID) -> [DonationGoal] {
        let key = peerKey(peerId)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([DonationGoal].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        let seeded: [DonationGoal] = [
            DonationGoal(id: UUID(), title: "Dream trip", subtitle: "Sardinia 2026", imageData: nil),
            DonationGoal(id: UUID(), title: "Kitchen refresh", subtitle: "SMEG fund", imageData: nil)
        ]
        if let data = try? JSONEncoder().encode(seeded) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return seeded
    }
}
